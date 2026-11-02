import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_auth_repository.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/secure/doctor_session_store.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/state/auth_provider.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.role);
  final String role;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? body,
    Future<void>? cancel,
  ) async {
    calls++;
    final claims = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': 'synthetic-user',
              'tenant_id': 'synthetic-tenant',
              'exp': 1,
            }),
          ),
        )
        .replaceAll('=', '');
    return ResponseBody.fromString(
      jsonEncode({
        'access_token': 'synthetic.$claims.synthetic',
        'refresh_token': 'synthetic-refresh',
        'user': {
          'id': 'synthetic-user',
          'tenant_id': 'synthetic-tenant',
          'full_name': 'Synthetic',
          'email': 'test@example.invalid',
          'role': role,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final role in ['doctor', 'technician']) {
    test('$role session restores offline only for the doctor', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secrets = MemorySecureTokenStorage();
      final session = DoctorSessionStore(secrets);
      final settings = SettingsStore(db);
      ApiClient makeClient() => ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: secrets,
      );
      final first = makeClient();
      final adapter = _Adapter(role);
      first.dio.httpClientAdapter = adapter;
      await first.deviceIdentity.saveActivation({
        'device_id': 'synthetic-device',
        'tenant_id': 'synthetic-tenant',
        'credential': 'synthetic-credential',
        'label': 'Synthetic tablet',
        'status': 'active',
      });
      final repo = HttpAuthRepository(
        first,
        settings: settings,
        db: db,
        doctorSession: session,
      );
      await repo.login(
        email: 'test@example.invalid',
        password: 'synthetic-password',
      );
      expect(adapter.calls, 1);
      final second = makeClient();
      final secondAdapter = _Adapter(role);
      second.dio.httpClientAdapter = secondAdapter;
      final restoredRepo = HttpAuthRepository(
        second,
        settings: settings,
        db: db,
        doctorSession: session,
      );
      final auth = AuthProvider(restoredRepo);
      await auth.restoreSession();
      expect(auth.isLoggedIn, role == 'doctor');
      expect(
        secondAdapter.calls,
        0,
        reason:
            'Offline restore must not call the server or expire on local token time',
      );
      if (role == 'doctor') {
        expect(auth.role, 'doctor');
        expect(db.activeOwner!.userId, 'synthetic-user');
        await auth.logout();
        expect(await session.read('synthetic-device', first.baseUrl), isNull);
        expect(await restoredRepo.restoreDoctorSession(), isNull);
      }
      auth.dispose();
      await first.close();
      await second.close();
      await db.close();
    });
  }
  test('doctor session is bound to device and API environment', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final secrets = MemorySecureTokenStorage();
    final client = ApiClient(
      baseUrl: 'https://synthetic.invalid/api/v1',
      settings: SettingsStore(db),
      secureStorage: secrets,
    );
    client.dio.httpClientAdapter = _Adapter('doctor');
    await client.deviceIdentity.saveActivation({
      'device_id': 'synthetic-device',
      'tenant_id': 'synthetic-tenant',
      'credential': 'synthetic-credential',
      'label': 'Synthetic',
      'status': 'active',
    });
    final store = DoctorSessionStore(secrets);
    final repo = HttpAuthRepository(
      client,
      settings: SettingsStore(db),
      db: db,
      doctorSession: store,
    );
    await repo.login(
      email: 'test@example.invalid',
      password: 'synthetic-password',
    );
    expect(await store.read('other-device', client.baseUrl), isNull);
    expect(
      await store.read('synthetic-device', 'https://other.invalid/api/v1'),
      isNull,
    );
    await db.putSetting(kSessionOwner, 'other-tenant:other-user');
    expect(await repo.restoreDoctorSession(), isNull);
    await client.close();
    await db.close();
  });
}
