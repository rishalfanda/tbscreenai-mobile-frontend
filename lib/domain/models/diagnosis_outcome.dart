import 'package:myapp/domain/models/segmentation_overlays.dart';

/// Result of one AI inference run over a chest X-ray.
class DiagnosisOutcome {
  const DiagnosisOutcome({
    required this.isPositive,
    required this.confidence,
    required this.processingTime,
    required this.modelVersion,
    required this.createdAt,
    this.processingTimeMs,
    this.isMock = true,
    this.consolidation = 0,
    this.cavity = 0,
    this.effusion = 0,
    this.fibrotic = 0,
    this.calcification = 0,
    this.segmentation,
  });

  final bool isPositive;
  final int confidence;
  final String processingTime;
  final String modelVersion;
  final DateTime createdAt;
  final int? processingTimeMs;

  /// Unknown provenance is treated as demo, never implicitly clinical.
  final bool isMock;
  final double consolidation;
  final double cavity;
  final double effusion;
  final double fibrotic;
  final double calcification;

  /// Pre-rendered lung/lesion overlay visuals. Only the on-device path
  /// produces these — mock/HTTP outcomes leave this `null`.
  final SegmentationOverlays? segmentation;

  Map<String, double> get findings => {
    'consolidation': consolidation,
    'cavity': cavity,
    'effusion': effusion,
    'fibrotic': fibrotic,
    'calcification': calcification,
  };
}
