import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:myapp/core/utils/uuid.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/encrypted_xray_store.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/screening_result.dart';
import 'package:myapp/domain/repositories/screening_store.dart';

class ClinicalPersistenceException implements Exception {
  const ClinicalPersistenceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineScreeningStore implements ScreeningStore {
  OfflineScreeningStore({
    required AppDatabase db,
    required SyncEngine syncEngine,
    required EncryptedXrayStore xrayStore,
    required Future<String> Function() deviceId,
  }) : _db = db,
       _syncEngine = syncEngine,
       _xrayStore = xrayStore,
       _deviceId = deviceId;

  final AppDatabase _db;
  final SyncEngine _syncEngine;
  final EncryptedXrayStore _xrayStore;
  final Future<String> Function() _deviceId;

  @override
  Future<ScreeningResult> persist(ScreeningResult result) async {
    if (result.outcome.isMock) {
      throw const ClinicalPersistenceException(
        'Demo inference cannot be saved as a clinical diagnosis.',
      );
    }
    final patientId = result.draft.patientId;
    if (patientId == null || patientId.trim().isEmpty) {
      throw const ClinicalPersistenceException(
        'Pilih pasien dari menu Patient sebelum menyimpan screening.',
      );
    }
    final image = result.draft.image;
    if (image == null || image.isEmpty) {
      throw const ClinicalPersistenceException(
        'The analyzed X-ray is unavailable.',
      );
    }

    final diagnosisId = result.id ?? uuidV4();
    final deviceId = await _deviceId();
    final patientSnapshot = result.draft.toPatientSnapshot();
    final clinicalSnapshot = result.draft.toClinicalSnapshot(
      deviceId: deviceId,
    );
    if (result.outcome.imageId != null) {
      clinicalSnapshot['inference_image_id'] = result.outcome.imageId;
    }
    late final String imageReference;
    await _db.transaction(() async {
      imageReference = await _xrayStore.persist(
        artifactId: diagnosisId,
        image: image,
      );
      final outcome = result.outcome;
      await _db.upsertDiagnosis(
        LocalDiagnosesCompanion.insert(
          id: diagnosisId,
          patientId: patientId,
          isPositive: outcome.isPositive,
          confidence: outcome.confidence,
          modelVersion: outcome.modelVersion,
          processingTimeMs: Value(outcome.processingTimeMs),
          findings: Value(jsonEncode(outcome.findings)),
          diagnosedAt: outcome.createdAt.toUtc(),
          imageChecksum: Value(image.checksumSha256),
          imageReference: Value(imageReference),
          provenance: Value(
            jsonEncode(
              outcome.provenance ??
                  {
                    'contract_version': 1,
                    'model_version': outcome.modelVersion,
                    'is_mock': false,
                    'inferred_at': outcome.createdAt.toUtc().toIso8601String(),
                    'device_id': deviceId,
                    'image_checksum': image.checksumSha256,
                  },
            ),
          ),
          isMock: const Value(false),
          patientSnapshot: Value(jsonEncode(patientSnapshot)),
          clinicalSnapshot: Value(jsonEncode(clinicalSnapshot)),
          saveStatus: const Value('pending_sync'),
        ),
      );
      await _syncEngine.enqueueDiagnosisCreate(
        diagnosisId,
        _createPayload(
          patientId: patientId,
          outcome: outcome,
          draft: result.draft,
        ),
      );
    });

    return result.copyWith(
      id: diagnosisId,
      imageReference: imageReference,
      saveStatus: ScreeningSaveStatus.pendingSync,
      persistenceError: null,
    );
  }

  Map<String, dynamic> _createPayload({
    required String patientId,
    required DiagnosisOutcome outcome,
    required DiagnosisDraft draft,
  }) => {
    'patient_id': patientId,
    'clinical': {
      'schema_version': 1,
      if (draft.heightCm != null) 'height_cm': draft.heightCm,
      if (draft.weightKg != null) 'weight_kg': draft.weightKg,
      'symptoms': draft.symptoms.toList()..sort(),
      if (draft.comorbidity != null) 'comorbidity': draft.comorbidity,
      if (draft.smoking != null) 'smoking': draft.smoking,
      if (draft.tbContact != null) 'tb_contact': draft.tbContact,
      if (draft.pediatricScore != null) 'pediatric_score': draft.pediatricScore,
      if (draft.windowsPresence != null)
        'windows_presence': draft.windowsPresence,
      if (draft.sunlightExposure != null)
        'sunlight_exposure': draft.sunlightExposure,
      if (draft.bta != null) 'bta': draft.bta,
      if (draft.culture != null) 'culture': draft.culture,
      if (draft.xpert != null) 'xpert': draft.xpert,
      if (draft.igra != null) 'igra': draft.igra,
      if (draft.tbHistory != null) 'tb_history': draft.tbHistory,
      if (draft.tbStatus != null) 'tb_status': draft.tbStatus,
    },
    'is_positive': outcome.isPositive,
    'confidence': outcome.confidence,
    'model_version': outcome.modelVersion,
    if (outcome.processingTimeMs != null)
      'processing_time_ms': outcome.processingTimeMs,
    'findings': outcome.findings,
    if (outcome.imageId != null) 'image_id': outcome.imageId,
    if (outcome.provenance != null) 'provenance': outcome.provenance,
    'diagnosed_at': outcome.createdAt.toUtc().toIso8601String(),
  };

  @override
  Future<ScreeningResult?> restoreLatest() async {
    final row = await _db.latestDurableDiagnosis();
    if (row == null || row.imageReference == null) return null;
    final localArtifact = await _db.findEncryptedArtifact(row.id);
    final imageReference = localArtifact == null
        ? row.imageReference!
        : 'local-encrypted://${row.id}';
    final image = await _xrayStore.read(imageReference);
    if (row.imageChecksum != image.checksumSha256) {
      throw StateError('Diagnosis and X-ray checksum do not match.');
    }
    final patient = _decodeMap(row.patientSnapshot, 'patient snapshot');
    final clinical = _decodeMap(row.clinicalSnapshot, 'clinical snapshot');
    final draft = DiagnosisDraft.fromSnapshots(
      patient: patient,
      clinical: clinical,
      image: image,
    );
    final findings = _decodeMap(row.findings, 'findings');
    final storedProvenance = _decodeMap(row.provenance, 'provenance');
    final outcome = DiagnosisOutcome(
      isPositive: row.isPositive,
      confidence: row.confidence,
      processingTime: row.processingTimeMs == null
          ? 'Not available'
          : '${(row.processingTimeMs! / 1000).toStringAsFixed(1)}s',
      processingTimeMs: row.processingTimeMs,
      modelVersion: row.modelVersion,
      createdAt: row.diagnosedAt,
      isMock: row.isMock,
      consolidation: _number(findings['consolidation']),
      cavity: _number(findings['cavity']),
      effusion: _number(findings['effusion']),
      fibrotic: _number(findings['fibrotic']),
      calcification: _number(findings['calcification']),
      infiltrate: _number(findings['infiltrate']),
      imageId: clinical['inference_image_id'] as String?,
      provenance: storedProvenance,
    );
    return ScreeningResult(
      draft: draft,
      outcome: outcome,
      id: row.id,
      imageReference: imageReference,
      saveStatus: _saveStatus(row.saveStatus),
    );
  }

  @override
  Stream<ScreeningSaveStatus> watchSaveStatus(String id) =>
      _db.watchDiagnoses().map((rows) {
        final matching = rows.where((row) => row.id == id);
        return matching.isEmpty
            ? ScreeningSaveStatus.unsaved
            : _saveStatus(matching.first.saveStatus);
      }).distinct();

  Map<String, dynamic> _decodeMap(String raw, String label) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('Stored $label is invalid.');
    }
    return decoded.cast<String, dynamic>();
  }

  double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

  ScreeningSaveStatus _saveStatus(String value) => switch (value) {
    'pending_sync' => ScreeningSaveStatus.pendingSync,
    'saved' => ScreeningSaveStatus.saved,
    'conflict' => ScreeningSaveStatus.conflict,
    'failed' => ScreeningSaveStatus.failed,
    _ => ScreeningSaveStatus.unsaved,
  };
}
