import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';

/// Contract for the Sync Center: AI model updates + medical-data backup.
/// Offline-first — every operation is user-initiated, never automatic.
abstract class SyncRepository {
  /// Version currently installed on this device (fast, local read).
  Future<String> getInstalledModelVersion();

  /// Contacts the update server. Mock: 2s simulated delay.
  Future<ModelVersionInfo> checkForUpdate();

  /// Downloads the latest model, emitting progress 0.0 → 1.0.
  Stream<double> downloadModel();

  Future<SyncSummary> getSyncSummary();

  /// Patients eligible for backup selection.
  Future<List<Patient>> getBackupCandidates();

  /// Uploads the selected patients, emitting the running uploaded count.
  Stream<int> uploadPatients(List<String> patientIds);
}
