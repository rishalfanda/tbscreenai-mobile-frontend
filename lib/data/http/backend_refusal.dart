import 'package:dio/dio.dart';

/// Stable API codes, never raw server text or request credentials in the UI.
String? backendRefusalCode(Object? body) {
  final detail = body is Map ? body['detail'] : null;
  return detail is Map && detail['code'] is String
      ? detail['code'] as String
      : null;
}

bool requiresTabletActivation(String? code) => const {
  'device_required',
  'device_unauthenticated',
  'device_pending',
  'device_revoked',
}.contains(code);

bool endsTabletSession(String? code) =>
    requiresTabletActivation(code) ||
    const {
      'account_disabled',
      'session_ended',
      'device_session_required',
    }.contains(code);

String? refusalMessage(String? code, {required bool english}) {
  final messages = <String, (String, String)>{
    'no_active_model': (
      'Model AI belum aktif. Minta teknisi mengaktifkan model terlebih dahulu.',
      'No active AI model. Ask a technician to activate a model first.',
    ),
    'invalid_credentials': (
      'Email atau password salah.',
      'Incorrect email or password.',
    ),
    'account_disabled': (
      'Akun dinonaktifkan. Hubungi admin instansi.',
      'Account disabled. Contact your institution administrator.',
    ),
    'session_ended': (
      'Sesi telah berakhir. Silakan login kembali.',
      'Your session ended. Please sign in again.',
    ),
    'device_required': (
      'Aktivasi tablet diperlukan sebelum login.',
      'Activate this tablet before signing in.',
    ),
    'device_unauthenticated': (
      'Identitas tablet tidak dikenali. Hubungi admin untuk aktivasi.',
      'Tablet identity not recognized. Contact your administrator for activation.',
    ),
    'device_pending': (
      'Tablet belum aktif. Masukkan kode aktivasi dari admin.',
      'Tablet is not active. Enter an administrator-issued activation code.',
    ),
    'device_revoked': (
      'Akses tablet dicabut. Hubungi admin sebelum aktivasi ulang.',
      'Tablet access revoked. Contact your administrator before reactivation.',
    ),
    'device_session_required': (
      'Login ulang pada tablet yang sudah diaktivasi.',
      'Sign in again on your activated tablet.',
    ),
    'token_invalid': (
      'Sesi kedaluwarsa. Silakan login kembali.',
      'Session expired. Please sign in again.',
    ),
    'refresh_token_invalid': (
      'Sesi kedaluwarsa. Silakan login kembali.',
      'Session expired. Please sign in again.',
    ),
    'temporary_password_expired': (
      'Password sementara kedaluwarsa. Minta teknisi mereset password.',
      'Temporary password expired. Ask your technician for a reset.',
    ),
  };
  final message = messages[code];
  return message == null
      ? null
      : english
      ? message.$2
      : message.$1;
}

String? refusalFromError(Object error) =>
    error is DioException ? backendRefusalCode(error.response?.data) : null;
