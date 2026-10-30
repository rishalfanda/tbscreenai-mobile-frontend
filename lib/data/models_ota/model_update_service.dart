import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/models_ota/model_store.dart';
import 'package:myapp/data/models_ota/model_update_pipeline.dart';
import 'package:myapp/domain/models/models.dart';

const _channel = 'stable';
const _appVersion = '1.0.0';

Map<String, dynamic>? _asJsonMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
  }
  return null;
}

/// The real (non-mock) AI-model update mechanism:
/// - GET /models: discovers all available model bundles across channels.
/// - GET /models/check: check for latest stable update.
/// - ModelUpdatePipeline: signed download -> verify -> activate -> smoke-test.
class ModelUpdateService {
  ModelUpdateService({
    required ApiClient client,
    required SettingsStore settings,
    required AppDatabase db,
    required ModelUpdatePipeline modelPipeline,
    ModelStore? store,
  }) : _client = client,
       _settings = settings,
       _db = db,
       _modelPipeline = modelPipeline,
       _store = store ?? ModelStore();

  final ApiClient _client;
  final SettingsStore _settings;
  final AppDatabase _db;
  final ModelUpdatePipeline _modelPipeline;
  final ModelStore _store;

  CancelToken? _currentDownloadCancelToken;

  /// `null` means no model bundle is installed on this device yet.
  Future<String?> getInstalledModelVersion() =>
      _settings.readInstalledModelVersion();

  /// Returns list of all installed bundle keys on disk.
  Future<List<String>> getInstalledModelKeys() =>
      _store.listInstalledBundleKeys();

  /// Cancels any currently active model download.
  void cancelModelDownload() {
    _currentDownloadCancelToken?.cancel('Dibatalkan oleh pengguna');
    _currentDownloadCancelToken = null;
  }

  /// Fetches available model bundles across channels.
  /// When [localOnly] is true, returns only local models on device without network queries.
  Future<List<AvailableModelBundle>> fetchAvailableModels({
    String? channel,
    bool? quantized,
    bool localOnly = false,
  }) async {
    final installed = await _settings.readInstalledModelVersion();
    List<AvailableModelBundle>? rawList;

    if (localOnly) {
      rawList = (await _synthesizeFromInstalledBundles()).where((m) {
        if (channel != null && channel.isNotEmpty && channel != 'all') {
          if (m.channel.toLowerCase() != channel.toLowerCase()) return false;
        }
        if (quantized != null && m.quantized != quantized) return false;
        return true;
      }).toList();
    } else {
      try {
        final response = await _client.dio.get<dynamic>(
          '/models',
          queryParameters: {
            if (channel != null && channel.isNotEmpty) 'channel': channel,
            'quantized': ?quantized,
            'app': _appVersion,
            if (installed != null && installed.isNotEmpty) 'current': installed,
          },
        );
        final data = _asJsonMap(response.data);
        if (data != null) {
          await _settings.saveAvailableModelsCache(jsonEncode(data));
          final modelsRaw = data['models'] as List?;
          if (modelsRaw != null) {
            rawList = modelsRaw
                .whereType<Map<String, dynamic>>()
                .map(AvailableModelBundle.fromJson)
                .toList();
          }
        }
      } catch (_) {
        // Offline fallback: try reading cached catalog.
        final cachedJson = await _settings.readAvailableModelsCache();
        if (cachedJson != null) {
          try {
            final data = jsonDecode(cachedJson) as Map<String, dynamic>;
            final modelsRaw = data['models'] as List?;
            if (modelsRaw != null) {
              rawList = modelsRaw
                  .whereType<Map<String, dynamic>>()
                  .map(AvailableModelBundle.fromJson)
                  .toList();
            }
          } catch (_) {}
        }
      }

      rawList ??= await _synthesizeFromInstalledBundles();
    }

    // Enrich with local device status and active pointer
    final enriched = <AvailableModelBundle>[];
    for (final m in rawList) {
      final status = await _store.getBundleStatus(m.id);
      final meta = await _store.readBundleMeta(m.id);
      final isCurrent = installed != null &&
          (installed.toLowerCase().trim() == m.id.toLowerCase().trim() ||
           installed.toLowerCase().trim() == m.version.toLowerCase().trim());
      enriched.add(
        m.copyWith(
          isCurrent: isCurrent,
          localStatus: status,
          verificationError: meta?['verification_error'] as String?,
        ),
      );
    }
    return enriched;
  }

