import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum XrayImageFormat { png, jpeg, dicom }

enum XrayImageSource { gallery, camera, demo }

class XrayImageValidationException implements Exception {
  const XrayImageValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A chest X-ray on its way to inference.
///
/// The repository contract used to take a filename `String`, which meant no
/// implementation could ever send an actual image — the backend's
/// `POST /diagnoses/infer` was unreachable by design. Carrying the bytes is
/// what makes the clinical flow connectable at all.
class XrayImage {
  XrayImage._({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.format,
    required this.source,
  }) : checksumSha256 = sha256.convert(bytes).toString();

  factory XrayImage.fromBytes({
    required Uint8List bytes,
    required String filename,
    required XrayImageSource source,
    int maxBytes = 25 * 1024 * 1024,
  }) {
    if (bytes.isEmpty) {
      throw const XrayImageValidationException('The selected file is empty.');
    }
    if (bytes.length > maxBytes) {
      throw const XrayImageValidationException(
        'The X-ray image must be 25 MB or smaller.',
      );
    }

    final format = _detectFormat(bytes);
    if (format == null) {
      throw const XrayImageValidationException(
        'Unsupported file. Select a real PNG, JPEG, or DICOM image.',
      );
    }

    return XrayImage._(
      bytes: Uint8List.fromList(bytes).asUnmodifiableView(),
      filename: filename.trim().isEmpty ? _fallbackFilename(format) : filename,
      mimeType: _mimeType(format),
      format: format,
      source: source,
    );
  }

  /// Stand-in for a real capture, used until an image source plugin lands.
  ///
  /// Deliberately a genuine PNG rather than arbitrary bytes: the backend
  /// validates by file signature, so a placeholder that is not really an image
  /// would be rejected with 415 and the flow would appear broken for the wrong
  /// reason. This exercises the real request path end to end.
  factory XrayImage.placeholder([String filename = 'xray_placeholder.png']) {
    return XrayImage.fromBytes(
      bytes: _placeholderPng,
      filename: filename,
      source: XrayImageSource.demo,
    );
  }

  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final XrayImageFormat format;
  final XrayImageSource source;
  final String checksumSha256;

  int get sizeBytes => bytes.length;

  bool get isEmpty => bytes.isEmpty;

  bool get canPreview => format != XrayImageFormat.dicom;
}

XrayImageFormat? _detectFormat(Uint8List bytes) {
  const png = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (_startsWith(bytes, png)) return XrayImageFormat.png;
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return XrayImageFormat.jpeg;
  }
  if (bytes.length >= 132 &&
      bytes[128] == 0x44 &&
      bytes[129] == 0x49 &&
      bytes[130] == 0x43 &&
      bytes[131] == 0x4d) {
    return XrayImageFormat.dicom;
  }
  return null;
}

bool _startsWith(Uint8List bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}

String _mimeType(XrayImageFormat format) => switch (format) {
  XrayImageFormat.png => 'image/png',
  XrayImageFormat.jpeg => 'image/jpeg',
  XrayImageFormat.dicom => 'application/dicom',
};

String _fallbackFilename(XrayImageFormat format) => switch (format) {
  XrayImageFormat.png => 'xray.png',
  XrayImageFormat.jpeg => 'xray.jpg',
  XrayImageFormat.dicom => 'xray.dcm',
};

/// Smallest valid PNG: 1x1, transparent. Real signature, real IHDR/IDAT/IEND.
final Uint8List _placeholderPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
