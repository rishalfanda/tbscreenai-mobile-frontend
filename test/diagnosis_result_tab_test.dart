// Safety test: the result tab must never show a verdict it did not compute.
// Before this guard existed it rendered a hardcoded "TB Detected / 85%" even
// when no analysis had been run.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
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
  for (final size in [const Size(400, 900), const Size(1600, 1000)]) {
    testWidgets('ONNX result at $size with 200 percent text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..lastOutcome = DiagnosisOutcome(
          isPositive: true,
          confidence: 91,
          processingTime: '2.9s',
          modelVersion: 'onnx-2026.09.04',
          createdAt: DateTime(2026),
          isMock: false,
          infiltrate: 4.2,
        );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(body: DiagnosisResultTab(onNewScreening: () {})),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Infiltrat'), findsOneWidget);
      expect(find.text('4.2%'), findsOneWidget);
      expect(find.text('91%'), findsOneWidget);
      expect(find.text('Hasil model backend'), findsOneWidget);
    });
  }

  testWidgets('shows a neutral empty state before any run', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(DiagnosisProvider(MockDiagnosisRepository())),
    );
    await tester.pump();

    expect(find.text('Belum ada hasil analisis.'), findsOneWidget);
    expect(find.byKey(const Key('diagnosis-result-content')), findsNothing);
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
    expect(find.text('73%'), findsOneWidget);
    expect(find.text('85%'), findsNothing);
    expect(find.text('Screening AI'), findsOneWidget);
    expect(find.text('Level Indikasi TB: High'), findsOneWidget);
  });

  testWidgets('a negative verdict displays Non-TB and corresponding risk category', (
    tester,
  ) async {
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

    // 100 - 73 = 27% (Low risk)
    expect(find.text('Screening AI'), findsOneWidget);
    expect(find.text('Level Indikasi TB: Low'), findsOneWidget);
    expect(find.text('27%'), findsOneWidget);
    expect(
      find.text('Kemungkinan TB rendah, namun belum dapat sepenuhnya dikesampingkan.'),
      findsOneWidget,
    );
    expect(
      find.text('Hasil skrining negatif. Pemeriksaan lanjutan bila terdapat gejala atau faktor risiko tinggi.'),
      findsOneWidget,
    );
    expect(provider.lastOutcome?.confidence, 73);
  });

  testWidgets('renders Grey Area category when score is in 40-60%', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final provider = DiagnosisProvider(MockDiagnosisRepository())
      ..lastOutcome = DiagnosisOutcome(
        isPositive: false,
        confidence: 50,
        processingTime: '2.0s',
        modelVersion: 'TBScreen v2.1.0',
        createdAt: DateTime(2026, 7, 24, 10, 30),
      );

    await tester.pumpWidget(_wrap(provider));
    await tester.pump();

    expect(find.text('Screening AI'), findsOneWidget);
    expect(find.text('Level Indikasi TB: Grey Area'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(
      find.text('Model tidak dapat memberikan keputusan dengan keyakinan yang cukup.'),
      findsOneWidget,
    );
    expect(
      find.text('Wajib dilakukan validasi tambahan oleh dokter, disertai evaluasi klinis dan pemeriksaan penunjang.'),
      findsOneWidget,
    );
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
            lungAreaPx: 1200,
          ),
        );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      expect(find.text('Rontgen'), findsOneWidget);
      expect(find.text('Paru'), findsOneWidget);
      expect(find.text('Lesi'), findsOneWidget);
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

      expect(find.text('Paru'), findsNothing);
      expect(find.text('Lesi'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    },
  );

  testWidgets(
    'renders Screening AI, updated recommendation, and collapsible clinical details panel',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..attachPlaceholderImage('xray.png')
        ..lastOutcome = DiagnosisOutcome(
          isPositive: true,
          confidence: 88,
          processingTime: '1.8s',
          modelVersion: 'TBScreen v2.1.0',
          createdAt: DateTime(2026, 7, 24, 10, 30),
        );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      // Heading "Screening AI"
      expect(find.text('Screening AI'), findsOneWidget);
      // Level & confidence
      expect(find.text('Level Indikasi TB: Very High'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);

      // Interpretation text
      expect(
        find.text(
          'Model menunjukkan indikasi TB dengan keyakinan sangat tinggi.',
        ),
        findsOneWidget,
      );

      // Patient identity card
      expect(find.text('Identitas Pasien'), findsOneWidget);

      // Tindak Lanjut card
      expect(find.text('Tindak Lanjut'), findsOneWidget);
      expect(
        find.text(
          'Hasil skrining positif. Perlu dilanjutkan dengan pemeriksaan lanjutan.',
        ),
        findsOneWidget,
      );

      // Collapsible clinical details panel (Hide/Unhide)
      expect(
        find.byKey(const Key('clinical-details-expansion-panel')),
        findsOneWidget,
      );

      // Runtime details and new screening button
      expect(find.text('Detail Runtime & Aksi'), findsOneWidget);
      expect(find.byKey(const Key('new-screening-button')), findsOneWidget);
    },
  );

  testWidgets(
    'disabled action buttons (PDF, Cetak, Simpan when mock) use readable light disabledForegroundColor on dark card',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..attachPlaceholderImage('xray.png')
        ..lastOutcome = DiagnosisOutcome(
          isPositive: true,
          confidence: 88,
          processingTime: '1.8s',
          modelVersion: 'TBScreen v2.1.0',
          createdAt: DateTime(2026, 7, 24, 10, 30),
          isMock: true,
        );

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      for (final label in ['Simpan', 'PDF', 'Cetak']) {
        final buttonFinder = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is OutlinedButton),
        );
        expect(buttonFinder, findsOneWidget, reason: 'Button "$label" exists');
        final button = tester.widget<OutlinedButton>(buttonFinder);
        expect(button.onPressed, isNull, reason: 'Button "$label" is disabled');
        final disabledFg = button.style?.foregroundColor?.resolve({
          WidgetState.disabled,
        });
        expect(
          disabledFg,
          const Color(0xFF94A3B8),
          reason: 'Disabled "$label" button must have high-contrast light text',
        );
      }
    },
  );

  testWidgets(
    'allows selecting all or specific lesions in lesion segmentation view and preserves selection in fullscreen viewer',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Uint8List solidPng(int r, int g, int b, {int a = 255}) {
        final im = img.Image(width: 4, height: 4, numChannels: 4);
        for (var y = 0; y < 4; y++) {
          for (var x = 0; x < 4; x++) {
            im.setPixelRgba(x, y, r, g, b, a);
          }
        }
        return Uint8List.fromList(img.encodePng(im));
      }

      final xrayPng = solidPng(20, 20, 20);
      final lungPng = solidPng(40, 80, 120);
      final lesionPng = solidPng(200, 100, 50);
      final consolidationLayer = solidPng(255, 0, 0, a: 140);
      final cavityLayer = solidPng(0, 255, 0, a: 140);

      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..attachPlaceholderImage('xray.png')
        ..lastOutcome = DiagnosisOutcome(
          isPositive: true,
          confidence: 88,
          processingTime: '1.2s',
          modelVersion: 'TBScreen v2.1.0',
          createdAt: DateTime(2026, 11, 11, 8, 40),
          segmentation: SegmentationOverlays(
            xrayPng: xrayPng,
            lungPng: lungPng,
            lesionPng: lesionPng,
            lesionLayerPngs: {
              'consolidation': consolidationLayer,
              'cavity': cavityLayer,
            },
            legend: const [
              LesionLegendEntry(
                name: 'consolidation',
                red: 255,
                green: 0,
                blue: 0,
                pixelCount: 12,
              ),
              LesionLegendEntry(
                name: 'cavity',
                red: 0,
                green: 255,
                blue: 0,
                pixelCount: 6,
              ),
              LesionLegendEntry(
                name: 'effusion',
                red: 0,
                green: 0,
                blue: 255,
                pixelCount: 0,
              ),
            ],
            lungAreaPx: 1000,
          ),
        );

      List<Uint8List> previewImages() => tester
          .widgetList<Image>(
            find.descendant(
              of: find.byKey(const Key('xray-image-viewer-trigger')),
              matching: find.byType(Image),
            ),
          )
          .map((w) => (w.image as MemoryImage).bytes)
          .toList();

      List<Uint8List> viewerImages() => tester
          .widgetList<Image>(
            find.descendant(
              of: find.byKey(const Key('xray-image-viewer-dialog')),
              matching: find.byType(Image),
            ),
          )
          .map((w) => (w.image as MemoryImage).bytes)
          .toList();

      await tester.pumpWidget(_wrap(provider));
      await tester.pump();

      // Initially on X-ray view: lesion filter controls stay hidden.
      expect(previewImages(), [xrayPng]);
      expect(find.byKey(const Key('lesion-filter-all')), findsNothing);

      // Switch to Lesion view: All + detected lesion toggle buttons appear.
      await tester.tap(find.text('Lesi'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesion-filter-all')), findsOneWidget);
      expect(
        find.byKey(const Key('lesion-filter-consolidation')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('lesion-filter-cavity')), findsOneWidget);
      expect(find.byKey(const Key('lesion-filter-effusion')), findsNothing);
      expect(previewImages(), [lesionPng]);

      // Deselect cavity: only consolidation layer renders over base X-ray.
      await tester.tap(find.byKey(const Key('lesion-filter-cavity')));
      await tester.pump();
      expect(previewImages(), [xrayPng, consolidationLayer]);

      // Fullscreen zoom viewer mirrors the filtered subset.
      await tester.tap(find.byKey(const Key('xray-image-viewer-trigger')));
      await tester.pumpAndSettle();
      expect(viewerImages(), [xrayPng, consolidationLayer]);
      await tester.tap(find.byKey(const Key('xray-image-viewer-close-button')));
      await tester.pumpAndSettle();

      // Deselect consolidation too: clean base X-ray shows with 0 overlays.
      await tester.tap(find.byKey(const Key('lesion-filter-consolidation')));
      await tester.pump();
      expect(previewImages(), [xrayPng]);

      // Clicking "Semua" selects all detected lesions again.
      await tester.tap(find.byKey(const Key('lesion-filter-all')));
      await tester.pump();
      expect(previewImages(), [lesionPng]);
      expect(tester.takeException(), isNull);
    },
  );
}
