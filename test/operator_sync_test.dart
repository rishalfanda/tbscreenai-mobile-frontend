import 'package:myapp/data/local/mappers.dart';
import 'package:myapp/data/offline/offline_validation_repository.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/features/sync/presentation/operator_sync_screen.dart';
import 'staging_doctor_navigation_test.dart' as app_fixture;
import 'package:image/image.dart' as img;
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_auth_repository.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/encrypted_xray_store.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/offline/device_operator_outbox.dart';
import 'package:myapp/data/offline/operator_sync_service.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/state/auth_provider.dart';

const tenant = '11111111-1111-4111-8111-111111111111';
const doctor = '22222222-2222-4222-8222-222222222222';
const technician = '33333333-3333-4333-8333-333333333333';
const patient = '44444444-4444-4444-8444-444444444444';
const diagnosis = '55555555-5555-4555-8555-555555555555';
const registered = '66666666-6666-4666-8666-666666666666';
const localDevice = 'local-device';
const profile = UserProfile(
  userId: technician,
  tenantId: tenant,
  displayName: 'Synthetic technician',
  email: 'tech@example.invalid',
  role: 'technician',
);

class _Auth implements AuthRepository {
  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async => profile;
  @override
  Future<void> logout() async {}
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final FutureOr<(int, Object?)> Function(RequestOptions) answer;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    final (status, body) = await answer(o);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

late AppDatabase db;
late MemorySecureTokenStorage secure;
late DeviceOperatorOutbox outbox;
late ApiClient client;
late AuthProvider auth;
late EncryptedXrayStore xray;
Future<void> owner(
  String id, {
  String role = 'doctor',
  String tenantId = tenant,
}) async {
  db.invalidateSession();
  await db.activateOwner(
    db.sessionGeneration,
    DataOwner(tenantId: tenantId, userId: id, deviceId: localDevice),
  );
  await SettingsStore(db).saveIdentity(
    userId: id,
    tenantId: tenantId,
    role: role,
    displayName: 'Synthetic',
    email: 'synthetic@example.invalid',
  );
}

Future<void> seed({bool image = false}) async {
  await owner(doctor);
  await db.upsertPatient(
    LocalPatientsCompanion.insert(
      id: patient,
      code: 'SYN-OPERATOR',
      name: 'Synthetic patient',
      age: 30,
      gender: 'male',
    ),
  );
  await db.enqueue(
    SyncQueueCompanion.insert(
      clientOpId: 'patient-op',
      entityType: 'patient',
      entityId: patient,
      operation: 'create',
      payload: jsonEncode({
        'name': 'Synthetic patient',
        'code': 'SYN-OPERATOR',
      }),
      createdAt: DateTime.utc(2026),
    ),
  );
  if (image) {
    final picture = XrayImage.fromBytes(
      bytes: Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2))),
      filename: 'synthetic.png',
      source: XrayImageSource.gallery,
    );
    final reference = await xray.persist(artifactId: diagnosis, image: picture);
    await db.upsertDiagnosis(
      LocalDiagnosesCompanion.insert(
        id: diagnosis,
        patientId: patient,
        isPositive: false,
        confidence: 80,
        modelVersion: 'synthetic-model',
        diagnosedAt: DateTime.utc(2026),
        imageReference: Value(reference),
        imageChecksum: Value(picture.checksumSha256),
        isMock: const Value(false),
      ),
    );
    await db.enqueue(
      SyncQueueCompanion.insert(
        clientOpId: 'diagnosis-op',
        entityType: 'diagnosis',
        entityId: diagnosis,
        operation: 'create',
        payload: jsonEncode({'patient_id': patient, 'is_positive': false}),
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
  }
}

Future<void> handoff() async {
  await outbox.captureDoctorQueue();
  await db.clearSessionData();
  await owner(technician, role: 'technician');
}

