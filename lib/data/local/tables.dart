import 'package:drift/drift.dart';

/// Cached patients. Mirrors the server row plus two local-only columns:
/// [updatedAt] (the server version this cache is based on) and [hasConflict].
class LocalPatients extends Table {
  /// Server UUID, or a client-generated UUID for rows created offline.
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get name => text()();
  IntColumn get age => integer()();
  TextColumn get gender => text()();
  TextColumn get status => text().withDefault(const Constant('Normal'))();
  IntColumn get confidence => integer().nullable()();
  TextColumn get lastVisit => text().nullable()();

  /// JSON-encoded `List<String>`.
  TextColumn get history => text().withDefault(const Constant('[]'))();

  /// Server-side updated_at this cache was built from — the basis for
  /// conflict detection on the next push.
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// Set when the server rejected our change because its version is newer.
  /// Medical data is never auto-overwritten; a doctor reviews it manually.
  BoolColumn get hasConflict => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached diagnoses.
class LocalDiagnoses extends Table {
  TextColumn get id => text()();
  TextColumn get patientId => text()();
  BoolColumn get isPositive => boolean()();
  IntColumn get confidence => integer()();
  TextColumn get modelVersion => text()();
  IntColumn get processingTimeMs => integer().nullable()();

  /// JSON-encoded findings map (consolidation, cavity, effusion, ...).
  TextColumn get findings => text().withDefault(const Constant('{}'))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get doctorNote => text().nullable()();
  DateTimeColumn get diagnosedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get hasConflict => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Write-ahead queue. Every local mutation lands here first and is pushed to
/// the server later; the row survives app restarts, so nothing is lost offline.
class SyncQueue extends Table {
  /// Client-generated UUID sent as `client_op_id`. The backend's
  /// UNIQUE(tenant_id, client_op_id) makes a retry a no-op instead of a
  /// duplicate — so this column IS the idempotency key.
  TextColumn get clientOpId => text()();

  /// 'patient' | 'diagnosis'
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();

  /// 'create' | 'update'
  TextColumn get operation => text()();

  /// JSON-encoded request body.
  TextColumn get payload => text()();

  /// Server version the edit was based on — omitted for creates.
  DateTimeColumn get baseUpdatedAt => dateTime().nullable()();

  /// pending | synced | conflict | failed
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Server explanation for conflict/failed.
  TextColumn get detail => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {clientOpId};
}

/// Key/value store for device-local facts: JWT tokens, installed AI model
/// version, last successful sync timestamp.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
