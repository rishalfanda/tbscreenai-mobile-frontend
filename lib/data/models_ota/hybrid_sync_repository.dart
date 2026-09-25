import 'package:myapp/data/models_ota/model_update_service.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

/// Sources model-update calls from the real [ModelUpdateService] while
/// delegating data-backup calls to [backup] unchanged.
///
/// This is what makes the Sync Center's model-update card real even in
/// mock/demo mode: `backup` is a bare `MockSyncRepository` there (so the Data
/// Backup card keeps its seeded demo data untouched), but
/// `getInstalledModelVersion`/`checkForUpdate`/`downloadModel` are never
/// simulated. Mirrors `HybridDiagnosisRepository`'s decorator shape.
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
  Future<SyncSummary> getSyncSummary() => _backup.getSyncSummary();

  @override
  Future<List<Patient>> getBackupCandidates() => _backup.getBackupCandidates();

  @override
  Stream<int> uploadPatients(List<String> patientIds) =>
      _backup.uploadPatients(patientIds);
}
