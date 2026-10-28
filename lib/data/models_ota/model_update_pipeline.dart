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
import 'package:myapp/domain/models/models.dart';

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
class ModelUpdatePipeline {
  ModelUpdatePipeline({
    required Dio downloadDio,
    required OnnxInferenceEngine engine,
  }) : _dio = downloadDio,
       _engine = engine;

  final Dio _dio;
  final OnnxInferenceEngine _engine;
  final ModelStore _store = ModelStore();

  /// Downloads, verifies, and stages a model bundle with speed and cancellation support.
  Stream<ModelDownloadProgress> installBundleWithProgress({
    required String bundleKey,
    required String version,
    required String downloadUrl,
    String? sha256,
    CancelToken? cancelToken,
    Map<String, dynamic>? metadata,
    required Uint8List smokeTestSampleBytes,
  }) async* {
    if (downloadUrl.isEmpty) {
      throw ModelInstallException(
        ModelInstallPhase.downloading,
        'no download URL available for this model bundle',
      );
    }

    final incomingName = '_download_${DateTime.now().millisecondsSinceEpoch}';
    final tempDir = await getTemporaryDirectory();
    final zipFile = File(
      '${tempDir.path}${Platform.pathSeparator}model_$incomingName.zip',
    );

    var lastReceived = 0;
    var lastTotal = 0;

    try {
      final progressController = StreamController<ModelDownloadProgress>();
      unawaited(
        downloadBundleZip(
              dio: _dio,
              url: downloadUrl,
              dest: zipFile,
              sha256Hex: sha256,
              cancelToken: cancelToken,
              onProgress: (received, total, speed) {
                lastReceived = received;
                lastTotal = total;
                if (!progressController.isClosed) {
                  final fraction = total > 0 ? received / total : 0.0;
                  progressController.add(
                    ModelDownloadProgress(
                      fraction: fraction.clamp(0.0, 1.0),
                      receivedBytes: received,
                      totalBytes: total,
                      bytesPerSecond: speed,
                      speedText: ModelDownloadProgress.formatSpeed(speed),
                      phase: ModelInstallPhase.downloading,
                    ),
                  );
                }
              },
            )
            .then((_) => progressController.close())
            .catchError((Object e) {
              if (!progressController.isClosed) {
                progressController.addError(e);
                progressController.close();
              }
            }),
      );

      await for (final progress in progressController.stream) {
        yield progress;
      }
    } catch (e) {
      await _cleanupTemp(zipFile);
      if (e is ModelInstallCancelledException) rethrow;
      throw ModelInstallException(ModelInstallPhase.downloading, '$e');
    }

    if (cancelToken?.isCancelled ?? false) {
      await _cleanupTemp(zipFile);
      throw const ModelInstallCancelledException();
    }

    yield ModelDownloadProgress(
      fraction: 1.0,
      receivedBytes: lastReceived,
      totalBytes: lastTotal,
      phase: ModelInstallPhase.verifying,
    );

    late final Directory incomingDir;
    try {
      incomingDir = await _store.freshIncomingDir(incomingName);
      await extractBundleZip(zipFile.path, incomingDir.path);
    } catch (e) {
      await _cleanupTemp(zipFile);
      await _store.wipeIncoming();
      throw ModelInstallException(ModelInstallPhase.downloading, '$e');
    }
    await _cleanupTemp(zipFile);

    // Promote to version directory and set initial downloaded status
    try {
      await _store.promoteIncoming(incomingName, asVersion: bundleKey);
      if (metadata != null) {
        await _store.writeBundleMeta(bundleKey, metadata);
      }
      await _store.setBundleStatus(bundleKey, ModelBundleStatus.downloaded);
    } catch (e) {
      throw ModelInstallException(ModelInstallPhase.activating, '$e');
    }

    // Verify downloaded bundle on disk
    final destDir = await _store.versionDir(bundleKey);
    try {
      final manifest = await verifyBundleDir(destDir);
      if (manifest.bundleVersion != version) {
        throw StateError(
          'downloaded bundle is v${manifest.bundleVersion}, expected v$version',
        );
      }
      await _store.setBundleStatus(bundleKey, ModelBundleStatus.verified);
    } catch (e) {
      await _store.setBundleStatus(
        bundleKey,
        ModelBundleStatus.verificationFailed,
        error: '$e',
      );
      throw ModelInstallException(ModelInstallPhase.verifying, '$e');
    }

    yield ModelDownloadProgress(
      fraction: 1.0,
      receivedBytes: lastReceived,
      totalBytes: lastTotal,
      phase: ModelInstallPhase.completed,
    );
  }

