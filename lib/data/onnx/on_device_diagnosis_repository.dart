import 'package:flutter/foundation.dart';

import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/data/onnx/inference_result.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';

/// Runs inference on-device against the currently-installed, verified ONNX
/// model bundle (installed via Sync Center — see `ModelUpdatePipeline`).
///
/// Only used directly when a bundle is active; `HybridDiagnosisRepository` is
/// what the app actually wires into `DiagnosisRepository`, falling back to
/// the mock/http repository when no bundle is installed.
class OnDeviceDiagnosisRepository implements DiagnosisRepository {
  OnDeviceDiagnosisRepository(this._engine);

  final OnnxInferenceEngine _engine;

  /// No on-device symptom source exists — same seed data every repository uses.
  @override
  Future<List<String>> getSymptomOptions() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.symptomOptions));

  @override
  Future<DiagnosisOutcome> runInference({required XrayImage image}) async {
    final stopwatch = Stopwatch()..start();
    final result = await _engine.run(image.bytes);
    stopwatch.stop();
    return outcomeFromInferenceResult(result, stopwatch.elapsed);
  }
}

/// Names this app's `DiagnosisOutcome` tracks. Matched case-insensitively
/// against the bundle manifest's `render.lesion_names` — a bundle revision
/// need not carry every one of these classes.
const List<String> _trackedLesionNames = [
  'consolidation',
  'cavity',
  'effusion',
  'fibrotic',
  'calcification',
];

/// Maps one chain run onto the app's fixed `DiagnosisOutcome` shape. A
/// top-level function (rather than a private method) so it's independently
/// testable, mirroring `http_diagnosis_repository.dart`'s `_outcomeFromJson`.
@visibleForTesting
DiagnosisOutcome outcomeFromInferenceResult(
  InferenceResult result,
  Duration elapsed,
) {
  final lungArea = result.lungAreaPx;
  final lesionCounts = result.lesionPixelCounts;
  final percentages = <String, double>{};
  for (final tracked in _trackedLesionNames) {
    final index = result.lesionNames.indexWhere(
      (name) => name.toLowerCase() == tracked,
    );
    percentages[tracked] = (index >= 0 && lungArea > 0)
        ? 100.0 * lesionCounts[index] / lungArea
        : 0.0;
  }

  return DiagnosisOutcome(
    isPositive: result.decisionIsTb,
    confidence: (result.positiveConfidence * 100).round().clamp(0, 100),
    processingTime: '${(elapsed.inMilliseconds / 1000).toStringAsFixed(1)}s',
    modelVersion: result.bundleVersion,
    createdAt: DateTime.now(),
    isMock: false,
    consolidation: percentages['consolidation']!,
    cavity: percentages['cavity']!,
    effusion: percentages['effusion']!,
    fibrotic: percentages['fibrotic']!,
    calcification: percentages['calcification']!,
  );
}
