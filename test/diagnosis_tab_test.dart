// Tab-navigation behavior of the combined diagnosis screen: the result tab
// is unreachable until a real analysis exists, a successful analysis jumps
// there automatically, and the input tab locks (and the view snaps back)
// once an outcome is cleared. There's no visible tab bar, so tests reach
// the hidden tab boundary the same way a user would: swiping the body
// (blocked by NeverScrollableScrollPhysics while no outcome exists).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_screen.dart';
import 'package:myapp/state/diagnosis_provider.dart';

Widget _app(DiagnosisProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: Scaffold(
        body: DiagnosisScreen(
          pickImage: () async => null,
          hasModelOverride: true,
        ),
      ),
    ),
  );
}

void _seedRequiredFields(DiagnosisProvider provider) {
  provider
    ..updatePatientName('Patient A')
    ..updateGender('Female')
    ..updateAge(34)
    ..updateHeight(160)
    ..updateWeight(55);
}

void main() {
  testWidgets('the result tab is disabled and unreachable with no outcome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(DiagnosisProvider(MockDiagnosisRepository())));
    await tester.pump();

    // Swiping is the only navigation path now that the tab bar is hidden;
    // NeverScrollableScrollPhysics should still block it with no outcome.
    await tester.fling(
      find.byKey(const Key('diagnosis-tab-view')),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('diagnosis-input-content')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Belum ada hasil analisis.').hitTestable(), findsNothing);
  });

  testWidgets('a successful analysis switches to the result tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = DiagnosisProvider(MockDiagnosisRepository());
    _seedRequiredFields(provider);
    provider.attachPlaceholderImage('xray.png');

    await tester.pumpWidget(_app(provider));
    await tester.ensureVisible(find.byKey(const Key('analyze-button')));
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('diagnosis-result-content')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('diagnosis-input-content')).hitTestable(),
      findsNothing,
    );
  });

  testWidgets(
    'clearing the outcome while on the result tab snaps back to the input tab',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final provider = DiagnosisProvider(MockDiagnosisRepository());
      _seedRequiredFields(provider);
      provider.attachPlaceholderImage('xray.png');

      await tester.pumpWidget(_app(provider));
      await tester.ensureVisible(find.byKey(const Key('analyze-button')));
      await tester.tap(find.byKey(const Key('analyze-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('diagnosis-result-content')).hitTestable(),
        findsOneWidget,
      );

      // Bypasses the UI reset button (covered by reset_confirmation_test.dart)
      // to isolate the tab host's own generic "snap back when the outcome
      // disappears" guard from the confirmation-dialog flow.
      provider.resetForNewDiagnosis();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('diagnosis-input-content')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('diagnosis-result-content')).hitTestable(),
        findsNothing,
      );
    },
  );

  testWidgets(
    'the input tab locks after analysis, but the reset button stays usable',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final provider = DiagnosisProvider(MockDiagnosisRepository());
      _seedRequiredFields(provider);
      provider.attachPlaceholderImage('xray.png');

      await tester.pumpWidget(_app(provider));
      await tester.ensureVisible(find.byKey(const Key('analyze-button')));
      await tester.tap(find.byKey(const Key('analyze-button')));
      await tester.pumpAndSettle();

      // Back to the input tab to inspect its locked state — swipe right,
      // since there's no tab bar and the result tab unlocked swiping once
      // an outcome exists.
      await tester.fling(
        find.byKey(const Key('diagnosis-tab-view')),
        const Offset(500, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('upload-xray')).hitTestable(),
        findsNothing,
      );
      expect(
        find.byKey(const Key('reset-button')).hitTestable(),
        findsOneWidget,
      );
    },
  );
}
