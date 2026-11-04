import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'package:myapp/data/models_ota/bundle_archive.dart';
import 'package:myapp/data/models_ota/bundle_download.dart';
import 'package:myapp/data/models_ota/bundle_verifier.dart';
import 'package:myapp/data/models_ota/model_store.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/models.dart';
export 'package:myapp/domain/models/model_download_progress.dart' show ModelDownloadProgress, ModelInstallPhase;

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
    Dio? authenticatedDio,
    Uri? apiBase,
    ModelStore? store,
  }) : _dio = downloadDio,
       _engine = engine,
       _authenticatedDio = authenticatedDio,
       _apiBase = apiBase,
       _store = store ?? ModelStore();

  final Dio _dio;
  final Dio? _authenticatedDio;
  final Uri? _apiBase;
  static bool isApiBundle(String url, Uri base) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.hasAuthority &&
        uri.userInfo.isEmpty &&
        uri.origin == base.origin &&
        uri.path.startsWith('${base.path}/models/');
  }

  final OnnxInferenceEngine _engine;
  final ModelStore _store;

  OnnxInferenceEngine get engine => _engine;
  ModelStore get store => _store;

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
    final authenticated =
        _authenticatedDio != null &&
        _apiBase != null &&
        isApiBundle(downloadUrl, _apiBase);
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
                dio: authenticated ? _authenticatedDio : _dio,
                followRedirects: !authenticated,
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
      if (manifest.bundleVersion != version && version.isNotEmpty) {
        throw StateError(
          'downloaded bundle is v${manifest.bundleVersion}, expected v$version',
        );
      }
      if (smokeTestSampleBytes.isNotEmpty) {
        await _engine.smokeTestBundleDir(destDir, smokeTestSampleBytes);
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
  }

  /// Verifies an already downloaded bundle directory on disk without re-downloading.
  Future<bool> verifyExistingBundle(
    String bundleKey, {
    Uint8List? smokeTestSampleBytes,
  }) async {
    final d = await _store.versionDir(bundleKey);
    if (!await d.exists()) {
      throw StateError(
        'Direktori model $bundleKey tidak ditemukan di perangkat.',
      );
    }
    try {
      await verifyBundleDir(d);
      Uint8List? sample = smokeTestSampleBytes;
      if (sample == null) {
        try {
          final loaded = await rootBundle.load('assets/sample/xray.png');
          sample = loaded.buffer.asUint8List();
        } catch (_) {}
      }
      if (sample != null && sample.isNotEmpty) {
        await _engine.smokeTestBundleDir(d, sample);
      }
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

  /// Activates an already installed bundle, executes a smoke test, and reloads the inference engine.
  Future<void> activateExisting(
    String bundleKey, {
    Uint8List? smokeTestSampleBytes,
  }) async {
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
    var initPassed = false;
    try {
      final opened = await _engine.init();
      if (!opened) {
        throw StateError('Failed to initialize inference engine for $bundleKey');
      }
      initPassed = true;

      Uint8List? sample = smokeTestSampleBytes;
      if (sample == null) {
        try {
          final data = await rootBundle.load('assets/sample/xray.png');
          sample = data.buffer.asUint8List();
        } catch (_) {}
      }

      if (sample != null) {
        await _engine.smokeTest(sample);
      }
    } catch (e) {
      await _store.setBundleStatus(
        bundleKey,
        ModelBundleStatus.verificationFailed,
        error: '$e',
      );
      await _rollback();
      throw ModelInstallException(
        initPassed
            ? ModelInstallPhase.smokeTesting
            : ModelInstallPhase.activating,
        '$e',
      );
    }
  }

  /// Swap back to the previously-active bundle (if any) and reopen it.
  Future<void> _rollback() async {
    try {
      if (await _store.previousVersion() != null) {
        await _store.rollback();
      } else {
        await _store.clearActive();
      }
    } catch (_) {
      try {
        await _store.clearActive();
      } catch (_) {}
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
