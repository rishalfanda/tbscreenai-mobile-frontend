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
    this.operation = 'update',
    this.localLesionRating,
    this.serverLesionRating,
    this.serverValidationDeletedAt,
    this.serverValidationDeletedBy,
    this.requiresExplicitRating = false,
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
  final String operation;
  final int? localLesionRating;
  final int? serverLesionRating;
  final DateTime? serverValidationDeletedAt;
  final String? serverValidationDeletedBy;
  final bool requiresExplicitRating;

  bool get isDelete => operation == 'delete_validation';
  bool get serverDeleted => serverValidationDeletedAt != null;
  bool get hasServerSnapshot => serverVersion != null;
}
