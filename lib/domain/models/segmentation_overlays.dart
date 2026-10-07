import 'dart:typed_data';

/// Pre-rendered lung/lesion segmentation visuals for one inference run.
/// Only ever populated by the on-device path — mock/HTTP outcomes have no
/// pixel-level mask data, so this stays `null` there.
class SegmentationOverlays {
  const SegmentationOverlays({
    required this.xrayPng,
    required this.lungPng,
    required this.lesionPng,
    required this.legend,
    required this.lungAreaPx,
  });

  /// The X-ray resampled to the mask grid, no overlay — same base image the
  /// other two are drawn on top of, so all three swap without a size jump.
  final Uint8List xrayPng;

  /// X-ray with the lung field outlined and lightly tinted.
  final Uint8List lungPng;

  /// X-ray with each detected lesion class tinted by its palette color.
  final Uint8List lesionPng;

  final List<LesionLegendEntry> legend;

  /// Total lung-field pixel count for this run — the denominator for each
  /// [LesionLegendEntry]'s area proportion.
  final int lungAreaPx;
}

/// One row of the lesion color legend — plain RGB, no `dart:ui`/Flutter
/// `Color` here since domain models stay Flutter-free.
class LesionLegendEntry {
  const LesionLegendEntry({
    required this.name,
    required this.red,
    required this.green,
    required this.blue,
    required this.pixelCount,
  });

  final String name;
  final int red;
  final int green;
  final int blue;
  final int pixelCount;
}
