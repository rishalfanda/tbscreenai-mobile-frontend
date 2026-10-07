// Safety test: the result tab must never show a verdict it did not compute.
// Before this guard existed it rendered a hardcoded "TB Detected / 85%" even
// when no analysis had been run.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/segmentation_overlays.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/diagnosis_result_tab.dart';
import 'package:myapp/state/diagnosis_provider.dart';

Widget _wrap(DiagnosisProvider provider) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      home: Scaffold(body: DiagnosisResultTab(onNewScreening: () {})),
    ),
  );
}

void main() {
  testWidgets('shows a neutral empty state before any run', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(DiagnosisProvider(MockDiagnosisRepository())),
    );
    await tester.pump();

    expect(find.text('Belum ada hasil analisis.'), findsOneWidget);
    expect(find.text('Hasil Screening'), findsNothing);
    expect(find.text('Terdeteksi TB'), findsNothing);
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

    expect(find.text('Belum ada hasil analisis.'), findsNothing);
    // 73 comes from the outcome; the old code would have shown a hardcoded 85.
    expect(find.text('73%'), findsOneWidget);
    expect(find.text('85%'), findsNothing);
  });

  testWidgets(
    'a negative verdict displays confidence in "Normal", not confidence in TB',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..lastOutcome = DiagnosisOutcome(
          isPositive: false,
          confidence: 73,
          processingTime: '2.9s',
          modelVersion: 'TBScreen v2.1.0',
          createdAt: DateTime(2026, 7, 24, 10, 30),
        );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      // The stored value (73, confidence of the TB class) is flipped only
      // for display since the verdict is Normal — the model stays untouched.
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('27%'), findsOneWidget);
      expect(find.text('73%'), findsNothing);
      expect(provider.lastOutcome?.confidence, 73);
    },
  );

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
            lungAreaPx: 1200,
          ),
        );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(find.text('Konsolidasi · 1.0%'), findsOneWidget);
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
