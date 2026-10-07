import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/unavailable_repositories.dart';

void main() {
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