  /// Downloads, verifies and activates a specific model bundle (returns 0.0..1.0 progress).
  Stream<double> installBundle({
    required String bundleKey,
    required String version,
    required String downloadUrl,
    String? sha256,
    CancelToken? cancelToken,
    Map<String, dynamic>? metadata,
    required Uint8List smokeTestSampleBytes,
  }) async* {
    await for (final p in installBundleWithProgress(
      bundleKey: bundleKey,
      version: version,
      downloadUrl: downloadUrl,
      sha256: sha256,
      cancelToken: cancelToken,
      metadata: metadata,
      smokeTestSampleBytes: smokeTestSampleBytes,
    )) {
      yield p.fraction;
    }
  }

  /// Downloads, verifies and activates [info]'s bundle. Emits download
  /// progress 0.0..1.0 (matching `SyncRepository.downloadModel()`'s existing
  /// contract) and completes once the new bundle has passed its smoke test.
  /// Throws [ModelInstallException] on any failure.
  Stream<double> install({
    required ModelVersionInfo info,
    required Uint8List smokeTestSampleBytes,
    CancelToken? cancelToken,
  }) async* {
    final url = info.downloadUrl;
    if (url == null || url.isEmpty) {
      throw ModelInstallException(
        ModelInstallPhase.downloading,
        'no download URL available for this model version',
      );
    }
    yield* installBundle(
      bundleKey: info.latestVersion,
      version: info.latestVersion,
      downloadUrl: url,
      sha256: info.sha256,
      cancelToken: cancelToken,
      smokeTestSampleBytes: smokeTestSampleBytes,
    );
    await activateExisting(info.latestVersion);
    try {
      await _engine.smokeTest(smokeTestSampleBytes);
    } catch (e) {
      await _rollback();
      throw ModelInstallException(ModelInstallPhase.smokeTesting, '$e');
    }
  }

  /// Verifies an already downloaded bundle directory on disk without re-downloading.
  Future<bool> verifyExistingBundle(String bundleKey) async {
    final d = await _store.versionDir(bundleKey);
    if (!await d.exists()) {
      throw StateError(
        'Direktori model $bundleKey tidak ditemukan di perangkat.',
      );
    }
    try {
      await verifyBundleDir(d);
      await _store.setBundleStatus(bundleKey, ModelBundleStatus.verified);
      return true;
    } catch (e) {
      await _store.setBundleStatus(
        bundleKey,
        ModelBundleStatus.verificationFailed,
        error: '$e',
      );
      throw ModelInstallException(ModelInstallPhase.verifying, '$e');
    }
  }

  /// Deletes a bundle and unloads session if currently active.
  Future<void> deleteBundle(String bundleKey) async {
    final active = await _store.activeVersion();
    await _store.deleteBundle(bundleKey);
    if (active == bundleKey) {
      await _engine.init();
    }
  }

  /// Activates an already installed bundle and reloads the inference engine.
  Future<void> activateExisting(String bundleKey) async {
    final isInstalled = await _store.isInstalled(bundleKey);
    if (!isInstalled) {
      throw StateError('Bundle $bundleKey is not installed on this device.');
    }
    final status = await _store.getBundleStatus(bundleKey);
    if (status != ModelBundleStatus.verified) {
      throw StateError(
        'Model $bundleKey belum terverifikasi dan tidak dapat digunakan.',
      );
    }
    await _store.activate(bundleKey);
    final opened = await _engine.init();
    if (!opened) {
      await _rollback();
      throw StateError('Failed to initialize inference engine for $bundleKey');
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
