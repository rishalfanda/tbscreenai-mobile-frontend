import 'dart:async';

import 'package:myapp/data/onnx/async_semaphore.dart';
import 'package:myapp/data/onnx/bundle_manifest.dart';
import 'package:myapp/data/onnx/bundle_store.dart';
import 'package:myapp/data/onnx/ort_session_pool.dart';
import 'package:myapp/data/onnx/tensor.dart';

/// Generic, manifest-driven ONNX dynamic DAG runner — executes independent
/// pipeline steps concurrently using an event-driven Completer pattern throttled
/// by an [AsyncSemaphore].
///
/// It contains **no** TB-specific logic: it builds an execution graph from
/// `step.inputs` (`@input` / `<step>.<name>`), maps each session's outputs
/// positionally, and returns the tensors named by `manifest.outputs`.
class OrtChainExecutor {
  OrtChainExecutor({
    required this.store,
    required this.pool,
    this.concurrencyLimit = 2,
  });

  final BundleStore store;
  final OrtSessionPool pool;

  /// Maximum number of model sessions running inference concurrently.
  final int concurrencyLimit;

  BundleManifest get _m => store.manifest;

  /// When true, ignore each step's `ep_preference` and run every model on the
  /// CPU provider. NNAPI / XNNPACK mis-handle the transformer-based seg nets
  /// (and `.ort`-format layout transforms), so CPU is the reliable default.
  bool _forceCpu = true;

  bool get forceCpu => _forceCpu;

  /// Switch EP strategy. Drops cached sessions if the strategy actually changed
  /// so the next run rebuilds them with the new provider list.
  Future<void> setForceCpu(bool value) async {
    if (value == _forceCpu) return;
    _forceCpu = value;
    for (final s in _sessions.values) {
      await s.close();
    }
    _sessions.clear();
    _sessionFutures.clear();
    _providerUsed.clear();
  }

  final Map<String, OrtSessionHandle> _sessions = {};
  final Map<String, Future<OrtSessionHandle>> _sessionFutures = {};
  final Map<String, String> _providerUsed = {};

  /// Which EP preference each model file was loaded with (diagnostics/UI).
  Map<String, String> get providersUsed => Map.unmodifiable(_providerUsed);

  /// Wall-clock spent inside each pipeline step's `session.run` (+ its lazy
  /// session load, the first time). Keyed by `step.id`.
  final Map<String, Duration> stepTimings = {};

  /// Wall-clock spent creating each model's session (keyed by `step.id`).
  final Map<String, Duration> sessionLoadTimings = {};

  /// One run of the chain using a dynamic DAG scheduler.
  ///
  /// [decodedImage] is the bundle's single input: `uint8` NHWC `[1, H, W, 3]`
  /// RGB, produced by decoding the X-ray. Nothing else is pre-processed here —
  /// resize / normalise happens inside `preprocess.ort`.
  ///
  /// [onStep] fires with each `step.id` just before it runs (UI progress).
  Future<Map<String, Tensor>> run(
    Tensor decodedImage, {
    String? rfDataset,
    void Function(String stepId)? onStep,
  }) async {
    stepTimings.clear();
    sessionLoadTimings.clear();

    final rfFile = _m.resolveRfFile(rfDataset);
    final semaphore = AsyncSemaphore(concurrencyLimit);

    final nodeCompleters = <String, Completer<Map<String, Tensor>>>{
      for (final step in _m.pipeline) step.id: Completer<Map<String, Tensor>>(),
    };

    // Schedule all nodes in the DAG; dependencies gate execution order
    for (final step in _m.pipeline) {
      unawaited(
        _scheduleNode(
          step: step,
          decodedImage: decodedImage,
          rfFile: rfFile,
          nodeCompleters: nodeCompleters,
          semaphore: semaphore,
          onStep: onStep,
        ),
      );
    }

    // Await all nodes in the pipeline to ensure completion and propagate any failures
    await Future.wait(nodeCompleters.values.map((c) => c.future));

    // Map declared outputs from the produced node outputs
    final result = <String, Tensor>{};
    for (final entry in _m.outputs.entries) {
      final parts = entry.value.split('.');
      final nodeId = parts[0];
      final outputKey = parts[1];
      final stepOut = await nodeCompleters[nodeId]!.future;
      final tensor = stepOut[outputKey];
      if (tensor != null) {
        result[entry.key] = tensor;
      }
    }
    return result;
  }

