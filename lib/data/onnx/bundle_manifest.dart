import 'dart:convert';

/// Typed view over `manifest.json` (see `week-1/pipeline-app/METHODOLOGY.md` §1.5
/// and `build/manifest.py`).
///
/// The app is driven entirely by this file — it holds no TB-specific constants of
/// its own. Everything the chain executor and the UI need is here.
class BundleManifest {
  BundleManifest._({
    required this.schemaVersion,
    required this.bundleVersion,
    required this.createdUtc,
    required this.input,
    required this.pipeline,
    required this.rfActive,
    required this.rfAvailable,
    required this.outputs,
    required this.render,
    required this.bakedConstants,
    required this.featureOrder,
    required this.fileDigests,
  });

  /// The highest `schema_version` this build of the app can execute.
  static const int maxSupportedSchema = 1;

  final int schemaVersion;
  final String bundleVersion;
  final String createdUtc;

  final ManifestInput input;

  /// The ordered chain. Run front to back.
  final List<PipelineStep> pipeline;

  /// `rf_<token>.ort` used by default, and every RF file available.
  final String rfActive;
  final List<String> rfAvailable;

  /// `ui_name -> "<step_id>.<output_name>"`.
  final Map<String, String> outputs;

  final ManifestRender render;

  /// Constants compiled into the graphs — thresholds, class indices, image
  /// sizes. Read through the typed accessors below.
  final Map<String, dynamic> bakedConstants;

  /// The 36 feature names, in `feature_vec` output order.
  final List<String> featureOrder;

  /// `models/<file> -> sha256`, for integrity checks.
  final Map<String, String> fileDigests;

  bool get schemaSupported => schemaVersion <= maxSupportedSchema;

  /// The RF file for a dataset name (fuzzy), or the default active one.
  String resolveRfFile(String? dataset) {
    if (dataset == null || dataset.trim().isEmpty) return rfActive;
    final key = dataset.trim().toLowerCase();
    for (final file in rfAvailable) {
      final token = _stem(file).replaceFirst('rf_', '');
      if (token == key || key.contains(token) || token.contains(key)) {
        return file;
      }
    }
    return rfActive;
  }

  /// The RF token (dataset name) for a `rf_<token>.ort` file.
  static String rfToken(String file) => _stem(file).replaceFirst('rf_', '');

  /// Every model file referenced by the chain (with `@rf_active` resolved).
  List<String> referencedModelFiles({String? rfDataset}) {
    final rf = resolveRfFile(rfDataset);
    return [for (final step in pipeline) step.isRfActive ? rf : step.model];
  }

  static String _stem(String file) => file.split('/').last.split('.').first;

  /// Parses `manifest.json`. Every value the chain executor or UI needs is
  /// **required** — a missing or wrong-type key throws [FormatException] rather
  /// than falling back to an app-baked default. The app holds no TB constants of
  /// its own; the bundle is the single source of truth.
  static BundleManifest parse(String jsonText) {
    final m = jsonDecode(jsonText) as Map<String, dynamic>;

    final input = _reqMap(m, 'input');
    final render = _reqMap(m, 'render');
    final rf = _reqMap(m, 'rf');
    final bakedConstants = _reqMap(m, 'baked_constants');
    final rawDigests =
        (m['file_digests_sha256'] as Map<String, dynamic>?) ?? const {};

    final rfAvailable = _reqList(rf, 'available').cast<String>();
    if (rfAvailable.isEmpty) {
      throw const FormatException('manifest.json: "rf.available" is empty');
    }

    final pipeline = <PipelineStep>[];
    for (final raw in _reqList(m, 'pipeline')) {
      final s = raw as Map<String, dynamic>;
      pipeline.add(
        PipelineStep(
          id: _reqString(s, 'id'),
          model: _reqString(s, 'model'),
          inputs: _reqMap(s, 'inputs').cast<String, String>(),
          outputs: _reqList(s, 'outputs').cast<String>(),
          epPreference: _reqList(s, 'ep_preference').cast<String>(),
        ),
      );
    }
    if (pipeline.isEmpty) {
      throw const FormatException('manifest.json: "pipeline" is empty');
    }

    final outputs = _reqMap(m, 'outputs').cast<String, String>();
    if (outputs.isEmpty) {
      throw const FormatException('manifest.json: "outputs" is empty');
    }

    return BundleManifest._(
      schemaVersion: _reqNum(m, 'schema_version').toInt(),
      bundleVersion: (m['bundle_version'] as String?) ?? 'unknown',
      createdUtc: (m['created_utc'] as String?) ?? '',
      input: ManifestInput(
        name: _reqString(input, 'name'),
        dtype: _reqString(input, 'dtype'),
        layout: _reqString(input, 'layout'),
        channels: _reqString(input, 'channels'),
      ),
      pipeline: pipeline,
      rfActive: _reqString(rf, 'active'),
      rfAvailable: rfAvailable,
      outputs: outputs,
      render: ManifestRender(
        positiveLabel: _reqString(render, 'positive_label'),
        negativeLabel: _reqString(render, 'negative_label'),
        lesionNames: _reqList(render, 'lesion_names').cast<String>(),
        lesionPaletteRgb: [
          for (final c in _reqList(render, 'lesion_palette_rgb'))
            (c as List).cast<num>().map((n) => n.toInt()).toList(),
        ],
      ),
      bakedConstants: bakedConstants,
      featureOrder: _reqList(m, 'feature_order').cast<String>(),
      fileDigests: rawDigests.map((k, v) => MapEntry(k, v as String)),
    );
  }

