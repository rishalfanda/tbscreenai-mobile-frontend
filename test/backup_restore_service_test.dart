import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/data/backup/backup_restore_models.dart';
import 'package:myapp/data/backup/device_backup_restore_service.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/offline/device_operator_outbox.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/domain/models/user_profile.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final ResponseBody Function(RequestOptions) answer;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return answer(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late AppDatabase db;
  late MemorySecureTokenStorage secrets;
  late ApiClient client;
  late DeviceOperatorOutbox outbox;

  const technician = UserProfile(
    userId: 'tech-1',
    tenantId: 'tenant-1',
    displayName: 'Teknisi',
    email: 'tech@example.test',
    role: 'technician',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    secrets = MemorySecureTokenStorage();
    client = ApiClient(
      baseUrl: 'https://synthetic.example/api/v1',
      secureStorage: secrets,
    );
    await client.deviceIdentity.saveActivation({
      'status': 'active',
      'device_id': 'device-1',
      'tenant_id': 'tenant-1',
      'credential': 'synthetic-credential',
      'label': 'Tablet Test',
    });
    await db.activateOwner(
      db.sessionGeneration,
      const DataOwner(
        tenantId: 'tenant-1',
        userId: 'tech-1',
        deviceId: 'device-1',
      ),
    );
    outbox = DeviceOperatorOutbox(db, secrets);
  });

  tearDown(() async {
    client.close();
    await db.close();
  });

  DeviceBackupRestoreService service(UserProfile actor) =>
      DeviceBackupRestoreService(
        client: client,
        db: db,
        outbox: outbox,
        secureStorage: secrets,
        actor: () => actor,
        localDeviceId: () async => 'device-1',
      );

  test('pending restore uses deployed endpoint and parses plan', () async {
    final adapter = _Adapter(
      (_) => _json({
        'restore_id': 'restore-1',
        'backup_id': 'backup-1',
        'backup_name': 'Backup RS - Tablet',
        'backup_completed_at': '2026-11-11T00:00:00Z',
        'counts': {'patients': 1, 'diagnoses': 1, 'images': 1},
        'records_expected': 2,
        'snapshot': {
          'url': '/restores/restore-1/snapshot',
          'sha256': 'a' * 64,
          'size_bytes': 10,
        },
        'images': const [],
        'images_to_download': 0,
      }),
    );
    client.dio.httpClientAdapter = adapter;

    final pending = await service(technician).pendingRestore();

    expect(pending?.restoreId, 'restore-1');
    expect(pending?.recordsExpected, 2);
    expect(adapter.requests.single.path, '/restores/pending');
  });

  test('doctor is rejected before any backup request', () async {
    final adapter = _Adapter((_) => _json({}));
    client.dio.httpClientAdapter = adapter;
    const doctor = UserProfile(
      userId: 'doctor-1',
      tenantId: 'tenant-1',
      displayName: 'Dokter',
      email: 'doctor@example.test',
    );

    await expectLater(
      service(doctor).pendingRestore(),
      throwsA(
        isA<BackupRestoreException>().having(
          (error) => error.message,
          'message',
          contains('Hanya teknisi'),
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });

  test('backup with no synchronized inventory fails closed', () async {
    final adapter = _Adapter((_) => _json({}));
    client.dio.httpClientAdapter = adapter;

    await expectLater(
      service(technician).createBackup(),
      throwsA(
        isA<BackupRestoreException>().having(
          (error) => error.message,
          'message',
          contains('Tidak ada data'),
        ),
      ),
    );
    expect(adapter.requests, isEmpty);
  });
}
