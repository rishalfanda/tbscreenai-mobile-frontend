import 'package:myapp/domain/models/clinical_conflict.dart';

/// Numeric PR40 conflict recovery. A legacy trust score is never converted to
/// a lesion rating; the clinician must explicitly supply a new rating.
abstract interface class NumericValidationConflictRepository {
  Future<void> resolveNumericConflict({
    required ClinicalConflict conflict,
    required ConflictDecision decision,
    String? status,
    int? lesionRating,
    String? note,
  });
}
