import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/xray_image.dart';

/// Contract for AI diagnosis inference.
abstract class DiagnosisRepository {
  Future<List<String>> getSymptomOptions();

  /// Runs inference over [image] and returns the outcome.
  ///
  /// Takes the image itself, not a filename. The previous signature accepted a
  /// `String imageLabel`, which no networked implementation could act on — so
  /// the backend's `/diagnoses/infer` had never been called by any client,
  /// despite both sides claiming to implement it.
  Future<DiagnosisOutcome> runInference({required XrayImage image});
}
