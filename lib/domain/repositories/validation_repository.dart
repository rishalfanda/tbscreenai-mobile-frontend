import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/models/clinical_conflict.dart';
import 'package:myapp/domain/models/validation_case.dart';

enum ValidationSubmissionState { demo, queued, synced, conflict }

class ValidationSubmission {
  const ValidationSubmission(this.state);

  final ValidationSubmissionState state;
}

/// Contract for doctor validation of AI diagnoses.
abstract class ValidationRepository {
  Future<List<ValidationCase>> getCases();

  Stream<int> watchPendingCount() async* {
    yield (await getCases()).where((row) => row.status == 'pending').length;
  }

  /// Persists the doctor's verdict. [status]: "agreed" | "disagreed" | "pending".
  Future<ValidationSubmission> submitValidation({
    required String id,
    required String status,
    String? note,
  });

  Future<List<ClinicalConflict>> getConflicts() async => const [];

  Future<void> resolveConflict({
    required ClinicalConflict conflict,
    required ConflictDecision decision,
  }) {
    throw UnsupportedError('Conflict resolution is unavailable.');
  }
}

/// Local numeric review, deliberately separate from the legacy server verdict.
abstract interface class NumericValidationRepository {
  Future<void> submitScore({
    required String id,
    required int score,
    String? status,
    String? note,
  });
  Future<XrayImage?> loadCaseImage(String id);
}
