import 'package:myapp/data/onnx/bundle_manifest.dart';
import 'package:myapp/data/onnx/bundle_store.dart';
import 'package:myapp/data/onnx/ort_session_pool.dart';
import 'package:myapp/data/onnx/tensor.dart';

/// Generic, manifest-driven ONNX chain runner — the Dart mirror of
/// `week-1/pipeline-app/build/chain_runner.py`.
///
/// It contains **no** TB-specific logic: it walks `manifest.pipeline` in order,
/// wires named tensors between steps (`@input` / `<step>.<name>`), maps each
/// session's outputs positionally, and returns the tensors named by
/// `manifest.outputs`. Every threshold / class count / feature name lives in the
/// bundle.
class OrtChainExecutor {
  OrtChainExecutor({required this.store, required this.pool});

  final BundleStore store;
  final OrtSessionPool pool;

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
    _providerUsed.clear();
  }

  final Map<String, OrtSessionHandle> _sessions = {};
  final Map<String, String> _providerUsed = {};

  /// Which EP preference each model file was loaded with (diagnostics/UI).
  Map<String, String> get providersUsed => Map.unmodifiable(_providerUsed);

  /// Wall-clock spent inside each pipeline step's `session.run` (+ its lazy
  /// session load, the first time). Keyed by `step.id`.
  final Map<String, Duration> stepTimings = {};

  /// Wall-clock spent creating each model's session (keyed by `step.id`).
  final Map<String, Duration> sessionLoadTimings = {};

  /// One run of the chain.
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
    final produced = <String, Map<String, Tensor>>{};

    for (final step in _m.pipeline) {
      onStep?.call(step.id);
      final modelFile = step.isRfActive ? rfFile : step.model;

      final sw = Stopwatch()..start();
      final session = await _session(step, modelFile);
      final loaded = sw.elapsed;
      if (sessionLoadTimings[step.id] == null) {
        sessionLoadTimings[step.id] = loaded;
      }

      final feeds = <String, Tensor>{};
      step.inputs.forEach((inputName, ref) {
        feeds[inputName] = _resolve(ref, decodedImage, produced);
      });

      final outputs = await session.run(feeds);
      stepTimings[step.id] = sw.elapsed;

      final stepOut = <String, Tensor>{};
      for (var i = 0; i < step.outputs.length && i < outputs.length; i++) {
        stepOut[step.outputs[i]] = outputs[i];
      }
      produced[step.id] = stepOut;

      // The two segmentation nets are the memory hogs; drop them once their
      // step has run (sequential chain -> safe).
      final stem = _stem(modelFile);
      if (stem == 'seg_lung' || stem == 'seg_lesion') {
        final s = _sessions.remove(modelFile);
        if (s != null) await s.close();
      }
    }

    final result = <String, Tensor>{};
    _m.outputs.forEach((uiName, ref) {
      final parts = ref.split('.');
      final step = produced[parts[0]];
      if (step != null && step[parts[1]] != null) {
        result[uiName] = step[parts[1]]!;
      }
    });
    return result;
  }

  Tensor _resolve(
    String ref,
    Tensor image,
    Map<String, Map<String, Tensor>> produced,
  ) {
    if (ref == '@input') return image;
    final parts = ref.split('.');
    return produced[parts[0]]![parts[1]]!;
  }

  Future<OrtSessionHandle> _session(PipelineStep step, String file) async {
    final existing = _sessions[file];
    if (existing != null) return existing;
    final session = await pool.createSession(
      store.modelPath(file),
      preferredProviders: _forceCpu ? const ['cpu'] : step.epPreference,
      label: file,
    );
    _sessions[file] = session;
    _providerUsed[file] = session.activeProvider;
    logOrt('$file -> ${session.activeProvider}');
    return session;
  }

  static String _stem(String file) => file.split('/').last.split('.').first;

  Future<void> dispose() async {
    for (final s in _sessions.values) {
      await s.close();
    }
    _sessions.clear();
  }
}
