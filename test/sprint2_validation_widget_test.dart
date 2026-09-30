import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/domain/models/clinical_conflict.dart';
import 'package:myapp/domain/models/validation_case.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/validation/presentation/validation_screen.dart';

ValidationCase _case(String id, {bool conflict = false}) => ValidationCase(
  id: id,
  name: 'Patient $id',
  initials: id,
  age: 34,
  gender: 'Female',
  aiScore: 87,
  diagnosisDate: '2026-09-30',
  status: 'pending',
  hasConflict: conflict,
  findings: const ValidationFindings(
    consolidation: 0,
    cavity: 0,
    effusion: 0,
    fibrotic: 0,
    calcification: 0,
  ),
);

class _Repository extends ValidationRepository {
  _Repository({this.conflicted = false});
  final bool conflicted;
  final completion = Completer<ValidationSubmission>();
  String? submittedId;
  String? submittedNote;
  ConflictDecision? decision;
  @override
  Future<List<ValidationCase>> getCases() async => [
    _case('A', conflict: conflicted),
    if (!conflicted) _case('B'),
  ];
  @override
  Future<ValidationSubmission> submitValidation({
    required String id,
    required String status,
    String? note,
  }) {
    submittedId = id;
    submittedNote = note;
    return completion.future;
  }

  @override
  Future<List<ClinicalConflict>> getConflicts() async => conflicted
      ? [
          const ClinicalConflict(
            clientOpId: 'op',
            diagnosisId: 'A',
            localStatus: 'disagreed',
            localNote: 'Local note',
            baseVersion: 4,
            detail: 'Server changed',
            serverStatus: 'agreed',
            serverNote: 'Server note',
            serverVersion: 7,
          ),
        ]
      : [];
  @override
  Future<void> resolveConflict({
    required ClinicalConflict conflict,
    required ConflictDecision decision,
  }) async {
    this.decision = decision;
  }
}

Future<void> _mount(WidgetTester tester, _Repository repository) async {
  tester.view.physicalSize = const Size(1900, 982);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<ValidationRepository>.value(
      value: repository,
      child: const MaterialApp(home: ValidationScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    'Keep server': ConflictDecision.keepServer,
    'Reapply local': ConflictDecision.reapplyLocal,
    'Cancel / keep open': ConflictDecision.cancel,
  }.entries) {
    testWidgets('FE-109 ${entry.key} requires confirmation', (tester) async {
      final repository = _Repository(conflicted: true);
      await _mount(tester, repository);
      final action = find.text(entry.key);
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(find.text('Note: Local note'), findsOneWidget);
      expect(find.text('Note: Server note'), findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(repository.decision, isNull);
      expect(find.text('Confirm conflict decision'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repository.decision, entry.value);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'FE-107 switching case while verdict is in flight preserves selection and note',
    (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await tester.enterText(find.byType(TextField).last, 'Note A');
      final agree = find.text('Agree with AI Result');
      await tester.ensureVisible(agree);
      await tester.tap(agree);
      await tester.pump();
      expect(repository.submittedId, 'A');
      expect(repository.submittedNote, 'Note A');
      await tester.tap(find.text('Patient B').first);
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'Note B');
      repository.completion.complete(
        const ValidationSubmission(ValidationSubmissionState.queued),
      );
      await tester.pumpAndSettle();
      expect(find.text('Note B'), findsOneWidget);
      expect(
        find.text('Saved locally; the verdict is pending sync.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
