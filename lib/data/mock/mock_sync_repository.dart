import 'package:flutter/foundation.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

/// Mock Sync Center backend. Timings mirror the old SyncCenterScreen
/// simulation exactly: 2s update check, 300ms/5% download ticks,
/// 800ms per uploaded patient.
class MockSyncRepository implements SyncRepository {
  @override
  Future<String> getInstalledModelVersion() =>
      SynchronousFuture(MockSeedData.modelVersionInfo.currentVersion);

  @override
  Future<ModelVersionInfo> checkForUpdate() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return MockSeedData.modelVersionInfo;
  }

  @override
  Stream<double> downloadModel() async* {
    var progress = 0.0;
    while (progress < 1.0) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      progress += 0.05;
      yield progress.clamp(0.0, 1.0);
    }
  }

  @override
  Future<SyncSummary> getSyncSummary() =>
      SynchronousFuture(MockSeedData.syncSummary);

  @override
  Future<List<Patient>> getBackupCandidates() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.patients));

  @override
  Stream<int> uploadPatients(List<String> patientIds) async* {
    var uploaded = 0;
    while (uploaded < patientIds.length) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      uploaded++;
      yield uploaded;
    }
  }
}
