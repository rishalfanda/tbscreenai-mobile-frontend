/// Local data footprint eligible for backup to the server.
class SyncSummary {
  const SyncSummary({
    required this.totalPatients,
    required this.totalDiagnoses,
    required this.totalSizeMB,
    this.lastSyncDate,
  });

  final int totalPatients;
  final int totalDiagnoses;
  final int totalSizeMB;
  final DateTime? lastSyncDate;
}
