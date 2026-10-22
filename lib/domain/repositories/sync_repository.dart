import 'package:myapp/domain/models/available_model_bundle.dart';
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

  /// Fetches available model bundles across channels.
  /// When [localOnly] is true, only returns bundles currently stored on device
  /// without querying remote endpoints.
  Future<List<AvailableModelBundle>> getAvailableModels({
    String? channel,
    bool? quantized,
    bool localOnly = false,
  });

  /// Bundle keys of all models currently downloaded and verified on disk.
  Future<List<String>> getInstalledModelKeys();

  /// Downloads, verifies, and stages the specified model bundle.
  Stream<double> downloadModelBundle(AvailableModelBundle model);

  /// Activates an already-downloaded model bundle for inference without re-downloading.
  Future<void> activateModelBundle(String bundleKey);

  /// Verifies an existing downloaded model bundle on disk.
  Future<bool> verifyModelBundle(String bundleKey);

  /// Deletes an installed model bundle from local storage.
  /// If the deleted model was active, the active model is cleared (null).
  Future<void> deleteModelBundle(String bundleKey);

  Future<SyncSummary> getSyncSummary();

  /// Patients eligible for backup selection.
  Future<List<Patient>> getBackupCandidates();

  /// Uploads the selected patients, emitting the running uploaded count.
  Stream<int> uploadPatients(List<String> patientIds);
}
