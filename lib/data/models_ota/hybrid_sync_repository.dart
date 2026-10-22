import 'package:myapp/data/models_ota/model_update_service.dart';
import 'package:myapp/domain/models/available_model_bundle.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

/// Sources model-update calls from the real [ModelUpdateService] while
/// delegating data-backup calls to [backup] unchanged.
class HybridSyncRepository implements SyncRepository {
  HybridSyncRepository({
    required ModelUpdateService modelUpdate,
    required SyncRepository backup,
  }) : _modelUpdate = modelUpdate,
       _backup = backup;

  final ModelUpdateService _modelUpdate;
  final SyncRepository _backup;

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
  Future<List<AvailableModelBundle>> getAvailableModels({
    String? channel,
    bool? quantized,
    bool localOnly = false,
  }) =>
      _modelUpdate.fetchAvailableModels(
        channel: channel,
        quantized: quantized,
        localOnly: localOnly,
      );

  @override
  Future<List<String>> getInstalledModelKeys() =>
      _modelUpdate.getInstalledModelKeys();

  @override
  Stream<double> downloadModelBundle(AvailableModelBundle model) =>
      _modelUpdate.downloadModelBundle(model);

  @override
  Future<void> activateModelBundle(String bundleKey) =>
      _modelUpdate.activateModelBundle(bundleKey);

  @override
  Future<bool> verifyModelBundle(String bundleKey) =>
      _modelUpdate.verifyModelBundle(bundleKey);

  @override
  Future<void> deleteModelBundle(String bundleKey) =>
      _modelUpdate.deleteModelBundle(bundleKey);

  @override
  Future<SyncSummary> getSyncSummary() => _backup.getSyncSummary();

  @override
  Future<List<Patient>> getBackupCandidates() => _backup.getBackupCandidates();

  @override
  Stream<int> uploadPatients(List<String> patientIds) =>
      _backup.uploadPatients(patientIds);
}
