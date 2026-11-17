import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/router/app_router.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_auth_repository.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/mock/mock_validation_repository.dart';
import 'package:myapp/data/offline/device_operator_outbox.dart';
import 'package:myapp/data/offline/offline_validation_repository.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/data/secure/device_identity_store.dart';
import 'package:myapp/data/secure/doctor_session_store.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/auth/presentation/auth_frame.dart';
import 'package:myapp/features/auth/presentation/change_password_screen.dart';
import 'package:myapp/features/auth/presentation/login_screen.dart';
import 'package:myapp/features/auth/presentation/tablet_activation_screen.dart';
import 'package:myapp/features/shared/presentation/app_shell.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/institution_provider.dart';

class _LoopbackHttp extends HttpOverrides {}

class _AuthAdapter implements HttpClientAdapter {
  _AuthAdapter(this.handler);

  final (int, Map<String, dynamic>) Function(RequestOptions options) handler;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    paths.add(options.path);
    final (status, payload) = handler(options);
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String _liveJwt({String sub = 'doctor-b', String tenantId = 'hospital-a'}) {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final body = base64Url.encode(
    utf8.encode(jsonEncode({'sub': sub, 'tenant_id': tenantId, 'exp': exp})),
  );
  return '$header.$body.sig';
}

Widget _wrapAuth(Widget child, AuthProvider auth, AppLanguage language) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: language),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  test(
    'B1: HttpAuthRepository skips local activation and revokes server session when clinician lacks an active model',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final settings = SettingsStore(db);
      final outbox = DeviceOperatorOutbox(db, secure);
      final doctorSession = DoctorSessionStore(secure);
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: secure,
      );
      addTearDown(() async {
        await client.close();
        await db.close();
      });

      await db.activateOwner(
        db.sessionGeneration,
        const DataOwner(
          tenantId: 'hospital-a',
          userId: 'doctor-a',
          deviceId: 'device-1',
        ),
      );
      await db.upsertPatient(
        LocalPatientsCompanion.insert(
          id: 'pat-a',
          code: 'P001',
          name: 'Prior Owner Patient',
          age: 42,
          gender: 'Male',
        ),
      );

      final adapter = _AuthAdapter((options) {
        if (options.path == '/auth/login') {
          return (
            200,
            {
              'access_token': _liveJwt(),
              'refresh_token': 'synthetic-refresh',
              'user': {
                'id': 'doctor-b',
                'tenant_id': 'hospital-a',
                'full_name': 'Doctor B',
                'email': 'doctor-b@example.invalid',
                'role': 'doctor',
              },
            },
          );
        }
        if (options.path == '/auth/logout') {
          return (200, {'ok': true});
        }
        return (404, {});
      });
      client.dio.httpClientAdapter = adapter;

      final repo = HttpAuthRepository(
        client,
        settings: settings,
        db: db,
        outbox: outbox,
        doctorSession: doctorSession,
        hasActiveModel: () async => false,
      );
      final auth = AuthProvider(repo, hasActiveModel: () async => false);
      addTearDown(auth.dispose);

      await expectLater(
        auth.login(email: 'doctor-b@example.invalid', password: 'secret'),
        throwsA(isA<NoActiveModelException>()),
      );

      expect(auth.isLoggedIn, isFalse);
      expect(auth.sessionRefusalCode, 'no_active_model');
      expect(client.tokens.hasSession, isFalse);
      expect(await secure.read(kSecureAccessToken), isNull);
      expect(await doctorSession.read('device-1', client.baseUrl), isNull);
      expect(await settings.readSessionOwner(), 'hospital-a:doctor-a');
      expect(await db.countPatients(), 1);
      expect(adapter.paths, ['/auth/login', '/auth/logout']);
    },
  );

  testWidgets(
    'B2: LoginScreen shows a single styled error banner without SnackBar duplication and clears on edit',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: SettingsStore(db),
        secureStorage: secure,
      );
      client.dio.httpClientAdapter = _AuthAdapter(
        (_) => (
          401,
          {
            'detail': {'code': 'invalid_credentials'},
          },
        ),
      );
      final repo = HttpAuthRepository(
        client,
        settings: SettingsStore(db),
        db: db,
      );
      final auth = AuthProvider(repo);
      final language = AppLanguage();
      addTearDown(() async {
        auth.dispose();
        language.dispose();
        await client.close();
        await db.close();
      });

      await tester.pumpWidget(_wrapAuth(const LoginScreen(), auth, language));

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'doctor@example.invalid',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong-pass');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthErrorBanner), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Incorrect email or password.'), findsOneWidget);

      // Toggling language updates the active login error banner live.
      language.select('id');
      await tester.pump();
      expect(find.text('Email atau password salah.'), findsOneWidget);

      // Editing password clears both inline error banner and sessionRefusalCode.
      await tester.enterText(find.byType(TextFormField).at(1), 'new-pass');
      await tester.pump();
      expect(find.byType(AuthErrorBanner), findsNothing);
      expect(auth.sessionRefusalCode, isNull);
    },
  );

  testWidgets(
    'B2: sessionRefusalCode renders in AuthErrorBanner on LoginScreen and TabletActivationScreen',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: SettingsStore(db),
      );
      final auth = AuthProvider(HttpAuthRepository(client, db: db))
        ..sessionRefusalCode = 'session_ended';
      final language = AppLanguage();
      addTearDown(() async {
        auth.dispose();
        language.dispose();
        await client.close();
        await db.close();
      });

      await tester.pumpWidget(_wrapAuth(const LoginScreen(), auth, language));
      expect(find.byType(AuthErrorBanner), findsOneWidget);
      expect(
        find.text('Your session ended. Please sign in again.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.c');
      await tester.pump();
      expect(find.byType(AuthErrorBanner), findsNothing);

      auth.sessionRefusalCode = 'device_revoked';
      await tester.pumpWidget(
        _wrapAuth(const TabletActivationScreen(), auth, language),
      );
      expect(find.byType(AuthErrorBanner), findsOneWidget);
      expect(
        find.text(
          'Tablet access revoked. Contact your administrator before reactivation.',
        ),
        findsOneWidget,
      );
    },
  );

  test(
    'B4: AuthProvider.logout awaits async onSessionEnded before releasing a queued login',
    () async {
      final events = <String>[];
      final releaseGate = Completer<void>();
      final repo = _FakeAuthRepo(
        onLogin: () async {
          events.add('repo_login');
          return const UserProfile(
            userId: 'doc-2',
            tenantId: 'hosp-1',
            displayName: 'Doctor Two',
            email: 'doc2@example.invalid',
            role: 'doctor',
          );
        },
        onLogout: () async {
          events.add('repo_logout');
        },
      );
      final auth = AuthProvider(
        repo,
        initialProfile: const UserProfile(
          userId: 'doc-1',
          tenantId: 'hosp-1',
          displayName: 'Doctor One',
          email: 'doc1@example.invalid',
          role: 'doctor',
        ),
        onSessionEnded: () async {
          events.add('release_start');
          await releaseGate.future;
          events.add('release_end');
        },
      );
      addTearDown(auth.dispose);

      final pendingLogout = auth.logout();
      await Future<void>.delayed(Duration.zero);
      final pendingLogin = auth.login(
        email: 'doc2@example.invalid',
        password: 'pw',
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, ['repo_logout', 'release_start']);
      expect(auth.isLoggedIn, isFalse);

      releaseGate.complete();
      await Future.wait([pendingLogout, pendingLogin]);

      expect(events, [
        'repo_logout',
        'release_start',
        'release_end',
        'repo_login',
      ]);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.userId, 'doc-2');
    },
  );

  test(
    'B4: expireSession aborts login waiting on logout and ignores stale non-activation expiry while authenticating',
    () async {
      final logoutGate = Completer<void>();
      final loginGate = Completer<void>();
      const profile = UserProfile(
        userId: 'doc-1',
        tenantId: 'hosp-1',
        displayName: 'Doctor One',
        email: 'doc1@example.invalid',
        role: 'doctor',
      );
      final repo = _FakeAuthRepo(
        onLogin: () async {
          await loginGate.future;
          return profile;
        },
        onLogout: () => logoutGate.future,
      );
      final auth = AuthProvider(repo, initialProfile: profile);
      addTearDown(auth.dispose);

      // Case A: logout in flight + queued login + device_revoked expiry.
      final pendingLogout = auth.logout();
      final abortedLogin = expectLater(
        auth.login(email: 'doc1@example.invalid', password: 'pw'),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);

      final expireFuture = auth.expireSession(code: 'device_revoked');
      expect(auth.deviceActivated, isFalse);
      expect(auth.sessionRefusalCode, 'device_revoked');

      logoutGate.complete();
      loginGate.complete();
      await Future.wait([pendingLogout, expireFuture, abortedLogin]);
      expect(auth.isLoggedIn, isFalse);

      // Case B: non-activation expiry during active login is ignored.
      final loginGate2 = Completer<void>();
      final repo2 = _FakeAuthRepo(
        onLogin: () async {
          await loginGate2.future;
          return profile;
        },
        onLogout: () async {},
      );
      final auth2 = AuthProvider(repo2);
      addTearDown(auth2.dispose);
      final activeLogin = auth2.login(
        email: 'doc1@example.invalid',
        password: 'pw',
      );
      await auth2.expireSession(code: 'session_ended');
      loginGate2.complete();
      await activeLogin;
      expect(auth2.isLoggedIn, isTrue);
      expect(auth2.sessionRefusalCode, isNull);
    },
  );

  testWidgets(
    'B4: failed logout cleanup surfaces logout_cleanup_failed on LoginScreen and avoids unhandled errors in AppShell & ChangePasswordScreen',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const profile = UserProfile(
        userId: 'doc-1',
        tenantId: 'hosp-1',
        displayName: 'Doctor One',
        email: 'doc1@example.invalid',
        role: 'doctor',
      );
      final repo = _FakeAuthRepo(
        onLogin: () async => profile,
        onLogout: () async => throw StateError('Outbox key missing'),
      );
      final language = AppLanguage();
      final auth = AuthProvider(repo, initialProfile: profile);
      final engine = OnnxInferenceEngine();
      addTearDown(() async {
        auth.dispose();
        language.dispose();
        await engine.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: language),
            Provider<ValidationRepository>.value(
              value: MockValidationRepository(),
            ),
            Provider<OnnxInferenceEngine>.value(value: engine),
          ],
          child: const MaterialApp(
            home: AppShell(location: '/dashboard', child: Text('Dashboard')),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(auth.status, AuthStatus.loggedOut);
      expect(auth.sessionRefusalCode, 'logout_cleanup_failed');

      await tester.pumpWidget(_wrapAuth(const LoginScreen(), auth, language));
      expect(find.byType(AuthErrorBanner), findsOneWidget);
      expect(
        find.text(
          'Failed to archive local data during sign out. Your offline data remains preserved — please sign in again.',
        ),
        findsOneWidget,
      );

      // Verify ChangePasswordScreen Sign Out absorbs cleanup failure safely too.
      final auth2 = AuthProvider(repo, initialProfile: profile);
      addTearDown(auth2.dispose);
      await tester.pumpWidget(
        _wrapAuth(const ChangePasswordScreen(), auth2, language),
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(auth2.status, AuthStatus.loggedOut);
      expect(auth2.sessionRefusalCode, 'logout_cleanup_failed');
    },
  );

  test(
    'P2: DeviceOperatorOutbox decrypts multi-chunk batches in order and restores without losing snapshots',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final outbox = DeviceOperatorOutbox(db, secure);
      addTearDown(db.close);

      const owner = DataOwner(
        tenantId: 'hosp-1',
        userId: 'doc-1',
        deviceId: 'dev-1',
      );
      await db.activateOwner(db.sessionGeneration, owner);

      // Empty restore returns cleanly.
      await outbox.restoreDoctorQueue();
      expect(await db.countPatients(), 0);

      // Seed 20 entries (>8 chunk threshold) mixing pending and retained received rows.
      for (var i = 0; i < 20; i++) {
        final ts = DateTime.utc(2026, 11, 16, 0, i).toIso8601String();
        final op = {
          'clientOpId': 'op-$i',
          'entityType': 'patient',
          'entityId': 'pat-$i',
          'operation': 'create',
          'payload': '{}',
          'status': i.isEven ? syncPending : syncSynced,
          'createdAt': ts,
          'retryCount': 0,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
        };
        final patient = {
          'id': 'pat-$i',
          'code': 'C$i',
          'name': 'Patient $i',
          'age': 30 + i,
          'gender': 'Female',
          'status': 'Normal',
          'history': '[]',
          'tombstone': false,
          'hasConflict': false,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
        };
        if (i.isEven) {
          await outbox.save({'op': op, 'patient': patient});
        } else {
          await outbox.retainReceived({'op': op, 'patient': patient});
        }
      }

      final entries = await outbox.entries(
        'hosp-1',
        'dev-1',
        ownerId: 'doc-1',
        includeReceived: true,
      );
      expect(entries.length, 20);
      for (var i = 0; i < 20; i++) {
        expect((entries[i]['op'] as Map)['clientOpId'], 'op-$i');
      }

      // Restore populates SQLite patients and queued sync ops.
      await db.clearSessionData();
      await db.activateOwner(db.sessionGeneration, owner);
      await db.putSetting(kUserRole, 'doctor');
      await outbox.restoreDoctorQueue();
      expect(await db.countPatients(), 20);
      expect((await db.pendingOps()).length, 10);
    },
  );

  test(
    'P3: AuthProvider.restoreSession(knownDevice) avoids re-reading device identity and duplicate session_owner SQLite queries',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final spyStorage = _CountingSecureStorage();
      final settings = _CountingSettingsStore(db);
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: spyStorage,
      );
      addTearDown(() async {
        await client.close();
        await db.close();
      });

      await client.deviceIdentity.saveActivation({
        'device_id': 'dev-1',
        'tenant_id': 'hosp-1',
        'credential': 'cred-1',
        'label': 'Tablet 1',
        'status': 'active',
      });
      final device = (await client.deviceIdentity.read())!;

      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final header = base64Url.encode(
        utf8.encode('{"alg":"HS256","typ":"JWT"}'),
      );
      final body = base64Url.encode(
        utf8.encode(
          jsonEncode({'sub': 'doc-1', 'tenant_id': 'hosp-1', 'exp': exp}),
        ),
      );
      final jwt = '$header.$body.sig';

      await settings.saveIdentity(
        userId: 'doc-1',
        tenantId: 'hosp-1',
        role: 'doctor',
        displayName: 'Dr. One',
        email: 'doc1@example.invalid',
      );
      await client.tokens.update(access: jwt, refresh: 'refresh-1');
      final doctorSession = DoctorSessionStore(spyStorage);
      await doctorSession.save(
        const UserProfile(
          userId: 'doc-1',
          tenantId: 'hosp-1',
          displayName: 'Dr. One',
          email: 'doc1@example.invalid',
          role: 'doctor',
        ),
        device.id,
        client.baseUrl,
      );

      spyStorage.resetCounts();
      settings.resetCounts();

      final repo = HttpAuthRepository(
        client,
        settings: settings,
        db: db,
        doctorSession: doctorSession,
      );
      final auth = AuthProvider(repo);
      addTearDown(auth.dispose);

      await auth.restoreSession(knownDevice: device);
      expect(auth.isLoggedIn, isTrue);
      expect(spyStorage.readsByKey['registered_tablet_identity_v1'] ?? 0, 0);
      expect(settings.sessionOwnerReads, 1);
    },
  );

  test(
    'B5: HttpAuthRepository.login rejects empty role and mismatched registered tenant',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final settings = SettingsStore(db);
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: secure,
      );
      addTearDown(() async {
        await client.close();
        await db.close();
      });

      await client.deviceIdentity.saveActivation({
        'device_id': 'dev-1',
        'tenant_id': 'hosp-a',
        'credential': 'cred-1',
        'label': 'Tablet A',
        'status': 'active',
      });

      var role = '';
      var tenant = 'hosp-a';
      final adapter = _AuthAdapter((options) {
        if (options.path == '/auth/login') {
          return (
            200,
            {
              'access_token': _liveJwt(),
              'refresh_token': 'ref-1',
              'user': {
                'id': 'u-1',
                'tenant_id': tenant,
                'full_name': 'User One',
                'email': 'u1@example.invalid',
                'role': role,
              },
            },
          );
        }
        return (200, {'ok': true});
      });
      client.dio.httpClientAdapter = adapter;

      final repo = HttpAuthRepository(client, settings: settings, db: db);
      await expectLater(
        repo.login(email: 'u1@example.invalid', password: 'pw'),
        throwsFormatException,
      );

      role = 'doctor';
      tenant = 'hosp-b';
      adapter.paths.clear();
      await expectLater(
        repo.login(email: 'u1@example.invalid', password: 'pw'),
        throwsFormatException,
      );
      expect(adapter.paths, ['/auth/login', '/auth/logout']);
      expect(client.tokens.hasSession, isFalse);
    },
  );

  test(
    'B6 & B7: ApiClient skips refresh on change-password 401 credential codes and supplies session_ended on repeatedUnauthorized',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final paths = <String>[];
      server.listen((request) async {
        await request.drain<void>();
        paths.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/auth/change-password')) {
          request.response.statusCode = 401;
          request.response.write(
            jsonEncode({
              'detail': {'code': 'current_password_wrong'},
            }),
          );
        } else if (request.uri.path.endsWith('/auth/refresh')) {
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode({'access_token': 'acc-2', 'refresh_token': 'ref-2'}),
          );
        } else {
          request.response.statusCode = 401;
          request.response.write('{}');
        }
        await request.response.close();
      });

      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
        settings: SettingsStore(db),
        secureStorage: secure,
        initialAccessToken: 'acc-1',
        initialRefreshToken: 'ref-1',
      );
      final events = <SessionExpiredEvent>[];
      final sub = client.sessionExpired.listen(events.add);
      try {
        await expectLater(
          client.dio.post<void>('/auth/change-password', data: {}),
          throwsA(isA<DioException>()),
        );
        expect(paths, ['/api/v1/auth/change-password']);
        expect(events, isEmpty);
        expect(client.tokens.hasSession, isTrue);

        await expectLater(
          client.dio.get<void>('/patients'),
          throwsA(isA<DioException>()),
        );
        expect(events.length, 1);
        expect(events.single.reason, SessionEndReason.repeatedUnauthorized);
        expect(events.single.code, 'session_ended');
      } finally {
        await sub.cancel();
        await client.close();
        await db.close();
        await server.close(force: true);
      }
    }, _LoopbackHttp()),
  );

  test(
    'B6: HttpAuthRepository.changePassword preserves updated session if outbox restore throws',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final settings = SettingsStore(db);
      final outbox = DeviceOperatorOutbox(db, secure);
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: secure,
      );
      addTearDown(() async {
        await client.close();
        await db.close();
      });

      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
      final header = base64Url.encode(
        utf8.encode('{"alg":"HS256","typ":"JWT"}'),
      );
      final body = base64Url.encode(
        utf8.encode(
          jsonEncode({'sub': 'doc-1', 'tenant_id': 'hosp-1', 'exp': exp}),
        ),
      );
      final jwt = '$header.$body.sig';

      client.dio.httpClientAdapter = _AuthAdapter((options) {
        final forced = options.path == '/auth/login';
        return (
          200,
          {
            'access_token': forced ? jwt : 'acc-after',
            'refresh_token': forced ? 'ref-before' : 'ref-after',
            'user': {
              'id': 'doc-1',
              'tenant_id': 'hosp-1',
              'full_name': 'Doc',
              'email': 'doc@example.invalid',
              'role': 'doctor',
              'must_change_password': forced,
            },
          },
        );
      });

      // Seed an encrypted outbox row without its AES key so restoreDoctorQueue throws.
      await db.putSetting(
        '${DeviceOperatorOutbox.prefix}stale',
        '{"cipher":"x"}',
      );

      final repo = HttpAuthRepository(
        client,
        settings: settings,
        db: db,
        outbox: outbox,
      );
      final auth = AuthProvider(repo);
      addTearDown(auth.dispose);

      await auth.login(email: 'doc@example.invalid', password: 'temp');
      expect(auth.mustChangePassword, isTrue);

      await auth.changePassword(
        currentPassword: 'temp',
        newPassword: 'new-password-123',
      );
      expect(auth.mustChangePassword, isFalse);
      expect(client.tokens.accessToken, 'acc-after');
    },
  );

  testWidgets(
    'B6 & B7: LoginScreen validates strict email/password and ChangePasswordScreen supports voluntary Back/Cancel + policy error banner',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = AppDatabase(NativeDatabase.memory());
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: SettingsStore(db),
      );
      final adapter = _AuthAdapter(
        (_) => (
          422,
          {
            'detail': {'code': 'weak_password'},
          },
        ),
      );
      client.dio.httpClientAdapter = adapter;

      var loginCalls = 0;
      final auth = AuthProvider(
        _FakeAuthRepo(
          onLogin: () async {
            loginCalls++;
            return const UserProfile(
              userId: 'doc-1',
              tenantId: 'hosp-1',
              displayName: 'Doc',
              email: 'doc@example.invalid',
              role: 'doctor',
            );
          },
          onLogout: () async {},
        ),
      );
      final language = AppLanguage();
      addTearDown(() async {
        auth.dispose();
        language.dispose();
        await client.close();
        await db.close();
      });

      await tester.pumpWidget(_wrapAuth(const LoginScreen(), auth, language));
      await tester.enterText(find.byType(TextFormField).at(0), 'user@host');
      await tester.enterText(find.byType(TextFormField).at(1), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();
      expect(loginCalls, 0);
      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      // Forced password change hides Back and Cancel.
      final forcedAuth = AuthProvider(
        HttpAuthRepository(client, db: db),
        initialProfile: const UserProfile(
          userId: 'doc-1',
          tenantId: 'hosp-1',
          displayName: 'Doc',
          email: 'doc@example.invalid',
          role: 'doctor',
          mustChangePassword: true,
        ),
      );
      addTearDown(forcedAuth.dispose);
      await tester.pumpWidget(
        _wrapAuth(const ChangePasswordScreen(), forcedAuth, language),
      );
      expect(
        find.byKey(const Key('change-password-back-button')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('change-password-cancel-button')),
        findsNothing,
      );

      // Voluntary password change exposes Back/Cancel, maps 422 weak_password to AuthErrorBanner, and returns home.
      final voluntaryAuth = AuthProvider(
        HttpAuthRepository(client, db: db),
        initialProfile: const UserProfile(
          userId: 'tech-1',
          tenantId: 'sardjito',
          displayName: 'Tech',
          email: 'tech@example.invalid',
          role: 'technician',
          mustChangePassword: false,
        ),
      );
      final router = AppRouter.create(voluntaryAuth);
      final engine = OnnxInferenceEngine();
      addTearDown(() async {
        router.dispose();
        voluntaryAuth.dispose();
        await engine.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: voluntaryAuth),
            ChangeNotifierProvider.value(value: language),
            ChangeNotifierProvider(create: (_) => InstitutionProvider()),
            Provider<ValidationRepository>.value(
              value: MockValidationRepository(),
            ),
            Provider<OnnxInferenceEngine>.value(value: engine),
            Provider<ApiClient>.value(value: client),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/change-password');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('change-password-back-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('change-password-cancel-button')),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'old-pass-1');
      await tester.enterText(find.byType(TextFormField).at(1), 'new-pass-123');
      await tester.enterText(find.byType(TextFormField).at(2), 'new-pass-123');
      await tester.tap(find.text('Save password'));
      await tester.pumpAndSettle();
      expect(find.byType(AuthErrorBanner), findsOneWidget);
      expect(
        find.text('New password does not meet security requirements.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('change-password-cancel-button')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/users');
    },
  );

  test(
    'C1: login restores pending ops synchronously, defers received cache to background, and rapid logout cancels cleanly',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final settings = SettingsStore(db);
      final outbox = DeviceOperatorOutbox(db, secure);
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: secure,
      );
      addTearDown(() async {
        await client.close();
        await db.close();
      });

      final deviceId = await settings.readOrCreateDeviceId();
      const docOwner = DataOwner(
        tenantId: 'hosp-1',
        userId: 'doc-1',
        deviceId: 'unused',
      );
      await db.activateOwner(
        db.sessionGeneration,
        DataOwner(
          tenantId: docOwner.tenantId,
          userId: docOwner.userId,
          deviceId: deviceId,
        ),
      );
      await db.putSetting(kUserRole, 'health_worker');
      final ts1 = DateTime.utc(2026, 11, 16, 1, 0).toIso8601String();
      final ts2 = DateTime.utc(2026, 11, 16, 1, 5).toIso8601String();
      await outbox.save({
        'op': {
          'clientOpId': 'op-pending-1',
          'entityType': 'patient',
          'entityId': 'pat-pending',
          'operation': 'create',
          'payload': '{}',
          'status': syncPending,
          'createdAt': ts1,
          'retryCount': 0,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': deviceId,
        },
        'patient': {
          'id': 'pat-pending',
          'code': 'P-PEND',
          'name': 'Pending Patient',
          'age': 31,
          'gender': 'Male',
          'status': 'Normal',
          'history': '[]',
          'tombstone': false,
          'hasConflict': false,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': deviceId,
        },
      });
      await outbox.retainReceived({
        'op': {
          'clientOpId': 'op-received-1',
          'entityType': 'patient',
          'entityId': 'pat-received',
          'operation': 'create',
          'payload': '{}',
          'status': syncSynced,
          'createdAt': ts2,
          'retryCount': 0,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': deviceId,
        },
        'patient': {
          'id': 'pat-received',
          'code': 'P-RECV',
          'name': 'Received Patient',
          'age': 45,
          'gender': 'Female',
          'status': 'Normal',
          'history': '[]',
          'tombstone': false,
          'hasConflict': false,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': deviceId,
        },
      });
      await db.clearSessionData();

      client.dio.httpClientAdapter = _AuthAdapter((options) {
        if (options.path == '/auth/login') {
          return (
            200,
            {
              'access_token': _liveJwt(sub: 'doc-1', tenantId: 'hosp-1'),
              'refresh_token': 'ref-doc-1',
              'user': {
                'id': 'doc-1',
                'tenant_id': 'hosp-1',
                'full_name': 'Clinician HW',
                'email': 'hw@example.invalid',
                'role': 'health_worker',
              },
            },
          );
        }
        return (200, {'ok': true});
      });

      final repo = HttpAuthRepository(
        client,
        settings: settings,
        db: db,
        outbox: outbox,
        doctorSession: DoctorSessionStore(secure),
        hasActiveModel: () async => true,
      );

      // Direct repo.login executes only the pendingOutbox phase.
      await repo.login(email: 'hw@example.invalid', password: 'secret');
      expect((await db.findPatient('pat-pending'))?.name, 'Pending Patient');
      expect(await db.findPatient('pat-received'), isNull);

      await repo.hydrateReceivedCache();
      expect((await db.findPatient('pat-received'))?.name, 'Received Patient');

      // AuthProvider.login schedules background hydration automatically.
      await repo.logout();
      expect(await db.countPatients(), 0);
      final auth = AuthProvider(repo, hasActiveModel: () async => true);
      addTearDown(auth.dispose);

      await auth.login(email: 'hw@example.invalid', password: 'secret');
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (await db.findPatient('pat-received') == null &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect((await db.findPatient('pat-pending'))?.name, 'Pending Patient');
      expect((await db.findPatient('pat-received'))?.name, 'Received Patient');

      // Rapid logout cancels/aborts in-flight hydration without leaking rows.
      await auth.logout();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(auth.isLoggedIn, isFalse);
      expect(await db.countPatients(), 0);

      await auth.login(email: 'hw@example.invalid', password: 'secret');
      await auth.logout();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(auth.isLoggedIn, isFalse);
      expect(await db.countPatients(), 0);
    },
  );

  test(
    'C1: entries SQL-filters foreign owners and restoreDoctorQueue batches conflicts, failures, and overlays',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final outbox = DeviceOperatorOutbox(db, secure);
      addTearDown(db.close);

      const owner1 = DataOwner(
        tenantId: 'hosp-1',
        userId: 'doc-1',
        deviceId: 'dev-1',
      );
      await db.activateOwner(db.sessionGeneration, owner1);
      await db.putSetting(kUserRole, 'doctor');

      final now = DateTime.utc(2026, 11, 16, 2, 0).toIso8601String();
      await outbox.save({
        'op': {
          'clientOpId': 'op-conflict',
          'entityType': 'diagnosis',
          'entityId': 'diag-1',
          'operation': 'update',
          'payload': '{}',
          'status': syncConflict,
          'createdAt': now,
          'retryCount': 1,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
        },
        'patient': {
          'id': 'pat-1',
          'code': 'P1',
          'name': 'Batched Patient',
          'age': 40,
          'gender': 'Male',
          'status': 'Normal',
          'history': '[]',
          'tombstone': false,
          'hasConflict': false,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
        },
        'diagnosis': {
          'id': 'diag-1',
          'patientId': 'pat-1',
          'isPositive': true,
          'confidence': 88,
          'modelVersion': 'v1',
          'findings': '{}',
          'status': 'pending',
          'diagnosedAt': now,
          'hasConflict': false,
          'tombstone': false,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
          'provenance': '{}',
          'isMock': false,
          'patientSnapshot': '{}',
          'clinicalSnapshot': '{}',
          'saveStatus': 'unsaved',
        },
        'artifact': {
          'id': 'diag-1',
          'cipherText': [1, 2, 3],
          'nonce': [4, 5, 6],
          'mac': [7, 8, 9],
          'filename': 'xray.png',
          'mimeType': 'image/png',
          'source': 'camera',
          'checksum': 'sum1',
          'sizeBytes': 10,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
          'createdAt': now,
        },
        'segmentation_artifacts': [
          {
            'id': 'diag-1:lung',
            'cipherText': [10, 11, 12],
            'nonce': [13, 14, 15],
            'mac': [16, 17, 18],
            'filename': 'lung.png',
            'mimeType': 'image/png',
            'source': 'onnx',
            'checksum': 'sum2',
            'sizeBytes': 5,
            'tenantId': 'hosp-1',
            'userId': 'doc-1',
            'deviceId': 'dev-1',
            'createdAt': now,
          },
        ],
      });

      // Seed a permanent-failure diagnosis op to verify batched failed saveStatus.
      await outbox.save({
        'op': {
          'clientOpId': 'op-failed',
          'entityType': 'diagnosis',
          'entityId': 'diag-failed',
          'operation': 'create',
          'payload': '{}',
          'status': syncPermanentFailure,
          'createdAt': now,
          'retryCount': 3,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
        },
        'diagnosis': {
          'id': 'diag-failed',
          'patientId': 'pat-1',
          'isPositive': false,
          'confidence': 42,
          'modelVersion': 'v1',
          'findings': '{}',
          'status': 'pending',
          'diagnosedAt': now,
          'hasConflict': false,
          'tombstone': false,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
          'provenance': '{}',
          'isMock': false,
          'patientSnapshot': '{}',
          'clinicalSnapshot': '{}',
          'saveStatus': 'unsaved',
        },
      });

      // Seed a foreign owner's corrupted ciphertext with valid JSON routing metadata;
      // doc-1 queries must filter it out in SQL before attempting decryption.
      await db.putSetting(
        '${DeviceOperatorOutbox.prefix}foreign-op',
        jsonEncode({
          'cipher': 'invalid',
          'nonce': 'invalid',
          'mac': 'invalid',
          'tenant_id': 'hosp-1',
          'device_id': 'dev-1',
          'owner_id': 'doc-2',
        }),
      );
      await outbox.retainReceived({
        'op': {
          'clientOpId': 'op-doc1-recv',
          'entityType': 'patient',
          'entityId': 'pat-2',
          'operation': 'create',
          'payload': '{}',
          'status': syncSynced,
          'createdAt': now,
          'retryCount': 0,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
        },
        'patient': {
          'id': 'pat-2',
          'code': 'P2',
          'name': 'Doc1 Received',
          'age': 29,
          'gender': 'Female',
          'status': 'Normal',
          'history': '[]',
          'tombstone': false,
          'hasConflict': false,
          'tenantId': 'hosp-1',
          'userId': 'doc-1',
          'deviceId': 'dev-1',
        },
      });

      final pendingOnly = await outbox.entries(
        'hosp-1',
        'dev-1',
        ownerId: 'doc-1',
        includePending: true,
        includeReceived: false,
      );
      expect(pendingOnly.length, 2);
      expect(
        pendingOnly.map((e) => (e['op'] as Map)['clientOpId']),
        containsAll(['op-conflict', 'op-failed']),
      );

      final receivedOnly = await outbox.entries(
        'hosp-1',
        'dev-1',
        ownerId: 'doc-1',
        includePending: false,
        includeReceived: true,
      );
      expect(receivedOnly.length, 1);
      expect((receivedOnly.single['op'] as Map)['clientOpId'], 'op-doc1-recv');

      await db.clearSessionData();
      await db.activateOwner(db.sessionGeneration, owner1);
      await db.putSetting(kUserRole, 'doctor');
      await outbox.restoreDoctorQueue(scope: OutboxRestoreScope.pendingOnly);

      final restoredDiag = (await db.findDiagnosis('diag-1'))!;
      expect(restoredDiag.hasConflict, isTrue);
      expect(restoredDiag.saveStatus, 'conflict');
      expect((await db.findDiagnosis('diag-failed'))?.saveStatus, 'failed');
      expect(await db.findEncryptedArtifact('diag-1'), isNotNull);
      expect(await db.findEncryptedArtifact('diag-1:lung'), isNotNull);
      expect(await db.findPatient('pat-2'), isNull);

      await outbox.restoreDoctorQueue(scope: OutboxRestoreScope.receivedOnly);
      expect((await db.findPatient('pat-2'))?.name, 'Doc1 Received');
    },
  );

  test(
    'C2: AuthProvider.login runs hasActiveModel once for clinicians, skips it for technicians, and preserves fallback when repo lacks gate',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final settings = SettingsStore(db);
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: secure,
      );
      addTearDown(() async {
        await client.close();
        await db.close();
      });

      var currentRole = 'doctor';
      client.dio.httpClientAdapter = _AuthAdapter((options) {
        if (options.path == '/auth/login') {
          return (
            200,
            {
              'access_token': _liveJwt(),
              'refresh_token': 'ref-token',
              'user': {
                'id': 'doctor-b',
                'tenant_id': 'hospital-a',
                'full_name': 'User B',
                'email': 'user-b@example.invalid',
                'role': currentRole,
              },
            },
          );
        }
        return (200, {'ok': true});
      });

      var checkCalls = 0;
      var modelPresent = true;
      Future<bool> hasActiveModel() async {
        checkCalls++;
        return modelPresent;
      }

      // 1. Repository with hasActiveModel wired: clinician triggers check once; technician 0 times.
      final gatedRepo = HttpAuthRepository(
        client,
        settings: settings,
        db: db,
        doctorSession: DoctorSessionStore(secure),
        hasActiveModel: hasActiveModel,
      );
      final authGated = AuthProvider(gatedRepo, hasActiveModel: hasActiveModel);
      addTearDown(authGated.dispose);

      await authGated.login(email: 'user-b@example.invalid', password: 'pw');
      expect(checkCalls, 1);
      await authGated.logout();

      currentRole = 'technician';
      await authGated.login(email: 'user-b@example.invalid', password: 'pw');
      expect(checkCalls, 1);
      await authGated.logout();

      // Clinician without model still fails closed with NoActiveModelException after 1 check.
      currentRole = 'doctor';
      modelPresent = false;
      await expectLater(
        authGated.login(email: 'user-b@example.invalid', password: 'pw'),
        throwsA(isA<NoActiveModelException>()),
      );
      expect(checkCalls, 2);
      expect(authGated.sessionRefusalCode, 'no_active_model');

      // 2. Repository without hasActiveModel: AuthProvider fallback still enforces the gate.
      final ungatedRepo = HttpAuthRepository(
        client,
        settings: settings,
        db: db,
      );
      final authFallback = AuthProvider(
        ungatedRepo,
        hasActiveModel: hasActiveModel,
      );
      addTearDown(authFallback.dispose);

      await expectLater(
        authFallback.login(email: 'user-b@example.invalid', password: 'pw'),
        throwsA(isA<NoActiveModelException>()),
      );
      expect(checkCalls, 3);
      expect(authFallback.sessionRefusalCode, 'no_active_model');
    },
  );

  test(
    'C3: DeviceIdentityStore caches valid identity across login/requests, clears on clearRegistration, and skips redundant doctor session writes',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final spyStorage = _CountingSecureStorage();
      final settings = SettingsStore(db);
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: spyStorage,
      );
      addTearDown(() async {
        await client.close();
        await db.close();
      });

      await client.deviceIdentity.saveActivation({
        'device_id': 'dev-1',
        'tenant_id': 'hosp-1',
        'credential': 'cred-1',
        'label': 'Tablet 1',
        'status': 'active',
      });
      spyStorage.resetCounts();

      var role = 'technician';
      var mustChangePassword = false;
      client.dio.httpClientAdapter = _AuthAdapter((options) {
        if (options.path == '/auth/login') {
          return (
            200,
            {
              'access_token': _liveJwt(sub: 'user-1', tenantId: 'hosp-1'),
              'refresh_token': 'ref-1',
              'user': {
                'id': 'user-1',
                'tenant_id': 'hosp-1',
                'full_name': 'User One',
                'email': 'u1@example.invalid',
                'role': role,
                'must_change_password': mustChangePassword,
              },
            },
          );
        }
        return (200, {'items': []});
      });

      final doctorSession = DoctorSessionStore(spyStorage);
      final repo = HttpAuthRepository(
        client,
        settings: settings,
        db: db,
        doctorSession: doctorSession,
        hasActiveModel: () async => true,
      );

      // Technician login never saves doctor_offline_session_v1 and reads cached device identity 0 extra times.
      await repo.login(email: 'u1@example.invalid', password: 'pw');
      await client.dio.get<Map<String, dynamic>>('/patients');
      expect(spyStorage.readsByKey['registered_tablet_identity_v1'] ?? 0, 0);
      expect(spyStorage.writesByKey[DoctorSessionStore.key] ?? 0, 0);
      expect(await settings.readRole(), 'technician');
      expect(await settings.readSessionOwner(), 'hosp-1:user-1');

      // Forced-password-change clinician also skips writing offline doctor session.
      role = 'doctor';
      mustChangePassword = true;
      spyStorage.resetCounts();
      await repo.login(email: 'u1@example.invalid', password: 'pw');
      expect(spyStorage.writesByKey[DoctorSessionStore.key] ?? 0, 0);

      // Full clinician login persists doctor session + tokens alongside batched identity settings.
      mustChangePassword = false;
      spyStorage.resetCounts();
      await repo.login(email: 'u1@example.invalid', password: 'pw');
      expect(spyStorage.writesByKey[DoctorSessionStore.key], 1);
      expect(spyStorage.writesByKey[kSecureAccessToken], 1);
      expect(spyStorage.writesByKey[kSecureRefreshToken], 1);
      expect(spyStorage.readsByKey['registered_tablet_identity_v1'] ?? 0, 0);
      expect(await settings.readDisplayName(), 'User One');
      expect(await settings.readEmail(), 'u1@example.invalid');

      // Re-reading from a cold store caches after 1 read, and clearRegistration invalidates the cache.
      final coldStore = DeviceIdentityStore(spyStorage);
      spyStorage.resetCounts();
      expect((await coldStore.read())?.id, 'dev-1');
      expect((await coldStore.read())?.id, 'dev-1');
      expect(spyStorage.readsByKey['registered_tablet_identity_v1'], 1);
      await coldStore.clearRegistration();
      expect(await coldStore.read(), isNull);
    },
  );

  test(
    'C3: captureDoctorQueue exits fast on empty queue and batch-encrypts multi-chunk pending ops with overlays',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final spyStorage = _CountingSecureStorage();
      final outbox = DeviceOperatorOutbox(db, spyStorage);
      addTearDown(db.close);

      const owner = DataOwner(
        tenantId: 'hosp-1',
        userId: 'doc-1',
        deviceId: 'dev-1',
      );
      await db.activateOwner(
        db.sessionGeneration,
        owner,
        identitySettings: SettingsStore.identityEntries(
          userId: 'doc-1',
          tenantId: 'hosp-1',
          role: 'doctor',
          displayName: 'Dr. Batch',
          email: 'batch@example.invalid',
        ),
      );

      // Empty queue must return without reading or creating the AES outbox key.
      await outbox.captureDoctorQueue();
      expect(spyStorage.readsByKey['device_operator_outbox_aes_v1'] ?? 0, 0);

      // Seed 10 pending patient+diagnosis+overlay ops (>4 batch threshold).
      for (var i = 0; i < 10; i++) {
        final pid = 'pat-$i';
        final did = 'diag-$i';
        final ts = DateTime.utc(2026, 11, 16, 3, i);
        await db.upsertPatient(
          LocalPatientsCompanion.insert(
            id: pid,
            code: 'C$i',
            name: 'Patient $i',
            age: 30 + i,
            gender: 'Male',
          ),
        );
        await db.upsertDiagnosis(
          LocalDiagnosesCompanion.insert(
            id: did,
            patientId: pid,
            isPositive: true,
            confidence: 90,
            modelVersion: 'v1',
            diagnosedAt: ts,
            clinicalSnapshot: Value(
              jsonEncode({
                'segmentation_v1': {
                  'lesion_layers': {'cavity': 'diag-$i:lesion:cavity'},
                },
              }),
            ),
          ),
        );
        for (final aid in [
          did,
          '$did:xray',
          '$did:lung',
          '$did:lesion:cavity',
        ]) {
          await db.upsertEncryptedArtifact(
            EncryptedXrayArtifactsCompanion.insert(
              id: aid,
              cipherText: Uint8List.fromList([1, 2, i]),
              nonce: Uint8List.fromList([3, 4, i]),
              mac: Uint8List.fromList([5, 6, i]),
              filename: '$aid.png',
              mimeType: 'image/png',
              source: 'onnx',
              checksum: 'sum-$aid',
              sizeBytes: 3,
              createdAt: ts,
            ),
          );
        }
        await db.enqueue(
          SyncQueueCompanion.insert(
            clientOpId: 'op-$i',
            entityType: 'diagnosis',
            entityId: did,
            operation: 'create',
            payload: '{}',
            createdAt: ts,
          ),
        );
      }

      spyStorage.resetCounts();
      await outbox.captureDoctorQueue();
      expect(spyStorage.readsByKey['device_operator_outbox_aes_v1'], 1);

      final archived = await outbox.entries(
        'hosp-1',
        'dev-1',
        ownerId: 'doc-1',
      );
      expect(archived.length, 10);

      await db.clearSessionData();
      await db.activateOwner(
        db.sessionGeneration,
        owner,
        identitySettings: SettingsStore.identityEntries(
          userId: 'doc-1',
          tenantId: 'hosp-1',
          role: 'doctor',
          displayName: 'Dr. Batch',
          email: 'batch@example.invalid',
        ),
      );
      await outbox.restoreDoctorQueue(scope: OutboxRestoreScope.pendingOnly);
      expect(await db.countPatients(), 10);
      expect((await db.pendingOps()).length, 10);
      expect(await db.findEncryptedArtifact('diag-9:lesion:cavity'), isNotNull);
    },
  );

  test(
    'C4: OfflineValidationRepository.watchPendingCount caches hidden reviews per owner and invalidates on sessionGeneration change',
    () async {
      final db = _CountingHiddenDb();
      final secure = MemorySecureTokenStorage();
      final settings = SettingsStore(db);
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: secure,
      );
      addTearDown(() async {
        await client.close();
        await db.close();
      });

      const owner1 = DataOwner(
        tenantId: 'hosp-1',
        userId: 'doc-1',
        deviceId: 'dev-1',
      );
      await db.activateOwner(
        db.sessionGeneration,
        owner1,
        identitySettings: SettingsStore.identityEntries(
          userId: 'doc-1',
          tenantId: 'hosp-1',
          role: 'doctor',
          displayName: 'Doc 1',
          email: 'doc1@example.invalid',
        ),
      );
      final repo = OfflineValidationRepository(
        db: db,
        client: client,
        syncEngine: SyncEngine(db: db, client: client, settings: settings),
        localOnly: true,
      );

      final emitted = <int>[];
      final sub = repo.watchPendingCount().listen(emitted.add);
      addTearDown(sub.cancel);

      Future<void> seedDiag(String id, {String? patientId}) async {
        await db.upsertPatient(
          LocalPatientsCompanion.insert(
            id: patientId ?? 'pat-$id',
            code: 'C-$id',
            name: 'Pat $id',
            age: 30,
            gender: 'Male',
          ),
        );
        await db.upsertDiagnosis(
          LocalDiagnosesCompanion.insert(
            id: id,
            patientId: patientId ?? 'pat-$id',
            isPositive: true,
            confidence: 80,
            modelVersion: 'v1',
            diagnosedAt: DateTime.utc(2026, 11, 16, 4),
            serverVersion: const Value(1),
            isMock: const Value(false),
          ),
        );
      }

      // Trigger multiple local_diagnoses emissions within the same session.
      await seedDiag('d-1');
      await seedDiag('d-2');
      await seedDiag('d-3');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted.last, 3);
      // deleted_validation_v1:... setting should be queried only once despite 3+ emissions.
      expect(db.hiddenSettingReads, 1);

      // Resetting/hiding a review updates the cache cleanly without re-reading SQLite.
      await repo.submitScore(id: 'd-2', score: 5, status: 'pending');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emitted.last, 2);
      expect(db.hiddenSettingReads, 1);

      // Session switch/logout bumps sessionGeneration and invalidates the cache.
      await db.clearSessionData();
      await db.activateOwner(db.sessionGeneration, owner1);
      await seedDiag('d-4');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(db.hiddenSettingReads, 2);
    },
  );
}