Future<void> activate() async => client.deviceIdentity.saveActivation({
  'device_id': registered,
  'tenant_id': tenant,
  'label': 'Synthetic tablet',
  'status': 'active',
  'credential': 'synthetic-device-secret',
});
OperatorSyncService service() => OperatorSyncService(
  db: db,
  client: client,
  outbox: outbox,
  xray: xray,
  auth: auth,
);
Map<String, Object?> receipt(
  RequestOptions o, {
  String status = 'applied',
  String? ownerId = doctor,
}) {
  final item = ((o.data as Map)['items'] as List).single as Map;
  return {
    'device_id': registered,
    'operator_user_id': technician,
    'results': [
      {
        'client_op_id': item['client_op_id'],
        'entity_id': item['entity_id'],
        'owner_user_id': ownerId,
        'status': status,
        'code': status == 'failed' ? 'invalid_payload' : null,
      },
    ],
  };
}

void main() {
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    secure = MemorySecureTokenStorage();
    outbox = DeviceOperatorOutbox(db, secure);
    xray = EncryptedXrayStore(db: db, secureStorage: secure);
    client = ApiClient(
      baseUrl: 'https://synthetic.invalid/api/v1',
      secureStorage: secure,
      initialAccessToken: 'synthetic-token',
      initialRefreshToken: 'synthetic-refresh',
    );
    auth = AuthProvider(_Auth(), initialProfile: profile);
  });
  tearDown(() async {
    auth.dispose();
    await client.close();
    await db.close();
  });
  test(
    'PR38 read-back preserves score endpoints and encrypted local X-ray',
    () async {
      await seed(image: true);
      final before = await db.findDiagnosis(diagnosis);
      final repo = OfflineValidationRepository(
        db: db,
        client: client,
        syncEngine: SyncEngine(
          db: db,
          client: client,
          settings: SettingsStore(db),
        ),
        xrayStore: xray,
        localOnly: true,
      );
      for (final score in [0, 10]) {
        await db.upsertDiagnosis(
          diagnosisRowFromJson({
            'id': diagnosis,
            'patient_id': patient,
            'is_positive': false,
            'confidence': 80,
            'model_version': 'synthetic-model',
            'status': 'agreed',
            'doctor_note': 'Synthetic server note',
            'validation_score': score,
            'validated_by': doctor,
            'validated_at': '2026-10-30T02:15:00Z',
            'version': 2,
          }),
        );
        final row = await db.findDiagnosis(diagnosis);
        expect(row!.validationScore, score);
        expect(row.validatedBy, doctor);
        expect(row.validatedAt!.toUtc(), DateTime.utc(2026, 10, 30, 2, 15));
        expect((await repo.getCases()).single.validationScore, score);
        expect(
          (await repo.getCases()).single.validationNote,
          'Synthetic server note',
        );
        expect(
          (await repo.loadCaseImage(diagnosis))!.checksumSha256,
          before!.imageChecksum,
        );
      }
    },
  );

  for (final supported in [false, true]) {
    test(
      'PR38 normal sync holds score until deployed contract: $supported',
      () async {
        await seed(image: true);
        final sync = SyncEngine(
          db: db,
          client: client,
          settings: SettingsStore(db),
        );
        final repo = OfflineValidationRepository(
          db: db,
          client: client,
          syncEngine: sync,
          localOnly: true,
        );
        await repo.submitScore(id: diagnosis, score: 10, status: 'agreed');
        for (final op in await db.pendingOps()) {
          if (op.operation != 'update') {
            await db.markOp(op.clientOpId, syncSynced);
          }
        }
        var posts = 0;
        client.dio.httpClientAdapter = _Adapter((o) {
          if (o.uri.path == '/openapi.json') {
            return (
              200,
              {
                'paths': {
                  '/api/v1/diagnoses/{diagnosis_id}/status': {
                    'patch': {
                      'requestBody': {
                        'content': {
                          'application/json': {
                            'schema': {
                              r'$ref':
                                  '#/components/schemas/DiagnosisValidationPatch',
                            },
                          },
                        },
                      },
                      'responses': {
                        '200': {
                          'content': {
                            'application/json': {
                              'schema': {
                                r'$ref': '#/components/schemas/DiagnosisOut',
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
                'components': {
                  'schemas': supported
                      ? {
                          'DiagnosisValidationPatch': {
                            'properties': {
                              'validation_score': {},
                              'validated_at': {},
                              'status': {},
                              'base_version': {},
                            },
                          },
                          'DiagnosisOut': {
                            'properties': {
                              'validation_score': {},
                              'validated_at': {},
                              'status': {},
                              'base_version': {},
                              'validated_by': {},
                            },
                          },
                        }
                      : {},
                },
              },
            );
          }
          posts++;
          expect(o.path, '/sync/push');
          final item = ((o.data as Map)['items'] as List).single as Map;
          expect((item['payload'] as Map)['validation_score'], 10);
          return (200, receipt(o));
        });
        final report = await sync.push();
        expect(posts, supported ? 1 : 0);
        expect(report.applied, supported ? 1 : 0);
        expect(report.blocked, supported ? 0 : 1);
        expect((await db.pendingOps()).length, supported ? 0 : 1);
      },
    );
  }

  for (final supported in [false, true]) {
    test(
      'PR38 score operator sync requires deployed contract: $supported',
      () async {
        await seed(image: true);
        final repo = OfflineValidationRepository(
          db: db,
          client: client,
          syncEngine: SyncEngine(
            db: db,
            client: client,
            settings: SettingsStore(db),
          ),
          xrayStore: xray,
          localOnly: true,
        );
        await repo.submitScore(
          id: diagnosis,
          score: 0,
          status: 'disagreed',
          note: 'Synthetic reason',
        );
        final queued = (await db.pendingOps())
            .where((op) => op.operation == 'update')
            .single;
        final body = jsonDecode(queued.payload) as Map;
        expect(body['validation_score'], 0);
        expect(body['status'], 'disagreed');
        expect(body['validated_at'], isNotNull);
        expect(body.containsKey('validated_by'), isFalse);
        expect(queued.baseVersion, 1);
        expect((await repo.getCases()).single.validationScore, 0);
        await expectLater(
          repo.submitScore(id: diagnosis, score: 10, status: 'agreed'),
          throwsA(isA<ValidationContractException>()),
        );
        await handoff();
        await activate();
        for (final entry in await service().queued()) {
          if ((entry['op'] as Map)['operation'] != 'update') {
            await outbox.remove((entry['op'] as Map)['clientOpId'] as String);
          }
        }
        var posts = 0;
        client.dio.httpClientAdapter = _Adapter((o) {
          if (o.uri.path == '/openapi.json') {
            return (
              200,
              {
                'paths': {
                  '/api/v1/diagnoses/{diagnosis_id}/status': {
                    'patch': {
                      'requestBody': {
                        'content': {
                          'application/json': {
                            'schema': {
                              r'$ref':
                                  '#/components/schemas/DiagnosisValidationPatch',
                            },
                          },
                        },
                      },
                      'responses': {
                        '200': {
                          'content': {
                            'application/json': {
                              'schema': {
                                r'$ref': '#/components/schemas/DiagnosisOut',
                              },
                            },
                          },
                        },
                      },
                    },
                  },
                },
                'components': {
                  'schemas': supported
                      ? {
                          'DiagnosisValidationPatch': {
                            'properties': {
                              'validation_score': {},
                              'validated_at': {},
                              'status': {},
                              'base_version': {},
                            },
                          },
                          'DiagnosisOut': {
                            'properties': {
                              'validation_score': {},
                              'validated_at': {},
                              'status': {},
                              'base_version': {},
                              'validated_by': {},
                            },
                          },
                        }
                      : {},
                },
              },
            );
          }
          posts++;
          final item = ((o.data as Map)['items'] as List).single as Map;
          expect(item['owner_user_id'], doctor);
          expect(item['base_version'], 1);
          expect((item['payload'] as Map)['validation_score'], 0);
          expect(
            (item['payload'] as Map)['validated_at'],
            body['validated_at'],
          );
          return (200, receipt(o));
        });
        final report = await service().push();
        expect(posts, supported ? 1 : 0);
        expect(report.blocked, supported ? 0 : 1);
        expect(report.applied, supported ? 1 : 0);
        expect((await service().queued()).length, supported ? 0 : 1);
      },
    );
  }

  test(
    'offline score 0 and 10 survive encrypted handoff and never reach legacy API',
    () async {
      await seed(image: true);
      var requests = 0;
      client.dio.httpClientAdapter = _Adapter((o) {
        requests++;
        return (200, receipt(o));
      });
      final repo = OfflineValidationRepository(
        db: db,
        client: client,
        syncEngine: SyncEngine(
          db: db,
          client: client,
          settings: SettingsStore(db),
        ),
        xrayStore: xray,
        localOnly: true,
      );
      expect((await repo.getCases()).single.serverVersion, isNull);
      final image = await repo.loadCaseImage(diagnosis);
      expect(image, isNotNull);
      for (final score in [0, 10]) {
        await repo.submitScore(
          id: diagnosis,
          score: score,
          note: 'Synthetic review',
        );
        expect((await repo.getCases()).single.validationScore, score);
      }
      expect((await db.opsWithStatus(syncBlockedContract)).length, 1);
      expect(
        (await db.pendingOps()).any((op) => op.operation == 'validate_score'),
        isFalse,
      );
      expect(requests, 0);
      await handoff();
      await activate();
      final entries = await service().queued();
      final held = entries
          .where(
            (entry) => (entry['op'] as Map)['operation'] == 'validate_score',
          )
          .single;
      expect(jsonDecode((held['op'] as Map)['payload'] as String)['score'], 10);
      // Only retain the score to isolate the operator's blocked-operation path.
      for (final entry in entries) {
        if (!identical(entry, held) &&
            (entry['op'] as Map)['operation'] != 'validate_score') {
          await outbox.remove((entry['op'] as Map)['clientOpId'] as String);
        }
      }
      final report = await service().push();
      expect(report.blocked, 1);
      expect(requests, 0);
      expect((await service().queued()).length, 1);
      await db.clearSessionData();
      await owner(doctor);
      await outbox.restoreDoctorQueue();
      expect((await repo.getCases()).single.validationScore, 10);
      expect(
        (await repo.loadCaseImage(diagnosis))!.checksumSha256,
        image!.checksumSha256,
      );
      await owner(technician, role: 'technician');
      await expectLater(
        repo.submitScore(id: diagnosis, score: 5),
        throwsA(isA<ValidationContractException>()),
      );
    },
  );

  testWidgets(
    'operator UI sends the retained queue and refreshes remaining count',
    (tester) async {
      await tester.runAsync(() async {
        await seed();
        await handoff();
        await activate();
      });
      client.dio.httpClientAdapter = _Adapter((o) => (200, receipt(o)));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider.value(value: client),
            Provider<OperatorSyncService>.value(value: service()),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
          ],
          child: const MaterialApp(home: Scaffold(body: OperatorSyncScreen())),
        ),
      );
      await app_fixture.pumpApp(tester);
      expect(find.text('Retained queue: 1'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Sync to server'));
      await app_fixture.pumpApp(tester);
      expect(find.text('Retained queue: 0'), findsOneWidget);
      expect(find.textContaining('Applied: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await app_fixture.pumpApp(tester);
    },
    skip: !AppConfig.useHttp,
  );
  test(
    'server record ACK alone cannot discard an unsent X-ray at logout',
    () async {
      await seed(image: true);
      await db.markOp('patient-op', syncSynced);
      await db.markOp('diagnosis-op', syncSynced);
      await handoff();
      final saved = await service().queued();
      expect(saved.length, 1);
      expect(saved.single['record_synced'], isTrue);
      expect(
        SyncQueueData.fromJson(
          saved.single['op'] as Map<String, dynamic>,
        ).clientOpId,
        'diagnosis-op',
      );
      expect(saved.single['artifact'], isNotNull);
      expect(await db.allPatients(), isEmpty);
    },
  );
  test(
    'process restart before logout preserves doctor queue during technician login',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'tbscreen_operator_test_',
      );
      final file = File('${folder.path}/synthetic.sqlite');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      outbox = DeviceOperatorOutbox(db, secure);
      xray = EncryptedXrayStore(db: db, secureStorage: secure);
      addTearDown(() async {
        await db.close();
        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          final generated = File('${file.path}$suffix');
          if (await generated.exists()) await generated.delete();
        }
        await folder.delete();
      });
      await seed(image: true);
      await SettingsStore(db).saveInstalledModelVersion('synthetic-installed');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      outbox = DeviceOperatorOutbox(db, secure);
      expect(db.activeOwner, isNull);
      client.dio.httpClientAdapter = _Adapter(
        (o) => (
          200,
          {
            'access_token': 'synthetic-access',
            'refresh_token': 'synthetic-refresh',
            'user': {
              'id': technician,
              'tenant_id': tenant,
              'full_name': 'Synthetic technician',
              'email': 'tech@example.invalid',
              'role': 'technician',
              'must_change_password': false,
            },
          },
        ),
      );
      final repo = HttpAuthRepository(
        client,
        settings: SettingsStore(db),
        db: db,
        outbox: outbox,
      );
      await repo.login(
        email: 'tech@example.invalid',
        password: 'synthetic-test',
      );
      expect(await db.allPatients(), isEmpty);
      expect((await outbox.entries(tenant, localDevice)).length, 2);
      expect(
        await SettingsStore(db).readInstalledModelVersion(),
        'synthetic-installed',
      );
    },
  );
  test(
    'temporary password cannot restore clinical cache before password replacement',
    () async {
      await seed();
      await outbox.captureDoctorQueue();
      await db.clearSessionData();
      client.dio.httpClientAdapter = _Adapter(
        (o) => (
          200,
          {
            'access_token': 'synthetic-next-access',
            'refresh_token': 'synthetic-next-refresh',
            'user': {
              'id': doctor,
              'tenant_id': tenant,
              'full_name': 'Synthetic doctor',
              'email': 'doctor@example.invalid',
              'role': 'doctor',
              'must_change_password': o.path == '/auth/login',
            },
          },
        ),
      );
      final repo = HttpAuthRepository(
        client,
        settings: SettingsStore(db),
        db: db,
        outbox: outbox,
      );
      final signedIn = await repo.login(
        email: 'doctor@example.invalid',
        password: 'synthetic-temporary',
      );
      expect(signedIn.mustChangePassword, isTrue);
      expect(await db.allPatients(), isEmpty);
      await repo.changePassword(
        currentPassword: 'synthetic-temporary',
        newPassword: 'synthetic-replacement',
      );
      expect((await db.allPatients()).single.name, 'Synthetic patient');
      expect((await db.pendingOps()).length, 1);
    },
  );
  test(
    'doctor logout archives ciphertext and technician cannot read doctor cache',
    () async {
      await seed(image: true);
      await SettingsStore(db).saveInstalledModelVersion('synthetic-installed');
      await handoff();
      expect(await db.allPatients(), isEmpty);
      expect(await db.allDiagnoses(), isEmpty);
      expect(await db.findEncryptedArtifact(diagnosis), isNull);
      final rows = await (db.select(
        db.appSettings,
      )..where((t) => t.key.like('${DeviceOperatorOutbox.prefix}%'))).get();
      expect(rows.length, 2);
      expect(
        rows.map((r) => r.value).join(),
        isNot(contains('Synthetic patient')),
      );
      expect((await service().queued()).length, 2);
      expect(await outbox.entries('other-tenant', localDevice), isEmpty);
      expect(await outbox.entries(tenant, 'other-device'), isEmpty);
      expect(
        await SettingsStore(db).readInstalledModelVersion(),
        'synthetic-installed',
      );
      await db.clearSessionData();
      await owner(doctor);
      await outbox.restoreDoctorQueue();
      expect((await db.allPatients()).single.name, 'Synthetic patient');
      expect((await db.pendingOps()).length, 2);
      expect(
        (await xray.read('local-encrypted://$diagnosis')).sizeBytes,
        greaterThan(0),
      );
    },
  );
  test(
    'real auth repository archives before clearing clinical cache on logout',
    () async {
      await seed();
      final repo = HttpAuthRepository(
        client,
        settings: SettingsStore(db),
        db: db,
        outbox: outbox,
      );
      await repo.logout();
      expect(await db.allPatients(), isEmpty);
      expect((await outbox.entries(tenant, localDevice)).length, 1);
    },
  );
  test('failed encryption never clears pending doctor work', () async {
    await seed();
    await outbox.captureDoctorQueue();
    await secure.delete('device_operator_outbox_aes_v1');
    final repo = HttpAuthRepository(
      client,
      settings: SettingsStore(db),
      db: db,
      outbox: outbox,
    );
    await expectLater(repo.logout(), throwsStateError);
    expect((await db.pendingOps()).length, 1);
    expect(client.tokens.hasSession, isFalse);
  });
  test(
    'pending handoff survives restart and remains tenant/device scoped',
    () async {
      await seed();
      await handoff();
      final restarted = DeviceOperatorOutbox(db, secure);
      expect((await restarted.entries(tenant, localDevice)).length, 1);
      expect(
        await restarted.entries(tenant, localDevice, ownerId: technician),
        isEmpty,
      );
    },
  );
  test(
    'operator sends original owner and device headers, never normal push/pull',
    () async {
      await seed();
      await handoff();
      await activate();
      client.dio.httpClientAdapter = _Adapter((o) {
        expect(o.path, '/sync/operator/push');
        expect(o.headers['X-Device-Id'], registered);
        expect(o.headers['X-Device-Credential'], 'synthetic-device-secret');
        final item = ((o.data as Map)['items'] as List).single as Map;
        expect(item['owner_user_id'], doctor);
        expect(item['client_op_id'], 'patient-op');
        return (200, receipt(o));
      });
      final report = await service().push();
      expect(report.applied, 1);
      expect(await service().queued(), isEmpty);
    },
  );
  test('unregistered tablet cannot transmit queue', () async {
    await seed();
    await handoff();
    var requests = 0;
    client.dio.httpClientAdapter = _Adapter((_) {
      requests++;
      return (200, {});
    });
    await expectLater(service().push(), throwsStateError);
    expect(requests, 0);
    expect((await service().queued()).length, 1);
  });
  for (final status in ['conflict', 'failed']) {
    test(
      '$status stays encrypted and returns to the doctor for correction',
      () async {
        await seed();
        await handoff();
        await activate();
        client.dio.httpClientAdapter = _Adapter(
          (o) => (200, receipt(o, status: status)),
        );
        final report = await service().push();
        expect(report.conflicts + report.failed, 1);
        expect((await service().queued()).length, 1);
        await db.clearSessionData();
        await owner(doctor);
        await outbox.restoreDoctorQueue();
        expect(
          (await db.opsWithStatus(
            status == 'conflict' ? syncConflict : syncPermanentFailure,
          )).length,
          1,
        );
      },
    );
  }
  test('malformed and mismatched owner receipts cannot clear queue', () async {
    await seed();
    await handoff();
    await activate();
    client.dio.httpClientAdapter = _Adapter(
      (o) => (200, receipt(o, ownerId: technician)),
    );
    expect((await service().push()).failed, 1);
    expect((await service().queued()).length, 1);
  });
  test(
    'network retry keeps client_op_id; skipped receipt clears queue',
    () async {
      await seed();
      await handoff();
      await activate();
      client.dio.httpClientAdapter = _Adapter(
        (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'synthetic offline',
        ),
      );
      expect((await service().push()).failed, 1);
      client.dio.httpClientAdapter = _Adapter((o) {
        expect(
          ((o.data as Map)['items'] as List).single['client_op_id'],
          'patient-op',
        );
        return (200, receipt(o, status: 'skipped'));
      });
      expect((await service().push()).skipped, 1);
      expect(await service().queued(), isEmpty);
    },
  );
  test(
    'late operator response after logout cannot delete retained work',
    () async {
      await seed();
      await handoff();
      await activate();
      final waiting = Completer<(int, Object?)>();
      final started = Completer<RequestOptions>();
      client.dio.httpClientAdapter = _Adapter((o) {
        started.complete(o);
        return waiting.future;
      });
      final run = service().push();
      final failed = expectLater(run, throwsStateError);
      final request = await started.future;
      await auth.logout();
      db.invalidateSession();
      waiting.complete((200, receipt(request)));
      await failed;
      expect((await outbox.entries(tenant, localDevice)).length, 1);
    },
  );
  test(
    'image upload resumes after record ACK; incomplete image never counts as synced',
    () async {
      await seed(image: true);
      await handoff();
      await activate();
      var complete = false, recordRequests = 0, chunkRequests = 0;
      client.dio.httpClientAdapter = _Adapter((o) {
        if (o.path == '/sync/operator/push') {
          recordRequests++;
          return (200, receipt(o));
        }
        if (o.path == '/blobs/init') {
          final body = o.data as Map;
          return (
            201,
            {
              'upload_id': 'synthetic-upload',
              'diagnosis_id': diagnosis,
              'size_bytes': body['size_bytes'],
              'chunk_count': body['chunk_count'],
              'chunk_size': body['chunk_size'],
              'received_chunks': chunkRequests > 0 ? [0] : [],
              'status': 'receiving',
            },
          );
        }
        if (o.path.contains('/chunks/')) {
          chunkRequests++;
          return (204, null);
        }
        if (!complete) return (503, {});
        return (
          200,
          {
            'upload_id': 'synthetic-upload',
            'diagnosis_id': diagnosis,
            'status': 'completed',
            'image_id': 'synthetic-image',
          },
        );
      });
      final first = await service().push();
      expect(first.applied, 1);
      expect(first.failed, 1);
      expect((await service().queued()).length, 1);
      complete = true;
      final second = await service().push();
      expect(second.skipped, 1);
      expect(recordRequests, 2);
      expect(chunkRequests, 1);
      expect(await service().queued(), isEmpty);
    },
  );
  test(
    'registered device headers attach at login and change-password as well as data',
    () async {
      await activate();
      client.dio.httpClientAdapter = _Adapter((o) {
        expect(o.headers['X-Device-Id'], registered);
        if (o.path != '/auth/login') {
          expect(o.headers['Authorization'], 'Bearer synthetic-token');
        }
        return (200, {});
      });
      await client.dio.post<Object?>('/auth/login', data: {});
      await client.dio.post<Object?>('/auth/change-password', data: {});
      await client.dio.get<Object?>('/auth/me');
      await client.tokens.clear();
      expect(await client.deviceIdentity.read(), isNotNull);
      expect(await db.getSetting('registered_tablet_identity_v1'), isNull);
    },
  );
  test(
    'activation nonce survives failed retries; activation stores secrets only in keychain',
    () async {
      final first = await client.deviceIdentity.activationNonce();
      expect(first.length, greaterThanOrEqualTo(22));
      expect(await client.deviceIdentity.activationNonce(), first);
      await activate();
      expect(await client.deviceIdentity.read(), isNotNull);
      expect(await db.getSetting('tablet_activation_nonce_v1'), isNull);
      await expectLater(activate(), throwsStateError);
    },
  );
}
