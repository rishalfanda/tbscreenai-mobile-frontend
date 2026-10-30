import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:myapp/domain/models/models.dart';

class BundleDownloadException implements Exception {
  BundleDownloadException(this.message);
  final String message;
  @override
  String toString() => 'BundleDownloadException: $message';
}

/// Downloads a bundle zip to [dest], reporting progress and transfer speed via
/// [onProgress]. If [sha256Hex] is given, the downloaded file's digest is
/// checked against it — a defense-in-depth pre-check ahead of the bundle's own
/// Ed25519/SHA256SUMS verification (`bundle_verifier.dart`), which remains the
/// authoritative gate.
///
/// Downloads a bundle zip to [dest], reporting progress and transfer speed via
/// [onProgress]. If [sha256Hex] is given, the downloaded file's digest is
/// checked against it — a defense-in-depth pre-check ahead of the bundle's own
/// Ed25519/SHA256SUMS verification (`bundle_verifier.dart`), which remains the
/// authoritative gate.
Future<void> downloadBundleZip({
  required Dio dio,
  required String url,
  required File dest,
  String? sha256Hex,
  CancelToken? cancelToken,
  required void Function(int received, int total, double bytesPerSecond) onProgress,
}) async {
  int lastBytes = 0;
  int lastTimestamp = DateTime.now().millisecondsSinceEpoch;
  double currentSpeed = 0.0;

  try {
    await dio.download(
      url,
      dest.path,
      cancelToken: cancelToken,
      options: Options(
        receiveTimeout: const Duration(minutes: 15),
      ),
      onReceiveProgress: (received, total) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final timeDeltaMs = now - lastTimestamp;
        if (timeDeltaMs >= 400 || (total > 0 && received >= total)) {
          final bytesDelta = received - lastBytes;
          if (timeDeltaMs > 0 && bytesDelta >= 0) {
            currentSpeed = (bytesDelta / (timeDeltaMs / 1000.0));
          }
          lastBytes = received;
          lastTimestamp = now;
        }
        onProgress(received, total > 0 ? total : received, currentSpeed);
      },
    );
  } on DioException catch (e) {
    if (CancelToken.isCancel(e) || e.type == DioExceptionType.cancel) {
      throw const ModelInstallCancelledException();
    }
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
