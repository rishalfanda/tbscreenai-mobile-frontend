import 'package:dio/dio.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/mappers.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

const _monthsId = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// "2025-06-10" → "10 Juni 2025"
String _formatDateId(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return '${parsed.day} ${_monthsId[parsed.month - 1]} ${parsed.year}';
}

/// Sync Center backed by the local database and the real sync endpoints.
///
/// Replaces the FASE 3 stub: the installed model version is now persisted per
/// device, the backup summary counts real cached rows, and uploading pushes
/// the sync queue instead of ticking a fake progress bar.
class OfflineSyncRepository implements SyncRepository {
  OfflineSyncRepository({
    required AppDatabase db,
    required ApiClient client,
    required SettingsStore settings,
    required SyncEngine engine,
  })  : _db = db,
        _client = client,
        _settings = settings,
        _engine = engine;

  final AppDatabase _db;
  final ApiClient _client;
  final SettingsStore _settings;
  final SyncEngine _engine;

  /// Result of the most recent upload, surfaced to the UI after the stream ends.
  SyncReport? lastReport;

  @override
  Future<String> getInstalledModelVersion() =>
      _settings.readInstalledModelVersion();

  @override
  Future<ModelVersionInfo> checkForUpdate() async {
    final installed = await _settings.readInstalledModelVersion();
    final response =
        await _client.dio.get<Map<String, dynamic>?>('/sync/model-version');
    final data = response.data;
    if (data == null) {
      return ModelVersionInfo(
        currentVersion: installed,
        latestVersion: installed,
        fileSize: '-',
        releaseDate: '-',
        changelog: const [],
      );
    }
    return ModelVersionInfo(
      currentVersion: installed,
      latestVersion: data['version'] as String,
      fileSize: '${data['file_size_mb']} MB',
      releaseDate: _formatDateId(data['release_date'] as String),
      changelog: List<String>.from(data['changelog'] as List? ?? const []),
    );
  }

  /// Emits download progress, then records the new version on this device.
  ///
  /// SCOPE: the model binary itself is not fetched yet — the backend exposes
  /// `download_url` but serves no file. What IS real now is that the installed
  /// version persists, so the next check compares against the right baseline.
  @override
  Stream<double> downloadModel() async* {
    final info = await checkForUpdate();
    var progress = 0.0;
    while (progress < 1.0) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      progress += 0.05;
      yield progress.clamp(0.0, 1.0);
    }
    await _settings.saveInstalledModelVersion(info.latestVersion);
  }

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
    lastReport = null;
    final rows = await _db.allPatients();
    final selected =
        rows.where((r) => patientCodes.contains(r.code)).toList();

    var queued = 0;
    for (final row in selected) {
      await _engine.enqueuePatientUpdate(
        row.id,
        patientPayloadFromRow(row),
        baseUpdatedAt: row.updatedAt,
      );
      queued++;
      yield queued;
    }

    try {
      lastReport = await _engine.push();
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
