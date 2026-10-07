import 'dart:typed_data';

import 'package:myapp/data/onnx/bundle_manifest.dart';
import 'package:myapp/data/onnx/tensor.dart';

/// Structured output of one pipeline run through the bundle's ONNX chain.
class InferenceResult {
  InferenceResult({
    required this.decisionIsTb,
    required this.probabilityFused,
    required this.probabilityCnn,
    required this.probabilityRf,
    required this.lungMask,
    required this.labelMap,
    required this.confidence,
    required this.featureVector,
    required this.featureNames,
    required this.lesionNames,
    required this.lesionPaletteRgb,
    required this.positiveLabel,
    required this.negativeLabel,
    required this.gridSize,
    required this.bundleVersion,
    required this.rfModel,
    required this.decisionThreshold,
    required this.elapsed,
    required this.providersUsed,
    this.stepTimings = const {},
  });

  /// Final verdict after fusion + threshold.
  final bool decisionIsTb;

  /// `P(TB)` fused, 0..1.
  final double probabilityFused;

  /// Per-branch `P(TB)`, 0..1. `-1` if that branch was absent.
  final double probabilityCnn;
  final double probabilityRf;

  /// 256x256, `{0,1}` — the dilated lung field.
  final Uint8List lungMask;

  /// 256x256 — lesion class `0..5`, or `-1` (background / low-conf / outside lung).
  final Int16List labelMap;

  /// 256x256 — max softmax confidence of the lesion class map.
  final Float32List confidence;

  /// The 36-value RF design vector.
  final List<double> featureVector;
  final List<String> featureNames;

  final List<String> lesionNames;
  final List<List<int>> lesionPaletteRgb;

  /// Verdict labels from `manifest.render` (e.g. `"TB"` / `"NON TB"`).
  final String positiveLabel;
  final String negativeLabel;

  /// `[H, W]` of the mask grid (256x256).
  final List<int> gridSize;

  final String bundleVersion;
  final String rfModel;

  final double decisionThreshold;
  final Duration elapsed;

  /// `model file -> execution provider`.
  final Map<String, String> providersUsed;

  /// `step.id -> wall-clock` for the ONNX chain.
  final Map<String, Duration> stepTimings;

  int get lungAreaPx {
    var n = 0;
    for (final v in lungMask) {
      if (v != 0) n++;
    }
    return n;
  }

  /// Per-class lesion pixel counts, in `lesionNames` order.
  List<int> get lesionPixelCounts {
    final counts = List<int>.filled(lesionNames.length, 0);
    for (final v in labelMap) {
      if (v >= 0 && v < counts.length) counts[v]++;
    }
    return counts;
  }

  int get lesionAreaPx => lesionPixelCounts.fold(0, (a, b) => a + b);

  double get positiveConfidence =>
      decisionIsTb ? probabilityFused : (1.0 - probabilityFused);

  // --------------------------------------------------------------- //
  /// Build from the chain executor's `manifest.outputs` map.
  static InferenceResult fromChainOutputs(
    Map<String, Tensor> out, {
    required BundleManifest manifest,
    required Duration elapsed,
    required Map<String, String> providersUsed,
    required Map<String, Duration> stepTimings,
    required String rfModel,
  }) {
    final h = manifest.segImageSize[0];
    final w = manifest.segImageSize[1];

    // Keys here are the `manifest.outputs` UI names — the schema-v1 contract,
    // already gated by `manifest.schemaSupported`.
    final pFused = out['probability']!.firstAsDouble;
    final isTb = out['decision']!.firstAsDouble.round() == 1;

    final pCnn = out['probability_cnn'] != null
        ? _tbColumn(out['probability_cnn']!, manifest.cnnTbIndex)
        : -1.0;
    final pRf = out['probability_rf'] != null
        ? _tbColumn(out['probability_rf']!, manifest.rfTbIndex)
        : -1.0;

    final lungMaskF = out['lung_mask']!.to2dFloat(h, w);
    final lungThreshold = manifest.lungThreshold;
    final lungMask = Uint8List(h * w);
    for (var i = 0; i < lungMask.length; i++) {
      lungMask[i] = lungMaskF[i] >= lungThreshold ? 1 : 0;
    }

    final labelF = out['lesion_map']!.to2dInt(h, w);
    final labelMap = Int16List(h * w);
    for (var i = 0; i < labelMap.length; i++) {
      labelMap[i] = labelF[i];
    }

    final confidence = out['confidence'] != null
        ? out['confidence']!.to2dFloat(h, w)
        : Float32List(h * w);

    return InferenceResult(
      decisionIsTb: isTb,
      probabilityFused: pFused.clamp(0.0, 1.0),
      probabilityCnn: pCnn,
      probabilityRf: pRf,
      lungMask: lungMask,
      labelMap: labelMap,
      confidence: confidence,
      featureVector: out['features']?.toDoubleList() ?? const [],
      featureNames: manifest.featureOrder,
      lesionNames: manifest.render.lesionNames,
      lesionPaletteRgb: manifest.render.lesionPaletteRgb,
      positiveLabel: manifest.render.positiveLabel,
      negativeLabel: manifest.render.negativeLabel,
      gridSize: [h, w],
      bundleVersion: manifest.bundleVersion,
      rfModel: rfModel,
      decisionThreshold: manifest.decisionThreshold,
      elapsed: elapsed,
      providersUsed: providersUsed,
      stepTimings: stepTimings,
    );
  }

  static double _tbColumn(Tensor probs, int idx) {
    final flat = probs.toDoubleList();
    if (flat.length > idx) return flat[idx].clamp(0.0, 1.0);
    return flat.isNotEmpty ? flat.last.clamp(0.0, 1.0) : -1.0;
  }
}
