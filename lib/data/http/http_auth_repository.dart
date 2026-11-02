import 'package:myapp/data/secure/doctor_session_store.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/data/offline/device_operator_outbox.dart';

/// Live auth against POST /auth/login + /auth/refresh.
class HttpAuthRepository
    implements
        AuthRepository,
        PasswordChangeRepository,
        PersistentDoctorAuthRepository {
  HttpAuthRepository(
    this._client, {
    SettingsStore? settings,
    AppDatabase? db,
    DeviceOperatorOutbox? outbox,
    DoctorSessionStore? doctorSession,
  }) : _settings = settings,
       _db = db,
       _outbox = outbox,
       _doctorSession = doctorSession;

  final DoctorSessionStore? _doctorSession;
  final ApiClient _client;
  final SettingsStore? _settings;
  final AppDatabase? _db;
  final DeviceOperatorOutbox? _outbox;
  int _operation = 0;
  Future<void>? _cleanup;
  UserProfile? _identity;

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    // Invalidate in-flight work immediately, but retain the previous owner's
    // cache until the replacement account has authenticated successfully.
    final operation = ++_operation;
    _identity = null;
    await _doctorSession?.clear();
    _ensureCurrent(operation);
    _db?.invalidateSession();
    final clearingTokens = _client.tokens.clear();
    final cleanup = _cleanup;
    if (cleanup != null) await cleanup;
    await clearingTokens;
    await _outbox?.captureDoctorQueue();
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
        role is! String ||
        (user.containsKey('must_change_password') &&
            user['must_change_password'] is! bool)) {
      throw const FormatException('Authenticated user identity is incomplete');
    }
    _ensureCurrent(operation, tokenGeneration: tokenGeneration);

    final profile = UserProfile(
      userId: userId,
      tenantId: tenantId,
      displayName: displayName,
      email: userEmail,
      role: role,
      mustChangePassword: user['must_change_password'] == true,
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
        if (!profile.mustChangePassword) await _outbox?.restoreDoctorQueue();
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
    final device = await _client.deviceIdentity.read();
    _ensureCurrent(operation);
    if (device != null && device.tenantId == profile.tenantId) {
      await _doctorSession?.save(profile, device.id, _client.baseUrl);
    }
    _ensureCurrent(operation);
    _identity = profile;
    return profile;
  }

  @override
  Future<UserProfile?> restoreDoctorSession() async {
    final operation = ++_operation;
    final db = _db;
    final settings = _settings;
    final device = await _client.deviceIdentity.read();
    _ensureCurrent(operation);
    if (_doctorSession == null ||
        db == null ||
        settings == null ||
        device == null) {
      await _client.tokens.clear();
      return null;
    }
    try {
      final profile = await _doctorSession.read(device.id, _client.baseUrl);
      if (profile == null ||
          profile.tenantId != device.tenantId ||
          await settings.readSessionOwner() !=
              '${profile.tenantId}:${profile.userId}' ||
          await settings.readRole() != 'doctor' ||
          !await _client.tokens.restore(
            localAuthenticationGranted: true,
            allowExpiredAccess: true,
          )) {
        await _doctorSession.clear();
        await _client.tokens.clear();
        return null;
      }
      _ensureCurrent(operation);
      final localDevice = await settings.readOrCreateDeviceId();
      await db.activateOwner(
        db.sessionGeneration,
        DataOwner(
          tenantId: profile.tenantId,
          userId: profile.userId,
          deviceId: localDevice,
        ),
      );
      _ensureCurrent(operation);
      _identity = profile;
      return profile;
    } catch (_) {
      if (operation == _operation) {
        await _doctorSession.clear();
        await _client.tokens.clear();
      }
      return null;
    }
  }

  void _ensureCurrent(int operation, {int? tokenGeneration}) {
    if (operation != _operation ||
        (tokenGeneration != null &&
            tokenGeneration != _client.tokens.generation)) {
      throw StateError('Session changed');
    }
  }

  @override
  Future<UserProfile> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final operation = _operation;
    final generation = _client.tokens.generation;
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/auth/change-password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
    _ensureCurrent(operation, tokenGeneration: generation);
    final data = response.data;
    final user = data?['user'];
    final access = data?['access_token'];
    final refresh = data?['refresh_token'];
    if (user is! Map<String, dynamic> ||
        access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        user['id'] is! String ||
        user['tenant_id'] is! String ||
        user['full_name'] is! String ||
        user['email'] is! String ||
        user['role'] is! String ||
        user['must_change_password'] != false) {
      throw const FormatException('Password change response is invalid');
    }
    final identity = _identity;
    if (identity == null ||
        user['id'] != identity.userId ||
        user['tenant_id'] != identity.tenantId ||
        user['role'] != identity.role) {
      throw const FormatException('Password change identity mismatch');
    }
    final owner = await _settings?.readSessionOwner();
    _ensureCurrent(operation, tokenGeneration: generation);
    if (owner != null && owner != '${user['tenant_id']}:${user['id']}') {
      throw const FormatException('Password change identity mismatch');
    }
    await _client.tokens.replaceSession(access: access, refresh: refresh);
    _ensureCurrent(operation);
    await _outbox?.restoreDoctorQueue();
    _ensureCurrent(operation);
    final updated = UserProfile(
      userId: user['id'] as String,
      tenantId: user['tenant_id'] as String,
      displayName: user['full_name'] as String,
      email: user['email'] as String,
      role: user['role'] as String,
    );
    final device = await _client.deviceIdentity.read();
    if (device != null && device.tenantId == updated.tenantId) {
      await _doctorSession?.save(updated, device.id, _client.baseUrl);
    }
    _identity = updated;
    return updated;
  }

  @override
  Future<void> logout() {
    _operation++;
    _identity = null;
    _db?.invalidateSession();
    return _clearSession();
  }

  Future<void> _clearSession() {
    final clearedTokens = _client.tokens.clear();
    final clearedDoctorSession = _doctorSession?.clear();

    Future<void> clean() async {
      await _outbox?.captureDoctorQueue();
      await clearedTokens;
      await clearedDoctorSession;
      await _db?.clearSessionData();
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
