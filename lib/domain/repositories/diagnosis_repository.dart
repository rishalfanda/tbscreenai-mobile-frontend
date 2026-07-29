import 'package:myapp/domain/models/diagnosis_outcome.dart';

/// Contract for AI diagnosis inference.
abstract class DiagnosisRepository {
  Future<List<String>> getSymptomOptions();

  /// Runs inference on the attached image and returns the outcome.
  /// Mock: 3s simulated delay with randomized findings.
  Future<DiagnosisOutcome> runInference({required String imageLabel});
}
