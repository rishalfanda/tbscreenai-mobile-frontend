import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/mock/mock_sync_repository.dart';
import 'package:myapp/data/models_ota/model_store.dart';
import 'package:myapp/data/models_ota/model_update_pipeline.dart';
import 'package:myapp/data/models_ota/model_update_service.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/available_model_bundle.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';
import 'package:myapp/features/sync/presentation/sync_center_screen.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final Object? body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? s,
    Future<void>? c,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _ModelRepository extends MockSyncRepository {
  _ModelRepository({this.throwDownloadError = false, this.throwActivationError = false});
  final bool throwDownloadError;
  final bool throwActivationError;
  bool isDownloaded = false;

  @override
  Future<String> getInstalledModelVersion() async => 'installed-one';

  @override
  Future<ModelVersionInfo> checkForUpdate() async => const ModelVersionInfo(
    currentVersion: 'installed-one',
    latestVersion: 'candidate-two',
    fileSize: '1 MB',
    releaseDate: '-',
    changelog: [],
    downloadUrl: 'https://example.com/models/bundle.zip',
  );

  @override
  Stream<ModelDownloadProgress> downloadModelWithProgress({
    AvailableModelBundle? model,
  }) async* {
    yield const ModelDownloadProgress(
      fraction: 0.5,
      bytesPerSecond: 1024 * 1024,
      speedText: '1.0 MB/s',
      phase: ModelInstallPhase.downloading,
    );
    if (throwDownloadError) {
      throw ModelInstallException(
        ModelInstallPhase.downloading,
        'Synthetic failure',
      );
    }
    isDownloaded = true;
    yield const ModelDownloadProgress(
      fraction: 1.0,
      phase: ModelInstallPhase.completed,
    );
  }

  @override
  Future<List<AvailableModelBundle>> getAvailableModels({
    String? channel,
    bool? quantized,
    bool localOnly = false,
  }) async {
    return [
      if (isDownloaded)
        const AvailableModelBundle(
          channel: 'stable',
          version: 'candidate-two',
          isLatest: true,
          isCurrent: false,
          localStatus: ModelBundleStatus.verified,
        ),
    ];
  }

  @override
  Future<void> activateModelBundle(String bundleKey) async {
    if (throwActivationError) {
      throw StateError('Gagal mengaktifkan model');
    }
    await super.activateModelBundle(bundleKey);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('model download credentials are limited to the API model namespace', () {
    final base = Uri.parse('https://api.example.org/api/v1');
    expect(
      ModelUpdatePipeline.isApiBundle(
        'https://api.example.org/api/v1/models/stable/v1/bundle.zip',
        base,
      ),
      isTrue,
    );
    for (final url in [
      'https://cdn.example.org/bundle.zip',
      'https://api.example.org/other/bundle.zip',
      'https://api.example.org.evil.invalid/api/v1/models/a',
      'http://api.example.org/api/v1/models/a',
      'https://user:secret@api.example.org/api/v1/models/a',
      '/models/a',
    ]) {
      expect(ModelUpdatePipeline.isApiBundle(url, base), isFalse, reason: url);
    }
  });
  test(
    'server policy prevents unsupported or disallowed model installation',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final settings = SettingsStore(db);
      final client = ApiClient(baseUrl: 'https://synthetic.invalid/api/v1');
      addTearDown(db.close);
      addTearDown(client.close);
      await settings.saveInstalledModelVersion('installed-one');
      final service = ModelUpdateService(
        client: client,
        settings: settings,
        db: db,
        modelPipeline: ModelUpdatePipeline(
          downloadDio: Dio(),
          engine: OnnxInferenceEngine(),
        ),
      );
      client.dio.httpClientAdapter = _Adapter({
        'latest': 'candidate-two',
        'app_supported': false,
        'update_available': false,
      });
      await expectLater(
        service.checkForUpdate(),
        throwsA(isA<ModelInstallException>()),
      );
      client.dio.httpClientAdapter = _Adapter({
        'latest': 'candidate-two',
        'app_supported': true,
        'update_available': false,
      });
      expect((await service.checkForUpdate()).hasUpdate, isFalse);
      await expectLater(
        service.downloadModel().toList(),
        throwsA(isA<ModelInstallException>()),
      );
      client.dio.httpClientAdapter = _Adapter({'unexpected': 'response'});
      await expectLater(service.checkForUpdate(), throwsFormatException);
      expect(await settings.readInstalledModelVersion(), 'installed-one');
    },
  );
    testWidgets('model download error shows error message and never marks as done', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Provider<SyncRepository>.value(
          value: _ModelRepository(throwDownloadError: true),
          child: const MaterialApp(
            home: Scaffold(body: SyncCenterScreen(modelsOnly: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Periksa Pembaruan Model'));
      await tester.pumpAndSettle();
      expect(find.text('Perbarui Sekarang'), findsOneWidget);
      await tester.tap(find.text('Perbarui Sekarang'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Model berhasil diperbarui'), findsNothing);
      expect(find.textContaining('Gagal mengunduh model'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('model activation error shows error message', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Provider<SyncRepository>.value(
          value: _ModelRepository(throwActivationError: true),
          child: const MaterialApp(
            home: Scaffold(body: SyncCenterScreen(modelsOnly: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Periksa Pembaruan Model'));
      await tester.pumpAndSettle();
      expect(find.text('Perbarui Sekarang'), findsOneWidget);
      await tester.tap(find.text('Perbarui Sekarang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Aktifkan Model'), findsOneWidget);
      await tester.tap(find.text('Aktifkan Model'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.textContaining('Model berhasil diperbarui'), findsNothing);
      expect(find.textContaining('Gagal mengaktifkan model'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

  test('verified bundle that fails smoke test triggers rollback and restores settings', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final settings = SettingsStore(db);
    final client = ApiClient(baseUrl: 'https://example.com/api/v1');
    addTearDown(db.close);
    addTearDown(client.close);

    await settings.saveInstalledModelVersion('bundle-v1');
    final store = _MockStoreForRollback(
      installed: {'bundle-v1', 'bundle-v2'},
      statuses: {
        'bundle-v1': ModelBundleStatus.verified,
        'bundle-v2': ModelBundleStatus.verified,
      },
      active: 'bundle-v1',
    );
    final engine = _FailingSmokeTestEngine(failOnSmokeTest: true);
    final pipeline = ModelUpdatePipeline(
      downloadDio: Dio(),
      engine: engine,
      store: store,
    );
    final service = ModelUpdateService(
      client: client,
      settings: settings,
      db: db,
      modelPipeline: pipeline,
      store: store,
    );

    await expectLater(
      service.activateModelBundle(
        'bundle-v2',
        sampleBytes: Uint8List.fromList([1, 2, 3]),
      ),
      throwsA(isA<ModelInstallException>().having(
        (e) => e.phase,
        'phase',
        ModelInstallPhase.smokeTesting,
      )),
    );

    // Active version should be rolled back to bundle-v1
    expect(await store.activeVersion(), 'bundle-v1');
    // bundle-v2 status should be marked as verificationFailed
    expect(
      await store.getBundleStatus('bundle-v2'),
      ModelBundleStatus.verificationFailed,
    );
    // Settings store should be restored to bundle-v1
    expect(await settings.readInstalledModelVersion(), 'bundle-v1');
  });

  test('first model installation failure during smoke test clears active pointer and settings', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final settings = SettingsStore(db);
    final client = ApiClient(baseUrl: 'https://example.com/api/v1');
    addTearDown(db.close);
    addTearDown(client.close);

    final store = _MockStoreForRollback(
      installed: {'bundle-initial'},
      statuses: {'bundle-initial': ModelBundleStatus.verified},
      active: null,
      previous: null,
    );
    final engine = _FailingSmokeTestEngine(failOnSmokeTest: true);
    final pipeline = ModelUpdatePipeline(
      downloadDio: Dio(),
      engine: engine,
      store: store,
    );
    final service = ModelUpdateService(
      client: client,
      settings: settings,
      db: db,
      modelPipeline: pipeline,
      store: store,
    );

    await expectLater(
      service.activateModelBundle(
        'bundle-initial',
        sampleBytes: Uint8List.fromList([1, 2, 3]),
      ),
      throwsA(isA<ModelInstallException>()),
    );

    // Active version in store must be cleared (null)
    expect(await store.activeVersion(), isNull);
    // bundle-initial status is marked failed
    expect(
      await store.getBundleStatus('bundle-initial'),
      ModelBundleStatus.verificationFailed,
    );
    // Settings store must be null
    expect(await settings.readInstalledModelVersion(), isNull);
  });

  group('Real ModelStore regression & lifecycle tests', () {
    test('P1 regression: ModelStore with verificationFailed bundle never re-activates on clearActive()', () async {
      final tempDir = await Directory.systemTemp.createTemp('model_store_p1_test_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = ModelStore(rootProvider: () async => tempDir);

      // Create a bundle directory on disk with manifest.json
      final bundleDir = Directory('${tempDir.path}${Platform.pathSeparator}failed-bundle');
      await bundleDir.create(recursive: true);
      final manifestFile = File('${bundleDir.path}${Platform.pathSeparator}manifest.json');
      await manifestFile.writeAsString('{"bundle_version": "v1.0"}');

      // Mark as verificationFailed
      await store.setBundleStatus('failed-bundle', ModelBundleStatus.verificationFailed);

      // Clear active pointer
      await store.clearActive();

      // Verify activeVersion() is null
      expect(await store.activeVersion(), isNull);

      // Call activeBundleDir() - MUST return null and MUST NOT write back failed-bundle to ACTIVE
      final activeDir = await store.activeBundleDir();
      expect(activeDir, isNull);
      expect(await store.activeVersion(), isNull);
    });

    test('P1 regression: activeBundleDir returns null and clears pointer if active bundle is unverified', () async {
      final tempDir = await Directory.systemTemp.createTemp('model_store_unverified_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = ModelStore(rootProvider: () async => tempDir);

      // Create a bundle directory on disk
      final bundleDir = Directory('${tempDir.path}${Platform.pathSeparator}unverified-bundle');
      await bundleDir.create(recursive: true);
      final manifestFile = File('${bundleDir.path}${Platform.pathSeparator}manifest.json');
      await manifestFile.writeAsString('{"bundle_version": "v1.0"}');

      await store.setBundleStatus('unverified-bundle', ModelBundleStatus.downloaded);
      await store.activate('unverified-bundle');

      // activeBundleDir must return null and clear active pointer because bundle is not verified
      final activeDir = await store.activeBundleDir();
      expect(activeDir, isNull);
      expect(await store.activeVersion(), isNull);
    });

    test('ModelStore findNewestVerifiedBundleKey returns newest verified model by released_utc', () async {
      final tempDir = await Directory.systemTemp.createTemp('model_store_find_newest_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = ModelStore(rootProvider: () async => tempDir);

      for (final (name, date, status) in [
        ('model_v1', '2026-08-01T00:00:00Z', ModelBundleStatus.verified),
        ('model_v2', '2026-09-01T00:00:00Z', ModelBundleStatus.verified),
        ('model_v3', '2026-10-01T00:00:00Z', ModelBundleStatus.verificationFailed),
      ]) {
        final dir = Directory('${tempDir.path}${Platform.pathSeparator}$name');
        await dir.create(recursive: true);
        await File('${dir.path}${Platform.pathSeparator}manifest.json').writeAsString('{}');
        await store.writeBundleMeta(name, {'released_utc': date});
        await store.setBundleStatus(name, status);
      }

      // model_v3 is newer but failed verification, so model_v2 must be chosen
      final newest = await store.findNewestVerifiedBundleKey();
      expect(newest, 'model_v2');

      // If excluding model_v2, model_v1 must be chosen
      final secondNewest = await store.findNewestVerifiedBundleKey(excludingKey: 'model_v2');
      expect(secondNewest, 'model_v1');
    });

    test('ModelUpdateService deletes active model and falls back to newest verified model, or null if none', () async {
      final tempDir = await Directory.systemTemp.createTemp('service_delete_fallback_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = ModelStore(rootProvider: () async => tempDir);

      for (final (name, date) in [
        ('stable_v1', '2026-08-01T00:00:00Z'),
        ('stable_v2', '2026-09-01T00:00:00Z'),
      ]) {
        final dir = Directory('${tempDir.path}${Platform.pathSeparator}$name');
        await dir.create(recursive: true);
        await File('${dir.path}${Platform.pathSeparator}manifest.json').writeAsString('{}');
        await store.writeBundleMeta(name, {'released_utc': date});
        await store.setBundleStatus(name, ModelBundleStatus.verified);
      }

      final db = AppDatabase(NativeDatabase.memory());
      final settings = SettingsStore(db);
      final client = ApiClient(baseUrl: 'https://example.com/api/v1');
      addTearDown(db.close);
      addTearDown(client.close);

      final engine = _FailingSmokeTestEngine(failOnSmokeTest: false);
      final pipeline = ModelUpdatePipeline(
        downloadDio: Dio(),
        engine: engine,
        store: store,
      );
      final service = ModelUpdateService(
        client: client,
        settings: settings,
        db: db,
        modelPipeline: pipeline,
        store: store,
      );

      // Initially activate stable_v2
      await store.activate('stable_v2');
      await settings.saveInstalledModelVersion('stable_v2');
      expect(await store.activeVersion(), 'stable_v2');

      // Delete active model stable_v2 -> should automatically fall back to stable_v1
      await service.deleteModelBundle('stable_v2');
      expect(await store.activeVersion(), 'stable_v1');
      expect(await settings.readInstalledModelVersion(), 'stable_v1');

      // Delete remaining verified model stable_v1 -> should fall back to null (no model selected)
      await service.deleteModelBundle('stable_v1');
      expect(await store.activeVersion(), isNull);
      expect(await settings.readInstalledModelVersion(), isNull);
    });

    test('P2 regression: ModelUpdateService clears active and installed version if engine.init() fails on fallback candidate', () async {
      final tempDir = await Directory.systemTemp.createTemp('service_fallback_fail_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = ModelStore(rootProvider: () async => tempDir);

      for (final (name, date) in [
        ('stable_v1', '2026-08-01T00:00:00Z'),
        ('stable_v2', '2026-09-01T00:00:00Z'),
      ]) {
        final dir = Directory('${tempDir.path}${Platform.pathSeparator}$name');
        await dir.create(recursive: true);
        await File('${dir.path}${Platform.pathSeparator}manifest.json').writeAsString('{}');
        await store.writeBundleMeta(name, {'released_utc': date});
        await store.setBundleStatus(name, ModelBundleStatus.verified);
      }

      final db = AppDatabase(NativeDatabase.memory());
      final settings = SettingsStore(db);
      final client = ApiClient(baseUrl: 'https://example.com/api/v1');
      addTearDown(db.close);
      addTearDown(client.close);

      // Fail engine.init() specifically when candidate stable_v1 is active
      final engine = _FailingSmokeTestEngine(
        failOnSmokeTest: false,
        failingBundlesOnInit: {'stable_v1'},
        store: store,
      );
      final pipeline = ModelUpdatePipeline(
        downloadDio: Dio(),
        engine: engine,
        store: store,
      );
      final service = ModelUpdateService(
        client: client,
        settings: settings,
        db: db,
        modelPipeline: pipeline,
        store: store,
      );

      // Initially activate stable_v2
      await store.activate('stable_v2');
      await settings.saveInstalledModelVersion('stable_v2');
      expect(await store.activeVersion(), 'stable_v2');

      // Delete active model stable_v2 -> candidate stable_v1 fails engine.init()
      await service.deleteModelBundle('stable_v2');

      // Crucial P2 assertion: ACTIVE and installed setting must NOT point to stable_v1
      expect(await store.activeVersion(), isNull);
      expect(await settings.readInstalledModelVersion(), isNull);
      expect(await store.getBundleStatus('stable_v1'), ModelBundleStatus.verificationFailed);
    });

    test('ModelUpdateService falls back to next verified model if first candidate fails engine.init()', () async {
      final tempDir = await Directory.systemTemp.createTemp('service_fallback_multi_');
      addTearDown(() => tempDir.delete(recursive: true));

      final store = ModelStore(rootProvider: () async => tempDir);

      for (final (name, date) in [
        ('stable_v1', '2026-07-01T00:00:00Z'),
        ('stable_v2', '2026-08-01T00:00:00Z'),
        ('stable_v3', '2026-09-01T00:00:00Z'),
      ]) {
        final dir = Directory('${tempDir.path}${Platform.pathSeparator}$name');
        await dir.create(recursive: true);
        await File('${dir.path}${Platform.pathSeparator}manifest.json').writeAsString('{}');
        await store.writeBundleMeta(name, {'released_utc': date});
        await store.setBundleStatus(name, ModelBundleStatus.verified);
      }

      final db = AppDatabase(NativeDatabase.memory());
      final settings = SettingsStore(db);
      final client = ApiClient(baseUrl: 'https://example.com/api/v1');
      addTearDown(db.close);
      addTearDown(client.close);

      // Fail engine.init() specifically when stable_v2 is active
      final engine = _FailingSmokeTestEngine(
        failOnSmokeTest: false,
        failingBundlesOnInit: {'stable_v2'},
        store: store,
      );
      final pipeline = ModelUpdatePipeline(
        downloadDio: Dio(),
        engine: engine,
        store: store,
      );
      final service = ModelUpdateService(
        client: client,
        settings: settings,
        db: db,
        modelPipeline: pipeline,
        store: store,
      );

      // Initially activate stable_v3
      await store.activate('stable_v3');
      await settings.saveInstalledModelVersion('stable_v3');

      // Delete active model stable_v3 -> candidate stable_v2 fails engine.init(), falls back to stable_v1
      await service.deleteModelBundle('stable_v3');

      expect(await store.activeVersion(), 'stable_v1');
      expect(await settings.readInstalledModelVersion(), 'stable_v1');
      expect(await store.getBundleStatus('stable_v2'), ModelBundleStatus.verificationFailed);
      expect(await store.getBundleStatus('stable_v1'), ModelBundleStatus.verified);
    });
  });
}

class _MockStoreForRollback extends ModelStore {
  _MockStoreForRollback({
    required Set<String> installed,
    Map<String, ModelBundleStatus>? statuses,
    this.active,
    this.previous,
  })  : installed = Set.from(installed),
        statuses = statuses != null ? Map.from(statuses) : {};

  final Set<String> installed;
  final Map<String, ModelBundleStatus> statuses;
  String? active;
  String? previous;

  @override
  Future<bool> isInstalled(String bundleKey) async => installed.contains(bundleKey);

  @override
  Future<ModelBundleStatus> getBundleStatus(String bundleKey) async =>
      statuses[bundleKey] ?? ModelBundleStatus.notDownloaded;

  @override
  Future<void> setBundleStatus(
    String bundleKey,
    ModelBundleStatus status, {
    String? error,
  }) async {
    statuses[bundleKey] = status;
  }

  @override
  Future<String?> activeVersion() async => active;

  @override
  Future<String?> previousVersion() async => previous;

  @override
  Future<void> activate(String version) async {
    if (active != null && active != version) {
      previous = active;
    }
    active = version;
  }

  @override
  Future<String> rollback() async {
    if (previous == null) throw StateError('no previous');
    final prev = previous!;
    previous = active;
    active = prev;
    return prev;
  }

  @override
  Future<List<String>> listInstalledBundleKeys() async => installed.toList();

  @override
  Future<void> clearActive() async {
    active = null;
  }
}

class _FailingSmokeTestEngine extends OnnxInferenceEngine {
  _FailingSmokeTestEngine({
    this.failOnSmokeTest = true,
    this.failingBundlesOnInit,
    this.store,
  });
  final bool failOnSmokeTest;
  final Set<String>? failingBundlesOnInit;
  final ModelStore? store;
  int initCount = 0;
  int smokeTestCount = 0;

  @override
  Future<bool> init() async {
    initCount++;
    if (failingBundlesOnInit != null && store != null) {
      final active = await store!.activeVersion();
      if (active != null && failingBundlesOnInit!.contains(active)) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<void> smokeTest(Uint8List sampleBytes) async {
    smokeTestCount++;
    if (failOnSmokeTest) {
      throw StateError('Simulated inference failure during smoke test');
    }
  }
}
