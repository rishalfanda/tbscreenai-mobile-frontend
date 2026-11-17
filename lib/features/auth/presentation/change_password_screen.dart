import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/localization/language_toggle.dart';
import 'package:myapp/features/auth/presentation/auth_frame.dart';
import 'package:myapp/features/auth/presentation/logout_confirmation_dialog.dart';
import 'package:myapp/state/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  ({String id, String en})? _error;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _navigateBack(BuildContext context, AuthProvider auth) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(auth.mobileRole.home);
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      _current.clear();
      _next.clear();
      _confirm.clear();
      if (mounted) {
        GoRouter.maybeOf(context)?.go(auth.mobileRole.home);
      }
    } catch (failure) {
      if (!mounted) return;
      final status = failure is DioException
          ? failure.response?.statusCode
          : null;
      final data = failure is DioException ? failure.response?.data : null;
      final detail = data is Map ? data['detail'] : null;
      final code = detail is Map ? detail['code'] : null;
      setState(() {
        _error = switch (code) {
          'current_password_wrong' => (
            id: 'Password saat ini salah.',
            en: 'Current password is incorrect.',
          ),
          'password_unchanged' => (
            id: 'Password baru harus berbeda.',
            en: 'Choose a different password.',
          ),
          'weak_password' ||
          'password_too_short' ||
          'password_invalid' => (
            id: 'Password baru tidak memenuhi ketentuan keamanan.',
            en: 'New password does not meet security requirements.',
          ),
          _ => status == 400 || status == 422
              ? (
                  id: 'Password baru tidak memenuhi ketentuan keamanan.',
                  en: 'New password does not meet security requirements.',
                )
              : (
                  id: 'Password belum berubah. Periksa koneksi dan coba lagi.',
                  en:
                      'Password was not changed. Check your connection and retry.',
                ),
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  final _visible = <TextEditingController>{};
  Widget _visibility(TextEditingController controller) => IconButton(
    tooltip: context.trRead(
      _visible.contains(controller) ? 'Sembunyikan teks' : 'Tampilkan teks',
      _visible.contains(controller) ? 'Hide text' : 'Show text',
    ),
    onPressed: () => setState(() {
      _visible.contains(controller)
          ? _visible.remove(controller)
          : _visible.add(controller);
    }),
    icon: Icon(
      _visible.contains(controller)
          ? Icons.visibility_off_outlined
          : Icons.visibility_outlined,
    ),
  );

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguage?>();
    final auth = context.watch<AuthProvider>();
    final required = auth.mustChangePassword;
    return Scaffold(
      appBar: AppBar(
        leading: required
            ? null
            : IconButton(
                key: const Key('change-password-back-button'),
                icon: const Icon(Icons.arrow_back),
                tooltip: context.trRead('Kembali', 'Back'),
                onPressed: _busy ? null : () => _navigateBack(context, auth),
              ),
        title: Text(context.trRead('Ganti password', 'Change password')),
        actions: const [LanguageToggle()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Text(
                context.trRead(
                  required
                      ? 'Ganti password sementara sebelum melanjutkan.'
                      : 'Gunakan password baru untuk akun Anda.',
                  required
                      ? 'Replace your temporary password to continue.'
                      : 'Choose a new password for your account.',
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _current,
                        obscureText: !_visible.contains(_current),
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          suffixIcon: _visibility(_current),
                          labelText: context.trRead(
                            'Password saat ini',
                            'Current password',
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? context.trRead('Wajib diisi', 'Required')
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _next,
                        obscureText: !_visible.contains(_next),
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          suffixIcon: _visibility(_next),
                          labelText: context.trRead(
                            'Password baru',
                            'New password',
                          ),
                          helperText: context.trRead(
                            'Minimal 8 karakter, maksimal 72 byte.',
                            'At least 8 characters, at most 72 bytes.',
                          ),
                        ),
                        validator: (v) =>
                            v == null ||
                                v.runes.length < 8 ||
                                utf8.encode(v).length > 72 ||
                                v == _current.text
                            ? context.trRead(
                                'Gunakan password berbeda, 8 karakter sampai 72 byte.',
                                'Use a different password, 8 characters to 72 bytes.',
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirm,
                        obscureText: !_visible.contains(_confirm),
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          suffixIcon: _visibility(_confirm),
                          labelText: context.trRead(
                            'Konfirmasi password',
                            'Confirm password',
                          ),
                        ),
                        validator: (v) => v != _next.text
                            ? context.trRead(
                                'Konfirmasi tidak sama.',
                                'Passwords do not match.',
                              )
                            : null,
                        onFieldSubmitted: (_) => _busy ? null : _save(),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: AuthErrorBanner(
                            message: context.trRead(_error!.id, _error!.en),
                          ),
                        ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(
                          context.trRead(
                            _busy ? 'Menyimpan…' : 'Simpan password',
                            _busy ? 'Saving…' : 'Save password',
                          ),
                        ),
                      ),
                      if (!required) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          key: const Key('change-password-cancel-button'),
                          onPressed:
                              _busy ? null : () => _navigateBack(context, auth),
                          child: Text(context.trRead('Batal', 'Cancel')),
                        ),
                      ],
                      TextButton(
                        onPressed: _busy || auth.isBusy
                            ? null
                            : () => unawaited(confirmAndLogout(context)),
                        child: Text(context.trRead('Keluar', 'Sign out')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
