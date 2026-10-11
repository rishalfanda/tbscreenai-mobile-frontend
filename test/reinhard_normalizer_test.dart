import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/diagnosis/application/reinhard_normalizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReinhardNormalizer OpenCV LAB math & statistics', () {
    test('computeStats computes valid moments on synthetic image', () {
      final image = img.Image(width: 10, height: 10);
      for (var y = 0; y < 10; y++) {
        for (var x = 0; x < 10; x++) {
          image.setPixelRgb(x, y, (x + y) * 12, (x + y) * 12, (x + y) * 12);
        }
      }

      final stats = ReinhardNormalizer.computeStats(image);
      expect(stats.meanL, isPositive);
      expect(stats.stdL, isPositive);
      expect(stats.meanL.isFinite, isTrue);
      expect(stats.stdL.isFinite, isTrue);
      expect(stats.meanA.isFinite, isTrue);
      expect(stats.meanB.isFinite, isTrue);
    });

    test('identity test: normalizing against self preserves pixel values', () {
      final file = File('assets/sample/xray.png');
      expect(file.existsSync(), isTrue, reason: 'assets/sample/xray.png must exist');
      final bytes = file.readAsBytesSync();
      final ref = img.decodeImage(bytes)!;

      final stats = ReinhardNormalizer.computeStats(ref);
      final normalized = ReinhardNormalizer.normalizeImage(ref, stats);

      // Check multiple sample pixels across the image
      const samples = [
        (100, 100),
        (256, 256),
        (400, 300),
        (50, 450),
      ];

      for (final (x, y) in samples) {
        final pOrig = ref.getPixel(x, y);
        final pNorm = normalized.getPixel(x, y);
        expect((pOrig.r - pNorm.r).abs(), lessThanOrEqualTo(2));
        expect((pOrig.g - pNorm.g).abs(), lessThanOrEqualTo(2));
        expect((pOrig.b - pNorm.b).abs(), lessThanOrEqualTo(2));
      }
    });

    test('normalize(source, target) matches direct python reinhard_normalize signature', () {
      final file = File('assets/sample/xray.png');
      final bytes = file.readAsBytesSync();
      final target = img.decodeImage(bytes)!;

      final source = img.Image(width: 20, height: 20);
      img.fill(source, color: img.ColorRgb8(50, 120, 200));

      final result = ReinhardNormalizer.normalize(source, target);
      expect(result.width, 20);
      expect(result.height, 20);

      final resStats = ReinhardNormalizer.computeStats(result);
      // Normalized against grayscale X-ray target -> color channels become neutral (128)
      expect(resStats.meanA, closeTo(128.0, 1.0));
      expect(resStats.meanB, closeTo(128.0, 1.0));
    });

    test('stain/color removal: tinted image color channels converge to neutral reference', () {
      // Create a heavily yellow-tinted image
      final tinted = img.Image(width: 50, height: 50);
      for (var y = 0; y < 50; y++) {
        for (var x = 0; x < 50; x++) {
          tinted.setPixelRgb(x, y, 220, 200, 50); // Yellowish
        }
      }

      final beforeStats = ReinhardNormalizer.computeStats(tinted);
      // Yellowish image has b channel far from 128 (neutral)
      expect((beforeStats.meanB - 128.0).abs(), greaterThan(10.0));

      final normalized = ReinhardNormalizer.normalizeImage(
        tinted,
        ReinhardStats.defaultReferenceStats,
      );
      final afterStats = ReinhardNormalizer.computeStats(normalized);

      // After normalization with reference X-ray, chromatic deviation drops to 0
      expect((afterStats.meanB - 128.0).abs(), closeTo(0.0, 1.0));
      expect((afterStats.meanA - 128.0).abs(), closeTo(0.0, 1.0));
    });

    test('zero-variance and single-pixel images do not throw or produce NaN', () {
      // 1x1 image
      final singlePixel = img.Image(width: 1, height: 1);
      singlePixel.setPixelRgb(0, 0, 100, 100, 100);

      final stats = ReinhardNormalizer.computeStats(singlePixel);
      expect(stats.stdL.isNaN, isFalse);

      final normSingle = ReinhardNormalizer.normalizeImage(
        singlePixel,
        ReinhardStats.defaultReferenceStats,
      );
      final p = normSingle.getPixel(0, 0);
      expect(p.r.isNaN, isFalse);
      expect(p.r, inInclusiveRange(0, 255));

      // Solid black image (all 0s)
      final solidBlack = img.Image(width: 10, height: 10);
      final normBlack = ReinhardNormalizer.normalizeImage(
        solidBlack,
        ReinhardStats.defaultReferenceStats,
      );
      expect(normBlack.width, 10);
      expect(normBlack.height, 10);
    });
  });

  group('ReinhardNormalizer isolate and byte processing', () {
    test('normalizeBytes on PNG returns valid normalized PNG', () async {
      final imgObj = img.Image(width: 32, height: 32);
      img.fill(imgObj, color: img.ColorRgb8(150, 150, 150));
      final pngBytes = Uint8List.fromList(img.encodePng(imgObj));

      final outBytes = await ReinhardNormalizer.normalizeBytes(pngBytes);
      expect(outBytes, isNotEmpty);

      final decoded = img.decodeImage(outBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 32);
      expect(decoded.height, 32);
    });

    test('normalizeBytes on JPEG returns valid JPEG', () async {
      final imgObj = img.Image(width: 32, height: 32);
      img.fill(imgObj, color: img.ColorRgb8(120, 120, 120));
      final jpgBytes = Uint8List.fromList(img.encodeJpg(imgObj));

      final outBytes = await ReinhardNormalizer.normalizeBytes(jpgBytes);
      expect(outBytes, isNotEmpty);
      expect(outBytes[0], 0xFF);
      expect(outBytes[1], 0xD8);

      final decoded = img.decodeImage(outBytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 32);
      expect(decoded.height, 32);
    });

    test('normalizeBytes on non-image bytes returns original bytes unchanged', () async {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final outBytes = await ReinhardNormalizer.normalizeBytes(invalidBytes);
      expect(outBytes, equals(invalidBytes));
    });
  });

  group('normalizeXrayImage adapter', () {
    test('normalizeXrayImage preserves filename and source', () async {
      final imgObj = img.Image(width: 20, height: 20);
      img.fill(imgObj, color: img.ColorRgb8(80, 80, 80));
      final bytes = Uint8List.fromList(img.encodePng(imgObj));

      final input = XrayImage.fromBytes(
        bytes: bytes,
        filename: 'patient_chest.png',
        source: XrayImageSource.gallery,
      );

      final normalized = await ReinhardNormalizer.normalizeXrayImage(input);
      expect(normalized.filename, 'patient_chest.png');
      expect(normalized.source, XrayImageSource.gallery);
      expect(normalized.bytes, isNotEmpty);
      expect(normalized.canPreview, isTrue);
    });

    test('normalizeXrayImage on placeholder succeeds safely', () async {
      final placeholder = XrayImage.placeholder('placeholder.png');
      final normalized = await ReinhardNormalizer.normalizeXrayImage(placeholder);
      expect(normalized.filename, 'placeholder.png');
      expect(normalized.bytes, isNotEmpty);
    });
  });
}
