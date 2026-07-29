import 'package:myapp/domain/models/validation_case.dart';

/// Contract for doctor validation of AI diagnoses.
abstract class ValidationRepository {
  Future<List<ValidationCase>> getCases();

  /// Persists the doctor's verdict. [status]: "agreed" | "disagreed" | "pending".
  Future<void> submitValidation({
    required String id,
    required String status,
    String? note,
  });
}
