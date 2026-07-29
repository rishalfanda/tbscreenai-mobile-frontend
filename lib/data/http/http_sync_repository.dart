import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/patient_json.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

const _monthsId = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// "2025-06-10" → "10 Juni 2025" (display format the mock already used).
String _formatDateId(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return '${parsed.day} ${_monthsId[parsed.month - 1]} ${parsed.year}';
}

/// Live Sync Center backend.
///
/// SCOPE FASE 3 (explicit cuts, wired for real in FASE 4):
/// - installed model version is a device-local fact; without local storage it
///   is fixed at v1.2.0 here.
/// - downloadModel / uploadPatients still emit the same simulated progress as
///   the mock — the real file download (download_url) and the /sync/push queue
///   need the FASE 4 local database.
class HttpSyncRepository implements SyncRepository {
  HttpSyncRepository(this._client);

  final ApiClient _client;

  static const _installedVersion = 'v1.2.0';

  @override
  Future<String> getInstalledModelVersion() async => _installedVersion;

  @override
  Future<ModelVersionInfo> checkForUpdate() async {
    final response =
        await _client.dio.get<Map<String, dynamic>?>('/sync/model-version');
    final data = response.data;
    if (data == null) {
      // No release published yet — report "up to date".
      return const ModelVersionInfo(
        currentVersion: _installedVersion,
        latestVersion: _installedVersion,
        fileSize: '-',
        releaseDate: '-',
        changelog: [],
      );
    }
    return ModelVersionInfo(
      currentVersion: _installedVersion,
      latestVersion: data['version'] as String,
      fileSize: '${data['file_size_mb']} MB',
      releaseDate: _formatDateId(data['release_date'] as String),
      changelog: List<String>.from(data['changelog'] as List? ?? const []),
    );
  }

  @override
  Stream<double> downloadModel() async* {
    // Simulated progress (see class doc) — cadence identical to the mock.
    var progress = 0.0;
    while (progress < 1.0) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      progress += 0.05;
      yield progress.clamp(0.0, 1.0);
    }
  }

  @override
  Future<SyncSummary> getSyncSummary() async {
    final response = await _client.dio.get<Map<String, dynamic>>('/sync/pull');
    final data = response.data!;
    final patients = data['patients'] as List? ?? const [];
    final diagnoses = data['diagnoses'] as List? ?? const [];
    return SyncSummary(
      totalPatients: patients.length,
      totalDiagnoses: diagnoses.length,
      // Rough footprint estimate until real image storage lands.
      totalSizeMB: (patients.length * 4).clamp(1, 9999),
      lastSyncDate: null,
    );
  }

  @override
  Future<List<Patient>> getBackupCandidates() async {
    final response = await _client.dio.get<List<dynamic>>('/patients');
    return (response.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(patientFromJson)
        .toList();
  }

  @override
  Stream<int> uploadPatients(List<String> patientIds) async* {
    // Simulated per-patient progress (see class doc) — real push queue in FASE 4.
    var uploaded = 0;
    while (uploaded < patientIds.length) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      uploaded++;
      yield uploaded;
    }
  }
}
