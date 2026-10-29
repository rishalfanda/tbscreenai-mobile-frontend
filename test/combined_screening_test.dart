import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_screen.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:myapp/core/localization/app_language.dart';

DiagnosisProvider seeded({bool result = false}) {
  final provider = DiagnosisProvider(MockDiagnosisRepository())
    ..updatePatientName('Synthetic patient')
    ..updateGender('Female')
    ..updateAge(32)
    ..updateHeight(160)
    ..updateWeight(55)
    ..attachPlaceholderImage('synthetic.png');
  if (result) {
    provider.lastOutcome = DiagnosisOutcome(
      isPositive: true,
      confidence: 72,
      processingTime: '1.2s',
      modelVersion: 'test-model',
      createdAt: DateTime(2026, 10, 26),
      isMock: false,
    );
  }
  return provider;
}

Widget mount(
  DiagnosisProvider provider, {
  bool english = true,
  bool? hasModel,
}) {
  final language = AppLanguage()..select(english ? 'en' : 'id');
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      ChangeNotifierProvider.value(value: language),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: DiagnosisScreen(
          key: UniqueKey(),
          hasModelOverride: hasModel ?? true,
        ),
      ),
    ),
  );
}

void main() {
  for (final width in [320.0, 768.0, 1280.0]) {
    for (final english in [false, true]) {
      testWidgets('combined input/result at $width, English=$english', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final input = DiagnosisProvider(MockDiagnosisRepository());
        addTearDown(input.dispose);
        await tester.pumpWidget(mount(input, english: english));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('diagnosis-input-content')).hitTestable(),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('diagnosis-result-content')).hitTestable(),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        final result = seeded(result: true);
        addTearDown(result.dispose);
        await tester.pumpWidget(mount(result, english: english));
        await tester.pumpAndSettle();
        expect(find.text('72%'), findsOneWidget);
        expect(find.text('28%'), findsNothing);
        expect(find.text('Synthetic patient'), findsOneWidget);
        expect(find.text('Paru'), findsNothing);
        expect(find.text('Lungs'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'new screening confirms and clears both snapshot and form controllers',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = seeded(result: true);
      addTearDown(provider.dispose);
      await tester.pumpWidget(mount(provider));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('new-screening-button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(provider.lastResult, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(provider.lastResult, isNull);
      expect(provider.draft.patientName, isEmpty);
      expect(provider.draft.image, isNull);
      final field = tester.widget<TextFormField>(
        find.descendant(
          of: find.byKey(const Key('patient-name')),
          matching: find.byType(TextFormField),
        ),
      );
      expect(field.controller!.text, isEmpty);
      expect(
        find.byKey(const Key('diagnosis-input-content')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unavailable model directs clinician to technician without a sync shortcut',
    (tester) async {
      final provider = seeded();
      addTearDown(provider.dispose);
      await tester.pumpWidget(mount(provider, hasModel: false));
      await tester.pumpAndSettle();
      expect(find.textContaining('institution technician'), findsOneWidget);
      expect(find.text('Open Sync Center'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('analyze-button')))
            .onPressed,
        isNull,
      );
    },
  );
}
