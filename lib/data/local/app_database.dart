import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:myapp/core/utils/uuid.dart';
import 'package:myapp/data/local/tables.dart';

part 'app_database.g.dart';

// === Section: Sync queue state machine ===
const String syncBlockedContract = 'blocked_contract';
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
const String kLastModelCheck = 'last_model_check';
const String kAvailableModelsCache = 'available_models_cache';
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
/// v6 adds [ArchivedXrayArtifacts] for BLOB-native outbox artifact storage.
/// Session secrets and artifact keys live in platform secure storage.
@DriftDatabase(
  tables: [
    LocalPatients,
    LocalDiagnoses,
    SyncQueue,
    EncryptedXrayArtifacts,
    ArchivedXrayArtifacts,
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
  int get schemaVersion => 6;

  int _sessionGeneration = 0;
  DataOwner? _activeOwner;

  int get sessionGeneration => _sessionGeneration;
  DataOwner? get activeOwner => _activeOwner;

  void invalidateSession() => _sessionGeneration++;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createArchiveIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) await _migrateV1ToV2(m);
      if (from < 3) await _migrateV2ToV3(m);
      if (from < 5) {
        await m.addColumn(localDiagnoses, localDiagnoses.lesionRating);
        await m.addColumn(localDiagnoses, localDiagnoses.validationDeletedAt);
        await m.addColumn(localDiagnoses, localDiagnoses.validationDeletedBy);
      }
      if (from < 4) {
        await m.addColumn(localDiagnoses, localDiagnoses.validationScore);
        await m.addColumn(localDiagnoses, localDiagnoses.validatedBy);
        await m.addColumn(localDiagnoses, localDiagnoses.validatedAt);
      }
      if (from < 6) {
        await m.createTable(archivedXrayArtifacts);
        await _createArchiveIndexes();
      }
    },
    beforeOpen: (details) async {
      if (!kIsWeb) {
        await customStatement('PRAGMA journal_mode = WAL;');
        await customStatement('PRAGMA busy_timeout = 5000;');
      }
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

  static const List<String> _identitySettingKeys = [
    kSessionOwner,
    kUserId,
    kTenantId,
    kUserRole,
    kUserDisplayName,
    kUserEmail,
  ];

  /// Authenticates first, then switches the local owner atomically. A failed
  /// login never destroys the previous owner's offline work.
  Future<void> activateOwner(
    int generation,
    DataOwner owner, {
    Map<String, String>? identitySettings,
  }) {
    final settingsToWrite = <String, String>{
      ...?identitySettings,
      kSessionOwner: owner.key,
      kDeviceId: owner.deviceId,
    };
    _assertNoSessionSecrets(settingsToWrite.keys);
    return writeForSession(generation, () async {
      final previous = await getSetting(kSessionOwner);
      if (previous == owner.key) {
        await _claimUnattributedRows(owner);
      }
      _activeOwner = owner;
      await batch((b) {
        if (previous != null && previous != owner.key) {
          _addClinicalDataDeletes(b);
          b.deleteWhere(
            appSettings,
            (t) => t.key.isIn(const [..._identitySettingKeys, kLastSyncAt]),
          );
        } else if (previous != owner.key) {
          // A delta cursor belongs to exactly one account. A new owner must
          // start with a full pull or it can silently miss older records.
          b.deleteWhere(appSettings, (t) => t.key.equals(kLastSyncAt));
        }
        b.insertAllOnConflictUpdate(appSettings, [
          for (final entry in settingsToWrite.entries)
            AppSettingsCompanion.insert(key: entry.key, value: entry.value),
        ]);
      });
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

  void _assertNoSessionSecrets(Iterable<String> keys) {
    for (final key in keys) {
      if (key == kAccessToken || key == kRefreshToken) {
        throw ArgumentError('Session secrets are forbidden in SQLite');
      }
    }
  }

  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<Map<String, String>> getSettings(List<String> keys) async {
    if (keys.isEmpty) return const {};
    final rows = await (select(
      appSettings,
    )..where((t) => t.key.isIn(keys))).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> putSetting(String key, String value) {
    _assertNoSessionSecrets([key]);
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<void> putSettings(Map<String, String> entries) async {
    if (entries.isEmpty) return;
    _assertNoSessionSecrets(entries.keys);
    await batch((b) {
      b.insertAllOnConflictUpdate(appSettings, [
        for (final entry in entries.entries)
          AppSettingsCompanion.insert(key: entry.key, value: entry.value),
      ]);
    });
  }

  Future<void> deleteSetting(String key) {
    return (delete(appSettings)..where((t) => t.key.equals(key))).go();
  }

  Future<void> deleteSettings(List<String> keys) async {
    if (keys.isEmpty) return;
    await (delete(appSettings)..where((t) => t.key.isIn(keys))).go();
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

  Future<List<LocalPatient>> patientsByIds(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const [];
    final owner = _activeOwner;
    final out = <LocalPatient>[];
    const maxVars = 400;
    for (var i = 0; i < list.length; i += maxVars) {
      final slice = list.sublist(i, math.min(i + maxVars, list.length));
      final query = select(localPatients)
        ..where((t) => t.id.isIn(slice) & t.tombstone.equals(false));
      if (owner != null) {
        query.where(
          (t) =>
              t.tenantId.equals(owner.tenantId) &
              t.userId.equals(owner.userId) &
              t.deviceId.equals(owner.deviceId),
        );
      }
      out.addAll(await query.get());
    }
    return out;
  }

  // === Section: Diagnoses cache ===

  Future<List<LocalDiagnose>> activeValidations() {
    final query = select(localDiagnoses)
      ..where((t) => t.tombstone.equals(false) & t.validationDeletedAt.isNull())
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

  Future<List<EncryptedXrayArtifact>> findEncryptedArtifacts(
    Iterable<String> ids,
  ) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return const [];
    final owner = _activeOwner;
    final out = <EncryptedXrayArtifact>[];
    const maxVars = 400;
    for (var i = 0; i < list.length; i += maxVars) {
      final slice = list.sublist(i, math.min(i + maxVars, list.length));
      final query = select(encryptedXrayArtifacts)
        ..where((t) => t.id.isIn(slice));
      if (owner != null) {
        query.where(
          (t) =>
              t.tenantId.equals(owner.tenantId) &
              t.userId.equals(owner.userId) &
              t.deviceId.equals(owner.deviceId),
        );
      }
      out.addAll(await query.get());
    }
    return out;
  }

  Future<void> _createArchiveIndexes() => customStatement(
    'CREATE INDEX IF NOT EXISTS idx_archived_xray_owner '
    'ON archived_xray_artifacts (tenant_id, user_id, device_id, archive_key)',
  );

  /// Copies already-encrypted X-ray/overlay BLOBs inside SQLite from
  /// [encryptedXrayArtifacts] into [archivedXrayArtifacts] without allocating
  /// large byte buffers or JSON integer arrays in Dart.
  Future<void> copyEncryptedArtifactsToArchive(
    Map<String, List<String>> artifactIdsByArchiveKey,
    DataOwner owner,
  ) async {
    const maxVars = 400;
    for (final entry in artifactIdsByArchiveKey.entries) {
      final ids = entry.value;
      if (ids.isEmpty) continue;
      for (var i = 0; i < ids.length; i += maxVars) {
        final slice = ids.sublist(i, math.min(i + maxVars, ids.length));
        final placeholders = List.filled(slice.length, '?').join(',');
        await customInsert(
          'INSERT OR REPLACE INTO archived_xray_artifacts ('
          'archive_key, artifact_id, cipher_text, nonce, mac, filename, '
          'mime_type, source, checksum, size_bytes, created_at, '
          'tenant_id, user_id, device_id) '
          'SELECT ?, id, cipher_text, nonce, mac, filename, '
          'mime_type, source, checksum, size_bytes, created_at, '
          'tenant_id, user_id, device_id '
          'FROM encrypted_xray_artifacts '
          'WHERE id IN ($placeholders) '
          'AND tenant_id = ? AND user_id = ? AND device_id = ?',
          variables: [
            Variable.withString(entry.key),
            for (final id in slice) Variable.withString(id),
            Variable.withString(owner.tenantId),
            Variable.withString(owner.userId),
            Variable.withString(owner.deviceId),
          ],
          updates: {archivedXrayArtifacts},
        );
      }
    }
  }

  /// Restores archived BLOBs directly into [encryptedXrayArtifacts] inside SQLite
  /// for verified [artifactIdsByArchiveKey] entries owned by [owner].
  Future<void> copyArchiveArtifactsToActive(
    Map<String, List<String>> artifactIdsByArchiveKey,
    DataOwner owner,
  ) async {
    const maxVars = 400;
    for (final entry in artifactIdsByArchiveKey.entries) {
      final ids = entry.value;
      if (ids.isEmpty) continue;
      for (var i = 0; i < ids.length; i += maxVars) {
        final slice = ids.sublist(i, math.min(i + maxVars, ids.length));
        final placeholders = List.filled(slice.length, '?').join(',');
        await customInsert(
          'INSERT OR REPLACE INTO encrypted_xray_artifacts ('
          'id, cipher_text, nonce, mac, filename, '
          'mime_type, source, checksum, size_bytes, created_at, '
          'tenant_id, user_id, device_id) '
          'SELECT artifact_id, cipher_text, nonce, mac, filename, '
          'mime_type, source, checksum, size_bytes, created_at, '
          'tenant_id, user_id, device_id '
          'FROM archived_xray_artifacts '
          'WHERE archive_key = ? AND artifact_id IN ($placeholders) '
          'AND tenant_id = ? AND user_id = ? AND device_id = ?',
          variables: [
            Variable.withString(entry.key),
            for (final id in slice) Variable.withString(id),
            Variable.withString(owner.tenantId),
            Variable.withString(owner.userId),
            Variable.withString(owner.deviceId),
          ],
          updates: {encryptedXrayArtifacts},
        );
      }
    }
  }

  Future<void> upsertArchivedArtifacts(
    List<ArchivedXrayArtifactsCompanion> rows,
  ) async {
    if (rows.isEmpty) return;
    await batch((b) {
      b.insertAllOnConflictUpdate(archivedXrayArtifacts, rows);
    });
  }

  Future<void> rekeyArchivedArtifacts({
    required String fromKey,
    required String toKey,
    DataOwner? owner,
  }) async {
    if (fromKey == toKey) return;
    final ownerSql = owner == null
        ? ''
        : ' AND tenant_id = ? AND user_id = ? AND device_id = ?';
    await customInsert(
      'INSERT OR REPLACE INTO archived_xray_artifacts ('
      'archive_key, artifact_id, cipher_text, nonce, mac, filename, '
      'mime_type, source, checksum, size_bytes, created_at, '
      'tenant_id, user_id, device_id) '
      'SELECT ?, artifact_id, cipher_text, nonce, mac, filename, '
      'mime_type, source, checksum, size_bytes, created_at, '
      'tenant_id, user_id, device_id '
      'FROM archived_xray_artifacts '
      'WHERE archive_key = ?$ownerSql',
      variables: [
        Variable.withString(toKey),
        Variable.withString(fromKey),
        if (owner != null) ...[
          Variable.withString(owner.tenantId),
          Variable.withString(owner.userId),
          Variable.withString(owner.deviceId),
        ],
      ],
      updates: {archivedXrayArtifacts},
    );
  }

  Future<List<ArchivedXrayArtifact>> findArchivedArtifacts(
    String archiveKey, {
    List<String>? artifactIds,
    DataOwner? owner,
  }) async {
    if (artifactIds != null && artifactIds.isEmpty) return const [];
    final out = <ArchivedXrayArtifact>[];
    if (artifactIds == null) {
      final query = select(archivedXrayArtifacts)
        ..where((t) => t.archiveKey.equals(archiveKey));
      if (owner != null) {
        query.where(
          (t) =>
              t.tenantId.equals(owner.tenantId) &
              t.userId.equals(owner.userId) &
              t.deviceId.equals(owner.deviceId),
        );
      }
      out.addAll(await query.get());
      return out;
    }
    const maxVars = 400;
    for (var i = 0; i < artifactIds.length; i += maxVars) {
      final slice = artifactIds.sublist(
        i,
        math.min(i + maxVars, artifactIds.length),
      );
      final query = select(archivedXrayArtifacts)
        ..where(
          (t) => t.archiveKey.equals(archiveKey) & t.artifactId.isIn(slice),
        );
      if (owner != null) {
        query.where(
          (t) =>
              t.tenantId.equals(owner.tenantId) &
              t.userId.equals(owner.userId) &
              t.deviceId.equals(owner.deviceId),
        );
      }
      out.addAll(await query.get());
    }
    return out;
  }

  Future<void> deleteArchivedArtifactsForKeys(List<String> archiveKeys) async {
    if (archiveKeys.isEmpty) return;
    const maxVars = 400;
    for (var i = 0; i < archiveKeys.length; i += maxVars) {
      final slice = archiveKeys.sublist(
        i,
        math.min(i + maxVars, archiveKeys.length),
      );
      await (delete(
        archivedXrayArtifacts,
      )..where((t) => t.archiveKey.isIn(slice))).go();
    }
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

  /// Atomically upserts restored outbox entities and conflict/failure flags.
  Future<void> applyOutboxRestoreBatch({
    List<LocalPatientsCompanion> patients = const [],
    List<LocalDiagnosesCompanion> diagnoses = const [],
    List<EncryptedXrayArtifactsCompanion> artifacts = const [],
    List<SyncQueueCompanion> operations = const [],
    List<String> conflictPatientIds = const [],
    List<String> conflictDiagnosisIds = const [],
    List<String> failedDiagnosisIds = const [],
  }) async {
    if (patients.isEmpty &&
        diagnoses.isEmpty &&
        artifacts.isEmpty &&
        operations.isEmpty &&
        conflictPatientIds.isEmpty &&
        conflictDiagnosisIds.isEmpty &&
        failedDiagnosisIds.isEmpty) {
      return;
    }
    final ownedPatients = [for (final row in patients) _ownPatient(row)];
    final ownedDiagnoses = [for (final row in diagnoses) _ownDiagnosis(row)];
    final ownedArtifacts = [for (final row in artifacts) _ownArtifact(row)];
    final ownedOperations = [for (final row in operations) _ownOperation(row)];
    final owner = _activeOwner;

    Expression<bool> ownedIds(
      List<String> ids,
      GeneratedColumn<String> idColumn,
      GeneratedColumn<String> tenantColumn,
      GeneratedColumn<String> userColumn,
      GeneratedColumn<String> deviceColumn,
    ) {
      Expression<bool> pred = idColumn.isIn(ids);
      if (owner != null) {
        pred =
            pred &
            tenantColumn.equals(owner.tenantId) &
            userColumn.equals(owner.userId) &
            deviceColumn.equals(owner.deviceId);
      }
      return pred;
    }

    await batch((b) {
      if (ownedPatients.isNotEmpty) {
        b.insertAllOnConflictUpdate(localPatients, ownedPatients);
      }
      if (ownedDiagnoses.isNotEmpty) {
        b.insertAllOnConflictUpdate(localDiagnoses, ownedDiagnoses);
      }
      if (ownedArtifacts.isNotEmpty) {
        b.insertAllOnConflictUpdate(encryptedXrayArtifacts, ownedArtifacts);
      }
      if (ownedOperations.isNotEmpty) {
        b.insertAllOnConflictUpdate(syncQueue, ownedOperations);
      }
      if (conflictPatientIds.isNotEmpty) {
        b.update(
          localPatients,
          const LocalPatientsCompanion(hasConflict: Value(true)),
          where: (t) => ownedIds(
            conflictPatientIds,
            t.id,
            t.tenantId,
            t.userId,
            t.deviceId,
          ),
        );
      }
      if (conflictDiagnosisIds.isNotEmpty) {
        b.update(
          localDiagnoses,
          const LocalDiagnosesCompanion(
            hasConflict: Value(true),
            saveStatus: Value('conflict'),
          ),
          where: (t) => ownedIds(
            conflictDiagnosisIds,
            t.id,
            t.tenantId,
            t.userId,
            t.deviceId,
          ),
        );
      }
      if (failedDiagnosisIds.isNotEmpty) {
        b.update(
          localDiagnoses,
          const LocalDiagnosesCompanion(saveStatus: Value('failed')),
          where: (t) => ownedIds(
            failedDiagnosisIds,
            t.id,
            t.tenantId,
            t.userId,
            t.deviceId,
          ),
        );
      }
    });
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

  Future<List<SyncQueueData>> legacyRatingConflictCandidates() {
    final query = select(syncQueue)
      ..where(
        (t) =>
            t.entityType.equals('diagnosis') &
            t.operation.equals('update') &
            t.status.equals(syncSynced).not() &
            t.status.equals(syncConflict).not() &
            t.retryCount.isBiggerThanValue(0),
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
    return query.get();
  }

  Future<List<SyncQueueData>> pendingDiagnosisMutationsFor(
    Iterable<String> diagnosisIds,
  ) async {
    final list = diagnosisIds.toSet().toList();
    if (list.isEmpty) return const [];
    final owner = _activeOwner;
    final out = <SyncQueueData>[];
    const maxVars = 400;
    for (var i = 0; i < list.length; i += maxVars) {
      final slice = list.sublist(i, math.min(i + maxVars, list.length));
      final query = select(syncQueue)
        ..where(
          (t) =>
              t.entityId.isIn(slice) &
              t.entityType.equals('diagnosis') &
              t.status.equals(syncSynced).not() &
              t.operation.equals('create').not(),
        );
      if (owner != null) {
        query.where(
          (t) =>
              t.tenantId.equals(owner.tenantId) &
              t.userId.equals(owner.userId) &
              t.deviceId.equals(owner.deviceId),
        );
      }
      out.addAll(await query.get());
    }
    return out;
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
    await batch((b) {
      _addClinicalDataDeletes(b);
      b.deleteWhere(
        appSettings,
        (t) => t.key.isIn(const [..._identitySettingKeys, kLastSyncAt]),
      );
    });
  }

  /// Full wipe used by tests and explicit reset flows.
  Future<void> clearAll() async {
    _sessionGeneration++;
    _activeOwner = null;
    await batch((b) {
      _addClinicalDataDeletes(b);
      b.deleteWhere(archivedXrayArtifacts, (_) => const Constant(true));
      b.deleteWhere(appSettings, (_) => const Constant(true));
    });
  }

  void _addClinicalDataDeletes(Batch b) {
    b.deleteWhere(localPatients, (_) => const Constant(true));
    b.deleteWhere(localDiagnoses, (_) => const Constant(true));
    b.deleteWhere(syncQueue, (_) => const Constant(true));
    b.deleteWhere(encryptedXrayArtifacts, (_) => const Constant(true));
    b.deleteWhere(clinicalAuditEvents, (_) => const Constant(true));
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
