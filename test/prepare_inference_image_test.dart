import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/diagnosis/application/prepare_inference_image.dart';
import 'package:myapp/features/diagnosis/application/reinhard_normalizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final source in [XrayImageSource.camera, XrayImageSource.gallery]) {
    test(
      '$source executes Reinhard normalization for inference',
      () async {
        final pixels = img.Image(width: 8, height: 8);
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            pixels.setPixelRgb(x, y, 20 + x * 10, 30 + y * 10, 40);
          }
        }
        final image = XrayImage.fromBytes(
          bytes: Uint8List.fromList(img.encodePng(pixels)),
          filename: 'synthetic.png',
          source: source,
        );
        final normalized = await prepareInferenceImage(image);
        final expected = await ReinhardNormalizer.normalizeXrayImage(image);
        expect(normalized.bytes, expected.bytes);
        expect(normalized.checksumSha256, isNot(image.checksumSha256));
        expect(normalized.source, source);
        expect(normalized.filename, image.filename);

        // Even if legacy useHttp is passed, normalization is still executed
        final remote = await prepareInferenceImage(image, useHttp: true);
        expect(remote.bytes, expected.bytes);
        expect(remote.checksumSha256, isNot(image.checksumSha256));
      },
    );
  }
}
