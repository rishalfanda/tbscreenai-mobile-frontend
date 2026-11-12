import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/offline/offline_validation_repository.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/clinical_conflict.dart';

const _tenant = '11111111-1111-4111-8111-111111111111';
const _doctor = '22222222-2222-4222-8222-222222222222';
const _patient = '44444444-4444-4444-8444-444444444444';
const _diagnosis = '55555555-5555-4555-8555-555555555555';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final FutureOr<(int, Object?)> Function(RequestOptions) answer;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = await answer(options);
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

void main() {
  late AppDatabase db;
  late ApiClient client;
  late OfflineValidationRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    client = ApiClient(
      baseUrl: 'https://synthetic.invalid/api/v1',
      secureStorage: MemorySecureTokenStorage(),
      initialAccessToken: 'synthetic-token',
      initialRefreshToken: 'synthetic-refresh',
    );
    db.invalidateSession();
    await db.activateOwner(
      db.sessionGeneration,
      const DataOwner(
        tenantId: _tenant,
        userId: _doctor,
        deviceId: 'synthetic-device',
      ),
    );
    await SettingsStore(db).saveIdentity(
      userId: _doctor,
      tenantId: _tenant,
      role: 'doctor',
      displayName: 'Synthetic doctor',
      email: 'doctor@example.invalid',
    );
    await db.upsertPatient(
      LocalPatientsCompanion.insert(
        id: _patient,
        code: 'SYN-001',
        name: 'Synthetic patient',
        age: 30,
        gender: 'male',
      ),
    );
    await db.upsertDiagnosis(
      LocalDiagnosesCompanion.insert(
        id: _diagnosis,
        patientId: _patient,
        isPositive: true,
        confidence: 80,
        modelVersion: 'synthetic-model',
        diagnosedAt: DateTime.utc(2026, 11, 11, 10),
        isMock: const Value(false),
        serverVersion: const Value(2),
      ),
    );
    repository = OfflineValidationRepository(
      db: db,
      client: client,
      syncEngine: SyncEngine(
        db: db,
        client: client,
        settings: SettingsStore(db),
      ),
      localOnly: true,
    );
  });

  tearDown(() async {
    await client.close();
    await db.close();
  });

  Future<String> conflict({
    bool legacy = false,
    bool serverDeleted = false,
  }) async {
    if (legacy) {
      await repository.submitScore(id: _diagnosis, score: 8, status: 'agreed');
    } else {
      await repository.submitLesionRating(
        id: _diagnosis,
        rating: 7,
        status: 'agreed',
        note: 'Local review',
      );
    }
    final op = (await db.pendingOps()).single;
    await db.markOp(op.clientOpId, syncConflict, detail: 'version_conflict');
    await db.markDiagnosisConflict(_diagnosis, true);
    await db.saveConflictServerPayload(
      op.clientOpId,
      jsonEncode({
        'id': _diagnosis,
        'status': 'agreed',
        'doctor_note': 'Server review',
        'lesion_rating': 2,
        'version': 4,
        'updated_at': '2026-11-11T10:00:00Z',
        'validation_deleted_at': serverDeleted ? '2026-11-11T10:00:00Z' : null,
        'validation_deleted_by': serverDeleted ? _doctor : null,
      }),
    );
    return op.clientOpId;
  }

  test(
    'reapply keeps explicit lesion rating in a new immutable operation',
    () async {
      final oldId = await conflict();
      client.dio.httpClientAdapter = _Adapter((options) {
        if (options.uri.path.endsWith('/sync/push')) {
          return (503, {'detail': 'synthetic offline'});
        }
        throw StateError('Unexpected request ${options.uri}');
      });

      await repository.resolveConflict(
        conflict: (await repository.getConflicts()).single,
        decision: ConflictDecision.reapplyLocal,
      );

      expect((await db.findOperation(oldId))?.status, syncSynced);
      final replacement = (await db.select(db.syncQueue).get()).singleWhere(
        (op) => op.clientOpId != oldId,
      );
      expect(replacement.clientOpId, isNot(oldId));
      expect(replacement.baseVersion, 4);
      final replacementPayload = (jsonDecode(replacement.payload) as Map)
          .cast<String, dynamic>();
      expect(replacementPayload['lesion_rating'], 7);
      expect(replacementPayload.containsKey('validation_score'), isFalse);
    },
  );

  test('keep server applies lesion rating and deletion tombstone', () async {
    await conflict(serverDeleted: true);
    await repository.resolveConflict(
      conflict: (await repository.getConflicts()).single,
      decision: ConflictDecision.keepServer,
    );

    final row = (await db.findDiagnosis(_diagnosis))!;
    expect(row.lesionRating, 2);
    expect(row.validationDeletedAt?.toUtc(), DateTime.utc(2026, 11, 11, 10));
    expect(await repository.getCases(), isEmpty);
  });

  test(
    'legacy score conflict requires a clinician supplied lesion rating',
    () async {
      await conflict(legacy: true);
      final clinicalConflict = (await repository.getConflicts()).single;
      expect(clinicalConflict.requiresExplicitRating, isTrue);

      await expectLater(
        repository.resolveConflict(
          conflict: clinicalConflict,
          decision: ConflictDecision.reapplyLocal,
        ),
        throwsA(isA<ValidationContractException>()),
      );
    },
  );

  test('legacy retry needs a fresh explicit lesion rating', () async {
    final oldId = await conflict(legacy: true);
    client.dio.httpClientAdapter = _Adapter((options) {
      if (options.uri.path.endsWith('/sync/push')) {
        return (503, {'detail': 'synthetic offline'});
      }
      throw StateError('Unexpected request ${options.uri}');
    });
    await repository.resolveNumericConflict(
      conflict: (await repository.getConflicts()).single,
      decision: ConflictDecision.reapplyLocal,
      status: 'disagreed',
      lesionRating: 6,
      note: 'Explicit review',
    );
    final replacement = (await db.select(db.syncQueue).get()).singleWhere(
      (op) => op.clientOpId != oldId,
    );
    final payload = jsonDecode(replacement.payload) as Map;
    expect(payload['lesion_rating'], 6);
    expect(payload.containsKey('validation_score'), isFalse);
  });

  test(
    'promoting a dispatched legacy retry preserves the doctor note',
    () async {
      await repository.submitScore(
        id: _diagnosis,
        score: 8,
        status: 'agreed',
        note: 'Keep this clinical note',
      );
      final op = (await db.pendingOps()).single;
      await db.markOpRetryable(
        op,
        nextAttemptAt: DateTime.utc(2026, 11, 11),
        detail: 'Synthetic timeout after dispatch',
      );

      final conflicts = await repository.getConflicts();
      expect(conflicts, hasLength(1));
      expect(
        (await db.findDiagnosis(_diagnosis))?.doctorNote,
        'Keep this clinical note',
      );
      expect((await db.findOperation(op.clientOpId))?.status, syncConflict);
    },
  );

  test(
    'delete conflict retries with a new operation and server baseline',
    () async {
      await repository.submitLesionRating(
        id: _diagnosis,
        rating: 5,
        status: 'agreed',
      );
      final validationOp = (await db.pendingOps()).single;
      await db.markOp(validationOp.clientOpId, syncSynced);
      await repository.resetValidation(_diagnosis);
      final deleteOp = (await db.pendingOps()).single;
      await db.markOp(
        deleteOp.clientOpId,
        syncConflict,
        detail: 'version_conflict',
      );
      await db.markDiagnosisConflict(_diagnosis, true);
      await db.saveConflictServerPayload(
        deleteOp.clientOpId,
        jsonEncode({
          'id': _diagnosis,
          'status': 'agreed',
          'lesion_rating': 5,
          'version': 5,
          'updated_at': '2026-11-11T11:00:00Z',
          'validation_deleted_at': null,
          'validation_deleted_by': null,
        }),
      );
      client.dio.httpClientAdapter = _Adapter((options) {
        if (options.uri.path.endsWith('/sync/push')) {
          return (503, {'detail': 'synthetic offline'});
        }
        throw StateError('Unexpected request ${options.uri}');
      });

      final clinicalConflict = (await repository.getConflicts()).single;
      expect(clinicalConflict.isDelete, isTrue);
      await repository.resolveConflict(
        conflict: clinicalConflict,
        decision: ConflictDecision.reapplyLocal,
      );
      final replacement = (await db.select(db.syncQueue).get()).singleWhere(
        (op) =>
            op.operation == 'delete_validation' &&
            op.clientOpId != deleteOp.clientOpId,
      );
      expect(replacement.baseVersion, 5);
      expect((await db.findOperation(deleteOp.clientOpId))?.status, syncSynced);
    },
  );

  test('server-deleted validation cannot be reapplied', () async {
    await conflict(serverDeleted: true);
    final clinicalConflict = (await repository.getConflicts()).single;
    await expectLater(
      repository.resolveNumericConflict(
        conflict: clinicalConflict,
        decision: ConflictDecision.reapplyLocal,
        status: 'agreed',
        lesionRating: 7,
      ),
      throwsA(isA<ValidationContractException>()),
    );
    expect(await db.opsWithStatus(syncConflict), hasLength(1));
  });

  test('another tenant session cannot resolve the conflict', () async {
    await conflict();
    final clinicalConflict = (await repository.getConflicts()).single;
    db.invalidateSession();
    await db.activateOwner(
      db.sessionGeneration,
      const DataOwner(
        tenantId: '99999999-9999-4999-8999-999999999999',
        userId: _doctor,
        deviceId: 'synthetic-device',
      ),
    );
    await SettingsStore(db).saveIdentity(
      userId: _doctor,
      tenantId: '99999999-9999-4999-8999-999999999999',
      role: 'doctor',
      displayName: 'Other tenant doctor',
      email: 'other@example.invalid',
    );
    await expectLater(
      repository.resolveConflict(
        conflict: clinicalConflict,
        decision: ConflictDecision.keepServer,
      ),
      throwsA(isA<ValidationContractException>()),
    );
  });

  test(
    'late server snapshot is not written after the account changes',
    () async {
      final opId = await conflict();
      await (db.update(db.syncQueue)
            ..where((row) => row.clientOpId.equals(opId)))
          .write(const SyncQueueCompanion(serverPayload: Value(null)));
      final response = Completer<(int, Object?)>();
      client.dio.httpClientAdapter = _Adapter((_) => response.future);
      final pendingRead = repository.getConflicts();
      await pumpEventQueue();

      db.invalidateSession();
      await db.activateOwner(
        db.sessionGeneration,
        const DataOwner(
          tenantId: '99999999-9999-4999-8999-999999999999',
          userId: _doctor,
          deviceId: 'synthetic-device',
        ),
      );
      response.complete((
        200,
        {
          'id': _diagnosis,
          'tenant_id': _tenant,
          'status': 'agreed',
          'version': 8,
          'updated_at': '2026-11-11T12:00:00Z',
        },
      ));
      final result = await pendingRead;
      expect(result.single.hasServerSnapshot, isFalse);

      db.invalidateSession();
      await db.activateOwner(
        db.sessionGeneration,
        const DataOwner(
          tenantId: _tenant,
          userId: _doctor,
          deviceId: 'synthetic-device',
        ),
      );
      expect((await db.findOperation(opId))?.serverPayload, isNull);
    },
  );
}
