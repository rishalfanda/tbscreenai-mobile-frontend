import 'package:flutter/foundation.dart';

import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/data/onnx/inference_result.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/data/onnx/segmentation_overlay.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/segmentation_overlays.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';

/// Runs inference on-device against the currently-installed, verified ONNX
/// model bundle (installed via Sync Center — see `ModelUpdatePipeline`).
///
/// Live screening requires a locally installed bundle; no network fallback.
class OnDeviceDiagnosisRepository implements DiagnosisRepository {
  OnDeviceDiagnosisRepository(this._engine);

  final OnnxInferenceEngine _engine;

  /// No on-device symptom source exists — same seed data every repository uses.
  @override
  Future<List<String>> getSymptomOptions() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.symptomOptions));

  @override
  Future<DiagnosisOutcome> runInference({required XrayImage image}) async {
    try {
      await _engine.ready;
    } catch (_) {
      throw const LocalModelUnavailable();
    }
    if (!_engine.hasBundle) throw const LocalModelUnavailable();
    final stopwatch = Stopwatch()..start();
    final result = await _engine.run(image.bytes);
    stopwatch.stop();
    final overlays = await renderSegmentationOverlays(
      xrayBytes: image.bytes,
      result: result,
    );
    if (overlays == null) {
      throw const FormatException('Segmentation images could not be rendered.');
    }
    final activeKey = await _engine.modelStore.activeVersion();
    final meta = activeKey == null
        ? null
        : await _engine.modelStore.readBundleMeta(activeKey);
    return outcomeFromInferenceResult(
      result,
      stopwatch.elapsed,
      segmentation: overlays,
      imageSha256: image.checksumSha256,
      bundleChannel: meta?['version'] == result.bundleVersion
          ? (meta?['channel'] as String?)
          : null,
      appVersion: const String.fromEnvironment('APP_VERSION'),
    );
  }
}

/// Names this app's `DiagnosisOutcome` tracks. Matched case-insensitively
/// against the bundle manifest's `render.lesion_names` — a bundle revision
/// need not carry every one of these classes.
const Map<String, String> _lesionAliases = {
  'consolidation': 'consolidation',
  'konsolidasi': 'consolidation',
  'cavity': 'cavity',
  'kavitas': 'cavity',
  'effusion': 'effusion',
  'efusi': 'effusion',
  'fibrotic': 'fibrotic',
  'fibrotik': 'fibrotic',
  'fibrosis': 'fibrotic',
  'calcification': 'calcification',
  'kalsifikasi': 'calcification',
  'infiltrate': 'infiltrate',
  'infiltrat': 'infiltrate',
};

/// Maps one chain run onto the app's fixed `DiagnosisOutcome` shape. A
/// top-level function (rather than a private method) so it's independently
/// testable, mirroring `http_diagnosis_repository.dart`'s `_outcomeFromJson`.
@visibleForTesting
DiagnosisOutcome outcomeFromInferenceResult(
  InferenceResult result,
  Duration elapsed, {
  SegmentationOverlays? segmentation,
  String? imageSha256,
  String? bundleChannel,
  String? appVersion,
  DateTime? inferredAt,
}) {
  if (result.lungMask.length != result.labelMap.length ||
      (result.hasLesionConfidence &&
          result.confidence.length != result.labelMap.length)) {
    throw const FormatException(
      'Inference mask and confidence dimensions differ.',
    );
  }
  final lungArea = result.lungAreaPx;
  final lesionCounts = result.lesionPixelCounts;
  if (lungArea <= 0 ||
      !result.probabilityFused.isFinite ||
      result.probabilityFused < 0 ||
      result.probabilityFused > 1) {
    throw const FormatException(
      'Inference output has no valid lung area or probability.',
    );
  }
  final percentages = {for (final name in _lesionAliases.values) name: 0.0};
  final seen = <String>{};
  for (var index = 0; index < result.lesionNames.length; index++) {
    final canonical =
        _lesionAliases[result.lesionNames[index].trim().toLowerCase()];
    if (canonical == null || !seen.add(canonical)) {
      throw const FormatException(
        'Unsupported or duplicate lesion class in model manifest.',
      );
    }
    final percent = 100.0 * lesionCounts[index] / lungArea;
    if (percent > 100) {
      throw const FormatException('Lesion area exceeds lung area.');
    }
    percentages[canonical] = percent;
  }
  if (result.labelMap.any(
    (label) => label < -1 || label >= result.lesionNames.length,
  )) {
    throw const FormatException('Unknown lesion class in inference output.');
  }
  bool probability(double value) => value.isFinite && value >= 0 && value <= 1;
  final when = (inferredAt ?? DateTime.now()).toUtc();
  // Mean maximum-softmax confidence over predicted lesion pixels within lungs.
  final lesionConfidences = <double>[];
  if (result.hasLesionConfidence) {
    for (var i = 0; i < result.labelMap.length; i++) {
      if (result.labelMap[i] >= 0 &&
          result.lungMask[i] != 0 &&
          probability(result.confidence[i])) {
        lesionConfidences.add(result.confidence[i]);
      }
    }
  }
  final provenance = <String, dynamic>{
    'schema_version': 1,
    'bundle_version': result.bundleVersion,
    'rf_model': result.rfModel,
    'inferred_at': when.toIso8601String(),
    'p_fused': result.probabilityFused,
    if (probability(result.probabilityCnn)) 'p_cnn': result.probabilityCnn,
    if (probability(result.probabilityRf)) 'p_rf': result.probabilityRf,
    if (lesionConfidences.isNotEmpty)
      'lesion_confidence':
          lesionConfidences.reduce((a, b) => a + b) / lesionConfidences.length,
    'image_sha256': ?imageSha256,
    if (bundleChannel != null && bundleChannel.isNotEmpty)
      'bundle_channel': bundleChannel,
    if (appVersion != null && appVersion.isNotEmpty) 'app_version': appVersion,
  };

  return DiagnosisOutcome(
    isPositive: result.decisionIsTb,
    confidence: (result.positiveConfidence * 100).round().clamp(0, 100),
    processingTime: '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s',
    processingTimeMs: elapsed.inMilliseconds,
    modelVersion: result.bundleVersion,
    createdAt: when,
    isMock: false,
    consolidation: percentages['consolidation']!,
    cavity: percentages['cavity']!,
    effusion: percentages['effusion']!,
    fibrotic: percentages['fibrotic']!,
    calcification: percentages['calcification']!,
    infiltrate: percentages['infiltrate']!,
    provenance: provenance,
    segmentation: segmentation,
  );
}