  static Map<String, dynamic> _reqMap(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is Map<String, dynamic>) return v;
    throw FormatException('manifest.json: missing or malformed object "$key"');
  }

  static List<dynamic> _reqList(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is List) return v;
    throw FormatException('manifest.json: missing or malformed array "$key"');
  }

  static String _reqString(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is String && v.isNotEmpty) return v;
    throw FormatException('manifest.json: missing string "$key"');
  }

  static num _reqNum(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is num) return v;
    throw FormatException('manifest.json: missing number "$key"');
  }

  // --- constants compiled into the graphs, read from `baked_constants` --- //
  List<int> get segImageSize => _constPair('seg_image_size');
  List<int> get clsImageSize => _constPair('cls_image_size');
  int get lesionNumClasses => _constNum('lesion_num_classes').toInt();
  double get decisionThreshold => _constNum('decision_threshold').toDouble();
  double get fusionAlphaRf => _constNum('fusion_alpha_rf').toDouble();
  int get cnnTbIndex => _constNum('cnn_tb_index').toInt();
  int get rfTbIndex => _constNum('rf_tb_index').toInt();
  double get lungThreshold => _constNum('lung_threshold').toDouble();
  double get lesionConfThreshold => _constNum('lesion_conf_threshold').toDouble();

  num _constNum(String key) {
    final v = bakedConstants[key];
    if (v is num) return v;
    throw FormatException(
      'manifest.json: baked_constants missing number "$key"',
    );
  }

  List<int> _constPair(String key) {
    final v = bakedConstants[key];
    if (v is List && v.length == 2 && v.every((e) => e is num)) {
      return v.cast<num>().map((n) => n.toInt()).toList();
    }
    throw FormatException(
      'manifest.json: baked_constants missing [x,y] pair "$key"',
    );
  }
}

class ManifestInput {
  const ManifestInput({
    required this.name,
    required this.dtype,
    required this.layout,
    required this.channels,
  });
  final String name;
  final String dtype;
  final String layout; // "NHWC"
  final String channels; // "RGB"
}

class PipelineStep {
  const PipelineStep({
    required this.id,
    required this.model,
    required this.inputs,
    required this.outputs,
    required this.epPreference,
  });

  final String id;

  /// `.ort` filename or the literal `"@rf_active"`.
  final String model;

  /// session-input-name -> `"@input"` or `"<step_id>.<output_name>"`.
  final Map<String, String> inputs;

  /// Positional: session output *i* -> `outputs[i]`.
  final List<String> outputs;

  final List<String> epPreference;

  bool get isRfActive => model == '@rf_active';
}

class ManifestRender {
  const ManifestRender({
    required this.positiveLabel,
    required this.negativeLabel,
    required this.lesionNames,
    required this.lesionPaletteRgb,
  });
  final String positiveLabel;
  final String negativeLabel;
  final List<String> lesionNames;
  final List<List<int>> lesionPaletteRgb;
}

/// `labels.json` — a small convenience duplicate of `manifest.render`.
class BundleLabels {
  const BundleLabels({
    required this.decision,
    required this.lesionClasses,
    required this.lesionPaletteRgb,
  });

  final List<String> decision; // ["NON TB", "TB"]
  final List<String> lesionClasses;
  final List<List<int>> lesionPaletteRgb;

  static BundleLabels parse(String jsonText) {
    final m = jsonDecode(jsonText) as Map<String, dynamic>;
    return BundleLabels(
      decision: (m['decision'] as List).cast<String>(),
      lesionClasses: (m['lesion_classes'] as List).cast<String>(),
      lesionPaletteRgb: [
        for (final c in (m['lesion_palette_rgb'] as List))
          (c as List).cast<num>().map((n) => n.toInt()).toList(),
      ],
    );
  }
}
