import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';

/// Contract for the Sync Center: AI model updates + medical-data backup.
/// Offline-first — every operation is user-initiated, never automatic.
abstract class SyncRepository {
  /// Version currently installed on this device (fast, local read). `null`
  /// means no model bundle is installed yet.
  Future<String?> getInstalledModelVersion();

  /// Contacts the update server. Mock: 2s simulated delay.
  Future<ModelVersionInfo> checkForUpdate();

  /// Downloads the latest model, emitting progress 0.0 → 1.0.
  Stream<double> downloadModel();

  /// The last update-check result persisted on this device, and when it was
  /// fetched — lets the Sync Center restore its Model Update card without
  /// re-querying the server every time the page opens. `null` if no check has
  /// ever completed.
  Future<(ModelVersionInfo, DateTime)?> lastKnownUpdateInfo();

  Future<SyncSummary> getSyncSummary();

  /// Patients eligible for backup selection.
  Future<List<Patient>> getBackupCandidates();

  /// Uploads the selected patients, emitting the running uploaded count.
  Stream<int> uploadPatients(List<String> patientIds);
}
