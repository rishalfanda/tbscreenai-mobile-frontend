import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/encrypted_xray_store.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/offline/offline_screening_store.dart';
import 'package:myapp/data/offline/offline_validation_repository.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/clinical_conflict.dart';
import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'package:myapp/domain/models/diagnosis_inference_request.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/screening_result.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/state/diagnosis_provider.dart';

class _Adapter implements HttpClientAdapter {
  String? verdict;
  int responseStatus = 200;
  final sent = <Map<String, dynamic>>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    if (options.path.startsWith('/diagnoses/')) {
      return _json({
        'id': 'diagnosis',
        'status': 'agreed',
        'doctor_note': 'Server note',
        'version': 7,
      });
    }
    if (verdict == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final items = ((options.data as Map)['items'] as List)
        .cast<Map<String, dynamic>>();
    sent.addAll(items);
    return _json({
      'results': [
        for (final item in items)
          {
            'client_op_id': item['client_op_id'],
            'status': verdict,
            'entity_id': item['entity_id'],
          },
      ],
    }, responseStatus);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Inference implements DiagnosisRepository, TypedDiagnosisRepository {
  DiagnosisInferenceRequest? request;
  @override
  Future<List<String>> getSymptomOptions() async => [];
  @override
  Future<DiagnosisOutcome> runInference({required XrayImage image}) async =>
      _outcome();
  @override
  Future<DiagnosisOutcome> runTypedInference(
    DiagnosisInferenceRequest request,
  ) async {
    this.request = request;
    return _outcome();
  }
}

DiagnosisOutcome _outcome({bool mock = false}) => DiagnosisOutcome(
  isPositive: true,
  confidence: 87,
  processingTime: '1s',
  processingTimeMs: 1000,
  modelVersion: 'model-1',
  createdAt: DateTime.utc(2026, 9, 30),
  isMock: mock,
  consolidation: 20,
);

DiagnosisDraft _draft() => DiagnosisDraft(
  patientId: 'patient',
  patientName: 'Synthetic patient',
  gender: 'Female',
  age: 34,
  heightCm: 160,
  weightKg: 55,
  symptoms: {'Cough'},
  modelType: 'CNN',
  image: XrayImage.fromBytes(
    bytes: XrayImage.placeholder().bytes,
    filename: 'synthetic.png',
    source: XrayImageSource.gallery,
  ),
);

void main() {
  late AppDatabase db;
  late ApiClient client;
  late _Adapter adapter;
  late SyncEngine engine;
  late MemorySecureTokenStorage secrets;
  late OfflineValidationRepository validation;
  OfflineScreeningStore store() => OfflineScreeningStore(
    db: db,
    syncEngine: engine,
    xrayStore: EncryptedXrayStore(db: db, secureStorage: secrets),
    deviceId: () async => 'device',
  );
  void bind() {
    engine = SyncEngine(db: db, client: client, settings: SettingsStore(db));
    validation = OfflineValidationRepository(
      db: db,
      client: client,
      syncEngine: engine,
    );
  }

  Future<void> seed() => db.upsertDiagnosis(
    LocalDiagnosesCompanion.insert(
      id: 'diagnosis',
      patientId: 'patient',
      isPositive: true,
      confidence: 87,
      modelVersion: 'model-1',
      diagnosedAt: DateTime.utc(2026),
      serverVersion: const Value(4),
      isMock: const Value(false),
    ),
  );
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    secrets = MemorySecureTokenStorage();
    adapter = _Adapter();
    client = ApiClient(baseUrl: 'http://fixture.invalid/api/v1');
    client.dio.httpClientAdapter = adapter;
    bind();
  });
  tearDown(() async {
    await client.close();
    await db.close();
  });

