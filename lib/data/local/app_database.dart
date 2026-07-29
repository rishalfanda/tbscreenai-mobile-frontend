import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:myapp/data/local/tables.dart';

part 'app_database.g.dart';

// === Section: Sync queue status values ===
const String syncPending = 'pending';
const String syncSynced = 'synced';
const String syncConflict = 'conflict';
const String syncFailed = 'failed';

// === Section: Settings keys ===
const String kAccessToken = 'access_token';
const String kRefreshToken = 'refresh_token';
const String kInstalledModelVersion = 'installed_model_version';
const String kLastSyncAt = 'last_sync_at';
const String kUserDisplayName = 'user_display_name';
const String kUserEmail = 'user_email';

/// On-device database. Offline-first: screens read from here, and every write
/// goes through [SyncQueue] so it survives being offline.
@DriftDatabase(tables: [LocalPatients, LocalDiagnoses, SyncQueue, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(
          name: 'tbscreen_local',
          web: kIsWeb
              ? DriftWebOptions(
                  sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                  driftWorker: Uri.parse('drift_worker.js'),
                )
              : null,
        ));

  @override
  int get schemaVersion => 1;

  // === Section: Settings ===

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> putSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<void> deleteSetting(String key) {
    return (delete(appSettings)..where((t) => t.key.equals(key))).go();
  }

  // === Section: Patients cache ===

  Future<List<LocalPatient>> allPatients() {
    return (select(localPatients)
          ..orderBy([(t) => OrderingTerm.desc(t.lastVisit)]))
        .get();
  }

  Future<LocalPatient?> findPatient(String id) {
    return (select(localPatients)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertPatient(LocalPatientsCompanion row) {
    return into(localPatients).insertOnConflictUpdate(row);
  }

  /// Replaces the cache with a fresh server snapshot, but keeps rows that are
  /// still waiting in the queue — dropping them would lose offline work.
  Future<void> replacePatientCache(List<LocalPatientsCompanion> rows) async {
    final queuedIds = await pendingEntityIds('patient');
    await batch((b) {
      b.deleteWhere(localPatients, (t) => t.id.isNotIn(queuedIds));
      b.insertAllOnConflictUpdate(localPatients, rows);
    });
  }

  Future<void> markPatientConflict(String id, bool value) {
    return (update(localPatients)..where((t) => t.id.equals(id)))
        .write(LocalPatientsCompanion(hasConflict: Value(value)));
  }

  Future<int> countPatients() async {
    final count = countAll();
    final row = await (selectOnly(localPatients)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // === Section: Diagnoses cache ===

  Future<List<LocalDiagnose>> allDiagnoses() {
    return (select(localDiagnoses)
          ..orderBy([(t) => OrderingTerm.desc(t.diagnosedAt)]))
        .get();
  }

  Future<void> upsertDiagnosis(LocalDiagnosesCompanion row) {
    return into(localDiagnoses).insertOnConflictUpdate(row);
  }

  Future<void> replaceDiagnosisCache(List<LocalDiagnosesCompanion> rows) async {
    final queuedIds = await pendingEntityIds('diagnosis');
    await batch((b) {
      b.deleteWhere(localDiagnoses, (t) => t.id.isNotIn(queuedIds));
      b.insertAllOnConflictUpdate(localDiagnoses, rows);
    });
  }

  Future<int> countDiagnoses() async {
    final count = countAll();
    final row = await (selectOnly(localDiagnoses)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // === Section: Sync queue ===

  Future<void> enqueue(SyncQueueCompanion op) {
    return into(syncQueue).insertOnConflictUpdate(op);
  }

  Future<List<SyncQueueData>> pendingOps() {
    return (select(syncQueue)
          ..where((t) => t.status.equals(syncPending))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<List<SyncQueueData>> opsWithStatus(String status) {
    return (select(syncQueue)..where((t) => t.status.equals(status))).get();
  }

  Future<List<String>> pendingEntityIds(String entityType) async {
    final rows = await (select(syncQueue)
          ..where((t) =>
              t.status.equals(syncPending) & t.entityType.equals(entityType)))
        .get();
    return rows.map((r) => r.entityId).toList();
  }

  Future<void> markOp(String clientOpId, String status, {String? detail}) {
    return (update(syncQueue)..where((t) => t.clientOpId.equals(clientOpId)))
        .write(SyncQueueCompanion(
      status: Value(status),
      detail: Value(detail),
      syncedAt: Value(status == syncSynced ? DateTime.now() : null),
    ));
  }

  Future<int> countPending() async {
    final count = countAll();
    final row = await (selectOnly(syncQueue)
          ..addColumns([count])
          ..where(syncQueue.status.equals(syncPending)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Wipes cached medical data on logout. Queue and settings are cleared too —
  /// nothing belonging to the previous user may stay on the device.
  Future<void> clearAll() async {
    await batch((b) {
      b.deleteWhere(localPatients, (_) => const Constant(true));
      b.deleteWhere(localDiagnoses, (_) => const Constant(true));
      b.deleteWhere(syncQueue, (_) => const Constant(true));
      b.deleteWhere(appSettings, (_) => const Constant(true));
    });
  }
}
