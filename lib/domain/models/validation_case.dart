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
    required this.status,
    this.doctorNote,
    this.xrayUrl,
    this.heatmapUrl,
    required this.findings,
  });

  final String id;
  final String name;
  final String initials;
  final int age;
  final String gender;
  final int aiScore;
  final String diagnosisDate;

  /// "pending" | "agreed" | "disagreed"
  final String status;
  final String? doctorNote;
  final String? xrayUrl;
  final String? heatmapUrl;
  final ValidationFindings findings;

  ValidationCase copyWith({
    String? status,
    String? doctorNote,
  }) {
    return ValidationCase(
      id: id,
      name: name,
      initials: initials,
      age: age,
      gender: gender,
      aiScore: aiScore,
      diagnosisDate: diagnosisDate,
      status: status ?? this.status,
      doctorNote: doctorNote ?? this.doctorNote,
      xrayUrl: xrayUrl,
      heatmapUrl: heatmapUrl,
      findings: findings,
    );
  }
}
