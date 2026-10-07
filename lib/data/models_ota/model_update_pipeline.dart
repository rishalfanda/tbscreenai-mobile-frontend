import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:myapp/data/models_ota/bundle_archive.dart';
import 'package:myapp/data/models_ota/bundle_download.dart';
import 'package:myapp/data/models_ota/bundle_verifier.dart';
import 'package:myapp/data/models_ota/model_store.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/installed_bundle_info.dart';
import 'package:myapp/domain/models/model_version_info.dart';

enum ModelInstallPhase { downloading, verifying, activating, smokeTesting }

/// Which stage of the install pipeline failed, for the UI to pick the right
/// Bahasa Indonesia error copy.
class ModelInstallException implements Exception {
  ModelInstallException(this.phase, this.message);
  final ModelInstallPhase phase;
  final String message;
  @override
  String toString() => 'ModelInstallException($phase): $message';
}

/// Orchestrates one model-bundle install: download -> extract -> verify ->
/// activate -> smoke-test, with automatic rollback if anything after
/// activation fails.
///
/// This app's equivalent of `inf_app`'s `UpdateController`, trimmed to a
/// single-version flow — there is no catalogue/channel machinery here, since
/// `OfflineSyncRepository.checkForUpdate()` already owns talking to
/// `/sync/model-version`.
class ModelUpdatePipeline {
  ModelUpdatePipeline({required Dio downloadDio, required OnnxInferenceEngine engine})
      : _dio = downloadDio,
        _engine = engine;

  final Dio _dio;
  final OnnxInferenceEngine _engine;
  final ModelStore _store = ModelStore();

  /// Downloads, verifies and activates [info]'s bundle. Emits download
  /// progress 0.0..1.0 (matching `SyncRepository.downloadModel()`'s existing
  /// contract) and completes once the new bundle has passed its smoke test.
  /// Throws [ModelInstallException] on any failure.
  Stream<double> install({
    required ModelVersionInfo info,
    required Uint8List smokeTestSampleBytes,
  }) async* {
    final url = info.downloadUrl;
    if (url == null || url.isEmpty) {
      throw ModelInstallException(
        ModelInstallPhase.downloading,
        'no download URL available for this model version',
      );
    }

    final incomingName = '_download_${DateTime.now().millisecondsSinceEpoch}';
    final tempDir = await getTemporaryDirectory();
    final zipFile = File(
      '${tempDir.path}${Platform.pathSeparator}model_$incomingName.zip',
    );

    try {
      final progressController = StreamController<double>();
      unawaited(
        downloadBundleZip(
              dio: _dio,
              url: url,
              dest: zipFile,
              sha256Hex: info.sha256,
              onProgress: (received, total) {
                if (!progressController.isClosed) {
                  progressController.add(total > 0 ? received / total : 0.0);
                }
              },
            )
            .then((_) => progressController.close())
            .catchError((Object e) {
              progressController.addError(e);
              progressController.close();
            }),
      );

      await for (final progress in progressController.stream) {
        yield progress.clamp(0.0, 1.0);
      }
    } catch (e) {
      await _cleanupTemp(zipFile);
      throw ModelInstallException(ModelInstallPhase.downloading, '$e');
    }

    late final Directory incomingDir;
    try {
      incomingDir = await _store.freshIncomingDir(incomingName);
      await extractBundleZip(zipFile.path, incomingDir.path);
      final manifest = await verifyBundleDir(incomingDir);
      if (manifest.bundleVersion != info.latestVersion) {
        throw StateError(
          'downloaded bundle is v${manifest.bundleVersion}, expected '
          'v${info.latestVersion}',
        );
      }
    } catch (e) {
      await _cleanupTemp(zipFile);
      await _store.wipeIncoming();
      throw ModelInstallException(ModelInstallPhase.verifying, '$e');
    }
    await _cleanupTemp(zipFile);

    try {
      await _store.promoteIncoming(incomingName, asVersion: info.latestVersion);
      await _store.activate(info.latestVersion);
      final opened = await _engine.init();
      if (!opened) throw StateError('installed bundle failed to open');
    } catch (e) {
      await _rollback();
      throw ModelInstallException(ModelInstallPhase.activating, '$e');
    }

    try {
      await _engine.smokeTest(smokeTestSampleBytes);
    } catch (e) {
      await _rollback();
      throw ModelInstallException(ModelInstallPhase.smokeTesting, '$e');
    }
  }

  /// Swap back to the previously-active bundle (if any) and reopen it.
  Future<void> _rollback() async {
    try {
      if (await _store.previousVersion() != null) {
        await _store.rollback();
      }
    } catch (_) {
      // Nothing to roll back to (first-ever install failed) — leave ACTIVE as
      // it is; `_engine.init()` below reports whatever is actually usable.
    }
    await _engine.init();
  }

  Future<void> _cleanupTemp(File zipFile) async {
    try {
      if (await zipFile.exists()) await zipFile.delete();
    } catch (_) {}
  }

  Future<InstalledBundleInfo?> currentBundleInfo() async {
    final manifest = _engine.manifest;
    if (manifest == null) return null;
    return InstalledBundleInfo(
      bundleVersion: manifest.bundleVersion,
      schemaVersion: manifest.schemaVersion,
      integrityVerified: _engine.integrityVerified,
    );
  }
}
