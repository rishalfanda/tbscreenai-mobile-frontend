import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:myapp/core/utils/uuid.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/clinical_conflict.dart';
import 'package:myapp/domain/models/validation_case.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';

class ValidationContractException implements Exception {
  const ValidationContractException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owner-scoped doctor validation backed by Drift and the idempotent sync
/// protocol. Every verdict is committed locally before network I/O begins.
class OfflineValidationRepository extends ValidationRepository {
  OfflineValidationRepository({
    required AppDatabase db,
    required ApiClient client,
    required SyncEngine syncEngine,
  }) : _db = db,
       _client = client,
       _syncEngine = syncEngine;

  final AppDatabase _db;
  final ApiClient _client;
  final SyncEngine _syncEngine;
  Future<void>? _refreshInFlight;

  @override
  Stream<int> watchPendingCount() => _db.watchDiagnoses().map(
    (rows) =>
        rows.where((row) => row.status == 'pending' && !row.isMock).length,
  );

  @override
  Future<List<ValidationCase>> getCases() async {
    var rows = await _db.allDiagnoses();
    if (rows.isEmpty) {
      try {
        await _refresh();
        rows = await _db.allDiagnoses();
      } catch (_) {
        // An empty offline state is honest; seeded mock cases are never used
        // in HTTP mode.
      }
    } else {
      unawaited(_refresh().catchError((_) {}));
    }

    final patients = {
      for (final patient in await _db.allPatients()) patient.id: patient,
    };
    return rows
        .map((row) {
          final patient = _map(row.patientSnapshot);
          final cachedPatient = patients[row.patientId];
          final name =
              patient['patient_name'] as String? ??
              cachedPatient?.name ??
              'Patient';
          final age =
              (patient['age'] as num?)?.toInt() ?? cachedPatient?.age ?? 0;
          final gender =
              patient['gender'] as String? ??
              cachedPatient?.gender ??
              'Not provided';
          final findings = _map(row.findings);
          return ValidationCase(
            id: row.id,
            patientId: row.patientId,
            name: name,
            initials: _initials(name),
            age: age,
            gender: gender,
            aiScore: row.confidence,
            diagnosisDate: row.diagnosedAt
                .toLocal()
                .toString()
                .split(' ')
                .first,
            status: row.status,
            doctorNote: row.doctorNote,
            xrayUrl: row.imageReference,
            findings: ValidationFindings(
              consolidation: _number(findings['consolidation']),
              cavity: _number(findings['cavity']),
              effusion: _number(findings['effusion']),
              fibrotic: _number(findings['fibrotic']),
              calcification: _number(findings['calcification']),
            ),
            serverVersion: row.serverVersion,
            hasConflict: row.hasConflict,
            syncState: row.saveStatus,
            isMock: row.isMock,
          );
        })
        .toList(growable: false);
  }

  Future<void> _refresh() {
    final running = _refreshInFlight;
    if (running != null) return running;
    final future = _syncEngine.pull();
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
  }

