// Safety test: the Result screen must never show a verdict it did not compute.
// Before this guard existed it rendered a hardcoded "TB Detected / 85%" even
// when no analysis had been run.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/features/result/presentation/result_screen.dart';
import 'package:myapp/state/diagnosis_provider.dart';

Widget _wrap(DiagnosisProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: const MaterialApp(home: Scaffold(body: ResultScreen())),
  );
}

void main() {
  testWidgets('shows empty state — never a fabricated verdict — before any run',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(DiagnosisProvider(MockDiagnosisRepository())));
    await tester.pump();

    expect(find.text('Belum ada hasil diagnosis'), findsOneWidget);
    expect(find.text('TB Detected'), findsNothing);
    expect(find.text('85%'), findsNothing);
  });

  testWidgets('renders the real outcome once one exists', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The outcome is set directly rather than via runDiagnosis(): that call
    // awaits a 3s Future.delayed, which never resolves under the test clock.
    final provider = DiagnosisProvider(MockDiagnosisRepository())
      ..lastOutcome = DiagnosisOutcome(
        isPositive: true,
        confidence: 73,
        processingTime: '2.9s',
        modelVersion: 'TBScreen v2.1.0',
        createdAt: DateTime(2026, 7, 24, 10, 30),
      );

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.text('Belum ada hasil diagnosis'), findsNothing);
    // 73 comes from the outcome; the old code would have shown a hardcoded 85.
    expect(find.text('73%'), findsOneWidget);
    expect(find.text('85%'), findsNothing);
  });
}
