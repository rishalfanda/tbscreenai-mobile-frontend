import 'package:drift/native.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/offline/offline_sync_repository.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/unavailable_repositories.dart';

void main() {
  test(
    'disabled artifact install cannot alter active version across repository recreation',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final settings = SettingsStore(db);
      final client = ApiClient(baseUrl: 'https://example.org/api/v1');
      await settings.saveInstalledModelVersion('legacy-unverified');
      await db.putSetting('verified_active_model_version', 'verified-existing');
      OfflineSyncRepository repository() => OfflineSyncRepository(
        db: db,
        client: client,
        settings: settings,
        engine: SyncEngine(db: db, client: client, settings: settings),
      );
      expect(
        await repository().getInstalledModelVersion(),
        'verified-existing',
      );
      await expectLater(
        repository().downloadModel().toList(),
        throwsUnsupportedError,
      );
      expect(
        await repository().getInstalledModelVersion(),
        'verified-existing',
      );
      await client.close();
      await db.close();
    },
  );

  test(
    'demo permitted; staging HTTPS and version required; production locked',
    () {
      AppConfig.validateValues('demo', false, '');
      expect(
        () => AppConfig.validateValues(
          'demo',
          true,
          'https://example.org/api/v1',
        ),
        throwsStateError,
      );
      AppConfig.validateValues(
        'staging',
        true,
        'https://staging.example.org/api/v1',
      );
      for (final env in ['production', 'unknown']) {
        expect(
          () =>
              AppConfig.validateValues(env, true, 'https://example.org/api/v1'),
          throwsStateError,
        );
      }
      expect(
        () => AppConfig.validateValues('staging', false, ''),
        throwsStateError,
      );
      for (final url in [
        '',
        'http://example.org/api/v1',
        'https://example.org',
        'https://example.org/api/v1?token=x',
      ]) {
        expect(
          () => AppConfig.validateValues('staging', true, url),
          throwsStateError,
        );
      }
    },
  );
  test('unavailable contracts expose no synthetic records', () async {
    expect(await UnavailableDatasetRepository().getDatasets(), isEmpty);
    expect(await UnavailableDashboardRepository().getMetrics(), isEmpty);
  });
  test('feature controls have no empty callback', () {
    final emptyCallback = RegExp(
      r'(onPressed|onTap|onChanged)\s*:\s*\([^)]*\)\s*(?:async\s*)?\{\s*\}',
    );
    for (final file
        in Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      expect(
        emptyCallback.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });
}
