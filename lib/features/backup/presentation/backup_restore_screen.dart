import 'package:flutter/material.dart';

import 'package:myapp/data/backup/backup_restore_models.dart';
import 'package:myapp/data/backup/device_backup_restore_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key, required this.service});

  final DeviceBackupRestoreService service;

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  RestorePlanSummary? _pending;
  bool _busy = false;
  String? _message;
  bool _error = false;

  bool get _id => Localizations.localeOf(context).languageCode == 'id';
  String _t(String id, String en) => _id ? id : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _message = error is BackupRestoreException
            ? error.message
            : _t('Operasi gagal. Coba lagi.', 'Operation failed. Try again.');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() => _run(() async {
    final pending = await widget.service.pendingRestore();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _message = pending == null
          ? _t('Tidak ada restore tertunda.', 'No pending restore.')
          : null;
    });
  });

  Future<void> _backup() => _run(() async {
    final result = await widget.service.createBackup();
    if (!mounted) return;
    setState(() {
      _message = _t(
        'Backup ${result.name} selesai: ${result.patientCount} pasien, '
            '${result.diagnosisCount} skrining, ${result.imageCount} gambar.',
        'Backup ${result.name} completed: ${result.patientCount} patients, '
            '${result.diagnosisCount} screenings, ${result.imageCount} images.',
      );
    });
  });

  Future<void> _restore() async {
    final pending = _pending;
    if (pending == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Pulihkan backup?', 'Restore backup?')),
        content: Text(
          _t(
            'Pastikan perangkat ini kosong. ${pending.recordsExpected} record '
                'dan ${pending.imagesToDownload} gambar akan diverifikasi sebelum disimpan.',
            'This device must be empty. ${pending.recordsExpected} records and '
                '${pending.imagesToDownload} images will be verified before saving.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Batal', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Pulihkan', 'Restore')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final result = await widget.service.restorePending();
      if (!mounted) return;
      setState(() {
        _pending = null;
        _message = _t(
          'Restore selesai: ${result.recordsRestored} record dan '
              '${result.imagesVerified} gambar terverifikasi.',
          'Restore completed: ${result.recordsRestored} records and '
              '${result.imagesVerified} verified images.',
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('Backup & Restore', 'Backup & Restore'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _t(
              'Backup hanya dibuat setelah seluruh data dokter tersinkron.',
              'A backup is created only after all doctor data is synchronized.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _backup,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(_t('Buat backup sekarang', 'Create backup now')),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  _t('Restore tertunda', 'Pending restore'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: _t('Periksa ulang', 'Refresh'),
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_pending case final pending?)
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: Text(pending.backupName),
                subtitle: Text(
                  _t(
                    '${pending.recordsExpected} record, ${pending.imagesToDownload} gambar',
                    '${pending.recordsExpected} records, ${pending.imagesToDownload} images',
                  ),
                ),
                trailing: FilledButton(
                  onPressed: _busy ? null : _restore,
                  child: Text(_t('Pulihkan', 'Restore')),
                ),
              ),
            ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
          ],
          if (_message case final message?) ...[
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: TextStyle(
                  color: _error
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
