import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:myapp/core/utils/uuid.dart';
import 'package:myapp/data/local/tables.dart';

part 'app_database.g.dart';

// === Section: Sync queue state machine ===
const String syncPending = 'pending';
const String syncSending = 'sending';
const String syncRetryable = 'retryable';
const String syncSynced = 'synced';
const String syncConflict = 'conflict';
const String syncPermanentFailure = 'permanent_failure';

/// Compatibility name for old tests/callers. A network failure is retryable.
const String syncFailed = syncRetryable;

// === Section: Non-secret settings keys ===
// Kept only so regression probes can prove these keys remain absent.
const String kAccessToken = 'access_token';
const String kRefreshToken = 'refresh_token';
const String kInstalledModelVersion = 'installed_model_version';
const String kLastSyncAt = 'last_sync_at';
const String kDeviceId = 'device_id';
const String kSessionOwner = 'session_owner';
const String kUserId = 'user_id';
const String kTenantId = 'tenant_id';
const String kUserRole = 'user_role';
const String kUserDisplayName = 'user_display_name';
const String kUserEmail = 'user_email';

class DataOwner {
  const DataOwner({
    required this.tenantId,
    required this.userId,
    required this.deviceId,
  });

  final String tenantId;
  final String userId;
  final String deviceId;

  String get key => '$tenantId:$userId';
}

