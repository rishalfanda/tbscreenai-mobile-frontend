import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import 'package:myapp/core/utils/uuid.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/mappers.dart';
import 'package:myapp/data/local/settings_store.dart';

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

  SyncReport add(SyncReport other) => SyncReport(
    applied: applied + other.applied,
    skipped: skipped + other.skipped,
    conflicts: conflicts + other.conflicts,
    failed: failed + other.failed,
  );
}

/// Offline queue protocol with idempotent replay and optimistic locking.
class SyncEngine {
  SyncEngine({
    required AppDatabase db,
    required ApiClient client,
    required SettingsStore settings,
    DateTime Function()? now,
    double Function()? jitter,
    int batchSize = 500,
  }) : assert(batchSize > 0 && batchSize <= 500),
       _db = db,
       _client = client,
       _settings = settings,
       _now = now ?? DateTime.now,
       _jitter = jitter ?? Random().nextDouble,
       _batchSize = batchSize;

  final AppDatabase _db;
  final ApiClient _client;
  final SettingsStore _settings;
  final DateTime Function() _now;
  final double Function() _jitter;
  final int _batchSize;

  Future<SyncReport>? _pushInFlight;

  Future<String> enqueuePatientCreate(Map<String, dynamic> payload) async {
    final entityId = uuidV4();
    await _db.enqueue(
      SyncQueueCompanion.insert(
        clientOpId: uuidV4(),
        entityType: 'patient',
        entityId: entityId,
        operation: 'create',
        payload: jsonEncode(payload),
        createdAt: _now().toUtc(),
      ),
    );
    return entityId;
  }

  Future<void> enqueuePatientUpdate(
    String entityId,
    Map<String, dynamic> payload, {
    int? baseVersion,
    DateTime? baseUpdatedAt,
  }) async {
    final cached = baseVersion == null ? await _db.findPatient(entityId) : null;
    await _db.enqueue(
      SyncQueueCompanion.insert(
        clientOpId: uuidV4(),
        entityType: 'patient',
        entityId: entityId,
        operation: 'update',
        payload: jsonEncode(payload),
        baseVersion: Value(baseVersion ?? cached?.serverVersion),
        baseUpdatedAt: Value(baseUpdatedAt ?? cached?.updatedAt),
        createdAt: _now().toUtc(),
      ),
    );
  }

  Future<void> enqueueDiagnosisStatus(
    String entityId, {
    required String status,
    String? doctorNote,
    int? baseVersion,
    DateTime? baseUpdatedAt,
  }) async {
    final cached = baseVersion == null
        ? await _db.findDiagnosis(entityId)
        : null;
    await _db.enqueue(
      SyncQueueCompanion.insert(
        clientOpId: uuidV4(),
        entityType: 'diagnosis',
        entityId: entityId,
        operation: 'update',
        payload: jsonEncode({'status': status, 'doctor_note': doctorNote}),
        baseVersion: Value(baseVersion ?? cached?.serverVersion),
        baseUpdatedAt: Value(baseUpdatedAt ?? cached?.updatedAt),
        createdAt: _now().toUtc(),
      ),
    );
  }

  Future<int> pendingCount() => _db.countPending();

  /// Manual pushes may bypass the scheduled delay; background pushes honor it.
  /// Both paths retain the original client_op_id.
  Future<SyncReport> push({bool manual = true}) {
    final running = _pushInFlight;
    if (running != null) return running;
    final future = _push(manual: manual);
    _pushInFlight = future;
    return future.whenComplete(() {
      if (identical(_pushInFlight, future)) _pushInFlight = null;
    });
  }

  Future<SyncReport> _push({required bool manual}) async {
    final session = _db.sessionGeneration;
    final pending = await _db.opsReadyForPush(
      manual: manual,
      now: _now().toUtc(),
    );
    if (session != _db.sessionGeneration || pending.isEmpty) {
      return const SyncReport.empty();
    }

    var report = const SyncReport.empty();
    for (var offset = 0; offset < pending.length; offset += _batchSize) {
      if (session != _db.sessionGeneration) return report;
      final end = min(offset + _batchSize, pending.length);
      final chunk = pending.sublist(offset, end);
      report = report.add(await _pushChunk(session, chunk));
    }

    return report;
  }

