import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/data/backup/device_backup_restore_service.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/encrypted_xray_store.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'package:myapp/data/offline/device_operator_outbox.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/domain/models/user_profile.dart';

class _RestoreAdapter implements HttpClientAdapter {
  _RestoreAdapter({
    required this.snapshot,
    this.rejectCompleteCount = 0,
    this.image,
    this.corruptImage = false,
    this.snapshotUrl,
  });

  final List<int> snapshot;
  final List<int>? image;
  final bool corruptImage;
  final String? snapshotUrl;
  int rejectCompleteCount;
  final requests = <RequestOptions>[];

  String get checksum => sha256
      .convert(snapshot)
      .bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();

  Map<String, Object> get plan => <String, Object>{
    'restore_id': 'restore-1',
    'backup_id': 'backup-1',
    'backup_name': 'Synthetic backup',
    'backup_completed_at': '2026-11-11T00:00:00Z',
    'counts': <String, int>{
      'patients': 1,
      'diagnoses': 1,
      'images': image == null ? 0 : 1,
    },
    'records_expected': 2,
    'snapshot': <String, Object>{
      'url': snapshotUrl ?? '/api/v1/restores/restore-1/snapshot',
      'sha256': checksum,
      'size_bytes': snapshot.length,
    },
    'images': <Object>[
      if (image != null)
        <String, Object>{
          'image_id': 'image-1',
          'url': '/api/v1/restores/restore-1/images/image-1',
          'sha256': sha256.convert(image!).toString(),
          'size_bytes': image!.length,
          'media_type': 'image/png',
        },
    ],
    'images_to_download': image == null ? 0 : 1,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'POST' && options.path == '/backups') {
      return _json(<String, Object>{'backup_id': 'backup-new'});
    }
    if (options.method == 'PUT' &&
        options.path == '/backups/backup-new/manifest') {
      return _json(<String, Object>{
        'backup_id': 'backup-new',
        'name': 'Synthetic complete backup',
        'status': 'complete',
        'counts': <String, int>{'patients': 1, 'diagnoses': 1, 'images': 1},
      });
    }
    if (options.uri.path == '/api/v1/restores/restore-1/images/image-1') {
      return ResponseBody.fromBytes(corruptImage ? <int>[0, 1] : image!, 200);
    }
    if (options.method == 'GET' && options.path == '/restores/pending') {
      return _json(plan);
    }
    if (options.method == 'GET' &&
        options.uri.path == '/api/v1/restores/restore-1/snapshot') {
      return ResponseBody.fromBytes(snapshot, 200);
    }
    if (options.method == 'GET' && options.path == '/restores/restore-1') {
      return _json(<String, Object>{'detail': 'admin role required'}, 403);
    }
    if (options.method == 'POST' &&
        options.path == '/restores/restore-1/complete') {
      if (rejectCompleteCount > 0) {
        rejectCompleteCount--;
        return _json(<String, Object>{'detail': 'synthetic rejection'}, 422);
      }
      return _json(<String, Object>{'status': 'completed'});
    }
    if (options.method == 'POST' &&
        options.path == '/restores/restore-1/fail') {
      return _json(<String, Object>{'status': 'failed'});
    }
    return _json(<String, Object>{'detail': 'not found'}, 404);
  }

  ResponseBody _json(Object body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late MemorySecureTokenStorage secrets;
  late ApiClient client;
  late DeviceOperatorOutbox outbox;

  const technician = UserProfile(
    userId: 'tech-1',
    tenantId: 'tenant-1',
    displayName: 'Technician',
    email: 'tech@example.invalid',
    role: 'technician',
  );

  List<int> snapshot({List<int>? image}) => utf8.encode(
    jsonEncode(<String, Object>{
      'format': 1,
      'backup_id': 'backup-1',
      'tenant_id': 'tenant-1',
      'patients': <Object>[
        <String, Object>{
          'id': 'patient-1',
          'tenant_id': 'tenant-1',
          'code': 'SYN-1',
          'name': 'Synthetic patient',
          'age': 40,
          'gender': 'Male',
          'version': 3,
          'updated_at': '2026-11-11T00:00:00Z',
        },
      ],
      'diagnoses': <Object>[
        <String, Object>{
          'id': 'diagnosis-1',
          'patient_id': 'patient-1',
          'tenant_id': 'tenant-1',
          'created_by': 'doctor-1',
          'version': 4,
          'is_positive': true,
          'confidence': 80,
          'model_version': 'synthetic-model',
          'processing_time_ms': 10,
          'diagnosed_at': '2026-11-11T08:15:30Z',
          'status': 'pending',
          'findings': <String, Object>{},
          'provenance': <String, Object>{'is_mock': false},
          'updated_at': '2026-11-11T00:00:00Z',
        },
      ],
      'images': <Object>[
        if (image != null)
          <String, Object>{
            'image_id': 'image-1',
            'diagnosis_id': 'diagnosis-1',
            'stored_sha256': sha256.convert(image).toString(),
            'size_bytes': image.length,
            'media_type': 'image/png',
          },
      ],
    }),
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    secrets = MemorySecureTokenStorage();
    client = ApiClient(
      baseUrl: 'https://synthetic.invalid/api/v1',
      secureStorage: secrets,
    );
    await client.deviceIdentity.saveActivation(<String, dynamic>{
      'status': 'active',
      'device_id': 'device-1',
      'tenant_id': 'tenant-1',
      'credential': 'synthetic-credential',
      'label': 'Synthetic device',
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
    await client.close();
    await db.close();
  });

  DeviceBackupRestoreService service() => DeviceBackupRestoreService(
    client: client,
    db: db,
    outbox: outbox,
    secureStorage: secrets,
    actor: () => technician,
    localDeviceId: () async => 'local-device-1',
  );

  test(
    'receiver restore never calls the administrator-only detail route',
    () async {
      final adapter = _RestoreAdapter(snapshot: snapshot());
      client.dio.httpClientAdapter = adapter;

      final result = await service().restorePending();

      expect(result.recordsRestored, 2);
      expect(
        adapter.requests.where(
          (request) =>
              request.method == 'GET' && request.path == '/restores/restore-1',
        ),
        isEmpty,
      );
    },
  );

  test(
    'a rejected complete report retains a staged idempotent retry',
    () async {
      final adapter = _RestoreAdapter(
        snapshot: snapshot(),
        rejectCompleteCount: 1,
      );
      client.dio.httpClientAdapter = adapter;

      await expectLater(
        service().restorePending(),
        throwsA(isA<DioException>()),
      );

      expect(
        await outbox.entries(
          'tenant-1',
          'local-device-1',
          includeReceived: true,
        ),
        hasLength(1),
      );
      expect(
        adapter.requests.any(
          (request) => request.path == '/restores/restore-1/fail',
        ),
        isFalse,
      );

      final pending = await service().pendingRestore();
      expect(pending?.restoreId, 'restore-1');
      final result = await service().restorePending();
      expect(result.recordsRestored, 2);
      expect(
        adapter.requests.where(
          (request) => request.path == '/restores/pending',
        ),
        hasLength(1),
        reason: 'Retry must only acknowledge the already-staged restore',
      );
      expect(
        adapter.requests.where(
          (request) => request.uri.path.endsWith('/snapshot'),
        ),
        hasLength(1),
      );
      expect(
        adapter.requests.where(
          (request) => request.path == '/restores/restore-1/complete',
        ),
        hasLength(2),
      );
    },
  );
  test(
    'verified restore is readable only in the original doctor scope',
    () async {
      final image = XrayImage.placeholder().bytes;
      final adapter = _RestoreAdapter(
        snapshot: snapshot(image: image),
        image: image,
      );
      client.dio.httpClientAdapter = adapter;
      final result = await service().restorePending();
      expect(result.imagesVerified, 1);
      await db.clearSessionData();
      await db.activateOwner(
        db.sessionGeneration,
        const DataOwner(
          tenantId: 'tenant-1',
          userId: 'other-doctor',
          deviceId: 'local-device-1',
        ),
      );
      await db.putSetting(kUserRole, 'doctor');
      await outbox.restoreDoctorQueue();
      expect(await db.allDiagnoses(), isEmpty);
      await db.clearSessionData();
      await db.activateOwner(
        db.sessionGeneration,
        const DataOwner(
          tenantId: 'tenant-1',
          userId: 'doctor-1',
          deviceId: 'local-device-1',
        ),
      );
      await db.putSetting(kUserRole, 'doctor');
      await outbox.restoreDoctorQueue();
      final row = (await db.allDiagnoses()).single;
      expect(row.serverVersion, 4);
      expect(row.diagnosedAt.toUtc(), DateTime.parse('2026-11-11T08:15:30Z'));
      final restored = await EncryptedXrayStore(
        db: db,
        secureStorage: secrets,
      ).read(row.imageReference!);
      expect(restored.bytes, orderedEquals(image));
      final draft = DiagnosisDraft.fromSnapshots(
        patient: (jsonDecode(row.patientSnapshot) as Map)
            .cast<String, dynamic>(),
        clinical: (jsonDecode(row.clinicalSnapshot) as Map)
            .cast<String, dynamic>(),
        image: restored,
      );
      expect(draft.patientName, 'Synthetic patient');
      expect(draft.patientId, 'patient-1');
      expect(draft.patientCode, 'SYN-1');
      expect(await db.pendingOps(), isEmpty);
    },
  );

  test(
    'bad image checksum fails without importing any clinical archive',
    () async {
      final image = XrayImage.placeholder().bytes;
      final adapter = _RestoreAdapter(
        snapshot: snapshot(image: image),
        image: image,
        corruptImage: true,
      );
      client.dio.httpClientAdapter = adapter;
      await expectLater(service().restorePending(), throwsA(isA<Exception>()));
      expect(
        await outbox.entries(
          'tenant-1',
          'local-device-1',
          includeReceived: true,
        ),
        isEmpty,
      );
      expect(
        adapter.requests.any((r) => r.path.endsWith('/complete')),
        isFalse,
      );
      expect(adapter.requests.any((r) => r.path.endsWith('/fail')), isTrue);
    },
  );
  test(
    'foreign restore URL is rejected before downloading with credentials',
    () async {
      final adapter = _RestoreAdapter(
        snapshot: snapshot(),
        snapshotUrl:
            'https://foreign.invalid/api/v1/restores/restore-1/snapshot',
      );
      client.dio.httpClientAdapter = adapter;
      await expectLater(service().restorePending(), throwsA(isA<Exception>()));
      expect(
        adapter.requests.any((r) => r.uri.host == 'foreign.invalid'),
        isFalse,
      );
      expect(
        await outbox.entries(
          'tenant-1',
          'local-device-1',
          includeReceived: true,
        ),
        isEmpty,
      );
    },
  );

  test(
    'incomplete clinical snapshot rolls back instead of acknowledging success',
    () async {
      final data = jsonDecode(utf8.decode(snapshot())) as Map<String, dynamic>;
      (data['diagnoses'] as List).single.remove('diagnosed_at');
      final adapter = _RestoreAdapter(snapshot: utf8.encode(jsonEncode(data)));
      client.dio.httpClientAdapter = adapter;
      await expectLater(service().restorePending(), throwsA(isA<Exception>()));
      expect(
        await outbox.entries(
          'tenant-1',
          'local-device-1',
          includeReceived: true,
        ),
        isEmpty,
      );
      expect(
        adapter.requests.any((r) => r.path.endsWith('/complete')),
        isFalse,
      );
    },
  );
  test(
    'backup submits server versions from local-device archives after receipt verification',
    () async {
      final image = XrayImage.placeholder().bytes;
      final adapter = _RestoreAdapter(
        snapshot: snapshot(image: image),
        image: image,
      );
      client.dio.httpClientAdapter = adapter;
      await service().restorePending();
      final backup = await service().createBackup();
      expect(backup.status, 'complete');
      final manifest = adapter.requests.singleWhere(
        (r) => r.path.endsWith('/manifest'),
      );
      final body = manifest.data as Map;
      expect(body['format'], 1);
      expect(body['patients'], <Object>[
        <String, Object>{'id': 'patient-1', 'version': 3},
      ]);
      expect(body['diagnoses'], <Object>[
        <String, Object>{
          'id': 'diagnosis-1',
          'version': 4,
          'image_sha256': sha256.convert(image).toString(),
        },
      ]);
    },
  );
}
