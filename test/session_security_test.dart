import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/data/http/api_client.dart';
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
