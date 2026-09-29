import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';

/// Live auth against POST /auth/login + /auth/refresh.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._client, {SettingsStore? settings, AppDatabase? db})
    : _settings = settings,
      _db = db;

  final ApiClient _client;
  final SettingsStore? _settings;
  final AppDatabase? _db;
  int _operation = 0;
  Future<void>? _cleanup;

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    // Invalidate in-flight work immediately, but retain the previous owner's
    // cache until the replacement account has authenticated successfully.
    final operation = ++_operation;
    _db?.invalidateSession();
    final clearingTokens = _client.tokens.clear();
    final cleanup = _cleanup;
    if (cleanup != null) await cleanup;
    await clearingTokens;
    _ensureCurrent(operation);

    final tokenGeneration = _client.tokens.generation;
    final databaseGeneration = _db?.sessionGeneration;
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data;
    final user = data?['user'];
    final access = data?['access_token'];
    final refresh = data?['refresh_token'];
    if (user is! Map<String, dynamic> ||
        access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const FormatException('Login response is missing session fields');
    }

    final userId = user['id'];
    final tenantId = user['tenant_id'];
    final displayName = user['full_name'];
    final userEmail = user['email'];
    final role = user['role'];
    if (userId is! String ||
        userId.isEmpty ||
        tenantId is! String ||
        tenantId.isEmpty ||
        displayName is! String ||
        userEmail is! String ||
        role is! String) {
      throw const FormatException('Authenticated user identity is incomplete');
    }
    _ensureCurrent(operation, tokenGeneration: tokenGeneration);

    final profile = UserProfile(
      userId: userId,
      tenantId: tenantId,
      displayName: displayName,
      email: userEmail,
      role: role,
    );

    try {
      final settings = _settings;
      final database = _db;
      if (database != null && settings != null) {
        final deviceId = await settings.readOrCreateDeviceId();
        _ensureCurrent(operation, tokenGeneration: tokenGeneration);
        await database.activateOwner(
          databaseGeneration!,
          DataOwner(tenantId: tenantId, userId: userId, deviceId: deviceId),
        );
        _ensureCurrent(operation, tokenGeneration: tokenGeneration);
        await settings.saveIdentity(
          userId: userId,
          tenantId: tenantId,
          role: role,
          displayName: displayName,
          email: userEmail,
        );
      }

      _ensureCurrent(operation, tokenGeneration: tokenGeneration);
      await _client.tokens.update(access: access, refresh: refresh);
      _ensureCurrent(operation);
    } catch (_) {
      // A newer login or logout owns cleanup. A failure in the current login
      // must fail closed and remove any partially activated local owner.
      if (operation == _operation) {
        await _client.tokens.clear();
        await _db?.clearSessionData();
      }
      rethrow;
    }
    return profile;
  }

  void _ensureCurrent(int operation, {int? tokenGeneration}) {
    if (operation != _operation ||
        (tokenGeneration != null &&
            tokenGeneration != _client.tokens.generation)) {
      throw StateError('Session changed');
    }
  }

  @override
  Future<void> logout() {
    _operation++;
    return _clearSession();
  }

  Future<void> _clearSession() {
    final clearedTokens = _client.tokens.clear();

    Future<void> clean() async {
      try {
        await clearedTokens;
      } finally {
        await _db?.clearSessionData();
      }
    }

    // Serialize cleanup even if expiry and user logout arrive together.
    final previous = _cleanup;
    final next = previous == null
        ? clean()
        : previous.then((_) => clean(), onError: (Object _) => clean());
    _cleanup = next;
    return next.whenComplete(() {
      if (identical(_cleanup, next)) _cleanup = null;
    });
  }
}
