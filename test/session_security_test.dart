import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/backend_refusal.dart';
import 'package:myapp/data/http/online_session_check.dart';
import 'package:myapp/data/http/http_auth_repository.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/state/auth_provider.dart';

class _LoopbackHttp extends HttpOverrides {}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

class _DelayedSecureStorage implements SecureTokenStorage {
  final values = <String, String>{};
  final firstWriteStarted = Completer<void>();
  final releaseFirstWrite = Completer<void>();
  var _delayNextWrite = true;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (_delayNextWrite) {
      _delayNextWrite = false;
      firstWriteStarted.complete();
      await releaseFirstWrite.future;
    }
    values[key] = value;
  }
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _SessionGate extends StatelessWidget {
  const _SessionGate(this.auth);

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ListenableBuilder(
        listenable: auth,
        builder: (context, _) => Scaffold(
          body: Center(
            child: Text(auth.isLoggedIn ? 'Private workspace' : 'Sign In'),
          ),
        ),
      ),
    );
  }
}

class _ImmediateAuthRepository implements AuthRepository {
  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) => SynchronousFuture(_profile);

  @override
  Future<void> logout() => SynchronousFuture(null);
}

const _profile = UserProfile(
  userId: 'doctor-1',
  tenantId: 'hospital-1',
  displayName: 'Doctor One',
  email: 'doctor@example.test',
  role: 'doctor',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PR39 reconnect keeps matching offline identity and rejects a different owner',
    () async {
      final auth = AuthProvider(
        _ImmediateAuthRepository(),
        initialProfile: _profile,
      );
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        initialAccessToken: 'synthetic-access',
        initialRefreshToken: 'synthetic-refresh',
      );
      var foreign = false;
      client.dio.httpClientAdapter = _Adapter(
        (_) => _json({
          'id': foreign ? 'another-doctor' : _profile.userId,
          'tenant_id': _profile.tenantId,
          'role': _profile.role,
          'is_active': true,
        }),
      );
      await checkOnlineSession(client, auth);
      expect(auth.isLoggedIn, true);
      foreign = true;
      await checkOnlineSession(client, auth);
      expect(auth.isLoggedIn, false);
      expect(auth.sessionRefusalCode, 'session_ended');
      auth.dispose();
      await client.close();
    },
  );

  test(
    'PR39 reconnect timeout leaves approved doctor identity intact',
    () async {
      final auth = AuthProvider(
        _ImmediateAuthRepository(),
        initialProfile: _profile,
      );
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        initialAccessToken: 'synthetic-access',
        initialRefreshToken: 'synthetic-refresh',
      );
      client.dio.httpClientAdapter = _Adapter(
        (o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionTimeout,
        ),
      );
      await checkOnlineSession(client, auth);
      expect(auth.isLoggedIn, true);
      expect(client.tokens.hasSession, true);
      auth.dispose();
      await client.close();
    },
  );

  for (final refusal in {
    'account_disabled': 401,
    'session_ended': 401,
    'device_revoked': 403,
    'device_pending': 403,
    'device_required': 401,
    'device_unauthenticated': 401,
    'device_session_required': 401,
  }.entries) {
    test(
      'PR39 ${refusal.key} ends session without refresh and preserves archive keys',
      () async {
        final secure = MemorySecureTokenStorage();
        final client = ApiClient(
          baseUrl: 'https://synthetic.invalid/api/v1',
          secureStorage: secure,
          initialAccessToken: 'synthetic-access',
          initialRefreshToken: 'synthetic-refresh',
        );
        await client.deviceIdentity.saveActivation({
          'device_id': 'synthetic-device',
          'tenant_id': 'hospital-1',
          'credential': 'synthetic-credential',
          'label': 'Synthetic',
          'status': 'active',
        });
        await secure.write(
          'device_operator_outbox_aes_v1',
          'synthetic-retained-key',
        );
        final events = <SessionExpiredEvent>[];
        final subscription = client.sessionExpired.listen(events.add);
        client.dio.httpClientAdapter = _Adapter(
          (o) => _json({
            'detail': {'code': refusal.key, 'message': 'Synthetic refusal'},
          }, refusal.value),
        );
        await expectLater(
          client.dio.get<Object?>('/auth/me'),
          throwsA(isA<DioException>()),
        );
        expect(events.single.code, refusal.key);
        expect(client.tokens.hasSession, false);
        expect(
          await client.deviceIdentity.read(),
          requiresTabletActivation(refusal.key) ? isNull : isNotNull,
        );
        expect(
          await secure.read('device_operator_outbox_aes_v1'),
          'synthetic-retained-key',
        );
        expect(refusalMessage(refusal.key, english: false), isNotNull);
        await subscription.cancel();
        await client.close();
      },
    );
  }

  test(
    'PR39 ordinary 403 and network failure keep approved offline session',
    () async {
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        initialAccessToken: 'synthetic-access',
        initialRefreshToken: 'synthetic-refresh',
      );
      final events = <SessionExpiredEvent>[];
      final subscription = client.sessionExpired.listen(events.add);
      client.dio.httpClientAdapter = _Adapter(
        (_) => _json({
          'detail': {
            'code': 'forbidden',
            'message': 'Synthetic permission denial',
          },
        }, 403),
      );
      await expectLater(
        client.dio.get<Object?>('/users'),
        throwsA(isA<DioException>()),
      );
      client.dio.httpClientAdapter = _Adapter(
        (o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
      );
      await expectLater(
        client.dio.get<Object?>('/auth/me'),
        throwsA(isA<DioException>()),
      );
      expect(events, isEmpty);
      expect(client.tokens.hasSession, true);
      await subscription.cancel();
      await client.close();
    },
  );

  test(
    'concurrent 401 responses share one refresh request',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var refreshes = 0;
      server.listen((request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/auth/refresh')) {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          request.response.write(
            jsonEncode({
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
            }),
          );
        } else if (request.headers.value(HttpHeaders.authorizationHeader) ==
            'Bearer old-access') {
          request.response.statusCode = 401;
          request.response.write('{}');
        } else {
          request.response.write('[]');
        }
        await request.response.close();
      });

      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
        initialAccessToken: 'old-access',
        initialRefreshToken: 'old-refresh',
      );
      try {
        await Future.wait([
          client.dio.get<List<dynamic>>('/patients'),
          client.dio.get<List<dynamic>>('/patients'),
        ]);
        expect(refreshes, 1);
      } finally {
        await client.close();
        await server.close(force: true);
      }
    }, _LoopbackHttp()),
  );

  test('stale secure write cannot erase a newer login token pair', () async {
    final storage = _DelayedSecureStorage();
    final tokens = TokenStore(secureStorage: storage);
    final stale = tokens.update(access: 'old-access', refresh: 'old-refresh');
    await storage.firstWriteStarted.future;
    final staleRejected = expectLater(stale, throwsA(isA<StateError>()));

    final clear = tokens.clear();
    final fresh = tokens.update(
      access: 'fresh-access',
      refresh: 'fresh-refresh',
    );
    storage.releaseFirstWrite.complete();

    await staleRejected;
    await clear;
    await fresh;
    expect(await storage.read(kSecureAccessToken), 'fresh-access');
    expect(await storage.read(kSecureRefreshToken), 'fresh-refresh');
    expect(tokens.accessToken, 'fresh-access');
  });

  test('session-expired event clears PHI and secrets before logout', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final secureStorage = MemorySecureTokenStorage();
    final settings = SettingsStore(db);
    final client = ApiClient(
      baseUrl: 'http://fixture.invalid/api/v1',
      settings: settings,
      secureStorage: secureStorage,
    );
    final auth = AuthProvider(
      HttpAuthRepository(client, settings: settings, db: db),
    );
    client.dio.httpClientAdapter = _Adapter(
      (_) => _json({
        'access_token': 'access',
        'refresh_token': 'refresh',
        'user': {
          'id': 'doctor-1',
          'tenant_id': 'hospital-1',
          'full_name': 'Doctor One',
          'email': 'doctor@example.test',
          'role': 'doctor',
        },
      }),
    );
    await auth.login(email: 'doctor@example.test', password: 'test');
    await db.upsertPatient(
      LocalPatientsCompanion.insert(
        id: 'patient-1',
        code: 'P1',
        name: 'Private Patient',
        age: 40,
        gender: 'Male',
      ),
    );
    expect(await db.countPatients(), 1);

    var expiryEvents = 0;
    final logoutComplete = Completer<void>();
    final eventSubscription = client.sessionExpired.listen((_) {
      expiryEvents++;
      auth.expireSession().then(
        (_) => logoutComplete.complete(),
        onError: logoutComplete.completeError,
      );
    });
    client.tokens.refreshToken = null;
    client.dio.httpClientAdapter = _Adapter((_) => _json({}, 401));
    await expectLater(
      client.dio.get<dynamic>('/patients'),
      throwsA(isA<DioException>()),
    );
    await logoutComplete.future;

    expect(expiryEvents, 1);
    expect(auth.status, AuthStatus.loggedOut);
    expect(await db.countPatients(), 0);
    expect(await secureStorage.read(kSecureAccessToken), isNull);

    await eventSubscription.cancel();
    auth.dispose();
    await client.close();
    await db.close();
  });

  testWidgets('session-expired state replaces private UI with login', (
    tester,
  ) async {
    final auth = AuthProvider(
      _ImmediateAuthRepository(),
      initialProfile: _profile,
    );
    await tester.pumpWidget(_SessionGate(auth));
    expect(find.text('Private workspace'), findsOneWidget);

    final logout = auth.expireSession();
    await tester.pump();
    await logout;
    await tester.pump();

    expect(auth.status, AuthStatus.loggedOut);
    expect(find.text('Sign In'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
}
