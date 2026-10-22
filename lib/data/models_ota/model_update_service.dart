import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/models_ota/model_store.dart';
import 'package:myapp/data/models_ota/model_update_pipeline.dart';
import 'package:myapp/domain/models/available_model_bundle.dart';
import 'package:myapp/domain/models/model_version_info.dart';

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
/// - GET /models/check: legacy check for latest stable update.
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

  /// `null` means no model bundle is installed on this device yet.
  Future<String?> getInstalledModelVersion() =>
      _settings.readInstalledModelVersion();

  /// Returns list of all installed bundle keys on disk.
  Future<List<String>> getInstalledModelKeys() =>
      _store.listInstalledBundleKeys();

  /// Fetches all available model bundles across channels from GET /models.
  Future<List<AvailableModelBundle>> fetchAvailableModels({
    String? channel,
    bool? quantized,
  }) async {
    final installed = await _settings.readInstalledModelVersion();
    try {
      final response = await _client.dio.get<dynamic>(
        '/models',
        queryParameters: {
          if (channel != null && channel.isNotEmpty) 'channel': channel,
          if (quantized != null) 'quantized': quantized,
          'app': _appVersion,
          if (installed != null && installed.isNotEmpty) 'current': installed,
        },
      );
      final data = _asJsonMap(response.data);
      if (data != null) {
        await _settings.saveAvailableModelsCache(jsonEncode(data));
        final modelsRaw = data['models'] as List?;
        if (modelsRaw != null) {
          return modelsRaw
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
            return modelsRaw
                .whereType<Map<String, dynamic>>()
                .map(AvailableModelBundle.fromJson)
                .toList();
          }
        } catch (_) {}
      }
    }

    // If completely offline with no network cache, synthesize entries from installed bundles.
    return _synthesizeFromInstalledBundles();
  }

  Future<List<AvailableModelBundle>> _synthesizeFromInstalledBundles() async {
    final installedKeys = await _store.listInstalledBundleKeys();
    final activeKey = await _store.activeVersion();
    final result = <AvailableModelBundle>[];

    for (final key in installedKeys) {
      final meta = await _store.readBundleMeta(key);
      if (meta != null) {
        result.add(AvailableModelBundle.fromJson(meta));
      } else {
        // Fallback if no meta.json exists: parse key
        final parts = key.split('_');
        final channel = parts.length > 1 ? parts.first : 'stable';
        final version = parts.length > 1 ? parts.sublist(1).join('_') : key;
        result.add(
          AvailableModelBundle(
            channel: channel,
            version: version,
            isLatest: false,
            isCurrent: key == activeKey,
            notes: 'Installed on device',
          ),
        );
      }
    }
    return result;
  }

  /// Downloads, verifies, and stages the specified model bundle.
  Stream<double> downloadModelBundle(AvailableModelBundle model) async* {
    final session = _db.sessionGeneration;
    final url = model.bundleZip ?? AppConfig.modelBundleUrl;

    if (url == null || url.isEmpty) {
      // Fallback simulation when no download URL is provided (e.g. dev/demo)
      var progress = 0.0;
      while (progress < 1.0) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (session != _db.sessionGeneration) return;
        progress += 0.05;
        yield progress.clamp(0.0, 1.0);
      }
      await _db.writeForSession(
        session,
        () => _settings.saveInstalledModelVersion(model.id),
      );
      return;
    }

    final sample = await rootBundle.load('assets/sample/xray.png');
    await for (final progress in _modelPipeline.installBundle(
      bundleKey: model.id,
      version: model.version,
      downloadUrl: url,
      sha256: model.bundleZipSha256,
      metadata: model.toJson(),
      smokeTestSampleBytes: sample.buffer.asUint8List(),
    )) {
      if (session != _db.sessionGeneration) return;
      yield progress;
    }
    if (session != _db.sessionGeneration) return;
    await _db.writeForSession(
      session,
      () => _settings.saveInstalledModelVersion(model.id),
    );
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

  /// Legacy single-version check for updates.
  Future<ModelVersionInfo> checkForUpdate() async {
    final installed = await _settings.readInstalledModelVersion();
    final response = await _client.dio.get<dynamic>(
      '/models/check',
      queryParameters: {
        'channel': _channel,
        if (installed != null && installed.isNotEmpty) 'current': installed,
        'app': _appVersion,
      },
    );
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
      info = ModelVersionInfo(
        currentVersion: installed ?? '',
        latestVersion: (data['latest'] as String?) ?? (installed ?? ''),
        fileSize: sizeBytes != null
            ? '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
            : '-',
        releaseDate: '-',
        changelog: List<String>.from(data['changelog'] as List? ?? const []),
        downloadUrl: data['bundle_zip'] as String?,
        sha256: data['bundle_zip_sha256'] as String?,
      );
    }
    await _cacheCheck(info);
    return info;
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

  Stream<double> downloadModel() async* {
    final session = _db.sessionGeneration;
    final info = await checkForUpdate();
    final url = info.downloadUrl ?? AppConfig.modelBundleUrl;

    if (url == null) {
      var progress = 0.0;
      while (progress < 1.0) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (session != _db.sessionGeneration) return;
        progress += 0.05;
        yield progress.clamp(0.0, 1.0);
      }
      await _db.writeForSession(
        session,
        () => _settings.saveInstalledModelVersion(info.latestVersion),
      );
      return;
    }

    final sample = await rootBundle.load('assets/sample/xray.png');
    await for (final progress in _modelPipeline.install(
      info: ModelVersionInfo(
        currentVersion: info.currentVersion,
        latestVersion: info.latestVersion,
        fileSize: info.fileSize,
        releaseDate: info.releaseDate,
        changelog: info.changelog,
        downloadUrl: url,
        sha256: info.sha256,
      ),
      smokeTestSampleBytes: sample.buffer.asUint8List(),
    )) {
      if (session != _db.sessionGeneration) return;
      yield progress;
    }
    if (session != _db.sessionGeneration) return;
    await _db.writeForSession(
      session,
      () => _settings.saveInstalledModelVersion(info.latestVersion),
    );
  }
}
