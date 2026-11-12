// Lung/lesion segmentation overlays: rendering the PNGs and threading the
// result into DiagnosisOutcome for the Result screen to pick up.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/onnx/inference_result.dart';
import 'package:myapp/data/onnx/on_device_diagnosis_repository.dart';
import 'package:myapp/data/onnx/segmentation_overlay.dart';
import 'package:myapp/domain/models/xray_image.dart';

InferenceResult _fakeResult({
  int grid = 4,
  List<String> names = const ['consolidation', 'cavity'],
  double pCnn = .75,
  double pRf = .85,
}) {
  final n = grid * grid;
  final lungMask = Uint8List(n)..fillRange(0, n, 1);
  final labelMap = Int16List(n)..fillRange(0, n, -1);
  labelMap[0] = 0; // one consolidation pixel; cavity stays at zero

  return InferenceResult(
    decisionIsTb: true,
    probabilityFused: 0.8,
    probabilityCnn: pCnn,
    probabilityRf: pRf,
    lungMask: lungMask,
    labelMap: labelMap,
    confidence: Float32List(n),
    featureVector: const [],
    featureNames: const [],
    lesionNames: names,
    lesionPaletteRgb: const [
      [255, 0, 0],
      [0, 255, 0],
    ],
    positiveLabel: 'TB',
    negativeLabel: 'NON TB',
    gridSize: [grid, grid],
    bundleVersion: 'v-test',
    rfModel: 'rf',
    decisionThreshold: 0.5,
    elapsed: Duration.zero,
    providersUsed: const {},
  );
}

void main() {
  group('renderSegmentationOverlays', () {
    test('produces PNGs and a legend matching lesionNames', () async {
      final overlays = await renderSegmentationOverlays(
        xrayBytes: XrayImage.placeholder().bytes,
        result: _fakeResult(),
      );

      expect(overlays, isNotNull);
      expect(overlays!.xrayPng, isNotEmpty);
      expect(overlays.lungPng, isNotEmpty);
      expect(overlays.lesionPng, isNotEmpty);
      expect(overlays.xrayPng.sublist(0, 8), [
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]);

      expect(overlays.legend, hasLength(2));
      expect(overlays.legend[0].name, 'consolidation');
      expect(overlays.legend[0].pixelCount, 1);
      expect(overlays.legend[1].name, 'cavity');
      expect(overlays.legend[1].pixelCount, 0);
      expect(overlays.lungAreaPx, 16);
    });

    test(
      'returns null when the X-ray bytes cannot be decoded as an image',
      () async {
        final overlays = await renderSegmentationOverlays(
          xrayBytes: Uint8List.fromList([1, 2, 3]),
          result: _fakeResult(),
        );
        expect(overlays, isNull);
      },
    );
  });

  test(
    'Indonesian manifest aliases map all six lesion classes including infiltrate',
    () {
      final result = _fakeResult(
        names: [
          ' Konsolidasi ',
          'KAVITAS',
          'efusi',
          'fibrotik',
          'kalsifikasi',
          'infiltrat',
        ],
      );
      for (var i = 0; i < 6; i++) {
        result.labelMap[i] = i;
        result.confidence[i] = .75;
      }
      final at = DateTime.utc(2026, 11, 11, 10);
      final outcome = outcomeFromInferenceResult(
        result,
        const Duration(milliseconds: 800),
        imageSha256: 'a' * 64,
        bundleChannel: 'stable',
        appVersion: '1.0.0+2',
        inferredAt: at,
      );
      for (final value in outcome.findings.values) {
        expect(value, 6.25);
      }
      expect(outcome.provenance!['schema_version'], 1);
      expect(outcome.provenance!['p_fused'], .8);
      expect(outcome.provenance!['p_cnn'], .75);
      expect(outcome.provenance!['p_rf'], .85);
      expect(outcome.provenance!['bundle_version'], 'v-test');
      expect(outcome.provenance!['rf_model'], 'rf');
      expect(outcome.provenance!['lesion_confidence'], .75);
      expect(outcome.provenance!['image_sha256'], 'a' * 64);
      expect(outcome.createdAt, at);
    },
  );

  test(
    'unknown aliases and empty lungs fail instead of emitting fabricated zeros',
    () {
      expect(
        () => outcomeFromInferenceResult(
          _fakeResult(names: ['unknown', 'cavity']),
          Duration.zero,
        ),
        throwsFormatException,
      );
      final empty = _fakeResult();
      empty.lungMask.fillRange(0, empty.lungMask.length, 0);
      expect(
        () => outcomeFromInferenceResult(empty, Duration.zero),
        throwsFormatException,
      );
      expect(
        () => outcomeFromInferenceResult(
          _fakeResult(names: ['consolidation', 'konsolidasi']),
          Duration.zero,
        ),
        throwsFormatException,
      );
    },
  );

  test('absent model branches are omitted instead of recorded as zero', () {
    final outcome = outcomeFromInferenceResult(
      _fakeResult(pCnn: -1, pRf: -1),
      Duration.zero,
    );
    expect(outcome.provenance!.containsKey('p_cnn'), false);
    expect(outcome.provenance!.containsKey('p_rf'), false);
  });

  group('outcomeFromInferenceResult', () {
    test('attaches the given segmentation to the outcome', () async {
      final result = _fakeResult();
      final overlays = await renderSegmentationOverlays(
        xrayBytes: XrayImage.placeholder().bytes,
        result: result,
      );

      final outcome = outcomeFromInferenceResult(
        result,
        const Duration(milliseconds: 500),
        segmentation: overlays,
      );

      expect(outcome.segmentation, same(overlays));
    });

    test('defaults segmentation to null', () {
      final outcome = outcomeFromInferenceResult(
        _fakeResult(),
        const Duration(milliseconds: 500),
      );
      expect(outcome.segmentation, isNull);
    });
  });
}
