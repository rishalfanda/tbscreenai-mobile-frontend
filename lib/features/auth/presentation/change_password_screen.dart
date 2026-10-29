import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/localization/language_toggle.dart';
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
  String? _error;
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
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
      if (mounted) context.go(auth.mobileRole.home);
    } catch (failure) {
      if (!mounted) return;
      final data = failure is DioException ? failure.response?.data : null;
      final detail = data is Map ? data['detail'] : null;
      final code = detail is Map ? detail['code'] : null;
      setState(() {
        _error = switch (code) {
          'current_password_wrong' => context.trRead(
            'Password saat ini salah.',
            'Current password is incorrect.',
          ),
          'password_unchanged' => context.trRead(
            'Password baru harus berbeda.',
            'Choose a different password.',
          ),
          _ => context.trRead(
            'Password belum berubah. Periksa koneksi dan coba lagi.',
            'Password was not changed. Check your connection and retry.',
          ),
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguage?>();
    final required = context.watch<AuthProvider>().mustChangePassword;
    return Scaffold(
      appBar: AppBar(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _current,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
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
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
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
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
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
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
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
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await context.read<AuthProvider>().logout();
                            },
                      child: Text(context.trRead('Keluar', 'Sign out')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