  Future<SyncReport> _pushChunk(int session, List<SyncQueueData> chunk) async {
    for (final op in chunk) {
      await _db.writeForSession(
        session,
        () => _db.markOpSending(op.clientOpId),
      );
    }
    if (session != _db.sessionGeneration) return const SyncReport.empty();

    final items = chunk.map(_pushItem).toList();
    final deviceId =
        chunk.first.deviceId ?? await _settings.readOrCreateDeviceId();
    late final Response<Map<String, dynamic>> response;
    try {
      response = await _client.dio.post<Map<String, dynamic>>(
        '/sync/push',
        data: {'device_id': deviceId, 'items': items},
      );
    } on DioException catch (error) {
      if (_isTransient(error)) {
        await _markRetryable(session, chunk, _describe(error));
      } else {
        await _markPermanent(session, chunk, _describe(error));
      }
      return SyncReport(
        applied: 0,
        skipped: 0,
        conflicts: 0,
        failed: chunk.length,
      );
    }

    final validation = _validateResults(response.data?['results'], chunk);
    if (validation.error != null) {
      await _markRetryable(session, chunk, validation.error!);
      return SyncReport(
        applied: 0,
        skipped: 0,
        conflicts: 0,
        failed: chunk.length,
      );
    }

    var applied = 0;
    var skipped = 0;
    var conflicts = 0;
    var failed = 0;
    final byId = {for (final op in chunk) op.clientOpId: op};
    for (final result in validation.results) {
      if (session != _db.sessionGeneration) return const SyncReport.empty();
      final opId = result['client_op_id'] as String;
      final status = result['status'] as String;
      final detail = result['detail'] as String?;
      final op = byId[opId]!;
      await _db.writeForSession(session, () async {
        switch (status) {
          case 'applied':
            applied++;
            await _db.markOp(opId, syncSynced);
          case 'skipped':
            skipped++;
            await _db.markOp(opId, syncSynced, detail: detail);
          case 'conflict':
            conflicts++;
            await _db.markOp(opId, syncConflict, detail: detail);
            if (op.entityType == 'patient') {
              await _db.markPatientConflict(op.entityId, true);
            } else if (op.entityType == 'diagnosis') {
              await _db.markDiagnosisConflict(op.entityId, true);
            }
        }
      });
    }
    return SyncReport(
      applied: applied,
      skipped: skipped,
      conflicts: conflicts,
      failed: failed,
    );
  }

  Map<String, dynamic> _pushItem(SyncQueueData op) => {
    'client_op_id': op.clientOpId,
    'entity_type': op.entityType,
    'operation': op.operation,
    'entity_id': op.entityId,
    if (op.baseVersion != null) 'base_version': op.baseVersion,
    if (op.baseUpdatedAt != null)
      'base_updated_at': op.baseUpdatedAt!.toUtc().toIso8601String(),
    'payload': jsonDecode(op.payload),
  };

  _ResultValidation _validateResults(Object? raw, List<SyncQueueData> chunk) {
    if (raw is! List) {
      return const _ResultValidation.error(
        'Protocol error: results is missing',
      );
    }
    final expected = {for (final op in chunk) op.clientOpId: op};
    final seen = <String>{};
    final results = <Map<String, dynamic>>[];
    const allowed = {'applied', 'skipped', 'conflict'};
    for (final item in raw) {
      if (item is! Map) {
        return const _ResultValidation.error(
          'Protocol error: malformed result item',
        );
      }
      late final Map<String, dynamic> result;
      try {
        result = Map<String, dynamic>.from(item);
      } on TypeError {
        return const _ResultValidation.error(
          'Protocol error: malformed result item',
        );
      }
      final id = result['client_op_id'];
      final status = result['status'];
      final detail = result['detail'];
      if (id is! String || !expected.containsKey(id)) {
        return const _ResultValidation.error(
          'Protocol error: unknown client_op_id',
        );
      }
      if (!seen.add(id)) {
        return const _ResultValidation.error(
          'Protocol error: duplicate client_op_id',
        );
      }
      if (status is! String || !allowed.contains(status)) {
        return const _ResultValidation.error(
          'Protocol error: unknown result status',
        );
      }
      if (detail != null && detail is! String) {
        return const _ResultValidation.error(
          'Protocol error: malformed result detail',
        );
      }
      final entityId = result['entity_id'];
      if (entityId != null &&
          (entityId is! String || entityId != expected[id]!.entityId)) {
        return const _ResultValidation.error(
          'Protocol error: mismatched entity_id',
        );
      }
      results.add(result);
    }
    if (seen.length != expected.length) {
      return const _ResultValidation.error(
        'Protocol error: incomplete push response',
      );
    }
    return _ResultValidation(results);
  }

