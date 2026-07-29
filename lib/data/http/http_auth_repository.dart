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

  @override
  Future<UserProfile> login({required String email, required String password}) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!;
    final user = data['user'] as Map<String, dynamic>;
    final profile = UserProfile(
      displayName: user['full_name'] as String,
      email: user['email'] as String,
      role: user['role'] as String,
    );

    await _client.tokens.update(
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
    await _settings?.saveSession(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      displayName: profile.displayName,
      email: profile.email,
    );
    return profile;
  }

  @override
  Future<void> logout() async {
    // Stateless JWT — clearing local tokens ends the session. Cached medical
    // data goes too: it belongs to the account that just signed out.
    await _client.tokens.clear();
    await _db?.clearAll();
  }
}
