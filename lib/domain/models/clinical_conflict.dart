enum ConflictDecision { keepServer, reapplyLocal, cancel }

class ClinicalConflict {
  const ClinicalConflict({
    required this.clientOpId,
    required this.diagnosisId,
    required this.localStatus,
    required this.localNote,
    required this.baseVersion,
    required this.detail,
    this.serverStatus,
    this.serverNote,
    this.serverVersion,
  });

  final String clientOpId;
  final String diagnosisId;
  final String localStatus;
  final String? localNote;
  final int? baseVersion;
  final String? detail;
  final String? serverStatus;
  final String? serverNote;
  final int? serverVersion;

  bool get hasServerSnapshot => serverStatus != null && serverVersion != null;
}
