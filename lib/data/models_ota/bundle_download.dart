import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

class BundleDownloadException implements Exception {
  BundleDownloadException(this.message);
  final String message;
  @override
  String toString() => 'BundleDownloadException: $message';
}

/// Downloads a bundle zip to [dest], reporting 0.0..1.0 progress via
/// [onProgress]. If [sha256Hex] is given, the downloaded file's digest is
/// checked against it — a defense-in-depth pre-check ahead of the bundle's own
/// Ed25519/SHA256SUMS verification (`bundle_verifier.dart`), which remains the
/// authoritative gate.
///
/// Uses a bare [dio] instance rather than the app's shared `ApiClient`, since
/// `downloadUrl` may point at a different host/CDN than the API base URL and
/// must not carry the `Authorization` header the API client injects on every
/// request.
Future<void> downloadBundleZip({
  required Dio dio,
  required String url,
  required File dest,
  String? sha256Hex,
  required void Function(int received, int total) onProgress,
}) async {
  try {
    await dio.download(
      url,
      dest.path,
      onReceiveProgress: (received, total) =>
          onProgress(received, total > 0 ? total : received),
    );
  } on DioException catch (e) {
    throw BundleDownloadException('download failed: ${e.message ?? e.type}');
  }

  if (sha256Hex != null && sha256Hex.isNotEmpty) {
    final digest = (await sha256.bind(dest.openRead()).first).toString();
    if (digest.toLowerCase() != sha256Hex.toLowerCase()) {
      throw BundleDownloadException(
        'downloaded file does not match the expected checksum',
      );
    }
  }
}
