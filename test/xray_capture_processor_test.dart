// Post-capture crop/rotate pipeline for the camera screen: pure pixel math,
// no hardware/CameraController involved, so fully unit-testable.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:myapp/features/camera/application/xray_capture_processor.dart';

Uint8List _encodeJpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(120, 120, 120));
  return img.encodeJpg(image);
}

void main() {
  group('maximalCenteredBox', () {
    test('a wide container is height-constrained', () {
      final box = maximalCenteredBox(2000, 1000, 5, 6);
      expect(box.height, 1000);
      expect(box.width, closeTo(1000 * 5 / 6, 0.001));
      expect(box.width, lessThanOrEqualTo(2000));
    });

    test('a tall container is width-constrained', () {
      final box = maximalCenteredBox(500, 2000, 5, 6);
      expect(box.width, 500);
      expect(box.height, closeTo(500 * 6 / 5, 0.001));
      expect(box.height, lessThanOrEqualTo(2000));
    });

    test('a square container is height-constrained for a 5:6 box', () {
      // 5:6 is taller than wide, so a width-filling box would overshoot a
      // square container's height — it must shrink to fit the height instead.
      final box = maximalCenteredBox(1000, 1000, 5, 6);
      expect(box.height, 1000);
      expect(box.width, closeTo(1000 * 5 / 6, 0.001));
    });
  });

  group('processCapturedXray', () {
    test(
      'crops a landscape capture to the 5:6 ratio and returns it portrait',
      () {
        final bytes = _encodeJpeg(1200, 800);

        final processed = processCapturedXray(bytes);
        final result = img.decodeImage(processed);

        expect(result, isNotNull);
        expect(result!.height, greaterThan(result.width));
        expect(
          result.width / result.height,
          closeTo(kXrayCropAspectW / kXrayCropAspectH, 0.01),
        );
      },
    );

    test('a capture already portrait stays portrait and keeps the ratio', () {
      final bytes = _encodeJpeg(900, 1600);

      final processed = processCapturedXray(bytes);
      final result = img.decodeImage(processed);

      expect(result, isNotNull);
      expect(result!.height, greaterThan(result.width));
      expect(
        result.width / result.height,
        closeTo(kXrayCropAspectW / kXrayCropAspectH, 0.01),
      );
    });

    test('bytes that are not a decodable image are returned unchanged', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(processCapturedXray(bytes), same(bytes));
    });
  });
}
