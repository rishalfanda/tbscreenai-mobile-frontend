/// AI model version info returned when checking the update server.
class ModelVersionInfo {
  const ModelVersionInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.fileSize,
    required this.releaseDate,
    required this.changelog,
    this.downloadUrl,
    this.sha256,
  });

  final String currentVersion;
  final String latestVersion;

  /// Human-readable size, e.g. "47.2 MB".
  final String fileSize;
  final String releaseDate;
  final List<String> changelog;

  /// Where to fetch the signed bundle zip. Null until the backend serves one
  /// (today it only serves version metadata) — see [AppConfig.modelBundleUrl]
  /// for a dev-time override.
  final String? downloadUrl;

  /// Expected sha256 of the bundle zip, for an early defense-in-depth check
  /// ahead of the bundle's own Ed25519/SHA256SUMS verification.
  final String? sha256;

  bool get hasUpdate => currentVersion != latestVersion;
}
