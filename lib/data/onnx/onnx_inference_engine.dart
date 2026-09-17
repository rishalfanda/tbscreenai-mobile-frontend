import 'dart:typed_data';

import 'package:myapp/data/models_ota/model_store.dart';
import 'package:myapp/data/onnx/bundle_manifest.dart';
import 'package:myapp/data/onnx/bundle_store.dart';
import 'package:myapp/data/onnx/image_input.dart';
import 'package:myapp/data/onnx/inference_result.dart';
import 'package:myapp/data/onnx/ort_chain_executor.dart';
import 'package:myapp/data/onnx/ort_session_pool.dart';

/// Opens the currently-active on-device model bundle and runs the ONNX chain
/// against it. One instance lives for the app's lifetime (see `app.dart`),
/// shared by the diagnosis repository and the model-update pipeline so both
/// always agree on which bundle is active.
///
/// Trimmed from `inf_app`'s `InferenceRunner`: no memory probe, no overlay
/// rendering — this app's `DiagnosisOutcome` has no slot for either.
class OnnxInferenceEngine {
  final OrtSessionPool _pool = OrtSessionPool();

  BundleStore? _store;
  OrtChainExecutor? _executor;

  bool get hasBundle => _executor != null && _store != null;

  BundleManifest? get manifest => _store?.manifest;

  bool get integrityVerified => _store?.integrityVerified ?? false;

  /// Run every model on CPU, ignoring the manifest's `ep_preference`. NNAPI /
  /// XNNPACK produce wrong shapes for the transformer seg nets and fail to
  /// load `.ort` layout-transformed graphs, so this app never turns it off.
  bool get forceCpu => true;

  /// Opens the `ModelStore`'s currently-active bundle. Safe to call
  /// repeatedly — the update pipeline calls it after every activation /
  /// rollback. Returns `false` when no bundle is active.
  Future<bool> init() async {
    await _executor?.dispose();
    _executor = null;
    _store = null;

    final dir = await ModelStore().activeBundleDir();
    if (dir == null) return false;

    final store = await BundleStore.open(dir);
    final executor = OrtChainExecutor(store: store, pool: _pool);
    await executor.setForceCpu(forceCpu);

    _store = store;
    _executor = executor;
    return true;
  }

  /// Run the pipeline on [imageBytes].
  Future<InferenceResult> run(Uint8List imageBytes) async {
    final executor = _executor;
    final store = _store;
    if (executor == null || store == null) {
      throw StateError(
        'No model bundle installed — install one from Sync Center first.',
      );
    }

    final input = store.manifest.input;
    if (input.layout.toUpperCase() != 'NHWC' ||
        input.channels.toUpperCase() != 'RGB') {
      throw StateError(
        'bundle input is ${input.layout}/${input.channels}; this app only '
        'feeds NHWC/RGB pixels',
      );
    }

    final decoded = await decodeForBundle(imageBytes);
    final out = await executor.run(decoded.toTensor());

    return InferenceResult.fromChainOutputs(
      out,
      manifest: store.manifest,
      elapsed: Duration.zero,
      providersUsed: executor.providersUsed,
      stepTimings: Map.of(executor.stepTimings),
      rfModel: store.manifest.rfActive,
    );
  }

  /// Runs the chain once against a bundled sample and asserts the outputs are
  /// finite and in range. Throws on any failure — the install pipeline
  /// catches this to trigger rollback.
  Future<void> smokeTest(Uint8List sampleBytes) async {
    final r = await run(sampleBytes);

    void check(bool ok, String why) {
      if (!ok) throw StateError('smoke test failed: $why');
    }

    bool prob(double p) => p.isFinite && p >= 0 && p <= 1;

    check(prob(r.probabilityFused), 'P(TB) fused = ${r.probabilityFused}');
    for (final b in [r.probabilityCnn, r.probabilityRf]) {
      check(b == -1.0 || prob(b), 'branch probability = $b');
    }
    final n = r.gridSize[0] * r.gridSize[1];
    check(r.lungMask.length == n, 'lung mask ${r.lungMask.length} px != $n');
    check(
      r.lungMask.every((v) => v == 0 || v == 1),
      'lung mask is not binary',
    );
    check(
      r.lungAreaPx > 0 && r.lungAreaPx < n,
      'degenerate lung mask (${r.lungAreaPx}/$n px)',
    );
    check(r.featureVector.every((x) => x.isFinite), 'non-finite feature value');
  }

  Future<void> dispose() async {
    await _executor?.dispose();
  }
}
