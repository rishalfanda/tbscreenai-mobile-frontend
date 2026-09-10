import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';

/// Live auth against POST /auth/login + /auth/refresh (FastAPI backend).
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._client, {SettingsStore? settings, AppDatabase? db})
    : _settings = settings,
      _db = db;

  final ApiClient _client;
  final SettingsStore? _settings;
  final AppDatabase? _db;
  int _operation = 0;
  Future<void> _cleanup = Future<void>.value();

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    // Invalidate in-flight work immediately, but retain the owner's offline
    // records until the server has authenticated a replacement account.
    final operation = ++_operation;
    _db?.invalidateSession();
    final clearingTokens = _client.tokens.clear();
    await _cleanup;
    await clearingTokens;
    if (operation != _operation) throw StateError('Session changed');
    final generation = _client.tokens.generation;
    final dbGeneration = _db?.sessionGeneration;
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!;
    final user = data['user'] as Map<String, dynamic>;
    if (user['id'] is! String || (user['id'] as String).isEmpty) {
      throw const FormatException('Authenticated user ID missing');
    }
    final owner = '${user['tenant_id'] ?? ''}:${user['id']}';
    if (operation != _operation || generation != _client.tokens.generation) {
      throw StateError('Session changed');
    }
    final profile = UserProfile(
      displayName: user['full_name'] as String,
      email: user['email'] as String,
      role: user['role'] as String,
    );

    Future<void> persist() async {
      await _settings?.saveSession(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        displayName: profile.displayName,
        email: profile.email,
      );
    }

    if (_db != null) {
      await _db.activateOwner(dbGeneration!, owner, persist);
    } else {
      await persist();
    }
    if (operation != _operation || generation != _client.tokens.generation) {
      throw StateError('Session changed');
    }
    _client.tokens.accessToken = data['access_token'] as String;
    _client.tokens.refreshToken = data['refresh_token'] as String;
    return profile;
  }

  @override
  Future<void> logout() {
    _operation++;
    return _clearSession();
  }

  Future<void> _clearSession() {
    // Stateless JWT — clearing local tokens ends the session. Cached medical
    // data goes too: it belongs to the account that just signed out.
    final clearedTokens = _client.tokens.clear();
    Future<void> clean() async {
      await clearedTokens;
      await _db?.clearAll();
    }

    // Serialize database cleanup even if multiple auth actions overlap.
    _cleanup = _cleanup.then((_) => clean(), onError: (Object _) => clean());
    return _cleanup;
  }
}