  @override
  Future<ValidationSubmission> submitValidation({
    required String id,
    required String status,
    String? note,
  }) async {
    final normalizedNote = note?.trim();
    final session = _db.sessionGeneration;
    _validate(status, normalizedNote);
    final row = await _db.findDiagnosis(id);
    if (row == null) {
      throw const ValidationContractException('Diagnosis is unavailable.');
    }
    if (row.isMock || row.hasConflict) {
      throw const ValidationContractException(
        'Demo or conflicted diagnoses cannot receive a new clinical verdict.',
      );
    }
    if (row.serverVersion == null || row.serverVersion! < 1) {
      throw const ValidationContractException(
        'Sync this diagnosis before reviewing its server version.',
      );
    }

    late final String opId;
    await _db.transaction(() async {
      if (session != _db.sessionGeneration) {
        throw const ValidationContractException(
          'The session changed. Sign in again before reviewing.',
        );
      }
      await _db.updateDiagnosisValidation(
        id,
        status: status,
        doctorNote: normalizedNote?.isEmpty == true ? null : normalizedNote,
      );
      opId = await _syncEngine.enqueueDiagnosisStatus(
        id,
        status: status,
        doctorNote: normalizedNote?.isEmpty == true ? null : normalizedNote,
        baseVersion: row.serverVersion,
        baseUpdatedAt: row.updatedAt,
      );
      await _db.appendClinicalAudit(
        ClinicalAuditEventsCompanion.insert(
          id: uuidV4(),
          entityType: 'diagnosis',
          entityId: id,
          action: 'validation_$status',
          details: Value(
            jsonEncode({
              'client_op_id': opId,
              'base_version': row.serverVersion,
            }),
          ),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    });

    await _syncEngine.push();
    final operation = await _db.findOperation(opId);
    if (operation?.status == syncPermanentFailure) {
      throw const ValidationContractException(
        'The server rejected this verdict. It remains local and needs correction.',
      );
    }
    return ValidationSubmission(switch (operation?.status) {
      syncSynced => ValidationSubmissionState.synced,
      syncConflict => ValidationSubmissionState.conflict,
      _ => ValidationSubmissionState.queued,
    });
  }

  void _validate(String status, String? note) {
    if (!const {'pending', 'agreed', 'disagreed'}.contains(status)) {
      throw const ValidationContractException('Validation status is invalid.');
    }
    if ((note?.length ?? 0) > 500) {
      throw const ValidationContractException(
        'Clinical note must be 500 characters or fewer.',
      );
    }
    if (status == 'disagreed' && (note == null || note.isEmpty)) {
      throw const ValidationContractException(
        'A clinical note is required when disagreeing.',
      );
    }
  }

  @override
  Future<List<ClinicalConflict>> getConflicts() async {
    final operations = (await _db.opsWithStatus(syncConflict))
        .where((op) => op.entityType == 'diagnosis' && op.operation == 'update')
        .toList(growable: false);
    return Future.wait(operations.map(_conflictFromOperation));
  }

  Future<ClinicalConflict> _conflictFromOperation(SyncQueueData op) async {
    final local = _map(op.payload);
    final server = await _serverPayload(op);
    return ClinicalConflict(
      clientOpId: op.clientOpId,
      diagnosisId: op.entityId,
      localStatus: local['status'] as String? ?? 'pending',
      localNote: local['doctor_note'] as String?,
      baseVersion: op.baseVersion,
      detail: op.detail,
      serverStatus: server?['status'] as String?,
      serverNote: server?['doctor_note'] as String?,
      serverVersion: (server?['version'] as num?)?.toInt(),
    );
  }

  Future<Map<String, dynamic>?> _serverPayload(SyncQueueData op) async {
    try {
      final payload = op.serverPayload == null
          ? (await _client.dio.get<Map<String, dynamic>>(
              '/diagnoses/${op.entityId}',
            )).data
          : _map(op.serverPayload!);
      if (payload == null ||
          payload['id'] != op.entityId ||
          !const {
            'pending',
            'agreed',
            'disagreed',
          }.contains(payload['status']) ||
          payload['version'] is! int ||
          (payload['version'] as int) < 1) {
        throw const FormatException('Conflict response is incomplete.');
      }
      await _db.saveConflictServerPayload(op.clientOpId, jsonEncode(payload));
      return payload;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> resolveConflict({
    required ClinicalConflict conflict,
    required ConflictDecision decision,
  }) async {
    final session = _db.sessionGeneration;
    final operation = await _db.findOperation(conflict.clientOpId);
    if (operation == null || operation.status != syncConflict) {
      throw const ValidationContractException(
        'This conflict is no longer active.',
      );
    }
    final server = await _serverPayload(operation);
    if (decision != ConflictDecision.cancel && server == null) {
      throw const ValidationContractException(
        'Server snapshot is unavailable. Reconnect before resolving.',
      );
    }

    final local = _map(operation.payload);
    final serverStatus = server?['status'] as String?;
    final serverNote = server?['doctor_note'] as String?;
    final serverVersion = (server?['version'] as num?)?.toInt();
    final updatedAt = DateTime.tryParse(server?['updated_at'] as String? ?? '');

    await _db.transaction(() async {
      if (session != _db.sessionGeneration) {
        throw const ValidationContractException(
          'The session changed. Reopen the conflict after signing in.',
        );
      }
      switch (decision) {
        case ConflictDecision.keepServer:
          if (serverStatus == null || serverVersion == null) {
            throw const ValidationContractException(
              'Server snapshot is incomplete.',
            );
          }
          await _db.updateDiagnosisValidation(
            operation.entityId,
            status: serverStatus,
            doctorNote: serverNote,
            serverVersion: serverVersion,
            updatedAt: updatedAt,
            hasConflict: false,
          );
          await _db.markOp(
            operation.clientOpId,
            syncSynced,
            detail: 'Resolved explicitly: kept server value',
          );
        case ConflictDecision.reapplyLocal:
          if (serverVersion == null) {
            throw const ValidationContractException(
              'Server version is unavailable.',
            );
          }
          final localStatus = local['status'] as String?;
          if (localStatus == null) {
            throw const ValidationContractException(
              'Local conflict payload is incomplete.',
            );
          }
          final localNote = local['doctor_note'] as String?;
          await _db.updateDiagnosisValidation(
            operation.entityId,
            status: localStatus,
            doctorNote: localNote,
            serverVersion: serverVersion,
            updatedAt: updatedAt,
            hasConflict: false,
          );
          await _db.markOp(
            operation.clientOpId,
            syncSynced,
            detail: 'Resolved explicitly: local value re-queued',
          );
          await _syncEngine.enqueueDiagnosisStatus(
            operation.entityId,
            status: localStatus,
            doctorNote: localNote,
            baseVersion: serverVersion,
            baseUpdatedAt: updatedAt,
          );
        case ConflictDecision.cancel:
          // Deliberately retain the conflict and both snapshots.
          break;
      }
      await _db.appendClinicalAudit(
        ClinicalAuditEventsCompanion.insert(
          id: uuidV4(),
          entityType: 'diagnosis',
          entityId: operation.entityId,
          action: 'conflict_${decision.name}',
          details: Value(
            jsonEncode({
              'client_op_id': operation.clientOpId,
              'base_version': operation.baseVersion,
              'server_version': serverVersion,
              'local_status': local['status'],
              'server_status': serverStatus,
            }),
          ),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    });

    if (decision == ConflictDecision.reapplyLocal) {
      await _syncEngine.push();
    }
  }

  Map<String, dynamic> _map(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? decoded.cast<String, dynamic>()
          : const <String, dynamic>{};
    } on FormatException {
      return const <String, dynamic>{};
    }
  }

  double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final initials = words.take(2).map((word) => word[0].toUpperCase()).join();
    return initials.isEmpty ? '?' : initials;
  }
}