  Future<List<AvailableModelBundle>> _synthesizeFromInstalledBundles() async {
    final installedKeys = await _store.listInstalledBundleKeys();
    final activeKey = await _settings.readInstalledModelVersion();
    final result = <AvailableModelBundle>[];

    for (final key in installedKeys) {
      final meta = await _store.readBundleMeta(key);
      final status = await _store.getBundleStatus(key);
      if (meta != null) {
        result.add(
          AvailableModelBundle.fromJson(meta).copyWith(
            localStatus: status,
            isCurrent: key == activeKey,
            verificationError: meta['verification_error'] as String?,
          ),
        );
      } else {
        final parts = key.split('_');
        final channel = parts.length > 1 ? parts.first : 'stable';
        final version = parts.length > 1 ? parts.sublist(1).join('_') : key;
        result.add(
          AvailableModelBundle(
            channel: channel,
            version: version,
            isLatest: false,
            isCurrent: key == activeKey,
            localStatus: status,
            notes: 'Installed on device',
          ),
        );
      }
    }
    return result;
  }

  /// Downloads, verifies, and stages the specified model bundle with real-time speed.
  Stream<ModelDownloadProgress> downloadModelWithProgress({
    AvailableModelBundle? model,
  }) async* {
    final session = _db.sessionGeneration;
    _currentDownloadCancelToken = CancelToken();

    try {
      AvailableModelBundle? target = model;
      if (target == null) {
        final info = await checkForUpdate();
        target = AvailableModelBundle(
          channel: _channel,
          version: info.latestVersion,
          isLatest: true,
          bundleZip: info.downloadUrl,
          bundleZipSha256: info.sha256,
          changelog: info.changelog,
        );
      }

      final url = target.bundleZip ?? AppConfig.modelBundleUrl;
      final bundleKey = target.id;
      final version = target.version;

      if (url == null || url.trim().isEmpty) {
        throw ModelInstallException(
          ModelInstallPhase.downloading,
          'Bundle model belum tersedia. Minta admin menyediakan URL download.',
        );
      }

      final sample = await rootBundle.load('assets/sample/xray.png');
      await for (final progress in _modelPipeline.installBundleWithProgress(
        bundleKey: bundleKey,
        version: version,
        downloadUrl: url,
        sha256: target.bundleZipSha256,
        cancelToken: _currentDownloadCancelToken,
        metadata: target.toJson(),
        smokeTestSampleBytes: sample.buffer.asUint8List(),
      )) {
        if (session != _db.sessionGeneration) return;
        yield progress;
      }

      // Automatically activate after successful installation
      await activateModelBundle(bundleKey);
    } finally {
      _currentDownloadCancelToken = null;
    }
  }

  /// Downloads, verifies, and stages the specified model bundle.
  Stream<double> downloadModelBundle(AvailableModelBundle model) =>
      downloadModelWithProgress(model: model).map((p) => p.fraction);

  /// Verifies an already downloaded bundle on disk.
  Future<bool> verifyModelBundle(String bundleKey) =>
      _modelPipeline.verifyExistingBundle(bundleKey);

  /// Deletes a bundle from disk and unloads active model if deleted.
  Future<void> deleteModelBundle(String bundleKey) async {
    final session = _db.sessionGeneration;
    await _modelPipeline.deleteBundle(bundleKey);
    final installed = await _settings.readInstalledModelVersion();
    if (installed == bundleKey ||
        (installed != null &&
            (installed.toLowerCase() == bundleKey.toLowerCase() ||
             bundleKey.endsWith('_$installed')))) {
      if (session == _db.sessionGeneration) {
        await _db.writeForSession(
          session,
          () => _settings.clearInstalledModelVersion(),
        );
      }
    }
  }

  /// Activates an already installed bundle without re-downloading.
  Future<void> activateModelBundle(String bundleKey) async {
    final session = _db.sessionGeneration;
    await _modelPipeline.activateExisting(bundleKey);
    if (session != _db.sessionGeneration) return;
    await _db.writeForSession(
      session,
      () => _settings.saveInstalledModelVersion(bundleKey),
    );
  }

