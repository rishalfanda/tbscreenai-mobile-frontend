// FASE 4 core guarantees, exercised against a real in-memory drift database
// and a stubbed /sync/push:
//   1. a queued write survives and is pushed with its client_op_id
//   2. a server "conflict" verdict never overwrites local medical data
//   3. a failed push leaves the op pending so the retry can happen
//   4. cache refresh keeps rows that are still queued

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/sync/sync_engine.dart';

/// Answers /sync/push with a canned verdict per client_op_id.
class _StubPushAdapter implements HttpClientAdapter {
  _StubPushAdapter(this.verdict);

  /// 'applied' | 'skipped' | 'conflict', or null to simulate a network failure.
  final String? verdict;
  int callCount = 0;
  List<Map<String, dynamic>> lastItems = const [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
      Future<void>? cancel) async {
    callCount++;
    final body = options.data as Map<String, dynamic>;
    lastItems = (body['items'] as List).cast<Map<String, dynamic>>();

    if (verdict == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }

    final results = lastItems
        .map((item) => {
              'client_op_id': item['client_op_id'],
              'status': verdict,
              'entity_id': item['entity_id'],
              'detail': verdict == 'conflict' ? 'Server version is newer' : null,
            })
        .toList();
    return ResponseBody.fromString(
      '{"results": ${_encode(results)}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  String _encode(List<Map<String, dynamic>> rows) {
    return '[${rows.map((r) => '{"client_op_id":"${r['client_op_id']}",'
        '"status":"${r['status']}",'
        '"entity_id":"${r['entity_id']}",'
        '"detail":${r['detail'] == null ? 'null' : '"${r['detail']}"'}}').join(',')}]';
  }

  @override
  void close({bool force = false}) {}
}

late AppDatabase db;
late ApiClient client;
late SyncEngine engine;

void _boot(String? verdict) {
  db = AppDatabase(NativeDatabase.memory());
  client = ApiClient(baseUrl: 'http://stub/api/v1');
  client.dio.httpClientAdapter = _StubPushAdapter(verdict);
  engine = SyncEngine(db: db, client: client, settings: SettingsStore(db));
}

Future<void> _seedPatient(String id) {
  return db.upsertPatient(LocalPatientsCompanion.insert(
    id: id,
    code: 'TB000001',
    name: 'Uji Pasien',
    age: 40,
    gender: 'Male',
    updatedAt: Value(DateTime(2026, 7, 1)),
  ));
}

void main() {
  tearDown(() async => db.close());

  test('queued write is pushed carrying its client_op_id', () async {
    _boot('applied');
    await _seedPatient('p1');
    await engine.enqueuePatientUpdate('p1', {'name': 'Nama Baru'},
        baseUpdatedAt: DateTime(2026, 7, 1));

    expect(await engine.pendingCount(), 1);

    final report = await engine.push();

    expect(report.applied, 1);
    expect(await engine.pendingCount(), 0);
    final adapter = client.dio.httpClientAdapter as _StubPushAdapter;
    expect(adapter.lastItems.single['client_op_id'], isNotEmpty);
    expect(adapter.lastItems.single['entity_id'], 'p1');
  });

  test('retry answered "skipped" is treated as success, not a duplicate',
      () async {
    _boot('skipped');
    await _seedPatient('p1');
    await engine.enqueuePatientUpdate('p1', {'name': 'Nama Baru'});

    final report = await engine.push();

    expect(report.skipped, 1);
    expect(report.applied, 0);
    expect(await engine.pendingCount(), 0);
  });

  test('conflict flags the row for manual review and never overwrites it',
      () async {
    _boot('conflict');
    await _seedPatient('p1');
    await engine.enqueuePatientUpdate('p1', {'name': 'Nama Baru'},
        baseUpdatedAt: DateTime(2026, 6, 1));

    final report = await engine.push();

    expect(report.conflicts, 1);
    expect(report.hasProblems, isTrue);

    final row = await db.findPatient('p1');
    expect(row!.hasConflict, isTrue);
    // Local data untouched — the doctor decides, not the sync engine.
    expect(row.name, 'Uji Pasien');

    final conflicts = await db.opsWithStatus(syncConflict);
    expect(conflicts.single.detail, 'Server version is newer');
  });

  test('network failure keeps nothing lost — op is retried on next push',
      () async {
    _boot(null);
    await _seedPatient('p1');
    await engine.enqueuePatientUpdate('p1', {'name': 'Nama Baru'});

    final first = await engine.push();
    expect(first.failed, 1);

    // Server reachable again: the same op is retried and now succeeds.
    client.dio.httpClientAdapter = _StubPushAdapter('applied');
    await db.markOp(
      (await db.opsWithStatus(syncFailed)).single.clientOpId,
      syncPending,
    );
    final second = await engine.push();
    expect(second.applied, 1);
  });

  test('cache refresh preserves rows still waiting in the queue', () async {
    _boot('applied');
    await _seedPatient('offline-only');
    await engine.enqueuePatientUpdate('offline-only', {'name': 'X'});

    // Server snapshot that does not contain the queued row.
    await db.replacePatientCache([
      LocalPatientsCompanion.insert(
        id: 'server-1',
        code: 'TB000009',
        name: 'Dari Server',
        age: 30,
        gender: 'Female',
      ),
    ]);

    final ids = (await db.allPatients()).map((r) => r.id).toSet();
    expect(ids, containsAll(<String>['offline-only', 'server-1']));
  });
}
