// TODO: Replace mock data with GET /api/validation/cases

class ValidationFindings {
  final double consolidation;
  final double cavity;
  final double effusion;
  final double fibrotic;
  final double calcification;

  const ValidationFindings({
    required this.consolidation,
    required this.cavity,
    required this.effusion,
    required this.fibrotic,
    required this.calcification,
  });
}

class ValidationCase {
  final String id;
  final String name;
  final String initials;
  final int age;
  final String gender;
  final int aiScore;
  final String diagnosisDate;
  String status; // "pending" | "agreed" | "disagreed"
  String? doctorNote;
  final String? xrayUrl;
  final String? heatmapUrl;
  final ValidationFindings findings;

  ValidationCase({
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

final List<ValidationCase> mockCases = [
  ValidationCase(
    id: "TB000001",
    name: "John Doe",
    initials: "JD",
    age: 45,
    gender: "Male",
    aiScore: 66,
    diagnosisDate: "Apr 30, 2026",
    status: "pending",
    findings: const ValidationFindings(
      consolidation: 26.34,
      cavity: 0.58,
      effusion: 5.64,
      fibrotic: 0,
      calcification: 0,
    ),
  ),
  ValidationCase(
    id: "TB000002",
    name: "Sarah Williams",
    initials: "SW",
    age: 32,
    gender: "Female",
    aiScore: 31,
    diagnosisDate: "Apr 26, 2026",
    status: "pending",
    findings: const ValidationFindings(
      consolidation: 12.10,
      cavity: 0,
      effusion: 3.20,
      fibrotic: 1.50,
      calcification: 0,
    ),
  ),
  ValidationCase(
    id: "TB000003",
    name: "Emily Davis",
    initials: "ED",
    age: 58,
    gender: "Female",
    aiScore: 55,
    diagnosisDate: "Apr 24, 2026",
    status: "pending",
    findings: const ValidationFindings(
      consolidation: 20.00,
      cavity: 1.20,
      effusion: 4.80,
      fibrotic: 0,
      calcification: 2.10,
    ),
  ),
  ValidationCase(
    id: "TB000004",
    name: "Jane Smith",
    initials: "JS",
    age: 29,
    gender: "Female",
    aiScore: 87,
    diagnosisDate: "Apr 23, 2026",
    status: "agreed",
    doctorNote: "Confirmed positive. Consolidation pattern consistent with TB.",
    findings: const ValidationFindings(
      consolidation: 38.50,
      cavity: 4.20,
      effusion: 8.10,
      fibrotic: 0,
      calcification: 0,
    ),
  ),
  ValidationCase(
    id: "TB000005",
    name: "Michael Chen",
    initials: "MC",
    age: 41,
    gender: "Male",
    aiScore: 22,
    diagnosisDate: "Apr 20, 2026",
    status: "disagreed",
    doctorNote: "Patient has old scarring from previous pneumonia, not active TB.",
    findings: const ValidationFindings(
      consolidation: 8.00,
      cavity: 0,
      effusion: 1.10,
      fibrotic: 14.30,
      calcification: 5.60,
    ),
  ),
  ValidationCase(
    id: "TB000006",
    name: "Robert Brown",
    initials: "RB",
    age: 63,
    gender: "Male",
    aiScore: 74,
    diagnosisDate: "Apr 18, 2026",
    status: "agreed",
    doctorNote: "",
    findings: const ValidationFindings(
      consolidation: 30.10,
      cavity: 3.80,
      effusion: 6.90,
      fibrotic: 0,
      calcification: 0,
    ),
  ),
];