/// Offline-first device database.
///
/// v2 adds explicit owner/version/retry metadata. v3 adds durable screening
/// snapshots, encrypted X-ray artifacts and conflict-resolution audit events.
/// Session secrets and artifact keys live in platform secure storage.
@DriftDatabase(
  tables: [
    LocalPatients,
    LocalDiagnoses,
    SyncQueue,
    EncryptedXrayArtifacts,
    ClinicalAuditEvents,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: 'tbscreen_local',
              web: kIsWeb
                  ? DriftWebOptions(
                      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                      driftWorker: Uri.parse('drift_worker.js'),
                    )
                  : null,
            ),
      );

  @override
  int get schemaVersion => 3;

  int _sessionGeneration = 0;
  DataOwner? _activeOwner;

  int get sessionGeneration => _sessionGeneration;
  DataOwner? get activeOwner => _activeOwner;

  void invalidateSession() => _sessionGeneration++;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await _migrateV1ToV2(m);
      if (from < 3) await _migrateV2ToV3(m);
    },
    beforeOpen: (details) async {
      // A process crash can leave an op in sending. The same client_op_id is
      // safe to replay because the backend enforces idempotency.
      if (details.versionNow >= 2) {
        await customUpdate(
          'UPDATE sync_queue '
          'SET status = ?, detail = COALESCE(detail, ?) '
          'WHERE status = ?',
          variables: [
            Variable.withString(syncRetryable),
            Variable.withString('Recovered after interrupted sync'),
            Variable.withString(syncSending),
          ],
          updates: {syncQueue},
        );
        await _deleteLegacyTokenRows();
      }
    },
  );

  Future<void> _migrateV1ToV2(Migrator m) async {
    await m.addColumn(localPatients, localPatients.tenantId);
    await m.addColumn(localPatients, localPatients.userId);
    await m.addColumn(localPatients, localPatients.deviceId);
    await m.addColumn(localPatients, localPatients.serverVersion);
    await m.addColumn(localPatients, localPatients.tombstone);

    await m.addColumn(localDiagnoses, localDiagnoses.tenantId);
    await m.addColumn(localDiagnoses, localDiagnoses.userId);
    await m.addColumn(localDiagnoses, localDiagnoses.deviceId);
    await m.addColumn(localDiagnoses, localDiagnoses.serverVersion);
    await m.addColumn(localDiagnoses, localDiagnoses.tombstone);
    await m.addColumn(localDiagnoses, localDiagnoses.imageChecksum);
    await m.addColumn(localDiagnoses, localDiagnoses.imageReference);
    await m.addColumn(localDiagnoses, localDiagnoses.provenance);
    await m.addColumn(localDiagnoses, localDiagnoses.isMock);

    await m.addColumn(syncQueue, syncQueue.tenantId);
    await m.addColumn(syncQueue, syncQueue.userId);
    await m.addColumn(syncQueue, syncQueue.deviceId);
    await m.addColumn(syncQueue, syncQueue.baseVersion);
    await m.addColumn(syncQueue, syncQueue.retryCount);
    await m.addColumn(syncQueue, syncQueue.nextAttemptAt);

    final owner = await _rawSetting(kSessionOwner);
    final separator = owner?.indexOf(':') ?? -1;
    final tenantId = separator > 0 ? owner!.substring(0, separator) : null;
    final userId = separator > 0 && separator < owner!.length - 1
        ? owner.substring(separator + 1)
        : null;
    final deviceId = await _rawSetting(kDeviceId) ?? uuidV4();
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: kDeviceId, value: deviceId),
    );

    if (tenantId != null && userId != null) {
      final variables = [
        Variable.withString(tenantId),
        Variable.withString(userId),
        Variable.withString(deviceId),
      ];
      for (final table in ['local_patients', 'local_diagnoses', 'sync_queue']) {
        await customUpdate(
          'UPDATE $table SET tenant_id = ?, user_id = ?, device_id = ? '
          'WHERE tenant_id IS NULL OR user_id IS NULL OR device_id IS NULL',
          variables: variables,
        );
      }
    } else {
      await customUpdate(
        'UPDATE sync_queue SET status = ?, detail = ? '
        'WHERE status != ?',
        variables: [
          Variable.withString(syncPermanentFailure),
          Variable.withString(
            'Quarantined during v2 migration: owner attribution required',
          ),
          Variable.withString(syncSynced),
        ],
        updates: {syncQueue},
      );
    }

    await customUpdate(
      'UPDATE sync_queue SET status = ?, retry_count = 1 '
      'WHERE status = ?',
      variables: [
        Variable.withString(syncRetryable),
        Variable.withString('failed'),
      ],
      updates: {syncQueue},
    );
    await _deleteLegacyTokenRows();
  }

  Future<void> _migrateV2ToV3(Migrator m) async {
    // Expand-only migration: existing clinical rows and queue entries remain
    // readable while new fields receive safe defaults.
    await m.addColumn(localDiagnoses, localDiagnoses.patientSnapshot);
    await m.addColumn(localDiagnoses, localDiagnoses.clinicalSnapshot);
    await m.addColumn(localDiagnoses, localDiagnoses.saveStatus);
    await m.addColumn(syncQueue, syncQueue.serverPayload);
    await m.createTable(encryptedXrayArtifacts);
    await m.createTable(clinicalAuditEvents);
  }

  Future<String?> _rawSetting(String key) async {
    final row = await customSelect(
      'SELECT value FROM app_settings WHERE key = ? LIMIT 1',
      variables: [Variable.withString(key)],
      readsFrom: {appSettings},
    ).getSingleOrNull();
    return row?.read<String>('value');
  }

  Future<void> _deleteLegacyTokenRows() => customUpdate(
    'DELETE FROM app_settings WHERE key IN (?, ?)',
    variables: [
      Variable.withString(kAccessToken),
      Variable.withString(kRefreshToken),
    ],
    updates: {appSettings},
  );

  /// Authenticates first, then switches the local owner atomically. A failed
  /// login never destroys the previous owner's offline work.
  Future<void> activateOwner(int generation, DataOwner owner) {
    return writeForSession(generation, () async {
      final previous = await getSetting(kSessionOwner);
      if (previous != null && previous != owner.key) {
        await _deleteClinicalData();
        await _deleteIdentitySettings();
      } else if (previous == owner.key) {
        await _claimUnattributedRows(owner);
      }
      if (previous != owner.key) {
        // A delta cursor belongs to exactly one account. A new owner must
        // start with a full pull or it can silently miss older records.
        await deleteSetting(kLastSyncAt);
      }
      _activeOwner = owner;
      await putSetting(kSessionOwner, owner.key);
      await putSetting(kDeviceId, owner.deviceId);
    });
  }

  /// Serializes writes with logout. A response from an earlier session cannot
  /// refill the cache after it has been cleared.
  Future<void> writeForSession(int generation, Future<void> Function() write) {
    return transaction(() async {
      if (generation != _sessionGeneration) return;
      await write();
    });
  }

  // === Section: Settings ===

  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> putSetting(String key, String value) {
    if (key == kAccessToken || key == kRefreshToken) {
      throw ArgumentError('Session secrets are forbidden in SQLite');
    }
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<void> deleteSetting(String key) {
    return (delete(appSettings)..where((t) => t.key.equals(key))).go();
  }

  // === Section: Patients cache ===

  Future<List<LocalPatient>> allPatients() => _patientQuery().get();

  Stream<List<LocalPatient>> watchPatients() => _patientQuery().watch();

  SimpleSelectStatement<$LocalPatientsTable, LocalPatient> _patientQuery() {
    final query = select(localPatients)
      ..where((t) => t.tombstone.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.lastVisit)]);
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query;
  }

  Future<LocalPatient?> findPatient(String id) {
    final query = select(localPatients)..where((t) => t.id.equals(id));
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.getSingleOrNull();
  }

  Future<void> upsertPatient(LocalPatientsCompanion row) {
    return into(localPatients).insertOnConflictUpdate(_ownPatient(row));
  }

  /// Replaces a full server snapshot while preserving every dirty/conflicted
  /// row. Incoming data is also prevented from overwriting those local edits.
  Future<void> replacePatientCache(List<LocalPatientsCompanion> rows) async {
    final protectedIds = (await protectedEntityIds('patient')).toSet();
    final safeRows = rows
        .where(
          (row) =>
              !protectedIds.contains(row.id.value) &&
              !(row.tombstone.present && row.tombstone.value),
        )
        .map(_ownPatient)
        .toList();
    final keepIds = {...protectedIds, ...safeRows.map((row) => row.id.value)};
    final owner = _activeOwner;

    await batch((b) {
      b.deleteWhere(localPatients, (t) {
        Expression<bool> predicate = t.id.isNotIn(keepIds);
        if (owner != null) {
          predicate =
              predicate &
              t.tenantId.equals(owner.tenantId) &
              t.userId.equals(owner.userId) &
              t.deviceId.equals(owner.deviceId);
        }
        return predicate;
      });
      b.insertAllOnConflictUpdate(localPatients, safeRows);
    });
  }

  Future<void> mergePatientChanges(List<LocalPatientsCompanion> rows) async {
    final protectedIds = (await protectedEntityIds('patient')).toSet();
    for (final raw in rows) {
      final id = raw.id.value;
      final deleted = raw.tombstone.present && raw.tombstone.value;
      if (protectedIds.contains(id)) {
        if (deleted) await markPatientConflict(id, true);
        continue;
      }
      if (deleted) {
        final statement = delete(localPatients)..where((t) => t.id.equals(id));
        final owner = _activeOwner;
        if (owner != null) {
          statement.where(
            (t) =>
                t.tenantId.equals(owner.tenantId) &
                t.userId.equals(owner.userId) &
                t.deviceId.equals(owner.deviceId),
          );
        }
        await statement.go();
      } else {
        await upsertPatient(raw);
      }
    }
  }

  Future<void> markPatientConflict(String id, bool value) {
    final statement = update(localPatients)..where((t) => t.id.equals(id));
    final owner = _activeOwner;
    if (owner != null) {
      statement.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return statement.write(LocalPatientsCompanion(hasConflict: Value(value)));
  }

  Future<int> countPatients() async => (await allPatients()).length;

  // === Section: Diagnoses cache ===

  Future<List<LocalDiagnose>> allDiagnoses() {
    final query = select(localDiagnoses)
      ..where((t) => t.tombstone.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.diagnosedAt)]);
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.get();
  }

  Stream<List<LocalDiagnose>> watchDiagnoses() {
    final query = select(localDiagnoses)
      ..where((t) => t.tombstone.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.diagnosedAt)]);
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.watch();
  }

  Future<LocalDiagnose?> latestDurableDiagnosis() {
    final query = select(localDiagnoses)
      ..where(
        (t) =>
            t.tombstone.equals(false) &
            t.patientSnapshot.equals('{}').not() &
            t.clinicalSnapshot.equals('{}').not(),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.diagnosedAt)])
      ..limit(1);
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.getSingleOrNull();
  }

  Future<void> upsertDiagnosis(LocalDiagnosesCompanion row) {
    return into(localDiagnoses).insertOnConflictUpdate(_ownDiagnosis(row));
  }

  Future<LocalDiagnose?> findDiagnosis(String id) {
    final query = select(localDiagnoses)..where((t) => t.id.equals(id));
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.getSingleOrNull();
  }

  Future<void> replaceDiagnosisCache(List<LocalDiagnosesCompanion> rows) async {
    final protectedIds = (await protectedEntityIds('diagnosis')).toSet();
    final safeRows = rows
        .where(
          (row) =>
              !protectedIds.contains(row.id.value) &&
              !(row.tombstone.present && row.tombstone.value),
        )
        .map(_ownDiagnosis)
        .toList();
    final keepIds = {...protectedIds, ...safeRows.map((row) => row.id.value)};
    final owner = _activeOwner;
    await batch((b) {
      b.deleteWhere(localDiagnoses, (t) {
        Expression<bool> predicate = t.id.isNotIn(keepIds);
        if (owner != null) {
          predicate =
              predicate &
              t.tenantId.equals(owner.tenantId) &
              t.userId.equals(owner.userId) &
              t.deviceId.equals(owner.deviceId);
        }
        return predicate;
      });
      b.insertAllOnConflictUpdate(localDiagnoses, safeRows);
    });
  }

  Future<void> mergeDiagnosisChanges(List<LocalDiagnosesCompanion> rows) async {
    final protectedIds = (await protectedEntityIds('diagnosis')).toSet();
    for (final raw in rows) {
      final id = raw.id.value;
      final deleted = raw.tombstone.present && raw.tombstone.value;
      if (protectedIds.contains(id)) {
        if (deleted) await markDiagnosisConflict(id, true);
        continue;
      }
      if (deleted) {
        final statement = delete(localDiagnoses)..where((t) => t.id.equals(id));
        final owner = _activeOwner;
        if (owner != null) {
          statement.where(
            (t) =>
                t.tenantId.equals(owner.tenantId) &
                t.userId.equals(owner.userId) &
                t.deviceId.equals(owner.deviceId),
          );
        }
        await statement.go();
      } else {
        await upsertDiagnosis(raw);
      }
    }
  }

  Future<void> markDiagnosisConflict(String id, bool value) {
    final statement = update(localDiagnoses)..where((t) => t.id.equals(id));
    final owner = _activeOwner;
    if (owner != null) {
      statement.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return statement.write(LocalDiagnosesCompanion(hasConflict: Value(value)));
  }

  Future<void> updateDiagnosisSaveStatus(String id, String status) {
    final statement = update(localDiagnoses)..where((t) => t.id.equals(id));
    final owner = _activeOwner;
    if (owner != null) {
      statement.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return statement.write(LocalDiagnosesCompanion(saveStatus: Value(status)));
  }

  Future<void> updateDiagnosisValidation(
    String id, {
    required String status,
    String? doctorNote,
    int? serverVersion,
    DateTime? updatedAt,
    bool? hasConflict,
  }) {
    final statement = update(localDiagnoses)..where((t) => t.id.equals(id));
    final owner = _activeOwner;
    if (owner != null) {
      statement.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return statement.write(
      LocalDiagnosesCompanion(
        status: Value(status),
        doctorNote: Value(doctorNote),
        serverVersion: serverVersion == null
            ? const Value.absent()
            : Value(serverVersion),
        updatedAt: updatedAt == null
            ? const Value.absent()
            : Value(updatedAt.toUtc()),
        hasConflict: hasConflict == null
            ? const Value.absent()
            : Value(hasConflict),
      ),
    );
  }

  Future<int> countDiagnoses() async => (await allDiagnoses()).length;

  // === Section: Encrypted clinical artifacts ===

  Future<void> upsertEncryptedArtifact(EncryptedXrayArtifactsCompanion row) {
    return into(
      encryptedXrayArtifacts,
    ).insertOnConflictUpdate(_ownArtifact(row));
  }

  Future<EncryptedXrayArtifact?> findEncryptedArtifact(String id) {
    final query = select(encryptedXrayArtifacts)..where((t) => t.id.equals(id));
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.getSingleOrNull();
  }

  // === Section: Clinical audit evidence ===

  Future<void> appendClinicalAudit(ClinicalAuditEventsCompanion event) {
    return into(clinicalAuditEvents).insert(_ownAuditEvent(event));
  }

  Future<List<ClinicalAuditEvent>> clinicalAuditFor(String entityId) {
    final query = select(clinicalAuditEvents)
      ..where((t) => t.entityId.equals(entityId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.get();
  }

  // === Section: Sync queue ===

  Future<void> enqueue(SyncQueueCompanion op) {
    return into(syncQueue).insertOnConflictUpdate(_ownOperation(op));
  }

  Future<List<SyncQueueData>> pendingOps() => opsReadyForPush(manual: true);

  Future<List<SyncQueueData>> opsReadyForPush({
    required bool manual,
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now().toUtc();
    final query = select(syncQueue)
      ..where(
        (t) =>
            t.status.equals(syncPending) |
            t.status.equals(syncRetryable) |
            t.status.equals(syncSending),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    if (!manual) {
      query.where(
        (t) =>
            t.nextAttemptAt.isNull() |
            t.nextAttemptAt.isSmallerOrEqualValue(instant),
      );
    }
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.get();
  }

  Future<List<SyncQueueData>> opsWithStatus(String status) {
    final query = select(syncQueue)..where((t) => t.status.equals(status));
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.get();
  }

  Future<List<String>> protectedEntityIds(String entityType) async {
    final query = select(syncQueue)
      ..where(
        (t) =>
            t.status.equals(syncSynced).not() & t.entityType.equals(entityType),
      );
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    final rows = await query.get();
    return rows.map((row) => row.entityId).toList();
  }

  Future<List<String>> pendingEntityIds(String entityType) =>
      protectedEntityIds(entityType);

  Future<void> markOp(String clientOpId, String status, {String? detail}) {
    final statement = update(syncQueue)
      ..where((t) => t.clientOpId.equals(clientOpId));
    _scopeOperation(statement);
    return statement.write(
      SyncQueueCompanion(
        status: Value(status),
        detail: Value(detail),
        nextAttemptAt: const Value(null),
        syncedAt: Value(status == syncSynced ? DateTime.now().toUtc() : null),
      ),
    );
  }

  Future<SyncQueueData?> findOperation(String clientOpId) {
    final query = select(syncQueue)
      ..where((t) => t.clientOpId.equals(clientOpId));
    final owner = _activeOwner;
    if (owner != null) {
      query.where(
        (t) =>
            t.tenantId.equals(owner.tenantId) &
            t.userId.equals(owner.userId) &
            t.deviceId.equals(owner.deviceId),
      );
    }
    return query.getSingleOrNull();
  }

  Future<void> saveConflictServerPayload(String clientOpId, String payload) {
    final statement = update(syncQueue)
      ..where((t) => t.clientOpId.equals(clientOpId));
    _scopeOperation(statement);
    return statement.write(SyncQueueCompanion(serverPayload: Value(payload)));
  }

  Future<void> markOpSending(String clientOpId) {
    final statement = update(syncQueue)
      ..where((t) => t.clientOpId.equals(clientOpId));
    _scopeOperation(statement);
    return statement.write(
      const SyncQueueCompanion(status: Value(syncSending), detail: Value(null)),
    );
  }

  Future<void> markOpRetryable(
    SyncQueueData op, {
    required DateTime nextAttemptAt,
    required String detail,
  }) {
    final statement = update(syncQueue)
      ..where((t) => t.clientOpId.equals(op.clientOpId));
    _scopeOperation(statement);
    return statement.write(
      SyncQueueCompanion(
        status: const Value(syncRetryable),
        detail: Value(detail),
        retryCount: Value(op.retryCount + 1),
        nextAttemptAt: Value(nextAttemptAt.toUtc()),
        syncedAt: const Value(null),
      ),
    );
  }

  Future<int> countPending() async {
    final rows = await opsReadyForPush(manual: true);
    return rows.length;
  }

  void _scopeOperation(UpdateStatement<$SyncQueueTable, SyncQueueData> query) {
    final owner = _activeOwner;
    if (owner == null) return;
    query.where(
      (t) =>
          t.tenantId.equals(owner.tenantId) &
          t.userId.equals(owner.userId) &
          t.deviceId.equals(owner.deviceId),
    );
  }

  // === Section: Session cleanup ===

  /// Clears PHI and queue state while retaining device-only settings.
  Future<void> clearSessionData() async {
    _sessionGeneration++;
    _activeOwner = null;
    await transaction(() async {
      await _deleteClinicalData();
      await _deleteIdentitySettings();
      await deleteSetting(kLastSyncAt);
    });
  }

  /// Full wipe used by tests and explicit reset flows.
  Future<void> clearAll() async {
    _sessionGeneration++;
    _activeOwner = null;
    await transaction(() async {
      await _deleteClinicalData();
      await delete(appSettings).go();
    });
  }

  Future<void> _deleteClinicalData() => batch((b) {
    b.deleteWhere(localPatients, (_) => const Constant(true));
    b.deleteWhere(localDiagnoses, (_) => const Constant(true));
    b.deleteWhere(syncQueue, (_) => const Constant(true));
    b.deleteWhere(encryptedXrayArtifacts, (_) => const Constant(true));
    b.deleteWhere(clinicalAuditEvents, (_) => const Constant(true));
  });

  Future<void> _deleteIdentitySettings() async {
    for (final key in [
      kSessionOwner,
      kUserId,
      kTenantId,
      kUserRole,
      kUserDisplayName,
      kUserEmail,
    ]) {
      await deleteSetting(key);
    }
  }

  Future<void> _claimUnattributedRows(DataOwner owner) async {
    final variables = [
      Variable.withString(owner.tenantId),
      Variable.withString(owner.userId),
      Variable.withString(owner.deviceId),
    ];
    for (final table in [
      'local_patients',
      'local_diagnoses',
      'sync_queue',
      'encrypted_xray_artifacts',
      'clinical_audit_events',
    ]) {
      await customUpdate(
        'UPDATE $table SET tenant_id = ?, user_id = ?, device_id = ? '
        'WHERE tenant_id IS NULL AND user_id IS NULL',
        variables: variables,
      );
    }
  }

  LocalPatientsCompanion _ownPatient(LocalPatientsCompanion row) {
    final owner = _activeOwner;
    if (owner == null) return row;
    return row.copyWith(
      tenantId: Value(owner.tenantId),
      userId: Value(owner.userId),
      deviceId: Value(owner.deviceId),
    );
  }

  LocalDiagnosesCompanion _ownDiagnosis(LocalDiagnosesCompanion row) {
    final owner = _activeOwner;
    if (owner == null) return row;
    return row.copyWith(
      tenantId: Value(owner.tenantId),
      userId: Value(owner.userId),
      deviceId: Value(owner.deviceId),
    );
  }

  SyncQueueCompanion _ownOperation(SyncQueueCompanion row) {
    final owner = _activeOwner;
    if (owner == null) return row;
    return row.copyWith(
      tenantId: Value(owner.tenantId),
      userId: Value(owner.userId),
      deviceId: Value(owner.deviceId),
    );
  }

  EncryptedXrayArtifactsCompanion _ownArtifact(
    EncryptedXrayArtifactsCompanion row,
  ) {
    final owner = _activeOwner;
    if (owner == null) return row;
    return row.copyWith(
      tenantId: Value(owner.tenantId),
      userId: Value(owner.userId),
      deviceId: Value(owner.deviceId),
    );
  }

  ClinicalAuditEventsCompanion _ownAuditEvent(
    ClinicalAuditEventsCompanion row,
  ) {
    final owner = _activeOwner;
    if (owner == null) return row;
    return row.copyWith(
      tenantId: Value(owner.tenantId),
      userId: Value(owner.userId),
      deviceId: Value(owner.deviceId),
    );
  }
}
