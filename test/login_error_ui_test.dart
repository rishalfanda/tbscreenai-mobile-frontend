import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_auth_repository.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/mock/mock_validation_repository.dart';
import 'package:myapp/data/offline/device_operator_outbox.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/data/secure/doctor_session_store.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/auth/presentation/auth_frame.dart';
import 'package:myapp/features/auth/presentation/change_password_screen.dart';
import 'package:myapp/features/auth/presentation/login_screen.dart';
import 'package:myapp/features/auth/presentation/tablet_activation_screen.dart';
import 'package:myapp/features/shared/presentation/app_shell.dart';
import 'package:myapp/state/auth_provider.dart';

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

String _liveJwt() {
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final header = base64Url.encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
  final body = base64Url.encode(
    utf8.encode(
      jsonEncode({'sub': 'doctor-b', 'tenant_id': 'hospital-a', 'exp': exp}),
    ),
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
      expect(find.text('Your session ended. Please sign in again.'), findsOneWidget);

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
            home: AppShell(
              location: '/dashboard',
              child: Text('Dashboard'),
            ),
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
