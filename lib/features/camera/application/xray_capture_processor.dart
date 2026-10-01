import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The crop guide's and the final crop's aspect ratio, width:height.
const double kXrayCropAspectW = 5;
const double kXrayCropAspectH = 6;

/// The largest box of aspect ratio `aspectW:aspectH` that fits within
/// `maxWidth` x `maxHeight`. Used both for the on-screen crop guide and for
/// the equivalent crop of the captured image, so both always agree.
({double width, double height}) maximalCenteredBox(
  double maxWidth,
  double maxHeight,
  double aspectW,
  double aspectH,
) {
  final byWidth = (width: maxWidth, height: maxWidth * aspectH / aspectW);
  if (byWidth.height <= maxHeight) return byWidth;
  return (width: maxHeight * aspectW / aspectH, height: maxHeight);
}

/// Normalizes a freshly-captured X-ray photo for inference:
/// 1. Physically applies any EXIF orientation (the camera plugin writes a
///    correctly-oriented EXIF tag, but `package:image` doesn't rotate pixel
///    data to match it on decode — that has to be done explicitly).
/// 2. Crops to the maximal centered 5:6 box (same math as the on-screen
///    guide), which is always taller than wide.
/// 3. Defensively rotates 90° if the result is still landscape — a no-op
///    given the 5:6 crop above, kept as an explicit safeguard.
Uint8List processCapturedXray(Uint8List jpegBytes) {
  // `image`'s format sniffing can throw (not just return null) on bytes it
  // doesn't recognize. A capture that can't be decoded should fall back to
  // the original bytes rather than crash the whole capture flow.
  img.Image? decoded;
  try {
    decoded = img.decodeImage(jpegBytes);
  } catch (_) {
    return jpegBytes;
  }
  if (decoded == null) return jpegBytes;

  decoded = img.bakeOrientation(decoded);

  final box = maximalCenteredBox(
    decoded.width.toDouble(),
    decoded.height.toDouble(),
    kXrayCropAspectW,
    kXrayCropAspectH,
  );
  decoded = img.copyCrop(
    decoded,
    x: ((decoded.width - box.width) / 2).round(),
    y: ((decoded.height - box.height) / 2).round(),
    width: box.width.round(),
    height: box.height.round(),
  );

  if (decoded.width > decoded.height) {
    decoded = img.copyRotate(decoded, angle: 90);
  }

  return Uint8List.fromList(img.encodeJpg(decoded));
}
