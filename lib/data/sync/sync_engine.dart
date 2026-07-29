import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import 'package:myapp/core/utils/uuid.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/mappers.dart';
import 'package:myapp/data/local/settings_store.dart';

/// Outcome of one queue flush, reported to the Sync Center UI.
class SyncReport {
  const SyncReport({
    required this.applied,
    required this.skipped,
    required this.conflicts,
    required this.failed,
  });

  const SyncReport.empty()
      : applied = 0,
        skipped = 0,
        conflicts = 0,
        failed = 0;

  final int applied;
  final int skipped;
  final int conflicts;
  final int failed;

  int get total => applied + skipped + conflicts + failed;
  bool get hasProblems => conflicts > 0 || failed > 0;
}

/// Drives the offline-first write path.
///
/// Every local mutation is written to [SyncQueue] first, then pushed later.
/// Two guarantees, both mirrored by the backend:
/// - **Idempotent**: each op carries a client-generated `client_op_id`, so a
///   retried request is answered `skipped` instead of applied twice.
/// - **No silent overwrite**: an op whose base version is stale comes back
///   `conflict`; the row is flagged for manual doctor review, never merged
///   automatically. Medical data is not safe to auto-resolve.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required ApiClient client,
    required SettingsStore settings,
  })  : _db = db,
        _client = client,
        _settings = settings;

  final AppDatabase _db;
  final ApiClient _client;
  final SettingsStore _settings;

  // === Section: Enqueue (local writes) ===

  /// Queues a patient create. Returns the client-generated row id so the
  /// caller can reference the record before the server has ever seen it.
  Future<String> enqueuePatientCreate(Map<String, dynamic> payload) async {
    final entityId = uuidV4();
    await _db.enqueue(SyncQueueCompanion.insert(
      clientOpId: uuidV4(),
      entityType: 'patient',
      entityId: entityId,
      operation: 'create',
      payload: jsonEncode(payload),
      createdAt: DateTime.now(),
    ));
    return entityId;
  }

  /// Queues a patient update. [baseUpdatedAt] is the server version the edit
  /// was made against — the server compares it to detect conflicts.
  Future<void> enqueuePatientUpdate(
    String entityId,
    Map<String, dynamic> payload, {
    DateTime? baseUpdatedAt,
  }) {
    return _db.enqueue(SyncQueueCompanion.insert(
      clientOpId: uuidV4(),
      entityType: 'patient',
      entityId: entityId,
      operation: 'update',
      payload: jsonEncode(payload),
      baseUpdatedAt: Value(baseUpdatedAt),
      createdAt: DateTime.now(),
    ));
  }

  Future<void> enqueueDiagnosisStatus(
    String entityId, {
    required String status,
    String? doctorNote,
    DateTime? baseUpdatedAt,
  }) {
    return _db.enqueue(SyncQueueCompanion.insert(
      clientOpId: uuidV4(),
      entityType: 'diagnosis',
      entityId: entityId,
      operation: 'update',
      payload: jsonEncode({'status': status, 'doctor_note': doctorNote}),
      baseUpdatedAt: Value(baseUpdatedAt),
      createdAt: DateTime.now(),
    ));
  }

  Future<int> pendingCount() => _db.countPending();

  // === Section: Push ===

  /// Sends every pending op in one request and records the per-op verdict.
  ///
  /// Ops are NOT deleted after success — they stay as `synced` history. A
  /// failed request leaves them `pending`, so the next flush retries them;
  /// that retry is safe precisely because of the op id.
  Future<SyncReport> push() async {
    final pending = await _db.pendingOps();
    if (pending.isEmpty) return const SyncReport.empty();

    final items = pending
        .map((op) => {
              'client_op_id': op.clientOpId,
              'entity_type': op.entityType,
              'operation': op.operation,
              'entity_id': op.entityId,
              if (op.baseUpdatedAt != null)
                'base_updated_at': op.baseUpdatedAt!.toUtc().toIso8601String(),
              'payload': jsonDecode(op.payload),
            })
        .toList();

    late final Response<Map<String, dynamic>> response;
    try {
      response = await _client.dio.post<Map<String, dynamic>>(
        '/sync/push',
        data: {'device_id': 'tablet', 'items': items},
      );
    } on DioException catch (e) {
      // Network/server failure: leave everything pending for the next attempt.
      for (final op in pending) {
        await _db.markOp(op.clientOpId, syncFailed, detail: _describe(e));
      }
      return SyncReport(applied: 0, skipped: 0, conflicts: 0, failed: pending.length);
    }

    var applied = 0, skipped = 0, conflicts = 0, failed = 0;
    final results = (response.data?['results'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    for (final result in results) {
      final opId = result['client_op_id'] as String;
      final status = result['status'] as String;
      final detail = result['detail'] as String?;
      final op = pending.firstWhere((o) => o.clientOpId == opId);

      switch (status) {
        case 'applied':
          applied++;
          await _db.markOp(opId, syncSynced);
        case 'skipped':
          // Server had seen this op id before — a retry, already applied.
          skipped++;
          await _db.markOp(opId, syncSynced, detail: detail);
        case 'conflict':
          conflicts++;
          await _db.markOp(opId, syncConflict, detail: detail);
          if (op.entityType == 'patient') {
            await _db.markPatientConflict(op.entityId, true);
          }
        default:
          failed++;
          await _db.markOp(opId, syncFailed, detail: detail);
      }
    }

    if (applied + skipped > 0) {
      await _settings.saveLastSyncAt(DateTime.now());
    }
    return SyncReport(
      applied: applied,
      skipped: skipped,
      conflicts: conflicts,
      failed: failed,
    );
  }

  // === Section: Pull ===

  /// Refreshes the local cache from the server. Rows still waiting in the
  /// queue are preserved — see [AppDatabase.replacePatientCache].
  Future<void> pull() async {
    final response = await _client.dio.get<Map<String, dynamic>>('/sync/pull');
    final data = response.data;
    if (data == null) return;

    final patients = (data['patients'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(patientRowFromJson)
        .toList();
    final diagnoses = (data['diagnoses'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(diagnosisRowFromJson)
        .toList();

    await _db.replacePatientCache(patients);
    await _db.replaceDiagnosisCache(diagnoses);
    await _settings.saveLastSyncAt(DateTime.now());
  }

  String _describe(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Tidak ada koneksi ke server';
    }
    return 'Gagal: ${e.response?.statusCode ?? e.type.name}';
  }
}