  test(
    'FE-106 typed inference persists encrypted image and restores after database reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp('screening-');
      addTearDown(() async {
        await db.close();
        db = AppDatabase(NativeDatabase.memory());
        await directory.delete(recursive: true);
      });
      await db.close();
      final file = File('${directory.path}/clinical.sqlite');
      db = AppDatabase(NativeDatabase(file));
      bind();
      final inference = _Inference();
      final provider =
          DiagnosisProvider(
              inference,
              screeningStore: store(),
              deviceId: () async => 'device',
            )
            ..updatePatientName('Synthetic patient')
            ..updateGender('Female')
            ..updateAge(34)
            ..updateHeight(160)
            ..updateWeight(55)
            ..attachImage(_draft().image!);
      provider.selectPatient(
        const Patient(
          id: 'P1',
          serverId: 'patient',
          name: 'Synthetic patient',
          age: 34,
          gender: 'Female',
          status: 'Normal',
          confidence: 0,
          lastVisit: '-',
          history: [],
        ),
      );
      expect(await provider.runDiagnosis(), isTrue);
      final persisted = provider.lastResult!;
      expect(persisted.saveStatus, ScreeningSaveStatus.pendingSync);
      final artifact = await db.findEncryptedArtifact(persisted.id!);
      expect(artifact!.cipherText, isNot(equals(_draft().image!.bytes)));
      expect(
        inference.request!.toJson()['patient'],
        provider.lastResult!.draft.toPatientSnapshot(),
      );
      provider.dispose();
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      bind();
      final restored = await store().restoreLatest();
      expect(
        restored!.draft.toPatientSnapshot(),
        persisted.draft.toPatientSnapshot(),
      );
      expect(
        restored.draft.image!.checksumSha256,
        _draft().image!.checksumSha256,
      );
      expect(restored.outcome.modelVersion, 'model-1');
      expect(await db.countPending(), 1);
      adapter.verdict = 'applied';
      await engine.push();
      await (db.update(
        db.localDiagnoses,
      )..where((row) => row.id.equals(persisted.id!))).write(
        const LocalDiagnosesCompanion(
          imageReference: Value('server/object.png'),
        ),
      );
      expect(
        (await store().restoreLatest())!.draft.image!.checksumSha256,
        persisted.draft.image!.checksumSha256,
      );
    },
  );

  test('FE-106 mock outcome never writes a clinical row or queue', () async {
    await expectLater(
      store().persist(
        ScreeningResult(draft: _draft(), outcome: _outcome(mock: true)),
      ),
      throwsA(isA<ClinicalPersistenceException>()),
    );
    expect(await db.countDiagnoses(), 0);
    expect(await db.countPending(), 0);
  });

  test('FE-106 altered checksum blocks restore', () async {
    final saved = await store().persist(
      ScreeningResult(draft: _draft(), outcome: _outcome()),
    );
    await (db.update(
      db.encryptedXrayArtifacts,
    )..where((row) => row.id.equals(saved.id!))).write(
      const EncryptedXrayArtifactsCompanion(checksum: Value('corrupt')),
    );
    await expectLater(store().restoreLatest(), throwsStateError);
  });

  test('FE-106 save status stream reflects successful sync', () async {
    final saved = await store().persist(
      ScreeningResult(draft: _draft(), outcome: _outcome()),
    );
    final statuses = <ScreeningSaveStatus>[];
    final subscription = store()
        .watchSaveStatus(saved.id!)
        .listen(statuses.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(statuses.last, ScreeningSaveStatus.pendingSync);
    adapter.verdict = 'applied';
    await engine.push();
    await pumpEventQueue();
    expect(statuses.last, ScreeningSaveStatus.saved);
  });

  test(
    'FE-107 disagree offline survives repository remount and retries same operation',
    () async {
      await seed();
      final result = await validation.submitValidation(
        id: 'diagnosis',
        status: 'disagreed',
        note: 'Review required',
      );
      expect(result.state, ValidationSubmissionState.queued);
      final pending = (await db.opsWithStatus(syncRetryable)).single;
      bind();
      expect(
        (await db.findDiagnosis('diagnosis'))!.doctorNote,
        'Review required',
      );
      adapter.verdict = 'applied';
      await engine.push();
      expect(adapter.sent.single['client_op_id'], pending.clientOpId);
      expect(
        (await db.clinicalAuditFor('diagnosis')).single.action,
        'validation_disagreed',
      );
    },
  );

  test(
    'FE-107 disagreement requires a note and rejection is not reported queued',
    () async {
      await seed();
      await expectLater(
        validation.submitValidation(id: 'diagnosis', status: 'disagreed'),
        throwsA(isA<ValidationContractException>()),
      );
      expect(await db.countPending(), 0);
      adapter
        ..verdict = 'applied'
        ..responseStatus = 422;
      await expectLater(
        validation.submitValidation(id: 'diagnosis', status: 'agreed'),
        throwsA(isA<ValidationContractException>()),
      );
      expect((await db.opsWithStatus(syncPermanentFailure)).length, 1);
    },
  );

  for (final decision in ConflictDecision.values) {
    test('FE-109 ${decision.name} is explicit and audited', () async {
      await seed();
      adapter.verdict = 'conflict';
      final result = await validation.submitValidation(
        id: 'diagnosis',
        status: 'disagreed',
        note: 'Local note',
      );
      expect(result.state, ValidationSubmissionState.conflict);
      final conflict = (await validation.getConflicts()).single;
      expect(conflict.localNote, 'Local note');
      expect(conflict.serverNote, 'Server note');
      adapter.verdict = null;
      await validation.resolveConflict(conflict: conflict, decision: decision);
      final row = (await db.findDiagnosis('diagnosis'))!;
      expect(
        (await db.clinicalAuditFor('diagnosis')).last.action,
        'conflict_${decision.name}',
      );
      if (decision == ConflictDecision.keepServer) {
        expect(row.status, 'agreed');
        expect(row.serverVersion, 7);
        expect(row.hasConflict, isFalse);
      } else if (decision == ConflictDecision.reapplyLocal) {
        final queued = (await db.opsWithStatus(syncRetryable)).single;
        expect(queued.baseVersion, 7);
        expect(queued.clientOpId, isNot(conflict.clientOpId));
        expect(row.doctorNote, 'Local note');
      } else {
        expect(row.hasConflict, isTrue);
        expect((await db.opsWithStatus(syncConflict)).length, 1);
      }
    });
  }

  test('FE-108 invalid demographics rejected at typed boundary', () {
    for (final draft in [
      _draft().copyWith(gender: ''),
      _draft().copyWith(heightCm: double.infinity),
    ]) {
      expect(
        () => DiagnosisInferenceRequest.fromDraft(
          draft: draft,
          deviceId: 'device',
        ),
        throwsA(isA<DiagnosisRequestValidationException>()),
      );
    }
  });

  test(
    'FE-108 metadata matches versioned fixture with image checksum and units',
    () {
      final expected =
          jsonDecode(
                File(
                  'test/fixtures/inference_metadata_v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final request = DiagnosisInferenceRequest.fromDraft(
        draft: _draft(),
        deviceId: 'device',
      );
      final payload = request.toJson();
      final clinical = Map<String, dynamic>.from(payload['clinical'] as Map);
      final image = clinical.remove('image') as Map;
      expect({...payload, 'clinical': clinical}, expected);
      expect(image['checksum_sha256'], request.image.checksumSha256);
      expect(image['mime_type'], 'image/png');
      expect(image['size_bytes'], request.image.sizeBytes);
    },
  );

  test(
    'FE-108 reset during device registration cannot start stale inference',
    () async {
      final device = Completer<String>();
      final inference = _Inference();
      final provider =
          DiagnosisProvider(inference, deviceId: () => device.future)
            ..updatePatientName('Synthetic')
            ..updateGender('Female')
            ..updateAge(34)
            ..updateHeight(160)
            ..updateWeight(55)
            ..attachImage(_draft().image!);
      final running = provider.runDiagnosis();
      expect(provider.isRunning, isTrue);
      provider.resetForNewDiagnosis();
      device.complete('device');
      expect(await running, isFalse);
      expect(inference.request, isNull);
      provider.dispose();
    },
  );
}
