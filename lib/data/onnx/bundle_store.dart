import 'dart:convert';
import 'dart:io';

import 'package:myapp/data/onnx/bundle_manifest.dart';

/// A verified model bundle on disk (one `models/<version>/` directory managed by
/// `ModelStore`).
///
/// Layout:
/// ```
/// <version>/
///   manifest.json
///   labels.json
///   SHA256SUMS  SHA256SUMS.sig
///   verified.json            written by the bundle verifier at install time
///   models/*.onnx  (or *.ort)
/// ```
///
/// Bundles are downloaded, signature-verified and staged by
/// `lib/data/models_ota/`; this type only opens an already-verified directory
/// for inference.
class BundleStore {
  BundleStore._({
    required this.dir,
    required this.manifest,
    required this.labels,
    required this.modelPaths,
  });

  final Directory dir;
  final BundleManifest manifest;
  final BundleLabels labels;

  /// model-file **stem** (`seg_lung`) -> absolute path (`.../models/seg_lung.onnx`).
  final Map<String, String> modelPaths;

  bool integrityVerified = false;
  String? integrityNote;

  String get version => manifest.bundleVersion;

  /// Absolute path for a model referenced by the manifest (`seg_lung.onnx` or a
  /// resolved `rf_<token>.onnx`). Extension-agnostic.
  String modelPath(String file) {
    final stem = file.split('/').last.split('.').first;
    final path = modelPaths[stem];
    if (path == null) {
      throw BundleException('model "$stem" is not in the bundle');
    }
    return path;
  }

  /// Open (parse) a staged bundle directory. Assumes the verifier has already
  /// checked its signature + digests; re-applies the schema gate defensively.
  static Future<BundleStore> open(Directory dir) async {
    final manifestJson =
        await File('${dir.path}${Platform.pathSeparator}manifest.json')
            .readAsString();
    final manifest = BundleManifest.parse(manifestJson);
    if (!manifest.schemaSupported) {
      throw BundleException(
        'bundle schema v${manifest.schemaVersion} is newer than this app '
        'supports (v${BundleManifest.maxSupportedSchema}) — update the app',
      );
    }

    final labelsFile =
        File('${dir.path}${Platform.pathSeparator}labels.json');
    final labels = await labelsFile.exists()
        ? BundleLabels.parse(await labelsFile.readAsString())
        : BundleLabels(
            decision: [
              manifest.render.negativeLabel,
              manifest.render.positiveLabel,
            ],
            lesionClasses: manifest.render.lesionNames,
            lesionPaletteRgb: manifest.render.lesionPaletteRgb,
          );

    final modelsDir = Directory('${dir.path}${Platform.pathSeparator}models');
    final modelPaths = <String, String>{};
    if (await modelsDir.exists()) {
      await for (final e in modelsDir.list()) {
        if (e is File) {
          final name = e.path.split(Platform.pathSeparator).last;
          final ext = name.split('.').last.toLowerCase();
          if (ext == 'ort' || ext == 'onnx') {
            modelPaths[name.split('.').first] = e.path;
          }
        }
      }
    }

    final store = BundleStore._(
      dir: dir,
      manifest: manifest,
      labels: labels,
      modelPaths: modelPaths,
    );
    await store._readVerifiedMarker();
    return store;
  }

  Future<void> _readVerifiedMarker() async {
    final f = File('${dir.path}${Platform.pathSeparator}verified.json');
    if (!await f.exists()) {
      integrityVerified = false;
      integrityNote = 'not verified';
      return;
    }
    try {
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      integrityVerified = m['signature'] == 'ed25519';
      integrityNote =
          integrityVerified ? 'Ed25519 signature verified' : 'unverified';
    } catch (_) {
      integrityVerified = false;
      integrityNote = 'verification marker unreadable';
    }
  }
}

class BundleException implements Exception {
  BundleException(this.message);
  final String message;
  @override
  String toString() => 'BundleException: $message';
}
