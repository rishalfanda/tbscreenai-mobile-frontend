import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/offline/operator_sync_service.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/state/auth_provider.dart';

class OperatorSyncScreen extends StatefulWidget {
  const OperatorSyncScreen({super.key});
  @override
  State<OperatorSyncScreen> createState() => _OperatorSyncScreenState();
}

class _OperatorSyncScreenState extends State<OperatorSyncScreen> {
  bool _busy = false, _consent = false, _activated = false;
  int _count = 0, _done = 0;
  String? _error;
  SyncReport? _report;
  UserProfile? _actor;
  bool get _current =>
      mounted &&
      context.read<AuthProvider>().isLoggedIn &&
      identical(context.read<AuthProvider>().profile, _actor);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (!identical(_actor, auth.profile)) {
      _actor = auth.profile;
      _count = 0;
      _report = null;
      _error = null;
      _consent = false;
      if (AppConfig.useHttp) _load();
    }
  }

  Future<void> _load() async {
    final service = context.read<OperatorSyncService?>();
    if (service == null) return;
    final actor = _actor;
    setState(() => _busy = true);
    try {
      final device = await context.read<ApiClient>().deviceIdentity.read();
      final entries = await service.queued();
      if (!_current || !identical(actor, _actor)) return;
      setState(() {
        _count = entries.length;
        _activated = device != null && device.tenantId == actor?.tenantId;
      });
    } catch (_) {
      if (_current) {
        setState(
          () => _error = context.trRead(
            'Antrean tidak dapat dibaca. Data tetap disimpan; coba lagi.',
            'Cannot read the queue. Data is retained; retry.',
          ),
        );
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    if (!_consent || _busy || !_activated || !_current) return;
    final service = context.read<OperatorSyncService>();
    final actor = _actor;
    setState(() {
      _busy = true;
      _error = null;
      _report = null;
      _done = 0;
    });
    try {
      final report = await service.push(
        onProgress: (done, total) {
          if (_current && identical(actor, _actor)) {
            setState(() {
              _done = done;
              _count = total;
            });
          }
        },
      );
      if (_current && identical(actor, _actor)) {
        final remaining = await service.queued();
        if (_current && identical(actor, _actor)) {
          setState(() {
            _report = report;
            _count = remaining.length;
            _done = 0;
          });
        }
      }
    } catch (_) {
      if (_current) {
        setState(
          () => _error = context.trRead(
            'Sync belum selesai. Periksa aktivasi tablet, login teknisi dan koneksi. Antrean tetap disimpan.',
            'Sync did not finish. Check tablet activation, technician login and connectivity. Queued work is retained.',
          ),
        );
      }
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguage?>();
    if (!AppConfig.useHttp) {
      return Center(
        child: Text(
          context.trRead(
            'Sync operator memerlukan tablet terdaftar dan API staging.',
            'Operator sync requires a registered tablet and staging API.',
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          context.trRead('Sync data pengguna', 'Sync user data'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          context.trRead(
            'Kirim antrean dokter dari tablet ini ke server instansi. Pemilik data tetap dokter; akun teknisi dicatat sebagai operator.',
            'Send doctors\' queued work from this tablet to your institution server. Doctors retain ownership; the technician is recorded as operator.',
          ),
        ),
        const SizedBox(height: 20),
        if (!_activated)
          Text(
            context.trRead(
              'Tablet belum diaktivasi untuk instansi ini. Keluar, buka Aktivasi tablet pada login, lalu login teknisi kembali.',
              'This tablet is not activated for this institution. Sign out, open Activate tablet at login, then sign in as technician again.',
            ),
          ),
        Text(
          '${context.trRead('Antrean tersimpan', 'Retained queue')}: $_count',
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_busy)
          LinearProgressIndicator(value: _count == 0 ? null : _done / _count),
        if (_report case final report?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              '${context.trRead('Diterapkan', 'Applied')}: ${report.applied} · ${context.trRead('Sudah terkirim', 'Already received')}: ${report.skipped}\n${context.trRead('Konflik', 'Conflicts')}: ${report.conflicts} · ${context.trRead('Belum selesai', 'Unfinished')}: ${report.failed}\n${context.trRead("Menunggu dukungan server", "Awaiting server support")}: ${report.blocked}',
            ),
          ),
        Text(
          context.trRead(
            'Konflik dan kegagalan tetap disimpan untuk diperbaiki; tidak dihitung sebagai sukses.',
            'Conflicts and failures are retained for correction; they are not counted as success.',
          ),
        ),
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            value: _consent,
            onChanged: _busy
                ? null
                : (value) => setState(() => _consent = value ?? false),
            title: Text(
              context.trRead(
                'Saya berwenang menyinkronkan data dokter pada tablet ini.',
                'I am authorized to synchronize doctor data from this tablet.',
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          children: [
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: Text(
                context.trRead('Muat ulang antrean', 'Refresh queue'),
              ),
            ),
            FilledButton(
              onPressed: _busy || !_activated || !_consent || _count == 0
                  ? null
                  : _sync,
              child: Text(context.trRead('Sync ke server', 'Sync to server')),
            ),
          ],
        ),
      ],
    );
  }
}
