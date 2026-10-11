import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:image/image.dart' as img;
import 'package:myapp/domain/models/xray_image.dart';

/// Statistical moments (mean and standard deviation) in OpenCV's 8-bit LAB color space
/// (matching `cv2.cvtColor(..., cv2.COLOR_RGB2LAB)` and `cv2.meanStdDev`).
class ReinhardStats {
  const ReinhardStats({
    required this.meanL,
    required this.meanA,
    required this.meanB,
    required this.stdL,
    required this.stdA,
    required this.stdB,
  });

  final double meanL;
  final double meanA;
  final double meanB;
  final double stdL;
  final double stdA;
  final double stdB;

  /// Default baseline reference statistics matching OpenCV COLOR_RGB2LAB
  /// on `assets/sample/xray.png` (512x512).
  ///
  /// Since the reference X-ray is grayscale, the chromatic channels are exactly neutral:
  /// meanA = 128.0, meanB = 128.0, stdA = 0.0, stdB = 0.0.
  static const defaultReferenceStats = ReinhardStats(
    meanL: 154.828876,
    meanA: 128.0,
    meanB: 128.0,
    stdL: 70.369755,
    stdA: 0.0,
    stdB: 0.0,
  );
}

class _NormalizeParams {
  const _NormalizeParams(this.bytes, this.stats);
  final Uint8List bytes;
  final ReinhardStats stats;
}

/// Standalone top-level worker for [compute] isolate execution.
Uint8List _isolateNormalizeWorker(_NormalizeParams params) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(params.bytes);
  } catch (_) {
    return params.bytes;
  }
  if (decoded == null) return params.bytes;

  final normalized = ReinhardNormalizer.normalizeImage(decoded, params.stats);

  // Preserve format: if source begins with JPEG SOI (0xFF, 0xD8, 0xFF), encode as JPEG;
  // otherwise encode as PNG.
  if (params.bytes.length >= 3 &&
      params.bytes[0] == 0xff &&
      params.bytes[1] == 0xd8 &&
      params.bytes[2] == 0xff) {
    return Uint8List.fromList(img.encodeJpg(normalized, quality: 95));
  }
  return Uint8List.fromList(img.encodePng(normalized));
}

/// Implementation of Reinhard stain/color normalization based on OpenCV LAB color space:
///
/// ```python
/// def reinhard_normalize(source, target):
///     src_lab = cv2.cvtColor(source, cv2.COLOR_RGB2LAB).astype(np.float32)
///     tgt_lab = cv2.cvtColor(target, cv2.COLOR_RGB2LAB).astype(np.float32)
///     src_mean, src_std = cv2.meanStdDev(src_lab)
///     tgt_mean, tgt_std = cv2.meanStdDev(tgt_lab)
///     for i in range(3):
///         res_lab[:, :, i] = ((src_lab[:, :, i] - src_mean[i]) * (tgt_std[i] / (src_std[i] + 1e-8))) + tgt_mean[i]
///     res_lab = np.clip(res_lab, 0, 255).astype(np.uint8)
///     return cv2.cvtColor(res_lab, cv2.COLOR_LAB2RGB)
/// ```
class ReinhardNormalizer {
  ReinhardNormalizer._();

  static const String defaultReferenceAssetPath = 'assets/sample/xray.png';

  // D65 illuminant white point constants used by OpenCV
  static const double _xn = 0.950456;
  static const double _yn = 1.000000;
  static const double _zn = 1.088754;

  static const double _threshold = 0.008856;
  static const double _aCoeff = 7.787;
  static const double _bCoeff = 16.0 / 116.0;

  static ReinhardStats _cachedRefStats = ReinhardStats.defaultReferenceStats;

  /// Returns the current reference statistics.
  static ReinhardStats get referenceStats => _cachedRefStats;

  /// Loads reference statistics from [assetPath] or cached memory.
  /// Defaults to [ReinhardStats.defaultReferenceStats] for the bundled reference X-ray.
  static Future<ReinhardStats> getReferenceStats({
    AssetBundle? bundle,
    String assetPath = defaultReferenceAssetPath,
  }) async {
    if (bundle != null || assetPath != defaultReferenceAssetPath) {
      try {
        final b = bundle ?? rootBundle;
        final byteData = await b.load(assetPath);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
        final image = img.decodeImage(bytes);
        if (image != null) {
          _cachedRefStats = computeStats(image);
          return _cachedRefStats;
        }
      } catch (_) {
        // Fall back safely.
      }
    }
    return _cachedRefStats;
  }

