import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal boundary around platform secure storage.
///
/// Production uses Android Keystore / Apple Keychain through
/// [FlutterSecureStorage]. Tests inject [MemorySecureTokenStorage], so a
/// missing platform plugin can never trigger a plaintext SQLite fallback.
abstract interface class SecureTokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecureTokenStorage implements SecureTokenStorage {
  PlatformSecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemorySecureTokenStorage implements SecureTokenStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
