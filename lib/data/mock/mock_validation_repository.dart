import 'package:flutter/foundation.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/validation_case.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';

/// Mock validation cases. getCases() is synchronous (no loading flash);
/// submitValidation keeps the 500ms simulated latency the screen had.
class MockValidationRepository extends ValidationRepository {
  @override
  Future<List<ValidationCase>> getCases() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.validationCases));

  @override
  Future<ValidationSubmission> submitValidation({
    required String id,
    required String status,
    String? note,
  }) {
    // Same artificial delay the screen used before the refactor.
    return Future<ValidationSubmission>.delayed(
      const Duration(milliseconds: 500),
      () => const ValidationSubmission(ValidationSubmissionState.demo),
    );
  }
}
