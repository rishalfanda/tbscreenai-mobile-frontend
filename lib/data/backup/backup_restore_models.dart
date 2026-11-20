class BackupRestoreException implements Exception {
  const BackupRestoreException(this.message);
  final String message;

  @override
  String toString() => message;
}

class BackupResult {
  const BackupResult({
    required this.id,
    required this.name,
    required this.status,
    required this.patientCount,
    required this.diagnosisCount,
    required this.imageCount,
    this.problemCount = 0,
  });

  final String id;
  final String name;
  final String status;
  final int patientCount;
  final int diagnosisCount;
  final int imageCount;
  final int problemCount;

  factory BackupResult.fromJson(Map<String, dynamic> json) {
    final counts =
        (json['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    return BackupResult(
      id: json['backup_id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
      patientCount: (counts['patients'] as num?)?.toInt() ?? 0,
      diagnosisCount: (counts['diagnoses'] as num?)?.toInt() ?? 0,
      imageCount: (counts['images'] as num?)?.toInt() ?? 0,
      problemCount: (json['problem_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class RestorePlanSummary {
  const RestorePlanSummary({
    required this.restoreId,
    required this.backupName,
    required this.recordsExpected,
    required this.imagesToDownload,
  });

  final String restoreId;
  final String backupName;
  final int recordsExpected;
  final int imagesToDownload;
}

class RestoreResult {
  const RestoreResult({
    required this.restoreId,
    required this.recordsRestored,
    required this.imagesVerified,
  });

  final String restoreId;
  final int recordsRestored;
  final int imagesVerified;
}
