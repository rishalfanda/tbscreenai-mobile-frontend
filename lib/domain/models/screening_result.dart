import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';

/// The result and the exact input that produced it travel together.
class ScreeningResult {
  ScreeningResult({required DiagnosisDraft draft, required this.outcome})
    : draft = draft.copyWith();

  final DiagnosisDraft draft;
  final DiagnosisOutcome outcome;
}
