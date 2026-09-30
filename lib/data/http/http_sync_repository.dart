import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/patient_json.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

const _monthsId = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// "2025-06-10" → "10 Juni 2025" (display format the mock already used).
String _formatDateId(String isoDate) {
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return isoDate;
  return '${parsed.day} ${_monthsId[parsed.month - 1]} ${parsed.year}';
}

/// Legacy HTTP adapter; artifact installation and unqueued uploads are disabled.
class HttpSyncRepository implements SyncRepository {
  HttpSyncRepository(this._client);

  final ApiClient _client;

  static const _installedVersion = 'Not installed';

  @override
  Future<String> getInstalledModelVersion() async => _installedVersion;

  @override
  Future<ModelVersionInfo> checkForUpdate() async {
    final response = await _client.dio.get<Map<String, dynamic>?>(
      '/sync/model-version',
    );
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
    throw UnsupportedError(
      'Model installation disabled: signed artifact distribution unavailable.',
    );
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
    throw UnsupportedError('Use the durable offline sync queue.');
  }
}
