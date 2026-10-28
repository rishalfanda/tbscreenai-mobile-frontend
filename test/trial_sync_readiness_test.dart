import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/models_ota/model_update_pipeline.dart';
import 'package:myapp/data/models_ota/model_update_service.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/data/sync/sync_engine.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final Future<Map<String, dynamic>> Function(RequestOptions) answer;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(await answer(options)),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _page(String id, {String? next}) => {
  'server_time': '2026-10-22T01:00:00Z',
  'patients': [
    {'id': id, 'code': id, 'name': 'Synthetic', 'age': 30, 'gender': 'Female'},
  ],
  'diagnoses': <dynamic>[],
  'has_more': next != null,
  'next_cursor': next,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SettingsStore settings;
  late ApiClient client;
  late SyncEngine engine;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsStore(db);
    client = ApiClient(baseUrl: 'https://synthetic.invalid/api/v1');
    engine = SyncEngine(db: db, client: client, settings: settings);
  });
  tearDown(() async => db.close());

  test(
    'pull keeps every page and commits watermark only at completion',
    () async {
      final queries = <Map<String, dynamic>>[];
      client.dio.httpClientAdapter = _Adapter((request) async {
        queries.add(Map.of(request.queryParameters));
        expect(await settings.readLastSyncAt(), isNull);
        expect(await db.allPatients(), isEmpty);
        return queries.length == 1 ? _page('p1', next: 'page-2') : _page('p2');
      });
      await engine.pull();
      expect(
        (await db.allPatients()).map((p) => p.id),
        containsAll(['p1', 'p2']),
      );
      expect(queries.first, {'limit': 500});
      expect(queries.last, {'limit': 500, 'cursor': 'page-2'});
      expect(await settings.readLastSyncAt(), DateTime.utc(2026, 10, 22, 1));
    },
  );

  test(
    'failed later page preserves cache and watermark; retry starts again',
    () async {
      final previous = DateTime.utc(2026, 10, 20);
      await settings.saveLastSyncAt(previous);
      var calls = 0;
      var fail = true;
      client.dio.httpClientAdapter = _Adapter((request) async {
        calls++;
        if (request.queryParameters['cursor'] == null) {
          expect(request.queryParameters['since'], previous.toIso8601String());
          return _page('p1', next: 'page-2');
        }
        if (fail) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'offline',
          );
        }
        return _page('p2');
      });
      await expectLater(engine.pull(), throwsA(isA<DioException>()));
      expect(await settings.readLastSyncAt(), previous);
      expect(await db.allPatients(), isEmpty);
      fail = false;
      await engine.pull();
      expect(calls, 4);
      expect((await db.allPatients()).length, 2);
    },
  );

  test(
    'repeated cursor fails without replacing cache or advancing watermark',
    () async {
      client.dio.httpClientAdapter = _Adapter(
        (_) async => _page('p1', next: 'same'),
      );
      await expectLater(engine.pull(), throwsFormatException);
      expect(await settings.readLastSyncAt(), isNull);
      expect(await db.allPatients(), isEmpty);
    },
  );

  for (final invalid in ['missing cursor', 'changed snapshot']) {
    test('$invalid never commits a partial pull', () async {
      var calls = 0;
      client.dio.httpClientAdapter = _Adapter((_) async {
        calls++;
        if (invalid == 'missing cursor') {
          return {..._page('p1'), 'has_more': true};
        }
        return calls == 1
            ? _page('p1', next: 'page-2')
            : {..._page('p2'), 'server_time': '2026-10-22T02:00:00Z'};
      });
      await expectLater(engine.pull(), throwsFormatException);
      expect(await db.allPatients(), isEmpty);
      expect(await settings.readLastSyncAt(), isNull);
    });
  }

  test(
    'logout during pagination prevents cache writes and next requests',
    () async {
      var calls = 0;
      client.dio.httpClientAdapter = _Adapter((_) async {
        calls++;
        db.invalidateSession();
        return _page('p1', next: 'page-2');
      });
      await engine.pull();
      expect(calls, 1);
      expect(await db.allPatients(), isEmpty);
      expect(await settings.readLastSyncAt(), isNull);
    },
  );

  for (final url in [null, '', '   ']) {
    test(
      'missing bundle URL ($url) never reports installed or completed',
      () async {
        await settings.saveInstalledModelVersion('installed-1');
        client.dio.httpClientAdapter = _Adapter(
          (_) async => {'latest': 'candidate-2', 'bundle_zip': url},
        );
        final service = ModelUpdateService(
          client: client,
          settings: settings,
          db: db,
          modelPipeline: ModelUpdatePipeline(
            downloadDio: Dio(),
            engine: OnnxInferenceEngine(),
          ),
        );
        final progress = <double>[];
        await expectLater(() async {
          await for (final value in service.downloadModel()) {
            progress.add(value);
          }
        }(), throwsA(isA<ModelInstallException>()));
        expect(progress, isEmpty);
        expect(await settings.readInstalledModelVersion(), 'installed-1');
      },
    );
  }
}
