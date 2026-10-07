import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:myapp/data/onnx/tensor.dart';

/// The bundle's single input, ready to feed the chain: `uint8` NHWC `[1,H,W,3]`
/// RGB, EXIF-rotated. The bundle's `preprocess.ort` does the resize + normalise.
class DecodedImage {
  const DecodedImage({
    required this.rgb,
    required this.width,
    required this.height,
  });

  final Uint8List rgb; // width*height*3, row-major RGB
  final int width;
  final int height;

  Tensor toTensor() => Tensor(data: rgb, shape: [1, height, width, 3]);
}

/// Decode + EXIF-bake a picked/captured image on a background isolate. Decoding a
/// 12 MP phone photo on the UI thread drops frames.
Future<DecodedImage> decodeForBundle(Uint8List fileBytes) =>
    compute(_decode, fileBytes);

DecodedImage _decode(Uint8List fileBytes) {
  final decoded = img.decodeImage(fileBytes);
  if (decoded == null) {
    throw const FormatException('That file is not an image this app can read.');
  }
  final oriented = img.bakeOrientation(decoded);
  return DecodedImage(
    rgb: oriented.getBytes(order: img.ChannelOrder.rgb),
    width: oriented.width,
    height: oriented.height,
  );
}
