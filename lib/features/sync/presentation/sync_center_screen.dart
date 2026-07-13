import 'dart:async';
import 'package:flutter/material.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/mock_data.dart';

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
          Row(
            children: [
              Text(
                'Sync Center',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
              ),
              const Spacer(),
              const _ConnectionChip(isOnline: true),
            ],
          ),
          const SizedBox(height: AppTheme.sp24),
          // === Section: Cards ===
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

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
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

enum _ModelSyncState { idle, checking, upToDate, updateAvailable, downloading, done, error }

class _ModelUpdateCard extends StatefulWidget {
  const _ModelUpdateCard();

  @override
  State<_ModelUpdateCard> createState() => _ModelUpdateCardState();
}

class _ModelUpdateCardState extends State<_ModelUpdateCard> {
  _ModelSyncState _state = _ModelSyncState.idle;
  double _progress = 0.0;
  String _currentVersion = MockData.modelInfo['currentVersion'] as String;
  DateTime? _lastChecked;
  Timer? _downloadTimer;

  @override
  void dispose() {
    _downloadTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _state = _ModelSyncState.checking;
      _lastChecked = DateTime.now();
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _state = _ModelSyncState.updateAvailable);
  }

  void _startDownload() {
    setState(() {
      _state = _ModelSyncState.downloading;
      _progress = 0.0;
    });
    _downloadTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _progress += 0.05);
      if (_progress >= 1.0) {
        timer.cancel();
        _onDownloadDone();
      }
    });
  }

  void _onDownloadDone() {
    if (!mounted) return;
    final newVersion = MockData.modelInfo['latestVersion'] as String;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Model berhasil diperbarui ke $newVersion')),
    );
    setState(() {
      _state = _ModelSyncState.idle;
      _currentVersion = newVersion;
      _progress = 0.0;
    });
  }

  String _formatLastChecked() {
    if (_lastChecked == null) return '—';
    final h = _lastChecked!.hour.toString().padLeft(2, '0');
    final m = _lastChecked!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pembaruan Model AI',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
            ),
            const SizedBox(height: AppTheme.sp16),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _ModelSyncState.idle:
        return _buildIdle(context);
      case _ModelSyncState.checking:
        return _buildChecking();
      case _ModelSyncState.upToDate:
        return _buildUpToDate(context);
      case _ModelSyncState.updateAvailable:
        return _buildUpdateAvailable(context);
      case _ModelSyncState.downloading:
        return _buildDownloading();
      case _ModelSyncState.done:
        return _buildIdle(context);
      case _ModelSyncState.error:
        return _buildError(context);
    }
  }

  Widget _buildIdle(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Versi Saat Ini: $_currentVersion',
            style: const TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: AppTheme.sp4),
        Text('Terakhir diperiksa: ${_formatLastChecked()}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: AppTheme.sp16),
        ElevatedButton.icon(
          onPressed: _checkForUpdate,
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('Periksa Pembaruan Model'),
        ),
      ],
    );
  }

  Widget _buildChecking() {
    return const Column(
      children: [
        SizedBox(height: AppTheme.sp8),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: AppTheme.sp12),
            Text('Memeriksa server...'),
          ],
        ),
        SizedBox(height: AppTheme.sp8),
      ],
    );
  }

  Widget _buildUpToDate(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 32),
            const SizedBox(width: AppTheme.sp12),
            Text('Model sudah versi terbaru ($_currentVersion)',
                style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: AppTheme.sp16),
        TextButton(
          onPressed: _checkForUpdate,
          child: const Text('Periksa Ulang'),
        ),
      ],
    );
  }

  Widget _buildUpdateAvailable(BuildContext context) {
    final info = MockData.modelInfo;
    final changelog = info['changelog'] as List<String>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: const Text('Versi Baru Tersedia',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          backgroundColor: AppTheme.warning.withValues(alpha: 0.15),
          side: BorderSide(color: AppTheme.warning.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: AppTheme.sp16),
        // Info table
        _InfoRow('Versi Saat Ini', _currentVersion),
        _InfoRow('Versi Baru', info['latestVersion'] as String),
        _InfoRow('Ukuran File', info['fileSize'] as String),
        _InfoRow('Tanggal Rilis', info['releaseDate'] as String),
        const SizedBox(height: AppTheme.sp8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Lihat Changelog',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          children: changelog
              .map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.textSecondary)),
                        Expanded(child: Text(c, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppTheme.sp16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _startDownload,
                child: const Text('Perbarui Sekarang'),
              ),
            ),
            const SizedBox(width: AppTheme.sp12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _state = _ModelSyncState.idle),
                child: const Text('Lewati'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDownloading() {
    final fileSizeMB = double.tryParse(
            (MockData.modelInfo['fileSize'] as String).replaceAll(' MB', '')) ??
        47.2;
    final downloaded = (_progress * fileSizeMB).toStringAsFixed(1);
    final percent = (_progress * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mengunduh pembaruan model...'),
        const SizedBox(height: AppTheme.sp12),
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: AppTheme.sp8),
        Text('$percent% · $downloaded MB / ${MockData.modelInfo['fileSize']}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
            Text('Gagal menghubungi server',
                style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: AppTheme.sp12),
        TextButton(
          onPressed: () => setState(() => _state = _ModelSyncState.idle),
          child: const Text('Coba Lagi'),
        ),
      ],
    );
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
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
  DateTime? _lastSyncDate;
  Timer? _uploadTimer;

  @override
  void dispose() {
    _uploadTimer?.cancel();
    super.dispose();
  }

  Future<void> _showConsentDialog() async {
    bool consentChecked = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Konfirmasi Pengiriman Data'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Data pasien akan dikirimkan ke server menggunakan enkripsi end-to-end. '
                    'Pastikan Anda memiliki wewenang untuk mengirim data medis ini.',
                  ),
                  const SizedBox(height: AppTheme.sp16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consentChecked,
                    onChanged: (v) =>
                        setDialogState(() => consentChecked = v ?? false),
                    title: const Text(
                      'Saya menyetujui pengiriman data medis ini ke server',
                      style: TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: consentChecked ? () => Navigator.pop(ctx, true) : null,
                  child: const Text('Lanjutkan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (confirmed == true) {
      setState(() {
        _state = _DataSyncState.selection;
        _selectedIds.clear();
      });
    }
  }

  void _startUpload() {
    setState(() {
      _state = _DataSyncState.uploading;
      _uploadedCount = 0;
    });
    _uploadTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _uploadedCount++);
      if (_uploadedCount >= _selectedIds.length) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _state = _DataSyncState.done;
          _lastSyncDate = DateTime.now();
        });
      }
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Belum pernah disinkronkan';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cadangan Data Medis',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
            ),
            const SizedBox(height: AppTheme.sp16),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_state) {
      case _DataSyncState.idle:
        return _buildIdle(context);
      case _DataSyncState.selection:
        return _buildSelection(context);
      case _DataSyncState.uploading:
        return _buildUploading();
      case _DataSyncState.done:
        return _buildDone(context);
      case _DataSyncState.error:
        return _buildError(context);
    }
  }

  Widget _buildIdle(BuildContext context) {
    final summary = MockData.syncSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          avatar: const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.error),
          label: const Text('Data Medis Sensitif',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error)),
          backgroundColor: AppTheme.error.withValues(alpha: 0.08),
          side: BorderSide(color: AppTheme.error.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: AppTheme.sp12),
        Text(
          '${summary['totalPatients']} Pasien · ${summary['totalDiagnoses']} Diagnosis · ~${summary['totalSizeMB']} MB',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.sp4),
        Text(
          _formatDate(_lastSyncDate),
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppTheme.sp16),
        ElevatedButton.icon(
          onPressed: _showConsentDialog,
          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
          label: const Text('Pilih Data & Unggah'),
        ),
      ],
    );
  }

  Widget _buildSelection(BuildContext context) {
    final patients = MockData.patients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pilih Pasien untuk Dicadangkan',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                )),
        const SizedBox(height: AppTheme.sp8),
        Row(
          children: [
            TextButton(
              onPressed: () =>
                  setState(() => _selectedIds.addAll(patients.map((p) => p.id))),
              child: const Text('Pilih Semua'),
            ),
            TextButton(
              onPressed: () => setState(() => _selectedIds.clear()),
              child: const Text('Batal Pilih'),
            ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: patients.length,
          itemBuilder: (_, i) {
            final p = patients[i];
            final initials = p.name.split(' ').take(2).map((w) => w[0]).join();
            return CheckboxListTile(
              value: _selectedIds.contains(p.id),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selectedIds.add(p.id);
                } else {
                  _selectedIds.remove(p.id);
                }
              }),
              secondary: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                child: Text(initials,
                    style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text('Kunjungan terakhir: ${p.lastVisit}',
                  style: const TextStyle(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.trailing,
            );
          },
        ),
        const SizedBox(height: AppTheme.sp16),
        Row(
          children: [
            Text('${_selectedIds.length} pasien dipilih',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
        Text('Mengunggah data pasien...',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: AppTheme.sp12),
        LinearProgressIndicator(
          value: total > 0 ? _uploadedCount / total : null,
        ),
        const SizedBox(height: AppTheme.sp8),
        Text('Mengunggah $_uploadedCount/$total pasien...',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            SizedBox(width: AppTheme.sp8),
            Text('Sinkronisasi selesai',
                style: TextStyle(
                    color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
        const SizedBox(height: AppTheme.sp8),
        Text('$_uploadedCount pasien berhasil diunggah',
            style: const TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: AppTheme.sp16),
        TextButton(
          onPressed: () => setState(() {
            _state = _DataSyncState.idle;
            _selectedIds.clear();
            _uploadedCount = 0;
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
            Text('Tidak ada koneksi internet. Hubungkan perangkat dan coba lagi.',
                style: TextStyle(color: AppTheme.error)),
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
