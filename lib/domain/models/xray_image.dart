import 'dart:convert';
import 'dart:typed_data';

/// A chest X-ray on its way to inference.
///
/// The repository contract used to take a filename `String`, which meant no
/// implementation could ever send an actual image — the backend's
/// `POST /diagnoses/infer` was unreachable by design. Carrying the bytes is
/// what makes the clinical flow connectable at all.
class XrayImage {
  const XrayImage({
    required this.bytes,
    required this.filename,
    this.mimeType = 'image/png',
  });

  /// Stand-in for a real capture, used until an image source plugin lands.
  ///
  /// Deliberately a genuine PNG rather than arbitrary bytes: the backend
  /// validates by file signature, so a placeholder that is not really an image
  /// would be rejected with 415 and the flow would appear broken for the wrong
  /// reason. This exercises the real request path end to end.
  factory XrayImage.placeholder([String filename = 'xray_placeholder.png']) {
    return XrayImage(bytes: _placeholderPng, filename: filename);
  }

  final Uint8List bytes;
  final String filename;
  final String mimeType;

  int get sizeBytes => bytes.length;

  bool get isEmpty => bytes.isEmpty;
}

/// Smallest valid PNG: 1x1, transparent. Real signature, real IHDR/IDAT/IEND.
final Uint8List _placeholderPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
