import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/models_ota/model_update_pipeline.dart';
import 'package:myapp/domain/models/model_version_info.dart';

/// This app has no channel picker (unlike `inf_app`'s Models tab) — every
/// check is against the `stable` channel.
const _channel = 'stable';

/// Sent as `?app=` so the server's `min_app_version` gate can decide whether
/// this build may still receive model updates. Keep in sync with
/// `pubspec.yaml`'s `version:` (before the `+build`) — mirrors `inf_app`'s
/// `kAppVersion` (`lib/src/update/app_info.dart`).
const _appVersion = '1.0.0';

/// Coerces a Dio response body into a JSON object, tolerating a
/// double-encoded body (a JSON string containing JSON) and anything else
/// unexpected by falling back to `null` — same as an empty/absent response —
/// rather than throwing.
Map<String, dynamic>? _asJsonMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Not JSON either — fall through to null.
    }
  }
  return null;
}

/// The real (non-mock) AI-model update mechanism: checks `GET /models/check`
/// (the real backend's route, matching `inf_app`'s `UpdateApi.check()` in
/// `lib/src/update/update_api.dart` — mounted under the same `/v1` base as
/// `AppConfig.apiBaseUrl`, there is no `/sync/model-version` on the server)
/// and, when a bundle is available, runs the signed download → verify →
/// activate → smoke-test pipeline (`ModelUpdatePipeline`).
///
/// Shared by every `SyncRepository` implementation the app actually runs —
/// see `HybridSyncRepository`, which uses this even in mock/demo mode so the
/// Sync Center's model-update card is never simulated, while its data-backup
/// half stays whatever `useHttp` already picks.
class ModelUpdateService {
  ModelUpdateService({
    required ApiClient client,
    required SettingsStore settings,
    required AppDatabase db,
    required ModelUpdatePipeline modelPipeline,
  }) : _client = client,
       _settings = settings,
       _db = db,
       _modelPipeline = modelPipeline;

  final ApiClient _client;
  final SettingsStore _settings;
  final AppDatabase _db;
  final ModelUpdatePipeline _modelPipeline;

  /// `null` means no model bundle is installed on this device yet.
  Future<String?> getInstalledModelVersion() =>
      _settings.readInstalledModelVersion();

  Future<ModelVersionInfo> checkForUpdate() async {
    final installed = await _settings.readInstalledModelVersion();
    // Fetched as `dynamic`, not `Map<String, dynamic>?` — some backends
    // double-encode the JSON body (the response is a JSON *string*, not an
    // object), which would otherwise throw a cast TypeError here instead of
    // a normal, handleable response.
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
        // `/models/check` carries no release date (only `/models/index.json`'s
        // per-version `released_utc` does, and that endpoint is for the
        // multi-version catalog browser this app doesn't have) — showing
        // unknown here rather than fabricating one.
        releaseDate: '-',
        changelog: List<String>.from(data['changelog'] as List? ?? const []),
        downloadUrl: data['bundle_zip'] as String?,
        sha256: data['bundle_zip_sha256'] as String?,
      );
    }
    await _cacheCheck(info);
    return info;
  }

  Future<void> _cacheCheck(ModelVersionInfo info) => _settings.saveLastModelCheckJson(
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

  /// The last cached check result plus when it was fetched, with
  /// `currentVersion` always re-derived from the live installed-version
  /// setting (never trusted from the cache, in case a rollback happened
  /// outside this flow). `null` if nothing has been cached yet or the cached
  /// entry is unreadable.
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
  /// Falls back to the old simulate-and-persist behavior when no download URL
  /// is available anywhere (today's real backend serves `download_url` for no
  /// version yet) — `AppConfig.modelBundleUrl` is a dev-time override for
  /// exercising the real path before that changes.
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
