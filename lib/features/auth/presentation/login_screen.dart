import 'auth_frame.dart';
import 'tablet_activation_screen.dart';
import 'package:myapp/features/shared/presentation/widgets/secret_form_field.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/core/config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = context.read<AuthProvider>();
    setState(() => _isSubmitting = true);
    try {
      // Mock resolves synchronously (no visible spinner); Http awaits the
      // backend and surfaces failures instead of navigating blindly.
      await auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _passwordController.clear();
      context.go(
        auth.mustChangePassword ? '/change-password' : auth.mobileRole.home,
      );
    } catch (failure) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final data = failure is DioException ? failure.response?.data : null;
      final detail = data is Map ? data['detail'] : null;
      final expired =
          detail is Map && detail['code'] == 'temporary_password_expired';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            expired
                ? context.trRead(
                    'Password sementara kedaluwarsa. Minta teknisi mereset password.',
                    'Temporary password expired. Ask your technician for a reset.',
                  )
                : context.trRead(
                    'Login gagal — periksa email/password atau koneksi server',
                    'Login failed — check email/password or server connection',
                  ),
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().deviceActivated) {
      return const TabletActivationScreen();
    }
    return AuthFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.trRead('Masuk', 'Sign In'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              enabled: !_isSubmitting,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: context.trRead('Email', 'Email'),
                prefixIcon: const Icon(Icons.mail_outline),
              ),
              validator: (v) => v == null || !v.contains('@')
                  ? context.trRead(
                      'Masukkan email yang valid',
                      'Enter a valid email',
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            SecretFormField(
              controller: _passwordController,
              label: context.trRead('Password', 'Password'),
              enabled: !_isSubmitting,
              validator: (v) => v == null || v.isEmpty
                  ? context.trRead(
                      'Password wajib diisi',
                      'Password is required',
                    )
                  : null,
              onSubmitted: (_) => _isSubmitting ? null : _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.trRead('Masuk', 'Sign In')),
            ),
            if (AppConfig.isDemo)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  context.trRead(
                    'Mode demo - data simulasi',
                    'Demo mode - simulated data',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
