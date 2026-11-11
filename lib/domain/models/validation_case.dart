/// AI finding percentages for one chest X-ray.
class ValidationFindings {
  const ValidationFindings({
    required this.consolidation,
    required this.cavity,
    required this.effusion,
    required this.fibrotic,
    required this.calcification,
  });

  final double consolidation;
  final double cavity;
  final double effusion;
  final double fibrotic;
  final double calcification;
}

/// Immutable AI diagnosis awaiting (or holding) doctor validation.
class ValidationCase {
  const ValidationCase({
    required this.id,
    required this.name,
    required this.initials,
    required this.age,
    required this.gender,
    required this.aiScore,
    required this.diagnosisDate,
    this.diagnosedAt,
    required this.status,
    this.patientCode,
    this.heightCm,
    this.weightKg,
    this.symptoms = const [],
    this.isPositive,
    this.validationScore,
    this.lesionRating,
    this.validationDeletedAt,
    this.validationDeletedBy,
    this.validationNote,
    this.patientId,
    this.serverVersion,
    this.hasConflict = false,
    this.syncState = 'saved',
    this.isMock = false,
    this.doctorNote,
    this.xrayUrl,
    this.heatmapUrl,
    required this.findings,
  });

  final String? patientCode;
  final double? heightCm, weightKg;
  final List<String> symptoms;
  final bool? isPositive;
  final int? validationScore;
  final int? lesionRating;
  final DateTime? validationDeletedAt;
  final String? validationDeletedBy;
  final String? validationNote;
  final String id;
  final String name;
  final String initials;
  final int age;
  final String gender;
  final int aiScore;
  final String diagnosisDate;

  /// Original screening instant, kept separate from display text.
  final DateTime? diagnosedAt;

  String get screeningDateTimeLabel => diagnosedAt == null
      ? diagnosisDate
      : diagnosedAt!
            .toLocal()
            .toIso8601String()
            .replaceFirst('T', ' ')
            .split('.')
            .first;

  /// "pending" | "agreed" | "disagreed"
  final String status;
  final String? patientId;
  final int? serverVersion;
  final bool hasConflict;
  final String syncState;
  final bool isMock;
  final String? doctorNote;
  final String? xrayUrl;
  final String? heatmapUrl;
  final ValidationFindings findings;

  ValidationCase copyWith({
    String? status,
    String? doctorNote,
    bool? hasConflict,
    String? syncState,
    int? serverVersion,
  }) {
    return ValidationCase(
      id: id,
      name: name,
      initials: initials,
      age: age,
      gender: gender,
      aiScore: aiScore,
      diagnosisDate: diagnosisDate,
      diagnosedAt: diagnosedAt,
      status: status ?? this.status,
      patientCode: patientCode,
      heightCm: heightCm,
      weightKg: weightKg,
      symptoms: symptoms,
      isPositive: isPositive,
      validationScore: validationScore,
      lesionRating: lesionRating,
      validationDeletedAt: validationDeletedAt,
      validationDeletedBy: validationDeletedBy,
      validationNote: validationNote,
      patientId: patientId,
      serverVersion: serverVersion ?? this.serverVersion,
      hasConflict: hasConflict ?? this.hasConflict,
      syncState: syncState ?? this.syncState,
      isMock: isMock,
      doctorNote: doctorNote ?? this.doctorNote,
      xrayUrl: xrayUrl,
      heatmapUrl: heatmapUrl,
      findings: findings,
    );
  }
}
