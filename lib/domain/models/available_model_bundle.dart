/// Model bundle descriptor returned by the model discovery endpoint (GET /v1/models).
class AvailableModelBundle {
  const AvailableModelBundle({
    required this.channel,
    required this.version,
    required this.isLatest,
    this.isCurrent = false,
    this.releasedUtc,
    this.schemaVersion = 1,
    this.quantized = false,
    this.mandatory = false,
    this.signatureVerified = true,
    this.sizeBytes = 0,
    this.bundleZipSha256,
    this.manifestSha256,
    this.notes,
    this.changelog = const [],
    this.minAppVersion,
    this.appSupported = true,
    this.bundleZip,
    this.manifestUrl,
    this.labelsUrl,
    this.sha256sumsUrl,
    this.signatureUrl,
    this.filesBase,
  });

  final String channel;
  final String version;
  final bool isLatest;
  final bool isCurrent;
  final DateTime? releasedUtc;
  final int schemaVersion;
  final bool quantized;
  final bool mandatory;
  final bool signatureVerified;
  final int sizeBytes;
  final String? bundleZipSha256;
  final String? manifestSha256;
  final String? notes;
  final List<String> changelog;
  final String? minAppVersion;
  final bool appSupported;
  final String? bundleZip;
  final String? manifestUrl;
  final String? labelsUrl;
  final String? sha256sumsUrl;
  final String? signatureUrl;
  final String? filesBase;

  /// Unique bundle key used for directory naming and identification: `${channel}_${version}`.
  String get id => '${channel.toLowerCase().trim()}_${version.trim()}';

  /// Human-readable file size, e.g. "504.1 MB" or "196.8 MB".
  String get formattedSize {
    if (sizeBytes <= 0) return '-';
    final mb = sizeBytes / (1024 * 1024);
    if (mb >= 1000) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Formatted release date, e.g. "17 Sep 2026".
  String get formattedDate {
    final date = releasedUtc;
    if (date == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final m = date.month >= 1 && date.month <= 12 ? months[date.month - 1] : '';
    return '${date.day} $m ${date.year}';
  }

  factory AvailableModelBundle.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['released_utc'];
    if (rawDate is String && rawDate.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawDate);
    }

    final rawChangelog = json['changelog'];
    final changelogList = rawChangelog is List
        ? rawChangelog.map((e) => e.toString()).toList()
        : const <String>[];

    return AvailableModelBundle(
      channel: (json['channel'] as String?) ?? 'stable',
      version: (json['version'] as String?) ?? '',
      isLatest: (json['is_latest'] as bool?) ?? false,
      isCurrent: (json['is_current'] as bool?) ?? false,
      releasedUtc: parsedDate,
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      quantized: (json['quantized'] as bool?) ?? false,
      mandatory: (json['mandatory'] as bool?) ?? false,
      signatureVerified: (json['signature_verified'] as bool?) ?? true,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      bundleZipSha256: json['bundle_zip_sha256'] as String?,
      manifestSha256: json['manifest_sha256'] as String?,
      notes: json['notes'] as String?,
      changelog: changelogList,
      minAppVersion: json['min_app_version'] as String?,
      appSupported: (json['app_supported'] as bool?) ?? true,
      bundleZip: json['bundle_zip'] as String?,
      manifestUrl: json['manifest_url'] as String?,
      labelsUrl: json['labels_url'] as String?,
      sha256sumsUrl: json['sha256sums_url'] as String?,
      signatureUrl: json['signature_url'] as String?,
      filesBase: json['files_base'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'channel': channel,
    'version': version,
    'is_latest': isLatest,
    'is_current': isCurrent,
    if (releasedUtc != null) 'released_utc': releasedUtc!.toIso8601String(),
    'schema_version': schemaVersion,
    'quantized': quantized,
    'mandatory': mandatory,
    'signature_verified': signatureVerified,
    'size_bytes': sizeBytes,
    if (bundleZipSha256 != null) 'bundle_zip_sha256': bundleZipSha256,
    if (manifestSha256 != null) 'manifest_sha256': manifestSha256,
    if (notes != null) 'notes': notes,
    'changelog': changelog,
    if (minAppVersion != null) 'min_app_version': minAppVersion,
    'app_supported': appSupported,
    if (bundleZip != null) 'bundle_zip': bundleZip,
    if (manifestUrl != null) 'manifest_url': manifestUrl,
    if (labelsUrl != null) 'labels_url': labelsUrl,
    if (sha256sumsUrl != null) 'sha256sums_url': sha256sumsUrl,
    if (signatureUrl != null) 'signature_url': signatureUrl,
    if (filesBase != null) 'files_base': filesBase,
  };

  AvailableModelBundle copyWith({
    String? channel,
    String? version,
    bool? isLatest,
    bool? isCurrent,
    DateTime? releasedUtc,
    int? schemaVersion,
    bool? quantized,
    bool? mandatory,
    bool? signatureVerified,
    int? sizeBytes,
    String? bundleZipSha256,
    String? manifestSha256,
    String? notes,
    List<String>? changelog,
    String? minAppVersion,
    bool? appSupported,
    String? bundleZip,
    String? manifestUrl,
    String? labelsUrl,
    String? sha256sumsUrl,
    String? signatureUrl,
    String? filesBase,
  }) {
    return AvailableModelBundle(
      channel: channel ?? this.channel,
      version: version ?? this.version,
      isLatest: isLatest ?? this.isLatest,
      isCurrent: isCurrent ?? this.isCurrent,
      releasedUtc: releasedUtc ?? this.releasedUtc,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      quantized: quantized ?? this.quantized,
      mandatory: mandatory ?? this.mandatory,
      signatureVerified: signatureVerified ?? this.signatureVerified,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      bundleZipSha256: bundleZipSha256 ?? this.bundleZipSha256,
      manifestSha256: manifestSha256 ?? this.manifestSha256,
      notes: notes ?? this.notes,
      changelog: changelog ?? this.changelog,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      appSupported: appSupported ?? this.appSupported,
      bundleZip: bundleZip ?? this.bundleZip,
      manifestUrl: manifestUrl ?? this.manifestUrl,
      labelsUrl: labelsUrl ?? this.labelsUrl,
      sha256sumsUrl: sha256sumsUrl ?? this.sha256sumsUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      filesBase: filesBase ?? this.filesBase,
    );
  }
}

