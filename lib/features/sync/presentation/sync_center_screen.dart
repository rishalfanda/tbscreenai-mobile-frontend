import 'package:myapp/core/localization/app_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/core/connectivity/connectivity_service.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/offline/offline_sync_repository.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/models.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/features/shared/presentation/model_initiation_dialog.dart';

class SyncCenterScreen extends StatelessWidget {
  const SyncCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.sp24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === Section: Header ===
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              AppText(
                'Sync Center',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const _ConnectionChip(),
            ],
          ),
          const SizedBox(height: AppTheme.sp24),
          // === Section: Cards (Side by side on wide, stacked on narrow) ===
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 880;
              if (stacked) {
                return const Column(
                  children: [
                    _ModelUpdateCard(),
                    SizedBox(height: AppTheme.sp24),
                    _DataBackupCard(),
                  ],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ModelUpdateCard()),
                  SizedBox(width: AppTheme.sp24),
                  Expanded(child: _DataBackupCard()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// === Section: Connection Chip ===

class _ConnectionChip extends StatefulWidget {
  const _ConnectionChip();

  @override
  State<_ConnectionChip> createState() => _ConnectionChipState();
}

class _ConnectionChipState extends State<_ConnectionChip> {
  final _connectivity = ConnectivityService();
  bool _isOnline = true;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _connectivity.checkNow().then((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
    _sub = _connectivity.onStatusChange.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _isOnline;
    return Chip(
      avatar: Icon(
        isOnline ? Icons.circle : Icons.wifi_off_rounded,
        size: 10,
        color: isOnline ? AppTheme.success : AppTheme.textSecondary,
      ),
      label: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOnline ? AppTheme.success : AppTheme.textSecondary,
        ),
      ),
      backgroundColor: isOnline
          ? AppTheme.success.withValues(alpha: 0.1)
          : AppTheme.textSecondary.withValues(alpha: 0.1),
      side: BorderSide(
        color: isOnline ? AppTheme.success : AppTheme.textSecondary,
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

// === Section: Model Update Card ===

enum _ModelSyncState {
  idle,
  checking,
  upToDate,
  readyToActivate,
  updateAvailable,
  downloading,
  verifying,
  verificationFailed,
  activating,
  done,
  error,
}

class _ModelUpdateCard extends StatefulWidget {
  const _ModelUpdateCard();

  @override
  State<_ModelUpdateCard> createState() => _ModelUpdateCardState();
}

class _ModelUpdateCardState extends State<_ModelUpdateCard> {
  _ModelSyncState _state = _ModelSyncState.idle;
  double _progress = 0.0;
  String _downloadSpeed = '';
  String _currentVersion = '';
  ModelVersionInfo? _updateInfo;
  AvailableModelBundle? _matchedLocalBundle;
  DateTime? _lastChecked;
  String? _errorMessage;
  StreamSubscription<ModelDownloadProgress>? _downloadSub;

  List<AvailableModelBundle> _storedModels = [];
  bool _showStoredModels = false;

  final _connectivity = ConnectivityService();
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _refreshInstalledState();

    _connectivity.checkNow().then((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
    _connectivitySub = _connectivity.onStatusChange.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
  }

  Future<void> _refreshInstalledState() async {
    final repository = context.read<SyncRepository>();
    final version = await repository.getInstalledModelVersion();
    final localModels = await repository.getAvailableModels(localOnly: true);
    if (!mounted) return;
    setState(() {
      _currentVersion = version ?? '';
      _storedModels = localModels;
    });

    final cached = await repository.lastKnownUpdateInfo();
    if (!mounted) return;
    if (cached != null) {
      final (info, checkedAt) = cached;
      _updateInfo = info;
      _lastChecked = checkedAt;
      _evaluateModelStatus(info, localModels, version);
    }
  }

  void _evaluateModelStatus(
    ModelVersionInfo info,
    List<AvailableModelBundle> localModels,
    String? currentVersion,
  ) {
    AvailableModelBundle? match;
    for (final m in localModels) {
      if (m.version.toLowerCase().trim() == info.latestVersion.toLowerCase().trim() ||
          m.id.toLowerCase().trim() == info.latestVersion.toLowerCase().trim() ||
          m.id.toLowerCase().trim().endsWith('_${info.latestVersion.toLowerCase().trim()}')) {
        match = m;
        break;
      }
    }

    _matchedLocalBundle = match;

    if (match != null) {
      final isActive = currentVersion != null &&
          (currentVersion.toLowerCase().trim() == match.id.toLowerCase().trim() ||
           currentVersion.toLowerCase().trim() == match.version.toLowerCase().trim());

      if (isActive && match.isVerified) {
        _state = _ModelSyncState.upToDate;
      } else if (match.isVerificationFailed) {
        _state = _ModelSyncState.verificationFailed;
      } else if (match.isVerified) {
        _state = _ModelSyncState.readyToActivate;
      } else {
        _state = _ModelSyncState.updateAvailable;
      }
    } else {
      final hasNew = info.latestVersion.isNotEmpty &&
          info.latestVersion != currentVersion;
      _state = hasNew ? _ModelSyncState.updateAvailable : _ModelSyncState.upToDate;
    }
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    if (!_isOnline) {
      setState(() {
        _state = _ModelSyncState.error;
        _errorMessage = 'Tidak ada koneksi internet. Hubungkan perangkat dan coba lagi.';
      });
      return;
    }

    setState(() {
      _state = _ModelSyncState.checking;
      _errorMessage = null;
    });

    final repository = context.read<SyncRepository>();
    try {
      final info = await repository.checkForUpdate();
      final localModels = await repository.getAvailableModels(localOnly: true);
      final currentVersion = await repository.getInstalledModelVersion();
      if (!mounted) return;
      setState(() {
        _updateInfo = info;
        _lastChecked = DateTime.now();
        _currentVersion = currentVersion ?? '';
        _storedModels = localModels;
        _evaluateModelStatus(info, localModels, currentVersion);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ModelSyncState.error;
        _errorMessage = 'Gagal memeriksa pembaruan model: $e';
      });
    }
  }

  void _startDownload() {
    if (!_isOnline) {
      setState(() {
        _state = _ModelSyncState.error;
        _errorMessage = 'Tidak ada koneksi internet. Hubungkan perangkat dan coba lagi.';
      });
      return;
    }

    final repository = context.read<SyncRepository>();
    setState(() {
      _state = _ModelSyncState.downloading;
      _progress = 0.0;
      _downloadSpeed = '';
      _errorMessage = null;
    });

    _downloadSub?.cancel();
    _downloadSub = repository
        .downloadModelWithProgress()
        .listen(
          (progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress.fraction;
              _downloadSpeed = progress.speedText;
              if (progress.phase == ModelInstallPhase.verifying) {
                _state = _ModelSyncState.verifying;
              } else if (progress.phase == ModelInstallPhase.activating) {
                _state = _ModelSyncState.activating;
              }
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            if (error is ModelInstallCancelledException) {
              setState(() {
                _state = _ModelSyncState.updateAvailable;
                _progress = 0.0;
                _downloadSpeed = '';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: AppText('Unduhan model dibatalkan.')),
              );
              return;
            }
            setState(() {
              _state = _ModelSyncState.error;
              _errorMessage = 'Gagal mengunduh atau memverifikasi model: $error';
            });
          },
          onDone: () async {
            if (!mounted) return;
            final newVersion = await repository.getInstalledModelVersion();
            final localModels = await repository.getAvailableModels(localOnly: true);
            if (!mounted) return;
            setState(() {
              _currentVersion = newVersion ?? (_updateInfo?.latestVersion ?? '');
              _storedModels = localModels;
              _state = _ModelSyncState.done;
              _progress = 1.0;
              _downloadSpeed = '';
            });

            OnnxInferenceEngine? engine;
            try {
              engine = context.read<OnnxInferenceEngine>();
            } catch (_) {}
            if (engine != null && mounted) {
              await initiateModelStandbyWithDialog(
                context,
                engine,
                message: 'Model berhasil diunduh. Menyiapkan model agar siap digunakan...',
              );
            }
          },
        );
  }

  void _cancelDownload() {
    final repository = context.read<SyncRepository>();
    repository.cancelModelDownload();
    _downloadSub?.cancel();
    setState(() {
      _state = _ModelSyncState.updateAvailable;
      _progress = 0.0;
      _downloadSpeed = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: AppText('Unduhan model dibatalkan.')),
    );
  }

  Future<void> _activateBundle(String bundleKey) async {
    final repository = context.read<SyncRepository>();
    setState(() => _state = _ModelSyncState.activating);
    try {
      await repository.activateModelBundle(bundleKey);
      await _refreshInstalledState();
      if (!mounted) return;
      setState(() => _state = _ModelSyncState.done);

      OnnxInferenceEngine? engine;
      try {
        engine = context.read<OnnxInferenceEngine>();
      } catch (_) {}
      if (engine != null && mounted) {
        await initiateModelStandbyWithDialog(
          context,
          engine,
          message: 'Model berhasil diaktifkan. Menyiapkan model agar siap digunakan...',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ModelSyncState.error;
        _errorMessage = 'Gagal mengaktifkan model: $e';
      });
    }
  }

  Future<void> _verifyBundle(String bundleKey) async {
    final repository = context.read<SyncRepository>();
    setState(() => _state = _ModelSyncState.verifying);
    try {
      final success = await repository.verifyModelBundle(bundleKey);
      await _refreshInstalledState();
      if (!mounted) return;
      setState(() => _state = _ModelSyncState.idle);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verifikasi integritas model berhasil.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ModelSyncState.verificationFailed;
        _errorMessage = 'Verifikasi ulang gagal: $e';
      });
    }
  }

  Future<void> _confirmDelete(AvailableModelBundle model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Model v${model.version}?'),
        content: Text(
          'Model ${model.channel.toUpperCase()} v${model.version} akan dihapus dari penyimpanan perangkat. '
          '${model.isCurrent ? "PERINGATAN: Model ini sedang aktif digunakan untuk inferensi." : "Tindakan ini akan membebaskan ruang memori."}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repository = context.read<SyncRepository>();
      await repository.deleteModelBundle(model.id);
      await _refreshInstalledState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Model v${model.version} berhasil dihapus.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTheme.sp12),
                Expanded(
                  child: AppText(
                    'Pembaruan Model AI',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp16),

            // Active Model Banner
            _buildActiveModelBanner(),
            const SizedBox(height: AppTheme.sp16),

            // State View
            switch (_state) {
              _ModelSyncState.idle => _buildIdle(context),
              _ModelSyncState.checking => _buildChecking(),
              _ModelSyncState.upToDate => _buildUpToDate(context),
              _ModelSyncState.readyToActivate => _buildReadyToActivate(context),
              _ModelSyncState.updateAvailable => _buildUpdateAvailable(context),
              _ModelSyncState.downloading => _buildDownloading(),
              _ModelSyncState.verifying => _buildVerifying(),
              _ModelSyncState.verificationFailed => _buildVerificationFailed(context),
              _ModelSyncState.activating => _buildActivating(),
              _ModelSyncState.done => _buildDone(context),
              _ModelSyncState.error => _buildError(context),
            },

            // Stored Models Expandable Section
            const SizedBox(height: AppTheme.sp24),
            const Divider(color: AppTheme.borderLight),
            const SizedBox(height: AppTheme.sp8),
            _buildStoredModelsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveModelBanner() {
    final hasActive = _currentVersion.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: hasActive
            ? AppTheme.primary.withValues(alpha: 0.05)
            : AppTheme.borderLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasActive
              ? AppTheme.primary.withValues(alpha: 0.2)
              : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasActive ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 20,
            color: hasActive ? AppTheme.primary : AppTheme.textSecondary,
          ),
          const SizedBox(width: AppTheme.sp8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasActive ? 'Model AI Aktif' : 'Belum Ada Model Aktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasActive ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
                Text(
                  hasActive ? _currentVersion : 'TIDAK ADA MODEL AKTIF',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
              ],
            ),
          ),
          if (hasActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'SIAP INFERENSI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_lastChecked != null) ...[
          Text(
            'Terakhir diperiksa: ${_formatDate(_lastChecked!)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: AppTheme.sp16),
        ],
        ElevatedButton.icon(
          onPressed: _checkForUpdate,
          icon: const Icon(Icons.sync_rounded, size: 18),
          label: const AppText('Periksa Pembaruan Model'),
        ),
      ],
    );
  }

  Widget _buildChecking() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.sp16),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppTheme.sp12),
          Text(
            'Memeriksa server...',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpToDate(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 24),
            const SizedBox(width: AppTheme.sp8),
            Text(
              'Model versi terbaru terpasang',
              style: TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        if (_lastChecked != null) ...[
          const SizedBox(height: AppTheme.sp4),
          Text(
            'Terakhir diperiksa: ${_formatDate(_lastChecked!)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
        const SizedBox(height: AppTheme.sp16),
        OutlinedButton.icon(
          onPressed: _checkForUpdate,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Periksa Lagi'),
        ),
      ],
    );
  }

  Widget _buildReadyToActivate(BuildContext context) {
    final bundle = _matchedLocalBundle;
    final ver = bundle?.version ?? _updateInfo?.latestVersion ?? '';
    final id = bundle?.id ?? ver;

    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.download_done_rounded, color: AppTheme.primary, size: 24),
              const SizedBox(width: AppTheme.sp8),
              const Expanded(
                child: Text(
                  'Model Terbaru Sudah Tersimpan di Perangkat',
                  style: TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp8),
          Text(
            'Versi $ver telah diverifikasi dan siap digunakan tanpa perlu mengunduh ulang.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: AppTheme.sp16),
          FilledButton.icon(
            onPressed: () => _activateBundle(id),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Aktifkan Model'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationFailed(BuildContext context) {
    final bundle = _matchedLocalBundle;
    final ver = bundle?.version ?? _updateInfo?.latestVersion ?? '';
    final id = bundle?.id ?? ver;

    return Container(
      padding: const EdgeInsets.all(AppTheme.sp16),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 24),
              const SizedBox(width: AppTheme.sp8),
              Expanded(
                child: Text(
                  'Verifikasi Integritas Model Gagal',
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sp8),
          Text(
            bundle?.verificationError ??
                'Checksum atau tanda tangan digital model v$ver tidak cocok.',
            style: const TextStyle(color: AppTheme.navy, fontSize: 13),
          ),
          const SizedBox(height: AppTheme.sp16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _verifyBundle(id),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('Verify Ulang'),
              ),
              const SizedBox(width: AppTheme.sp12),
              OutlinedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Unduh Ulang'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateAvailable(BuildContext context) {
    final info = _updateInfo;
    if (info == null) return _buildIdle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.new_releases_rounded, color: AppTheme.primary, size: 22),
            const SizedBox(width: AppTheme.sp8),
            Text(
              'Versi Baru Tersedia',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp12),
        _InfoRow('Versi Baru', info.latestVersion.startsWith('v') ? info.latestVersion : 'v${info.latestVersion}'),
        _InfoRow('Ukuran', info.fileSize),
        _InfoRow('Tanggal Rilis', info.releaseDate),
        if (info.changelog.isNotEmpty) ...[
          const SizedBox(height: AppTheme.sp8),
          const Text(
            'Catatan Pembaruan:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: AppTheme.sp4),
          ...info.changelog.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('â€¢ ', style: TextStyle(color: AppTheme.textSecondary)),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppTheme.sp16),
        ElevatedButton(
          onPressed: _startDownload,
          child: const AppText('Perbarui Sekarang'),
        ),
      ],
    );
  }

  Widget _buildDownloading() {
    final pct = (_progress * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Mengunduh model AI...',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.navy),
            ),
            const Spacer(),
            if (_downloadSpeed.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _downloadSpeed,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.sp12),
        LinearProgressIndicator(
          value: _progress > 0 ? _progress : null,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: AppTheme.sp8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$pct% selesai',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _cancelDownload,
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const AppText('Batal'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerifying() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.sp16),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppTheme.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Memverifikasi integritas model...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Memeriksa checksum SHA256 & tanda tangan digital Ed25519.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivating() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.sp16),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: AppTheme.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mengaktifkan model & inisialisasi mesin inferensi...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navy,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Memuat session ONNX Runtime dan menjalankan smoke test.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            const SizedBox(width: AppTheme.sp8),
            Expanded(
              child: Text(
                'Pembaruan Selesai',
                style: TextStyle(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        Text(
          'Model AI versi $_currentVersion berhasil diaktifkan dan siap digunakan.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: AppTheme.sp16),
        TextButton(
          onPressed: () => setState(() => _state = _ModelSyncState.idle),
          child: const Text('Selesai'),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.error_rounded, color: AppTheme.error, size: 28),
            const SizedBox(width: AppTheme.sp8),
            Expanded(
              child: Text(
                _errorMessage ?? 'Gagal menghubungi server',
                style: const TextStyle(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp12),
        TextButton(
          onPressed: () => setState(() {
            _state = _ModelSyncState.idle;
            _errorMessage = null;
          }),
          child: const Text('Coba Lagi'),
        ),
      ],
    );
  }

  // === Section: Stored Models List (Expandable Container) ===

  Widget _buildStoredModelsSection() {
    final count = _storedModels.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _showStoredModels = !_showStoredModels),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
                  color: AppTheme.navy,
                ),
                const SizedBox(width: AppTheme.sp8),
                Expanded(
                  child: Text(
                    'Model Tersimpan di Perangkat ($count)',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                Icon(
                  _showStoredModels
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_showStoredModels) ...[
          const SizedBox(height: AppTheme.sp12),
          if (_storedModels.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada model tersimpan di perangkat.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            )
          else
            ..._storedModels.map(_buildStoredModelItem),
        ],
      ],
    );
  }

  Widget _buildStoredModelItem(AvailableModelBundle model) {
    final isActive = model.isCurrent;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.sp8),
      padding: const EdgeInsets.all(AppTheme.sp12),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withValues(alpha: 0.04)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'v${model.version}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(width: AppTheme.sp8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        model.channel.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: AppTheme.sp8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Aktif',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      model.formattedSize,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'â€¢',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(model),
                  ],
                ),
              ],
            ),
          ),
          // Actions
          if (!isActive && model.isVerified)
            TextButton(
              onPressed: () => _activateBundle(model.id),
              child: const Text('Gunakan', style: TextStyle(fontSize: 12)),
            )
          else if (!isActive && model.isVerificationFailed)
            TextButton(
              onPressed: () => _verifyBundle(model.id),
              child: const Text('Verify Ulang', style: TextStyle(fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            tooltip: 'Hapus model',
            onPressed: () => _confirmDelete(model),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(AvailableModelBundle model) {
    if (model.isVerified) {
      return const Text(
        'Terverifikasi',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.success,
        ),
      );
    }
    if (model.isVerificationFailed) {
      return const Text(
        'Gagal Verifikasi',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.error,
        ),
      );
    }
    return const Text(
      'Diunduh',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.warning,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// === Section: Data Backup Card ===

enum _DataSyncState { idle, selection, uploading, done, error }

class _DataBackupCard extends StatefulWidget {
  const _DataBackupCard();

  @override
  State<_DataBackupCard> createState() => _DataBackupCardState();
}

class _DataBackupCardState extends State<_DataBackupCard> {
  _DataSyncState _state = _DataSyncState.idle;
  final Set<String> _selectedIds = {};
  int _uploadedCount = 0;
  SyncSummary? _summary;
  List<Patient> _candidates = const [];
  SyncReport? _report;

  final _connectivity = ConnectivityService();
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    final repository = context.read<SyncRepository>();
    repository.getSyncSummary().then((summary) {
      if (!mounted) return;
      setState(() => _summary = summary);
    });

    _connectivity.checkNow().then((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
    _connectivitySub = _connectivity.onStatusChange.listen((online) {
      if (!mounted) return;
      setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _openConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ConsentDialog(),
    );
    if (confirmed == true && mounted) {
      final repository = context.read<SyncRepository>();
      final candidates = await repository.getBackupCandidates();
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _selectedIds
          ..clear()
          ..addAll(candidates.map((p) => p.id));
        _state = _DataSyncState.selection;
      });
    }
  }

  void _startUpload() {
    if (!_isOnline) {
      setState(() => _state = _DataSyncState.error);
      return;
    }

    final repository = context.read<SyncRepository>();
    setState(() {
      _state = _DataSyncState.uploading;
      _uploadedCount = 0;
    });

    repository
        .uploadPatients(_selectedIds.toList())
        .listen(
          (count) {
            if (!mounted) return;
            setState(() => _uploadedCount = count);
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => _state = _DataSyncState.error);
          },
          onDone: () {
            if (!mounted) return;
            final report = repository is OfflineSyncRepository
                ? repository.lastReport
                : null;
            repository.getSyncSummary().then((updated) {
              if (!mounted) return;
              setState(() {
                _summary = updated;
                _report = report;
                _state = _DataSyncState.done;
              });
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: AppTheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTheme.sp12),
                Expanded(
                  child: AppText(
                    'Cadangan Data Medis',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.sp16),
            switch (_state) {
              _DataSyncState.idle => _buildIdle(context),
              _DataSyncState.selection => _buildSelection(context),
              _DataSyncState.uploading => _buildUploading(),
              _DataSyncState.done => _buildDone(context),
              _DataSyncState.error => _buildError(context),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildIdle(BuildContext context) {
    final summary = _summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          'Total Pasien',
          summary != null ? '${summary.totalPatients} pasien' : '...',
        ),
        _InfoRow(
          'Total Diagnosis',
          summary != null ? '${summary.totalDiagnoses} data' : '...',
        ),
        _InfoRow(
          'Estimasi Ukuran',
          summary != null ? '~${summary.totalSizeMB} MB' : '...',
        ),
        _InfoRow(
          'Terakhir Cadang',
          summary?.lastSyncDate != null
              ? _formatDate(summary!.lastSyncDate!)
              : 'Belum pernah',
        ),
        const SizedBox(height: AppTheme.sp16),
        ElevatedButton.icon(
          onPressed: _openConsent,
          icon: const Icon(Icons.backup_rounded, size: 18),
          label: const Text('Pilih Data & Unggah'),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _buildSelection(BuildContext context) {
    final allSelected =
        _selectedIds.length == _candidates.length && _candidates.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Pilih Pasien untuk Dicadangkan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                setState(() {
                  if (allSelected) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds
                      ..clear()
                      ..addAll(_candidates.map((p) => p.id));
                  }
                });
              },
              child: Text(allSelected ? 'Batal Semua' : 'Pilih Semua'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderLight),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _candidates.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.sp16),
                    child: Text(
                      'Tidak ada data pasien untuk dicadangkan.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _candidates.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppTheme.borderLight),
                  itemBuilder: (context, index) {
                    final patient = _candidates[index];
                    final checked = _selectedIds.contains(patient.id);
                    return CheckboxListTile(
                      dense: true,
                      value: checked,
                      title: Text(
                        '${patient.name} (${patient.id})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${patient.age} th â€¢ ${patient.gender == 'M' ? 'Laki-laki' : 'Perempuan'}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.add(patient.id);
                          } else {
                            _selectedIds.remove(patient.id);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
        const SizedBox(height: AppTheme.sp16),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _state = _DataSyncState.idle),
              child: const AppText('Batal'),
            ),
            const SizedBox(width: AppTheme.sp8),
            Text(
              '${_selectedIds.length} dipilih',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _selectedIds.isEmpty ? null : _startUpload,
              child: const Text('Mulai Unggah'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUploading() {
    final total = _selectedIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mengunggah data pasien...',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppTheme.sp12),
        LinearProgressIndicator(
          value: total > 0 ? _uploadedCount / total : null,
        ),
        const SizedBox(height: AppTheme.sp8),
        Text(
          'Mengunggah $_uploadedCount/$total pasien...',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final report = _report;
    final hasProblems = report?.hasProblems ?? false;
    final succeeded = report != null
        ? report.applied + report.skipped
        : _uploadedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasProblems
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: hasProblems ? AppTheme.warning : AppTheme.success,
              size: 28,
            ),
            const SizedBox(width: AppTheme.sp8),
            Text(
              hasProblems
                  ? 'Sinkronisasi selesai sebagian'
                  : 'Sinkronisasi selesai',
              style: TextStyle(
                color: hasProblems ? AppTheme.warning : AppTheme.success,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        Text(
          '$succeeded pasien berhasil diunggah',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        if (report != null && report.conflicts > 0) ...[
          const SizedBox(height: AppTheme.sp12),
          Container(
            padding: const EdgeInsets.all(AppTheme.sp12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.merge_type_rounded,
                  color: AppTheme.warning,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.sp8),
                Expanded(
                  child: Text(
                    '${report.conflicts} data konflik â€” versi di server lebih baru. '
                    'Data TIDAK ditimpa; perlu ditinjau manual oleh dokter.',
                    style: const TextStyle(fontSize: 13, color: AppTheme.navy),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (report != null && report.failed > 0) ...[
          const SizedBox(height: AppTheme.sp8),
          Text(
            '${report.failed} gagal terkirim â€” tetap tersimpan di antrean, '
            'akan dicoba lagi saat sinkronisasi berikutnya.',
            style: const TextStyle(fontSize: 13, color: AppTheme.error),
          ),
        ],
        const SizedBox(height: AppTheme.sp16),
        TextButton(
          onPressed: () => setState(() {
            _state = _DataSyncState.idle;
            _selectedIds.clear();
            _uploadedCount = 0;
            _report = null;
          }),
          child: const Text('Selesai'),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.error_rounded, color: AppTheme.error, size: 28),
            SizedBox(width: AppTheme.sp8),
            Text(
              'Tidak ada koneksi internet. Hubungkan perangkat dan coba lagi.',
              style: TextStyle(color: AppTheme.error),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.sp12),
        TextButton(
          onPressed: () => setState(() => _state = _DataSyncState.idle),
          child: const Text('Coba Lagi'),
        ),
      ],
    );
  }
}

// === Section: Consent Dialog ===

class _ConsentDialog extends StatefulWidget {
  const _ConsentDialog();

  @override
  State<_ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<_ConsentDialog> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.security_rounded, color: AppTheme.primary),
          SizedBox(width: AppTheme.sp8),
          Text(
            'Konfirmasi Pengiriman Data',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data medis pasien (rekam medis dan citra X-Ray) akan diunggah ke server '
              'pusat TB Screen AI melalui koneksi terenkripsi (TLS 1.3).',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: AppTheme.sp12),
            Container(
              padding: const EdgeInsets.all(AppTheme.sp12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_rounded, size: 16, color: AppTheme.primary),
                  SizedBox(width: AppTheme.sp8),
                  Expanded(
                    child: Text(
                      'Data dide-identifikasi sesuai standar privasi data medis sebelum dikirim.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.sp16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agreed,
              onChanged: (val) => setState(() => _agreed = val ?? false),
              title: const Text(
                'Saya mengonfirmasi bahwa data ini siap dicadangkan ke server pusat '
                'dan persetujuan pasien telah diperoleh.',
                style: TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const AppText('Batal'),
        ),
        ElevatedButton(
          onPressed: _agreed ? () => Navigator.pop(context, true) : null,
          child: const Text('Lanjutkan'),
        ),
      ],
    );
  }
}
