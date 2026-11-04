import 'auth_frame.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/features/shared/presentation/widgets/secret_form_field.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/backend_refusal.dart';
import 'package:myapp/core/localization/app_language.dart';

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
      if (mounted) {
        context.read<AuthProvider>().setDeviceActivated(true);
        context.go('/login');
      }
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
  Widget build(BuildContext context) => AuthFrame(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.trRead('Aktivasi tablet', 'Activate tablet'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 24),
        if (context.watch<AuthProvider>().sessionRefusalCode != null)
          Text(
            context.trRead(
              refusalMessage(
                    context.read<AuthProvider>().sessionRefusalCode,
                    english: false,
                  ) ??
                  'Aktivasi tablet diperlukan.',
              refusalMessage(
                    context.read<AuthProvider>().sessionRefusalCode,
                    english: true,
                  ) ??
                  'Tablet activation required.',
            ),
          ),
        SecretFormField(
          controller: _code,
          label: context.trRead('Kode aktivasi', 'Activation code'),
          maxLength: 64,
          enabled: !_busy,
          onSubmitted: (_) => _activate(),
        ),
        const SizedBox(height: 8),
        Text(
          context.trRead(
            'Masukkan kode aktivasi dari admin. Aktivasi memerlukan koneksi internet.',
            'Enter the activation code from your administrator. Internet is required.',
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _activate,
          child: Text(
            context.trRead(
              _busy ? 'Memproses...' : 'Aktifkan tablet',
              _busy ? 'Activating...' : 'Activate tablet',
            ),
          ),
        ),
      ],
    ),
  );
}