  /// Sets cached reference statistics (used in tests or custom configuration).
  @visibleForTesting
  static void setCachedReferenceStats(ReinhardStats? stats) {
    _cachedRefStats = stats ?? ReinhardStats.defaultReferenceStats;
  }

  /// Converts 8-bit RGB [0..255] to OpenCV 8-bit LAB [0..255].
  /// Matches OpenCV's `cv2.cvtColor(src, cv2.COLOR_RGB2LAB)`.
  static ({double l, double a, double b}) rgbToLab(int r, int g, int b) {
    final R = r / 255.0;
    final G = g / 255.0;
    final B = b / 255.0;

    // RGB to XYZ
    final X = 0.412453 * R + 0.357580 * G + 0.180423 * B;
    final Y = 0.212671 * R + 0.715160 * G + 0.072169 * B;
    final Z = 0.019334 * R + 0.119193 * G + 0.950227 * B;

    final x = X / _xn;
    final y = Y / _yn;
    final z = Z / _zn;

    double f(double t) {
      if (t > _threshold) {
        return math.pow(t, 1.0 / 3.0).toDouble();
      } else {
        return _aCoeff * t + _bCoeff;
      }
    }

    final fx = f(x);
    final fy = f(y);
    final fz = f(z);

    final L = 116.0 * fy - 16.0;
    final aVal = 500.0 * (fx - fy);
    final bVal = 200.0 * (fy - fz);

    // OpenCV 8-bit scale: L -> L * 255 / 100, a -> a + 128, b -> b + 128
    final l8u = (L * 255.0 / 100.0).round().clamp(0, 255).toDouble();
    final a8u = (aVal + 128.0).round().clamp(0, 255).toDouble();
    final b8u = (bVal + 128.0).round().clamp(0, 255).toDouble();

    return (l: l8u, a: a8u, b: b8u);
  }

  /// Converts OpenCV 8-bit LAB [0..255] back to 8-bit RGB [0..255].
  /// Matches OpenCV's `cv2.cvtColor(src, cv2.COLOR_LAB2RGB)`.
  static ({int r, int g, int b}) labToRgb(double l8u, double a8u, double b8u) {
    final L = l8u * 100.0 / 255.0;
    final aVal = a8u - 128.0;
    final bVal = b8u - 128.0;

    final fy = (L + 16.0) / 116.0;
    final fx = fy + aVal / 500.0;
    final fz = fy - bVal / 200.0;

    double finv(double t) {
      final t3 = t * t * t;
      if (t3 > _threshold) {
        return t3;
      } else {
        return (t - _bCoeff) / _aCoeff;
      }
    }

    final X = finv(fx) * _xn;
    final Y = finv(fy) * _yn;
    final Z = finv(fz) * _zn;

    // XYZ to RGB
    final R =  3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z;
    final G = -0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z;
    final B =  0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z;

    final r = (R * 255.0).round().clamp(0, 255);
    final g = (G * 255.0).round().clamp(0, 255);
    final b = (B * 255.0).round().clamp(0, 255);

    return (r: r, g: g, b: b);
  }

