/// AI model version info returned when checking the update server.
class ModelVersionInfo {
  const ModelVersionInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.fileSize,
    required this.releaseDate,
    required this.changelog,
  });

  final String currentVersion;
  final String latestVersion;

  /// Human-readable size, e.g. "47.2 MB".
  final String fileSize;
  final String releaseDate;
  final List<String> changelog;

  bool get hasUpdate => currentVersion != latestVersion;
}