  Future<void> _markRetryable(
    int session,
    List<SyncQueueData> ops,
    String detail,
  ) async {
    for (final op in ops) {
      final next = _now().toUtc().add(_backoff(op.retryCount));
      await _db.writeForSession(
        session,
        () => _db.markOpRetryable(op, nextAttemptAt: next, detail: detail),
      );
    }
  }

  Future<void> _markPermanent(
    int session,
    List<SyncQueueData> ops,
    String detail,
  ) async {
    for (final op in ops) {
      await _db.writeForSession(
        session,
        () => _db.markOp(op.clientOpId, syncPermanentFailure, detail: detail),
      );
    }
  }

  Duration _backoff(int retryCount) {
    final exponentialSeconds = min(300, 2 * (1 << min(retryCount, 7)));
    final factor = 0.75 + (_jitter().clamp(0.0, 1.0) * 0.5);
    return Duration(milliseconds: (exponentialSeconds * factor * 1000).round());
  }

  bool _isTransient(DioException error) {
    if ({
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    }.contains(error.type)) {
      return true;
    }
    final status = error.response?.statusCode;
    return status == 408 || status == 429 || (status != null && status >= 500);
  }

  /// Normal application sync always pushes, then pulls the authoritative
  /// delta. Low-level tests may exercise [push] independently.
  Future<SyncReport> sync({bool manual = true}) async {
    final report = await push(manual: manual);
    await pull();
    return report;
  }

  Future<void> pull() async {
    final session = _db.sessionGeneration;
    final since = await _settings.readLastSyncAt();
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/sync/pull',
      queryParameters: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
    );
    final data = response.data;
    if (data == null) {
      throw const FormatException('Sync pull response is empty');
    }
    final rawPatients = data['patients'];
    final rawDiagnoses = data['diagnoses'];
    if (rawPatients is! List || rawDiagnoses is! List) {
      throw const FormatException('Sync pull response is incomplete');
    }
    final serverTime = DateTime.tryParse(data['server_time'] as String? ?? '');
    if (serverTime == null) {
      throw const FormatException('Sync pull server_time is invalid');
    }
    final patients = rawPatients
        .map((row) => patientRowFromJson((row as Map).cast<String, dynamic>()))
        .toList();
    final diagnoses = rawDiagnoses
        .map(
          (row) => diagnosisRowFromJson((row as Map).cast<String, dynamic>()),
        )
        .toList();
    await _db.writeForSession(session, () async {
      if (since == null) {
        await _db.replacePatientCache(patients);
        await _db.replaceDiagnosisCache(diagnoses);
      } else {
        await _db.mergePatientChanges(patients);
        await _db.mergeDiagnosisChanges(diagnoses);
      }
      await _settings.saveLastSyncAt(serverTime);
    });
  }

  String _describe(DioException error) {
    if (_isTransient(error)) return 'Koneksi sementara gagal; akan dicoba lagi';
    return 'Ditolak server: ${error.response?.statusCode ?? error.type.name}';
  }
}

class _ResultValidation {
  const _ResultValidation(this.results) : error = null;
  const _ResultValidation.error(this.error) : results = const [];

  final List<Map<String, dynamic>> results;
  final String? error;
}