  /// Calculates OpenCV 8-bit LAB statistics (mean and standard deviation)
  /// for a given [image] matching `cv2.meanStdDev`.
  static ReinhardStats computeStats(img.Image image) {
    final w = image.width;
    final h = image.height;
    final n = w * h;
    if (n == 0) return ReinhardStats.defaultReferenceStats;

    double sumL = 0, sumA = 0, sumB = 0;
    final lVals = Float64List(n);
    final aVals = Float64List(n);
    final bVals = Float64List(n);

    var idx = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final lab = rgbToLab(p.r.toInt(), p.g.toInt(), p.b.toInt());
        lVals[idx] = lab.l;
        aVals[idx] = lab.a;
        bVals[idx] = lab.b;
        sumL += lab.l;
        sumA += lab.a;
        sumB += lab.b;
        idx++;
      }
    }

    final meanL = sumL / n;
    final meanA = sumA / n;
    final meanB = sumB / n;

    double varL = 0, varA = 0, varB = 0;
    for (var i = 0; i < n; i++) {
      final dl = lVals[i] - meanL;
      final da = aVals[i] - meanA;
      final db = bVals[i] - meanB;
      varL += dl * dl;
      varA += da * da;
      varB += db * db;
    }

    final stdL = math.sqrt(varL / n);
    final stdA = math.sqrt(varA / n);
    final stdB = math.sqrt(varB / n);

    return ReinhardStats(
      meanL: meanL,
      meanA: meanA,
      meanB: meanB,
      stdL: stdL,
      stdA: stdA,
      stdB: stdB,
    );
  }

  /// Direct normalization matching Python `reinhard_normalize(source, target)`.
  static img.Image normalize(img.Image source, img.Image target) {
    final tgtStats = computeStats(target);
    return normalizeImage(source, tgtStats);
  }

  /// Synchronously normalizes [source] image against [refStats] matching
  /// OpenCV channel-wise transfer:
  /// `((src_lab - src_mean) * (tgt_std / (src_std + 1e-8))) + tgt_mean`
  static img.Image normalizeImage(img.Image source, ReinhardStats refStats) {
    final srcStats = computeStats(source);
    final w = source.width;
    final h = source.height;
    final out = img.Image(width: w, height: h, numChannels: source.numChannels);

    // Channel scaling factors matching Python: tgt_std / (src_std + 1e-8)
    final scaleL = refStats.stdL / (srcStats.stdL + 1e-8);
    final scaleA = refStats.stdA / (srcStats.stdA + 1e-8);
    final scaleB = refStats.stdB / (srcStats.stdB + 1e-8);

    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = source.getPixel(x, y);
        final lab = rgbToLab(p.r.toInt(), p.g.toInt(), p.b.toInt());

        // res_lab = ((src_lab - src_mean) * scale) + tgt_mean
        // np.clip(res_lab, 0, 255).astype(np.uint8)
        final resL = ((lab.l - srcStats.meanL) * scaleL + refStats.meanL)
            .clamp(0.0, 255.0)
            .roundToDouble();
        final resA = ((lab.a - srcStats.meanA) * scaleA + refStats.meanA)
            .clamp(0.0, 255.0)
            .roundToDouble();
        final resB = ((lab.b - srcStats.meanB) * scaleB + refStats.meanB)
            .clamp(0.0, 255.0)
            .roundToDouble();

        // Convert back to RGB: cv2.cvtColor(res_lab, cv2.COLOR_LAB2RGB)
        final rgb = labToRgb(resL, resA, resB);

        out.setPixelRgba(x, y, rgb.r, rgb.g, rgb.b, p.a);
      }
    }
    return out;
  }

  /// Whether to run normalization in a background isolate via [compute].
  ///
  /// Enabled in production for smooth UI execution; disabled in tests
  /// where fake-async clocks in [WidgetTester.pumpAndSettle] cannot synchronize with isolates.
  @visibleForTesting
  static bool useIsolate = !Platform.environment.containsKey('FLUTTER_TEST');

  /// Asynchronously normalizes [sourceBytes] in a background isolate to keep UI smooth.
  static Future<Uint8List> normalizeBytes(
    Uint8List sourceBytes, {
    ReinhardStats? refStats,
  }) async {
    final stats = refStats ?? _cachedRefStats;
    final params = _NormalizeParams(sourceBytes, stats);
    if (!useIsolate) {
      return _isolateNormalizeWorker(params);
    }
    return compute(
      _isolateNormalizeWorker,
      params,
    );
  }

  /// Convenience wrapper that normalizes an [XrayImage] and returns a new [XrayImage]
  /// preserving the original filename and source.
  static Future<XrayImage> normalizeXrayImage(
    XrayImage image, {
    AssetBundle? bundle,
    ReinhardStats? refStats,
  }) async {
    try {
      final stats = refStats ??
          (bundle != null
              ? await getReferenceStats(bundle: bundle)
              : _cachedRefStats);
      final normalizedBytes =
          await normalizeBytes(image.bytes, refStats: stats);
      return XrayImage.fromBytes(
        bytes: normalizedBytes,
        filename: image.filename,
        source: image.source,
      );
    } catch (_) {
      // Gracefully fall back to unnormalized image if anything goes wrong.
      return image;
    }
  }
}
