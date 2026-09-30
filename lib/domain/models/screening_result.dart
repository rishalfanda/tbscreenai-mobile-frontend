import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';

enum ScreeningSaveStatus {
  demo,
  unsaved,
  saving,
  pendingSync,
  saved,
  conflict,
  failed,
}

/// The result and the exact input that produced it travel together.
class ScreeningResult {
  ScreeningResult({
    required DiagnosisDraft draft,
    required this.outcome,
    this.id,
    this.imageReference,
    this.saveStatus = ScreeningSaveStatus.unsaved,
    this.persistenceError,
  }) : draft = draft.copyWith();

  final DiagnosisDraft draft;
  final DiagnosisOutcome outcome;
  final String? id;
  final String? imageReference;
  final ScreeningSaveStatus saveStatus;
  final String? persistenceError;

  bool get requiresLeaveConfirmation =>
      saveStatus == ScreeningSaveStatus.unsaved ||
      saveStatus == ScreeningSaveStatus.saving ||
      saveStatus == ScreeningSaveStatus.pendingSync ||
      saveStatus == ScreeningSaveStatus.failed ||
      saveStatus == ScreeningSaveStatus.conflict;

  ScreeningResult copyWith({
    String? id,
    String? imageReference,
    ScreeningSaveStatus? saveStatus,
    Object? persistenceError = _unset,
  }) => ScreeningResult(
    draft: draft,
    outcome: outcome,
    id: id ?? this.id,
    imageReference: imageReference ?? this.imageReference,
    saveStatus: saveStatus ?? this.saveStatus,
    persistenceError: identical(persistenceError, _unset)
        ? this.persistenceError
        : persistenceError as String?,
  );
}

const Object _unset = Object();