  /// Check for updates from API.
  Future<ModelVersionInfo> checkForUpdate() async {
    final installed = await _settings.readInstalledModelVersion();
    try {
      final response = await _client.dio.get<dynamic>(
        '/models/check',
        queryParameters: {
          'channel': _channel,
          if (installed != null && installed.isNotEmpty) 'current': installed,
          'app': _appVersion,
        },
        options: Options(
          validateStatus: (status) =>
              status != null &&
              ((status >= 200 && status < 300) ||
                  status == 304 ||
                  status == 404),
        ),
      );

      if (response.statusCode == 404) {
        final info = ModelVersionInfo(
          currentVersion: installed ?? '',
          latestVersion: '',
          fileSize: '-',
          releaseDate: '-',
          changelog: const [],
        );
        await _cacheCheck(info);
        return info;
      }

      if (response.statusCode == 304) {
        final info = ModelVersionInfo(
          currentVersion: installed ?? '',
          latestVersion: installed ?? '',
          fileSize: '-',
          releaseDate: '-',
          changelog: const [],
        );
        await _cacheCheck(info);
        return info;
      }

      final data = _asJsonMap(response.data);
      final ModelVersionInfo info;
      if (data == null) {
        info = ModelVersionInfo(
          currentVersion: installed ?? '',
          latestVersion: installed ?? '',
          fileSize: '-',
          releaseDate: '-',
          changelog: const [],
        );
      } else {
        final sizeBytes = (data['size_bytes'] as num?)?.toInt();
        final latest = (data['latest_version'] as String?) ??
            (data['latest'] as String?) ??
            (installed ?? '');
        info = ModelVersionInfo(
          currentVersion: installed ?? '',
          latestVersion: latest,
          fileSize: sizeBytes != null
              ? '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
              : '-',
          releaseDate: (data['released_utc'] as String?) ?? '-',
          changelog: List<String>.from(data['changelog'] as List? ?? const []),
          downloadUrl: (data['bundle_zip'] as String?) ?? (data['download_url'] as String?),
          sha256: (data['bundle_zip_sha256'] as String?) ?? (data['sha256'] as String?),
        );
      }
      await _cacheCheck(info);
      return info;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        final info = ModelVersionInfo(
          currentVersion: installed ?? '',
          latestVersion: '',
          fileSize: '-',
          releaseDate: '-',
          changelog: const [],
        );
        await _cacheCheck(info);
        return info;
      }
      if (e.response?.statusCode == 304) {
        final info = ModelVersionInfo(
          currentVersion: installed ?? '',
          latestVersion: installed ?? '',
          fileSize: '-',
          releaseDate: '-',
          changelog: const [],
        );
        await _cacheCheck(info);
        return info;
      }
      rethrow;
    }
  }

  Future<void> _cacheCheck(ModelVersionInfo info) =>
      _settings.saveLastModelCheckJson(
        jsonEncode({
          'latestVersion': info.latestVersion,
          'fileSize': info.fileSize,
          'releaseDate': info.releaseDate,
          'changelog': info.changelog,
          'downloadUrl': info.downloadUrl,
          'sha256': info.sha256,
          'checkedAtIso': DateTime.now().toIso8601String(),
        }),
      );

  Future<(ModelVersionInfo, DateTime)?> readCachedCheck() async {
    final raw = await _settings.readLastModelCheckJson();
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final checkedAt = DateTime.tryParse(
        data['checkedAtIso'] as String? ?? '',
      );
      if (checkedAt == null) return null;
      final installed = await _settings.readInstalledModelVersion();
      final info = ModelVersionInfo(
        currentVersion: installed ?? '',
        latestVersion: (data['latestVersion'] as String?) ?? (installed ?? ''),
        fileSize: (data['fileSize'] as String?) ?? '-',
        releaseDate: (data['releaseDate'] as String?) ?? '-',
        changelog: List<String>.from(data['changelog'] as List? ?? const []),
        downloadUrl: data['downloadUrl'] as String?,
        sha256: data['sha256'] as String?,
      );
      return (info, checkedAt);
    } catch (_) {
      return null;
    }
  }

  /// Downloads, verifies and activates the new model bundle (see
  /// `ModelUpdatePipeline`), then records the new version on this device.
  ///
  /// Missing bundles fail without changing the installed version.
  Stream<double> downloadModel() =>
      downloadModelWithProgress().map((p) => p.fraction);
}
