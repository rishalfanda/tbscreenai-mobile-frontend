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
      '$source preserves bytes for HTTP and normalizes for local inference',
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
        final remote = await prepareInferenceImage(image, useHttp: true);
        expect(remote, same(image));
        expect(remote.checksumSha256, image.checksumSha256);

        final local = await prepareInferenceImage(image, useHttp: false);
        final expected = await ReinhardNormalizer.normalizeXrayImage(image);
        expect(local.bytes, expected.bytes);
        expect(local.checksumSha256, isNot(image.checksumSha256));
        expect(local.source, source);
      },
    );
  }
}
