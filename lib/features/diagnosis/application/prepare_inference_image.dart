import 'package:flutter/foundation.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/diagnosis/application/reinhard_normalizer.dart';

/// Normalizes a chest X-ray image using Reinhard color/stain transfer matching
/// OpenCV LAB statistics against the reference baseline before inference.
///
/// Reinhard normalization is always executed for on-device and screening inference
/// to ensure input contrast and histogram match model training standards.
Future<XrayImage> prepareInferenceImage(
  XrayImage image, {
  bool useHttp = false,
}) async {
  debugPrint(
    '[Reinhard] Running normalization on ${image.filename} (${image.source.name})',
  );
  final normalized = await ReinhardNormalizer.normalizeXrayImage(image);
  debugPrint('[Reinhard] Normalization complete for ${image.filename}');
  return normalized;
}
