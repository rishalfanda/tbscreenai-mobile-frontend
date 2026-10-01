// Resetting the diagnosis form is destructive and irreversible (it clears
// patient data, the attached X-ray, and any analysis outcome), so it must
// be gated behind a confirmation dialog rather than firing on a single tap.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/diagnosis_input_tab.dart';
import 'package:myapp/state/diagnosis_provider.dart';

Widget _app(DiagnosisProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: Scaffold(
        body: DiagnosisInputTab(
          onAnalyzeSuccess: () {},
          pickImage: () async => null,
          hasModelOverride: true,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping reset shows a confirmation dialog first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = DiagnosisProvider(MockDiagnosisRepository())
      ..updatePatientName('Patient A');
    await tester.pumpWidget(_app(provider));

    await tester.ensureVisible(find.byKey(const Key('reset-button')));
    await tester.tap(find.byKey(const Key('reset-button')));
    await tester.pump();

    expect(find.byKey(const Key('reset-confirm-dialog')), findsOneWidget);
    // Nothing is cleared yet — the dialog is still awaiting a choice.
    expect(provider.draft.patientName, 'Patient A');
  });

  testWidgets('cancelling the dialog leaves all data untouched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = DiagnosisProvider(MockDiagnosisRepository())
      ..updatePatientName('Patient A')
      ..attachPlaceholderImage('xray.png');
    await tester.pumpWidget(_app(provider));

    await tester.ensureVisible(find.byKey(const Key('reset-button')));
    await tester.tap(find.byKey(const Key('reset-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reset-confirm-cancel-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reset-confirm-dialog')), findsNothing);
    expect(provider.draft.patientName, 'Patient A');
    expect(provider.hasImage, isTrue);
    expect(find.text('Patient A'), findsOneWidget);
  });

  testWidgets('confirming the dialog clears the form and provider state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = DiagnosisProvider(MockDiagnosisRepository())
      ..updatePatientName('Patient A')
      ..attachPlaceholderImage('xray.png');
    await tester.pumpWidget(_app(provider));

    await tester.ensureVisible(find.byKey(const Key('reset-button')));
    await tester.tap(find.byKey(const Key('reset-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('reset-confirm-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reset-confirm-dialog')), findsNothing);
    expect(provider.draft.patientName, '');
    expect(provider.hasImage, isFalse);
    expect(provider.lastOutcome, isNull);
    expect(find.text('Patient A'), findsNothing);
  });
}
