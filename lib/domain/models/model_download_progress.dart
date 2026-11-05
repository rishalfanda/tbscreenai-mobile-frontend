enum ModelInstallPhase {
  downloading,
  verifying,
  activating,
  smokeTesting,
  completed,
}

class ModelInstallCancelledException implements Exception {
  const ModelInstallCancelledException([
    this.message = 'Model download cancelled by user',
  ]);
  final String message;

  @override
  String toString() => 'ModelInstallCancelledException: $message';
}

/// Download progress event with real-time transfer speed and phase indicators.
class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.fraction,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.bytesPerSecond = 0.0,
    this.speedText = '',
    this.phase = ModelInstallPhase.downloading,
  });

  final double fraction;
  final int receivedBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final String speedText;
  final ModelInstallPhase phase;

  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '';
    final mbps = bytesPerSec / (1024 * 1024);
    if (mbps >= 1.0) {
      return '${mbps.toStringAsFixed(1)} MB/s';
    }
    final kbps = bytesPerSec / 1024;
    return '${kbps.toStringAsFixed(0)} KB/s';
  }
}

