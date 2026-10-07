/// Facts about the on-device ONNX model bundle currently active, read
/// straight off its manifest + `verified.json` — no separate database record.
class InstalledBundleInfo {
  const InstalledBundleInfo({
    required this.bundleVersion,
    required this.schemaVersion,
    required this.integrityVerified,
    this.installedAt,
  });

  final String bundleVersion;
  final int schemaVersion;
  final bool integrityVerified;
  final DateTime? installedAt;
}