  Future<void> _scheduleNode({
    required PipelineStep step,
    required Tensor decodedImage,
    required String rfFile,
    required Map<String, Completer<Map<String, Tensor>>> nodeCompleters,
    required AsyncSemaphore semaphore,
    void Function(String stepId)? onStep,
  }) async {
    final completer = nodeCompleters[step.id]!;
    try {
      // 1. Collect and wait for parent dependencies
      final parentFutures = <Future<Map<String, Tensor>>>[];
      for (final source in step.inputs.values) {
        if (source != '@input') {
          final parentId = source.split('.').first;
          final parentCompleter = nodeCompleters[parentId];
          if (parentCompleter == null) {
            throw StateError(
              'Pipeline step "${step.id}" depends on unknown step "$parentId"',
            );
          }
          parentFutures.add(parentCompleter.future);
        }
      }

      if (parentFutures.isNotEmpty) {
        await Future.wait(parentFutures);
      }

      onStep?.call(step.id);

      // 2. Resolve input feeds
      final feeds = <String, Tensor>{};
      for (final entry in step.inputs.entries) {
        final source = entry.value;
        if (source == '@input') {
          feeds[entry.key] = decodedImage;
        } else {
          final parts = source.split('.');
          final parentId = parts[0];
          final outputKey = parts[1];
          final parentOutputs = await nodeCompleters[parentId]!.future;
          final tensor = parentOutputs[outputKey];
          if (tensor == null) {
            throw StateError(
              'Parent step "$parentId" did not produce output "$outputKey"',
            );
          }
          feeds[entry.key] = tensor;
        }
      }

      // 3. Run session under concurrency permit
      final modelFile = step.isRfActive ? rfFile : step.model;
      final outputs = await semaphore.withPermit(() async {
        final sw = Stopwatch()..start();
        final session = await _session(step, modelFile);
        final loaded = sw.elapsed;
        if (sessionLoadTimings[step.id] == null) {
          sessionLoadTimings[step.id] = loaded;
        }

        final result = await session.run(feeds);
        stepTimings[step.id] = sw.elapsed;
        return result;
      });

      // 4. Map positional outputs to declared names
      final stepOut = <String, Tensor>{};
      for (var i = 0; i < step.outputs.length && i < outputs.length; i++) {
        stepOut[step.outputs[i]] = outputs[i];
      }

      completer.complete(stepOut);

      // 5. Immediately drop memory-heavy segmentation sessions once executed
      final stem = _stem(modelFile);
      if (stem == 'seg_lung' || stem == 'seg_lesion') {
        _sessionFutures.remove(modelFile);
        final s = _sessions.remove(modelFile);
        if (s != null) await s.close();
      }
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  Future<OrtSessionHandle> _session(PipelineStep step, String file) {
    return _sessionFutures.putIfAbsent(file, () async {
      final session = await pool.createSession(
        store.modelPath(file),
        preferredProviders: _forceCpu ? const ['cpu'] : step.epPreference,
        label: file,
      );
      _sessions[file] = session;
      _providerUsed[file] = session.activeProvider;
      logOrt('$file -> ${session.activeProvider}');
      return session;
    });
  }

  static String _stem(String file) => file.split('/').last.split('.').first;

  Future<void> dispose() async {
    for (final s in _sessions.values) {
      await s.close();
    }
    _sessions.clear();
    _sessionFutures.clear();
  }
}
