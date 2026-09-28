import 'package:drift/drift.dart';

/// Cached patients. [serverVersion] is the primary optimistic-lock token;
/// [updatedAt] is retained only as a legacy/diagnostic secondary timestamp.
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

  TextColumn get tenantId => text().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get deviceId => text().nullable()();
  IntColumn get serverVersion => integer().nullable()();
  BoolColumn get tombstone => boolean().withDefault(const Constant(false))();

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
  TextColumn get tenantId => text().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get deviceId => text().nullable()();
  IntColumn get serverVersion => integer().nullable()();
  BoolColumn get tombstone => boolean().withDefault(const Constant(false))();
  TextColumn get imageChecksum => text().nullable()();
  TextColumn get imageReference => text().nullable()();
  TextColumn get provenance => text().withDefault(const Constant('{}'))();
  BoolColumn get isMock => boolean().withDefault(const Constant(true))();

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
  TextColumn get tenantId => text().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get deviceId => text().nullable()();

  /// 'create' | 'update'
  TextColumn get operation => text()();

  /// JSON-encoded request body.
  TextColumn get payload => text()();

  /// Server version the edit was based on — omitted for creates.
  IntColumn get baseVersion => integer().nullable()();
  DateTimeColumn get baseUpdatedAt => dateTime().nullable()();

  /// pending | sending | retryable | synced | conflict | permanent_failure
  TextColumn get status => text().withDefault(const Constant('pending'))();

  /// Server or protocol explanation for conflict/failure.
  TextColumn get detail => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {clientOpId};
}

/// Key/value store for non-secret device/session metadata. JWT token keys are
/// explicitly rejected by the database settings boundary.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
