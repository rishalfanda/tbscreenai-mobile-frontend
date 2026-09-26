// Safety test: the Result screen must never show a verdict it did not compute.
// Before this guard existed it rendered a hardcoded "TB Detected / 85%" even
// when no analysis had been run.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/segmentation_overlays.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/result/presentation/result_screen.dart';
import 'package:myapp/state/diagnosis_provider.dart';

Widget _wrap(DiagnosisProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: const MaterialApp(home: Scaffold(body: ResultScreen())),
  );
}

void main() {
  testWidgets('shows a clearly labelled dummy result before any run', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(DiagnosisProvider(MockDiagnosisRepository())),
    );
    await tester.pump();

    expect(find.text('Screening Result (Dummy)'), findsOneWidget);
    expect(find.text('DUMMY / DEMO — BUKAN HASIL KLINIS'), findsOneWidget);
    expect(find.text('TB Suspected'), findsOneWidget);
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

    expect(find.text('Screening Result (Dummy)'), findsNothing);
    // 73 comes from the outcome; the old code would have shown a hardcoded 85.
    expect(find.text('73%'), findsOneWidget);
    expect(find.text('85%'), findsNothing);
  });

  testWidgets(
    'shows the segmentation toggle and legend when the outcome carries one',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final placeholderBytes = XrayImage.placeholder().bytes;
      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..attachPlaceholderImage('xray.png')
        ..lastOutcome = DiagnosisOutcome(
          isPositive: true,
          confidence: 73,
          processingTime: '2.9s',
          modelVersion: 'TBScreen v2.1.0',
          createdAt: DateTime(2026, 7, 24, 10, 30),
          segmentation: SegmentationOverlays(
            xrayPng: placeholderBytes,
            lungPng: placeholderBytes,
            lesionPng: placeholderBytes,
            legend: const [
              LesionLegendEntry(
                name: 'consolidation',
                red: 255,
                green: 0,
                blue: 0,
                pixelCount: 12,
              ),
            ],
          ),
        );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(find.text('consolidation · 12 px'), findsOneWidget);
    },
  );

  testWidgets(
    'falls back to the plain image when the outcome has no segmentation',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..attachPlaceholderImage('xray.png')
        ..lastOutcome = DiagnosisOutcome(
          isPositive: true,
          confidence: 73,
          processingTime: '2.9s',
          modelVersion: 'TBScreen v2.1.0',
          createdAt: DateTime(2026, 7, 24, 10, 30),
        );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      expect(find.byType(SegmentedButton<int>), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    },
  );
}
