import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/features/diagnosis/application/reinhard_normalizer.dart';

/// HTTP inference owns preprocessing on the server, for every image source.
Future<XrayImage> prepareInferenceImage(
  XrayImage image, {
  bool useHttp = AppConfig.useHttp,
}) async => useHttp ? image : ReinhardNormalizer.normalizeXrayImage(image);
