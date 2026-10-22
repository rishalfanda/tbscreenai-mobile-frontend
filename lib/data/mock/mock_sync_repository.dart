import 'package:flutter/foundation.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/available_model_bundle.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/sync_summary.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

/// Mock Sync Center backend.
class MockSyncRepository implements SyncRepository {
  String _activeModelKey = 'stable_2026.09.04';
  final Set<String> _installedKeys = {'stable_2026.09.04'};

  @override
  Future<String> getInstalledModelVersion() =>
      SynchronousFuture(_activeModelKey);

  @override
  Future<ModelVersionInfo> checkForUpdate() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final base = MockSeedData.modelVersionInfo;
    return ModelVersionInfo(
      currentVersion: _activeModelKey,
      latestVersion: base.latestVersion,
      fileSize: base.fileSize,
      releaseDate: base.releaseDate,
      changelog: base.changelog,
      downloadUrl: base.downloadUrl,
      sha256: base.sha256,
    );
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
  Future<(ModelVersionInfo, DateTime)?> lastKnownUpdateInfo() =>
      SynchronousFuture(null);

  @override
  Future<List<AvailableModelBundle>> getAvailableModels({
    String? channel,
    bool? quantized,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return MockSeedData.availableModels.where((m) {
      if (channel != null && channel.isNotEmpty && channel != 'all') {
        if (m.channel.toLowerCase() != channel.toLowerCase()) return false;
      }
      if (quantized != null && m.quantized != quantized) {
        return false;
      }
      return true;
    }).map((m) {
      return m.copyWith(isCurrent: m.id == _activeModelKey);
    }).toList();
  }

  @override
  Future<List<String>> getInstalledModelKeys() =>
      SynchronousFuture(_installedKeys.toList());

  @override
  Stream<double> downloadModelBundle(AvailableModelBundle model) async* {
    var progress = 0.0;
    while (progress < 1.0) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      progress += 0.1;
      yield progress.clamp(0.0, 1.0);
    }
    _installedKeys.add(model.id);
    _activeModelKey = model.id;
  }

  @override
  Future<void> activateModelBundle(String bundleKey) async {
    _installedKeys.add(bundleKey);
    _activeModelKey = bundleKey;
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
