/// Result of one AI inference run over a chest X-ray.
class DiagnosisOutcome {
  const DiagnosisOutcome({
    required this.isPositive,
    required this.confidence,
    required this.processingTime,
    required this.modelVersion,
    required this.createdAt,
    this.consolidation = 0,
    this.cavity = 0,
    this.effusion = 0,
    this.fibrotic = 0,
    this.calcification = 0,
  });

  final bool isPositive;
  final int confidence;
  final String processingTime;
  final String modelVersion;
  final DateTime createdAt;
  final double consolidation;
  final double cavity;
  final double effusion;
  final double fibrotic;
  final double calcification;
}
