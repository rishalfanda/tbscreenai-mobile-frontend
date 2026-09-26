import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:myapp/data/onnx/inference_result.dart';
import 'package:myapp/domain/models/segmentation_overlays.dart';

/// Renders the lung/lesion segmentation to PNGs on a background isolate.
/// Ported from `inf_app`'s `segmentation_overlay.dart` — pure presentation,
/// no pipeline maths here. [InferenceResult] already carries everything
/// needed (`gridSize`, `lungMask`, `labelMap`, `lesionPaletteRgb`), so unlike
/// `inf_app` this doesn't need the bundle manifest passed in separately.
Future<SegmentationOverlays?> renderSegmentationOverlays({
  required Uint8List xrayBytes,
  required InferenceResult result,
}) async {
  final rendered = await compute(
    _render,
    _OverlayRequest(
      xrayBytes: xrayBytes,
      height: result.gridSize[0],
      width: result.gridSize[1],
      lungMask: result.lungMask,
      labelMap: result.labelMap,
      palette: result.lesionPaletteRgb,
    ),
  );
  if (rendered == null) return null;

  final counts = result.lesionPixelCounts;
  final legend = <LesionLegendEntry>[
    for (var i = 0; i < result.lesionNames.length; i++)
      LesionLegendEntry(
        name: result.lesionNames[i],
        red: result.lesionPaletteRgb[i][0],
        green: result.lesionPaletteRgb[i][1],
        blue: result.lesionPaletteRgb[i][2],
        pixelCount: counts[i],
      ),
  ];

  return SegmentationOverlays(
    xrayPng: rendered.xray,
    lungPng: rendered.lung,
    lesionPng: rendered.lesion,
    legend: legend,
  );
}

class _RenderedPngs {
  const _RenderedPngs({
    required this.xray,
    required this.lung,
    required this.lesion,
  });

  final Uint8List xray;
  final Uint8List lung;
  final Uint8List lesion;
}

class _OverlayRequest {
  const _OverlayRequest({
    required this.xrayBytes,
    required this.height,
    required this.width,
    required this.lungMask,
    required this.labelMap,
    required this.palette,
  });

  final Uint8List xrayBytes;
  final int height;
  final int width;
  final Uint8List lungMask;
  final Int16List labelMap;
  final List<List<int>> palette;
}

_RenderedPngs? _render(_OverlayRequest req) {
  // `image`'s format sniffing can throw (not just return null) on bytes it
  // doesn't recognize — e.g. a DICOM X-ray, which this package can't decode
  // at all. Segmentation is a nice-to-have on top of the classification
  // result, so any decode failure here should just mean "no overlay", never
  // take the whole analysis down with it.
  try {
    final decoded = img.decodeImage(req.xrayBytes);
    if (decoded == null) return null;

    final backdrop = img.copyResize(
      decoded,
      width: req.width,
      height: req.height,
      interpolation: img.Interpolation.linear,
    );

    return _RenderedPngs(
      xray: Uint8List.fromList(img.encodePng(backdrop)),
      lung: Uint8List.fromList(img.encodePng(_lungOverlay(backdrop, req))),
      lesion: Uint8List.fromList(
        img.encodePng(_lesionOverlay(backdrop, req)),
      ),
    );
  } catch (_) {
    return null;
  }
}

img.Image _lungOverlay(img.Image backdrop, _OverlayRequest req) {
  final h = req.height, w = req.width;
  final canvas = backdrop.clone();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final inside = req.lungMask[y * w + x] != 0;
      if (!inside) continue;
      if (_isBoundary(req.lungMask, x, y, w, h)) {
        canvas.setPixelRgba(x, y, 79, 195, 247, 255); // primary blue outline
      } else {
        _blend(canvas, x, y, 79, 195, 247, 0.16);
      }
    }
  }
  return canvas;
}

img.Image _lesionOverlay(img.Image backdrop, _OverlayRequest req) {
  final h = req.height, w = req.width;
  final canvas = backdrop.clone();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final cls = req.labelMap[y * w + x];
      if (cls < 0 || cls >= req.palette.length) continue;
      final c = req.palette[cls];
      _blend(canvas, x, y, c[0], c[1], c[2], 0.55);
    }
  }
  return canvas;
}

void _blend(img.Image im, int x, int y, int r, int g, int b, double a) {
  final p = im.getPixel(x, y);
  im.setPixelRgba(
    x,
    y,
    (p.r * (1 - a) + r * a).round(),
    (p.g * (1 - a) + g * a).round(),
    (p.b * (1 - a) + b * a).round(),
    255,
  );
}

bool _isBoundary(Uint8List mask, int x, int y, int w, int h) {
  for (final d in const [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ]) {
    final nx = x + d[0], ny = y + d[1];
    if (nx < 0 || ny < 0 || nx >= w || ny >= h) return true;
    if (mask[ny * w + nx] == 0) return true;
  }
  return false;
}
