import 'package:dio/dio.dart';

import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/mappers.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/models_ota/model_update_service.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

/// Sync Center backed by the local database and the real sync endpoints.
///
/// Replaces the FASE 3 stub: the installed model version is now persisted per
/// device, the backup summary counts real cached rows, and uploading pushes
/// the sync queue instead of ticking a fake progress bar. Model-update logic
/// itself lives in `ModelUpdateService` (shared with `HybridSyncRepository`
/// for mock/demo mode) — this class only owns the data-backup half.
class OfflineSyncRepository implements SyncRepository {
  OfflineSyncRepository({
    required AppDatabase db,
    required SettingsStore settings,
    required SyncEngine engine,
    required ModelUpdateService modelUpdate,
  }) : _db = db,
       _settings = settings,
       _engine = engine,
       _modelUpdate = modelUpdate;

  final AppDatabase _db;
  final SettingsStore _settings;
  final SyncEngine _engine;
  final ModelUpdateService _modelUpdate;

  /// Result of the most recent upload, surfaced to the UI after the stream ends.
  SyncReport? lastReport;

  @override
  Future<String?> getInstalledModelVersion() =>
      _modelUpdate.getInstalledModelVersion();

  @override
  Future<ModelVersionInfo> checkForUpdate() => _modelUpdate.checkForUpdate();

  @override
  Stream<double> downloadModel() => _modelUpdate.downloadModel();

  @override
  Future<(ModelVersionInfo, DateTime)?> lastKnownUpdateInfo() =>
      _modelUpdate.readCachedCheck();

  @override
  Future<SyncSummary> getSyncSummary() async {
    // Counts come from the local database — correct even with no connection.
    final patients = await _db.countPatients();
    final diagnoses = await _db.countDiagnoses();
    final lastSync = await _settings.readLastSyncAt();
    return SyncSummary(
      totalPatients: patients,
      totalDiagnoses: diagnoses,
      // Rough footprint estimate until X-ray images are stored locally.
      totalSizeMB: (patients * 4).clamp(0, 99999),
      lastSyncDate: lastSync,
    );
  }

  @override
  Future<List<Patient>> getBackupCandidates() async {
    final rows = await _db.allPatients();
    return rows.map(patientFromRow).toList();
  }

  /// Queues the selected patients, then flushes the queue to /sync/push.
  ///
  /// The count emitted is queue progress; the authoritative per-record verdict
  /// (applied / skipped / conflict / failed) lands in [lastReport].
  @override
  Stream<int> uploadPatients(List<String> patientCodes) async* {
    final session = _db.sessionGeneration;
    lastReport = null;
    final rows = await _db.allPatients();
    final selected = rows.where((r) => patientCodes.contains(r.code)).toList();

    var queued = 0;
    for (final row in selected) {
      if (session != _db.sessionGeneration) return;
      await _db.writeForSession(
        session,
        () => _engine.enqueuePatientUpdate(
          row.id,
          patientPayloadFromRow(row),
          baseVersion: row.serverVersion,
          baseUpdatedAt: row.updatedAt,
        ),
      );
      queued++;
      yield queued;
    }

    try {
      if (session != _db.sessionGeneration) return;
      lastReport = await _engine.sync();
    } on DioException {
      lastReport = SyncReport(
        applied: 0,
        skipped: 0,
        conflicts: 0,
        failed: selected.length,
      );
    }
  }
}
