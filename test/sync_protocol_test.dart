import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/sync/sync_engine.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions options) respond;
  int calls = 0;
  final List<List<Map<String, dynamic>>> batches = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    await requestStream?.drain<void>();
    final data = options.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      batches.add((data['items'] as List).cast<Map<String, dynamic>>());
    }
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late AppDatabase db;
  late ApiClient client;
  late SyncEngine engine;
  final now = DateTime.utc(2026, 9, 28, 8);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = ApiClient(baseUrl: 'http://sync.test/api/v1');
    engine = SyncEngine(
      db: db,
      client: client,
      settings: SettingsStore(db),
      now: () => now,
      jitter: () => 0.5,
    );
  });

  tearDown(() async {
    await client.close();
    await db.close();
  });

  test('duplicate response IDs are a retryable protocol failure', () async {
    await engine.enqueuePatientUpdate('p1', {'name': 'Local'});
    final opId = (await db.pendingOps()).single.clientOpId;
    client.dio.httpClientAdapter = _Adapter(
      (_) => _json({
        'results': [
          {'client_op_id': opId, 'status': 'applied'},
          {'client_op_id': opId, 'status': 'applied'},
        ],
      }),
    );

    final report = await engine.push();
    final retryable = (await db.opsWithStatus(syncRetryable)).single;

    expect(report.hasProblems, isTrue);
    expect(retryable.retryCount, 1);
    expect(retryable.nextAttemptAt, isNotNull);
    expect(retryable.detail, contains('duplicate'));
  });

  test('mismatched response entity ID is a protocol failure', () async {
    await engine.enqueuePatientUpdate('p1', {'name': 'Local'});
    final opId = (await db.pendingOps()).single.clientOpId;
    client.dio.httpClientAdapter = _Adapter(
      (_) => _json({
        'results': [
          {
            'client_op_id': opId,
            'status': 'applied',
            'entity_id': 'different-patient',
          },
        ],
      }),
    );

    final report = await engine.push();
    final retryable = (await db.opsWithStatus(syncRetryable)).single;

    expect(report.hasProblems, isTrue);
    expect(retryable.detail, contains('mismatched entity_id'));
  });

  test(
    'background retry honors backoff; manual retry keeps the same op ID',
    () async {
      await engine.enqueuePatientUpdate('p1', {'name': 'Local'});
      final originalId = (await db.pendingOps()).single.clientOpId;
      client.dio.httpClientAdapter = _Adapter(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      expect((await engine.push()).failed, 1);

      final recovered = _Adapter((options) {
        final items = ((options.data as Map)['items'] as List).cast<Map>();
        return _json({
          'results': [
            for (final item in items)
              {'client_op_id': item['client_op_id'], 'status': 'applied'},
          ],
        });
      });
      client.dio.httpClientAdapter = recovered;

      expect((await engine.push(manual: false)).total, 0);
      expect(recovered.calls, 0);
      expect((await engine.push()).applied, 1);
      expect(recovered.batches.single.single['client_op_id'], originalId);
    },
  );

  test('push chunks requests at the backend max of 500 items', () async {
    for (var index = 0; index < 501; index++) {
      await engine.enqueuePatientUpdate('p$index', {'name': 'Patient $index'});
    }
    final adapter = _Adapter((options) {
      final items = ((options.data as Map)['items'] as List).cast<Map>();
      return _json({
        'results': [
          for (final item in items)
            {'client_op_id': item['client_op_id'], 'status': 'applied'},
        ],
      });
    });
    client.dio.httpClientAdapter = adapter;

    final report = await engine.push();

    expect(report.applied, 501);
    expect(adapter.calls, 2);
    expect(adapter.batches.map((batch) => batch.length), [500, 1]);
  });

  test('concurrent local edit wins over a delayed server snapshot', () async {
    await db.upsertPatient(
      LocalPatientsCompanion.insert(
        id: 'p1',
        code: 'P1',
        name: 'Original',
        age: 40,
        gender: 'Male',
      ),
    );
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    client.dio.httpClientAdapter = _Adapter((_) {
      started.complete();
      return response.future;
    });

    final pull = engine.pull();
    await started.future;
    await db.upsertPatient(
      LocalPatientsCompanion.insert(
        id: 'p1',
        code: 'P1',
        name: 'Local Edit',
        age: 40,
        gender: 'Male',
      ),
    );
    await engine.enqueuePatientUpdate('p1', {'name': 'Local Edit'});
    response.complete(
      _json({
        'server_time': '2026-09-28T08:00:00Z',
        'patients': [
          {
            'id': 'p1',
            'code': 'P1',
            'name': 'Stale Server Value',
            'age': 40,
            'gender': 'Male',
            'version': 1,
          },
        ],
        'diagnoses': [],
      }),
    );
    await pull;

    expect((await db.findPatient('p1'))?.name, 'Local Edit');
    expect(await db.pendingOps(), hasLength(1));
  });
}
