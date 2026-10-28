import 'package:flutter/foundation.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/models.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';

/// Mock Sync Center backend.
class MockSyncRepository implements SyncRepository {
  String? _activeModelKey = 'stable_2026.09.04';
  final Set<String> _installedKeys = {'stable_2026.09.04', 'beta_2026.09.04'};
  final Map<String, ModelBundleStatus> _modelStatuses = {
    'stable_2026.09.04': ModelBundleStatus.verified,
    'beta_2026.09.04': ModelBundleStatus.verificationFailed,
    'stable_2026.08.15': ModelBundleStatus.notDownloaded,
  };

  bool _downloadCancelled = false;

  @override
  Future<String?> getInstalledModelVersion() =>
      SynchronousFuture(_activeModelKey);

  @override
  Future<ModelVersionInfo> checkForUpdate() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final base = MockSeedData.modelVersionInfo;
    return ModelVersionInfo(
      currentVersion: _activeModelKey ?? '',
      latestVersion: base.latestVersion,
      fileSize: base.fileSize,
      releaseDate: base.releaseDate,
      changelog: base.changelog,
      downloadUrl: base.downloadUrl,
      sha256: base.sha256,
    );
  }

  @override
  void cancelModelDownload() {
    _downloadCancelled = true;
  }

  @override
  Stream<ModelDownloadProgress> downloadModelWithProgress({
    AvailableModelBundle? model,
  }) async* {
    _downloadCancelled = false;
    final total = model?.sizeBytes != null && model!.sizeBytes > 0
        ? model.sizeBytes
        : 528571936; // ~504 MB
    var fraction = 0.0;
    while (fraction < 1.0) {
      if (_downloadCancelled) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (_downloadCancelled) return;
      fraction = (fraction + 0.1).clamp(0.0, 1.0);
      final received = (fraction * total).round();
      yield ModelDownloadProgress(
        fraction: fraction,
        receivedBytes: received,
        totalBytes: total,
        bytesPerSecond: 2.4 * 1024 * 1024,
        speedText: '2.4 MB/s',
        phase: fraction < 1.0
            ? ModelInstallPhase.downloading
            : ModelInstallPhase.verifying,
      );
    }

    if (_downloadCancelled) return;

    final key = model?.id ?? 'stable_${MockSeedData.modelVersionInfo.latestVersion}';
    _installedKeys.add(key);
    _modelStatuses[key] = ModelBundleStatus.verified;

    yield ModelDownloadProgress(
      fraction: 1.0,
      receivedBytes: total,
      totalBytes: total,
      speedText: '',
      phase: ModelInstallPhase.completed,
    );
  }

  @override
  Stream<double> downloadModel() =>
      downloadModelWithProgress().map((p) => p.fraction);

  @override
  Future<(ModelVersionInfo, DateTime)?> lastKnownUpdateInfo() =>
      SynchronousFuture(null);

  @override
  Future<List<AvailableModelBundle>> getAvailableModels({
    String? channel,
    bool? quantized,
    bool localOnly = false,
  }) async {
    await Future<void>.delayed(
      Duration(milliseconds: localOnly ? 100 : 600),
    );
    return MockSeedData.availableModels.where((m) {
      if (localOnly && !_installedKeys.contains(m.id)) {
        return false;
      }
      if (channel != null && channel.isNotEmpty && channel != 'all') {
        if (m.channel.toLowerCase() != channel.toLowerCase()) return false;
      }
      if (quantized != null && m.quantized != quantized) {
        return false;
      }
      return true;
    }).map((m) {
      final status = _modelStatuses[m.id] ?? ModelBundleStatus.notDownloaded;
      return m.copyWith(
        isCurrent: _activeModelKey != null && m.id == _activeModelKey,
        localStatus: status,
        verificationError: status == ModelBundleStatus.verificationFailed
            ? 'Checksum SHA256 atau tanda tangan digital Ed25519 tidak cocok.'
            : null,
      );
    }).toList();
  }

  @override
  Future<List<String>> getInstalledModelKeys() =>
      SynchronousFuture(_installedKeys.toList());

  @override
  Stream<double> downloadModelBundle(AvailableModelBundle model) =>
      downloadModelWithProgress(model: model).map((p) => p.fraction);

  @override
  Future<bool> verifyModelBundle(String bundleKey) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _modelStatuses[bundleKey] = ModelBundleStatus.verified;
    _installedKeys.add(bundleKey);
    return true;
  }

  @override
  Future<void> activateModelBundle(String bundleKey) async {
    final status = _modelStatuses[bundleKey];
    if (status != ModelBundleStatus.verified) {
      throw StateError(
        'Model $bundleKey belum terverifikasi dan tidak dapat digunakan.',
      );
    }
    _installedKeys.add(bundleKey);
    _activeModelKey = bundleKey;
  }

  @override
  Future<void> deleteModelBundle(String bundleKey) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _installedKeys.remove(bundleKey);
    _modelStatuses[bundleKey] = ModelBundleStatus.notDownloaded;
    if (_activeModelKey == bundleKey) {
      _activeModelKey = null;
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
