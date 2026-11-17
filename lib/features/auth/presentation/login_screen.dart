import 'auth_frame.dart';
import 'tablet_activation_screen.dart';
import 'package:myapp/features/shared/presentation/widgets/secret_form_field.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/data/http/backend_refusal.dart';
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
  ({String id, String en})? _submitError;

  void _clearErrorOnEdit() {
    if (_submitError != null) {
      setState(() => _submitError = null);
    }
    context.read<AuthProvider>().clearSessionRefusal();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.isBusy || _isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    auth.clearSessionRefusal();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    try {
      // Mock resolves synchronously (no visible spinner); Http awaits the
      // backend and surfaces failures instead of navigating blindly.
      await auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _passwordController.clear();
      setState(() => _isSubmitting = false);
      GoRouter.maybeOf(context)?.go(
        auth.mustChangePassword ? '/change-password' : auth.mobileRole.home,
      );
    } catch (failure) {
      if (!mounted) return;
      final nextError = failure is NoActiveModelException
          ? (
              id: 'Login gagal — belum ada model AI yang aktif. Silakan aktifkan model terlebih dahulu atau hubungi teknisi.',
              en: 'Login failed — no active AI model found. Please activate a model first or contact a technician.',
            )
          : () {
              final code = refusalFromError(failure);
              return (
                id:
                    refusalMessage(code, english: false) ??
                    'Login gagal — periksa email/password atau koneksi server',
                en:
                    refusalMessage(code, english: true) ??
                    'Login failed — check email/password or server connection',
              );
            }();
      setState(() {
        _isSubmitting = false;
        _submitError = nextError;
      });
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
    context.watch<AppLanguage?>();
    final auth = context.watch<AuthProvider>();
    if (!auth.deviceActivated) {
      return const TabletActivationScreen();
    }
    final busy = _isSubmitting || auth.isBusy;
    final refusalCode = auth.sessionRefusalCode;
    final bannerMessage = _submitError != null
        ? context.trRead(_submitError!.id, _submitError!.en)
        : refusalCode != null
        ? context.trRead(
            refusalMessage(refusalCode, english: false) ??
                'Silakan login kembali.',
            refusalMessage(refusalCode, english: true) ??
                'Please sign in again.',
          )
        : null;

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
            if (bannerMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: AuthErrorBanner(message: bannerMessage),
              ),
            const SizedBox(height: 24),
            AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    onChanged: (_) => _clearErrorOnEdit(),
                    decoration: InputDecoration(
                      labelText: context.trRead('Email', 'Email'),
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    validator: (v) =>
                        v == null ||
                            !RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim())
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
                    enabled: !busy,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => _clearErrorOnEdit(),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? context.trRead(
                            'Password wajib diisi',
                            'Password is required',
                          )
                        : null,
                    onSubmitted: (_) => busy ? null : _submit(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
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
