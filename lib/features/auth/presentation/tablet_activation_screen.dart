import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/localization/language_toggle.dart';

class TabletActivationScreen extends StatefulWidget {
  const TabletActivationScreen({super.key});
  @override
  State<TabletActivationScreen> createState() => _TabletActivationScreenState();
}

class _TabletActivationScreenState extends State<TabletActivationScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (_busy || _code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final client = context.read<ApiClient>();
    try {
      if (await client.deviceIdentity.read() != null) {
        throw StateError('Already activated');
      }
      final nonce = await client.deviceIdentity.activationNonce();
      final response = await client.dio.post<Object?>(
        '/devices/activation',
        data: {'activation_code': _code.text.trim(), 'client_nonce': nonce},
      );
      await client.deviceIdentity.saveActivation(response.data);
      _code.clear();
      if (mounted) context.go('/login');
    } catch (error) {
      if (!mounted) return;
      final status = error is DioException ? error.response?.statusCode : null;
      setState(
        () => _message =
            context.trRead(
              'Aktivasi belum berhasil. Periksa kode dari admin, status tablet dan koneksi, lalu coba lagi.',
              'Activation failed. Check the administrator-issued code, tablet status and connection, then retry.',
            ) +
            (status == null ? '' : ' (HTTP $status)'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguage?>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.trRead('Aktivasi tablet', 'Activate tablet')),
        actions: const [LanguageToggle()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                context.trRead(
                  'Masukkan kode aktivasi dari administrator untuk tablet ini. Setelah aktivasi, login teknisi dari tablet yang sama.',
                  'Enter the administrator-issued activation code for this tablet. After activation, sign in as technician on this same tablet.',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _code,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                maxLength: 64,
                decoration: InputDecoration(
                  labelText: context.trRead('Kode aktivasi', 'Activation code'),
                ),
              ),
              if (_message != null) Text(_message!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _activate,
                child: Text(
                  context.trRead(
                    _busy ? 'Memproses…' : 'Aktifkan tablet',
                    _busy ? 'Activating…' : 'Activate tablet',
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => context.go('/login'),
                child: Text(
                  context.trRead('Kembali ke login', 'Back to login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