class _CountingHiddenDb extends AppDatabase {
  _CountingHiddenDb() : super(NativeDatabase.memory());

  int hiddenSettingReads = 0;

  @override
  Future<String?> getSetting(String key) {
    if (key.startsWith('deleted_validation_v1:')) {
      hiddenSettingReads++;
    }
    return super.getSetting(key);
  }
}

class _CountingSecureStorage extends MemorySecureTokenStorage {
  final Map<String, int> readsByKey = {};
  final Map<String, int> writesByKey = {};
  final Map<String, int> deletesByKey = {};

  void resetCounts() {
    readsByKey.clear();
    writesByKey.clear();
    deletesByKey.clear();
  }

  @override
  Future<String?> read(String key) {
    readsByKey[key] = (readsByKey[key] ?? 0) + 1;
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) {
    writesByKey[key] = (writesByKey[key] ?? 0) + 1;
    return super.write(key, value);
  }

  @override
  Future<void> delete(String key) {
    deletesByKey[key] = (deletesByKey[key] ?? 0) + 1;
    return super.delete(key);
  }
}

class _CountingSettingsStore extends SettingsStore {
  _CountingSettingsStore(super.db);

  int sessionOwnerReads = 0;

  void resetCounts() => sessionOwnerReads = 0;

  @override
  Future<String?> readSessionOwner() {
    sessionOwnerReads++;
    return super.readSessionOwner();
  }
}

class _FakeAuthRepo implements AuthRepository {
  _FakeAuthRepo({required this.onLogin, required this.onLogout});

  final Future<UserProfile> Function() onLogin;
  final Future<void> Function() onLogout;

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) => onLogin();

  @override
  Future<void> logout() => onLogout();
}
