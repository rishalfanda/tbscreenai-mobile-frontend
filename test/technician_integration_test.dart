import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/router/app_router.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_auth_repository.dart';
import 'package:myapp/data/http/http_dataset_repository.dart';
import 'package:myapp/data/http/http_managed_users_repository.dart';
import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/models/dataset_page.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/domain/repositories/dataset_repository.dart';
import 'package:myapp/features/institution/presentation/live_users_screen.dart';
import 'package:myapp/features/dataset/presentation/live_dataset_screen.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/live_dataset_provider.dart';
import 'http_dataset_test.dart' as datasets;

Map<String, dynamic> user({
  String id = 'doctor',
  String tenant = 'hospital',
  String role = 'doctor',
  bool active = true,
}) => {
  'id': id,
  'tenant_id': tenant,
  'full_name': 'Synthetic $id',
  'email': '$id@example.invalid',
  'role': role,
  'is_active': active,
  'must_change_password': true,
  'specialization': null,
};
const actor = UserProfile(
  userId: 'tech',
  tenantId: 'hospital',
  displayName: 'Synthetic technician',
  email: 'tech@example.invalid',
  role: 'technician',
);

class _Auth implements AuthRepository {
  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async => actor;
  @override
  Future<void> logout() async {}
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final FutureOr<(int, Object?)> Function(RequestOptions) answer;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = await answer(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient client(FutureOr<(int, Object?)> Function(RequestOptions) answer) {
  final api = ApiClient(
    baseUrl: 'https://synthetic.invalid/api/v1',
    initialAccessToken: 'synthetic-access',
    initialRefreshToken: 'synthetic-refresh',
  );
  api.dio.httpClientAdapter = _Adapter(answer);
  addTearDown(api.close);
  return api;
}

Map<String, Object?> issued([Map<String, dynamic>? row]) => {
  'user': row ?? user(),
  'temporary_password': 'synthetic-once-only',
  'expires_at': '2026-11-01T00:00:00Z',
};
Map<String, Object?> tokenPair({
  bool required = false,
  String tenant = 'hospital',
  String access = 'synthetic-replacement',
}) => {
  'access_token': access,
  'refresh_token': 'synthetic-next-refresh',
  'user': {
    ...user(id: 'tech', role: 'technician', tenant: tenant),
    'must_change_password': required,
  },
};

void main() {
  test('technician permissions match PR37; doctor baseline is retained', () {
    for (final path in [
      '/users',
      '/technician',
      '/dashboard',
      '/dataset',
      '/account',
      '/models',
      '/sync',
    ]) {
      expect(MobileRole.technician.allows(path), isTrue);
    }
    for (final path in [
      '/diagnosis',
      '/result',
      '/validation',
      '/camera',
      '/patients',
    ]) {
      expect(MobileRole.technician.allows(path), isFalse);
    }
    expect(MobileRole.clinician.allows('/diagnosis'), isTrue);
    expect(MobileRole.parse('admin_rs'), MobileRole.unsupported);
  });
  test(
    'users list sends filter and pagination without a caller-selected tenant',
    () async {
      final api = client((o) {
        expect(o.path, '/users');
        expect(o.queryParameters, {
          'limit': 20,
          'offset': 20,
          'q': 'test',
          'is_active': false,
        });
        expect(o.headers.containsKey('X-Tenant-Id'), isFalse);
        return (
          200,
          {
            'items': [user()],
            'total': 21,
            'limit': 20,
            'offset': 20,
          },
        );
      });
      final page = await HttpManagedUsersRepository(
        api,
      ).list('hospital', query: ' test ', offset: 20, active: false);
      expect(page.total, 21);
      expect(page.items.single.mustChangePassword, isTrue);
    },
  );
  test('cross-tenant and mismatched detail responses are rejected', () async {
    final api = client((_) => (200, user(tenant: 'other')));
    final repo = HttpManagedUsersRepository(api);
    await expectLater(repo.detail('hospital', 'doctor'), throwsFormatException);
    api.dio.httpClientAdapter = _Adapter((_) => (200, user(id: 'different')));
    await expectLater(repo.detail('hospital', 'doctor'), throwsFormatException);
  });
  test(
    'create/reset return one-time secrets and deactivate uses PATCH, never DELETE',
    () async {
      final calls = <String>[];
      final api = client((o) {
        calls.add('${o.method} ${o.path}');
        if (o.path == '/users') {
          expect(o.data, {
            'full_name': 'Synthetic',
            'email': 'new@example.invalid',
            'role': 'doctor',
            'specialization': null,
          });
          return (201, issued());
        }
        if (o.path.endsWith('reset-password')) {
          return (200, issued());
        }
        expect(o.data, {'is_active': false});
        return (200, user(active: false));
      });
      final repo = HttpManagedUsersRepository(api);
      expect(
        (await repo.create(
          'hospital',
          name: ' Synthetic ',
          email: 'new@example.invalid',
        )).password,
        'synthetic-once-only',
      );
      await repo.reset('hospital', 'doctor');
      expect(
        (await repo.update('hospital', 'doctor', {'is_active': false})).active,
        isFalse,
      );
      expect(calls, [
        'POST /users',
        'POST /users/doctor/reset-password',
        'PATCH /users/doctor',
      ]);
    },
  );
  test('HTTP errors do not create a demo success', () async {
    final api = client(
      (_) => (
        409,
        {
          'detail': {'code': 'email_taken'},
        },
      ),
    );
    await expectLater(
      HttpManagedUsersRepository(
        api,
      ).create('hospital', name: 'Synthetic', email: 'new@example.invalid'),
      throwsA(isA<DioException>()),
    );
  });
  test(
    'temporary-password login flag persists until a validated new token pair',
    () async {
      final api = client(
        (o) => o.path == '/auth/login'
            ? (200, tokenPair(required: true, access: 'synthetic-before'))
            : (200, tokenPair()),
      );
      final auth = AuthProvider(HttpAuthRepository(api));
      addTearDown(auth.dispose);
      await auth.login(email: 'tech@example.invalid', password: 'synthetic');
      expect(auth.mustChangePassword, isTrue);
      await auth.changePassword(
        currentPassword: 'synthetic',
        newPassword: 'synthetic-new',
      );
      expect(auth.mustChangePassword, isFalse);
      expect(api.tokens.accessToken, 'synthetic-replacement');
    },
  );
  test(
    'password change wrong current password keeps the restricted session',
    () async {
      final api = client(
        (o) => o.path == '/auth/login'
            ? (200, tokenPair(required: true, access: 'synthetic-before'))
            : (
                400,
                {
                  'detail': {'code': 'current_password_wrong'},
                },
              ),
      );
      final auth = AuthProvider(HttpAuthRepository(api));
      addTearDown(auth.dispose);
      await auth.login(email: 'tech@example.invalid', password: 'synthetic');
      await expectLater(
        auth.changePassword(
          currentPassword: 'wrong',
          newPassword: 'synthetic-new',
        ),
        throwsA(isA<DioException>()),
      );
      expect(auth.mustChangePassword, isTrue);
      expect(api.tokens.accessToken, 'synthetic-before');
    },
  );
  test(
    'password change rejects identity swap before installing tokens',
    () async {
      final api = client(
        (o) => o.path == '/auth/login'
            ? (200, tokenPair(required: true, access: 'synthetic-before'))
            : (200, tokenPair(tenant: 'other')),
      );
      final auth = AuthProvider(HttpAuthRepository(api));
      addTearDown(auth.dispose);
      await auth.login(email: 'tech@example.invalid', password: 'synthetic');
      await expectLater(
        auth.changePassword(
          currentPassword: 'synthetic',
          newPassword: 'synthetic-new',
        ),
        throwsFormatException,
      );
      expect(api.tokens.accessToken, 'synthetic-before');
      expect(auth.mustChangePassword, isTrue);
    },
  );
  test(
    'late password response after logout cannot restore tokens or profile',
    () async {
      final waiting = Completer<(int, Object?)>();
      final api = client(
        (o) => o.path == '/auth/login'
            ? (200, tokenPair(required: true))
            : waiting.future,
      );
      final auth = AuthProvider(HttpAuthRepository(api));
      addTearDown(auth.dispose);
      await auth.login(email: 'tech@example.invalid', password: 'synthetic');
      final change = auth.changePassword(
        currentPassword: 'synthetic',
        newPassword: 'synthetic-new',
      );
      final rejected = expectLater(change, throwsA(anything));
      await Future<void>.delayed(Duration.zero);
      await auth.logout();
      waiting.complete((200, tokenPair()));
      await rejected;
      expect(api.tokens.hasSession, isFalse);
      expect(auth.isLoggedIn, isFalse);
    },
  );
  testWidgets('forced password change cannot be bypassed through a route', (
    tester,
  ) async {
    final auth = AuthProvider(
      _Auth(),
      initialProfile: const UserProfile(
        userId: 'tech',
        tenantId: 'hospital',
        displayName: 'Synthetic',
        email: 'tech@example.invalid',
        role: 'technician',
        mustChangePassword: true,
      ),
    );
    final router = AppRouter.create(auth);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => AppLanguage()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    for (final path in [
      '/users',
      '/dataset',
      '/sync',
      '/models',
      '/account',
      '/sync',
      '/diagnosis',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/change-password',
      );
    }
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets('live users manageable rows and paging fit $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = client(
        (_) => (
          200,
          {
            'items': [user(), user(id: 'tech', role: 'technician')],
            'total': 2,
            'limit': 20,
            'offset': 0,
          },
        ),
      );
      final auth = AuthProvider(_Auth(), initialProfile: actor);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider.value(value: api),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
          ],
          child: const MaterialApp(home: Scaffold(body: LiveUsersScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Synthetic doctor'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Read only'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(tester.takeException(), isNull);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(find.text('Synthetic doctor'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('temporary password dialog clears its content on logout', (
    tester,
  ) async {
    final api = client(
      (o) => o.path.endsWith('reset-password')
          ? (200, issued())
          : (
              200,
              {
                'items': [user()],
                'total': 1,
                'limit': 20,
                'offset': 0,
              },
            ),
    );
    final auth = AuthProvider(_Auth(), initialProfile: actor);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: api),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => AppLanguage()),
        ],
        child: const MaterialApp(home: Scaffold(body: LiveUsersScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('synthetic-once-only'), findsOneWidget);
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.text('synthetic-once-only'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('dataset technician write requests and tenant checks', () async {
    final calls = <String>[];
    final api = client((o) {
      calls.add('${o.method} ${o.path}');
      return (
        200,
        o.method == 'POST' && o.path == '/datasets' || o.method == 'PATCH'
            ? datasets.entry('dataset')
            : {},
      );
    });
    final repo = HttpDatasetRepository(api);
    final auth = AuthProvider(_Auth(), initialProfile: actor);
    addTearDown(auth.dispose);
    await repo.create(name: 'Synthetic');
    await repo.update('dataset', {'status': 'archived'});
    await repo.addItems('dataset', ['diagnosis']);
    await repo.removeItem('dataset', 'diagnosis');
    await repo.delete('dataset');
    expect(calls, [
      'POST /datasets',
      'PATCH /datasets/dataset',
      'POST /datasets/dataset/items',
      'DELETE /datasets/dataset/items/diagnosis',
      'DELETE /datasets/dataset',
    ]);
    api.dio.httpClientAdapter = _Adapter(
      (_) => (200, {'items': [], 'total': 0, 'limit': 20, 'offset': 0}),
    );
    final state = LiveDatasetProvider(repo, auth);
    addTearDown(state.dispose);
    expect(state.canWrite, isTrue);
    await state.loadList();
    expect(
      await state.mutate(
        (_) async => await Future.value(datasetsEntryOtherTenant()),
      ),
      isFalse,
    );
    expect(state.error, isNotNull);
  });
  testWidgets('create doctor shows duplicate error then a one-time password', (
    tester,
  ) async {
    var attempts = 0;
    final api = client((o) {
      if (o.method == 'POST') {
        attempts++;
        return attempts == 1
            ? (
                409,
                {
                  'detail': {'code': 'email_taken'},
                },
              )
            : (201, issued());
      }
      return (200, {'items': [], 'total': 0, 'limit': 20, 'offset': 0});
    });
    final auth = AuthProvider(_Auth(), initialProfile: actor);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: api),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => AppLanguage()),
        ],
        child: const MaterialApp(home: Scaffold(body: LiveUsersScreen())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add doctor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Synthetic doctor',
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'new@example.invalid',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Email is already in use.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('synthetic-once-only'), findsOneWidget);
    await tester.tap(find.text('Recorded securely'));
    await tester.pumpAndSettle();
    expect(find.text('synthetic-once-only'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'technician dataset creates, adds a screening and archives through API',
    (tester) async {
      var created = false, added = false, archived = false;
      final calls = <String>[];
      final api = client((o) {
        calls.add('${o.method} ${o.path}');
        final entry = {
          ...datasets.entry('dataset'),
          'name': 'Synthetic collection',
          'status': archived ? 'archived' : 'active',
        };
        if (o.path == '/datasets') {
          if (o.method == 'POST') {
            created = true;
            return (201, entry);
          }
          return (200, datasets.page(created ? [entry] : []));
        }
        if (o.path == '/diagnoses') {
          return (
            200,
            [
              {
                'id': 'screening',
                'tenant_id': 'hospital',
                'patient_id': 'synthetic-patient',
                'diagnosed_at': '2026-10-30T00:00:00Z',
                'is_positive': false,
                'confidence': 80,
              },
            ],
          );
        }
        if (o.path == '/datasets/dataset/items') {
          if (o.method == 'POST') {
            expect(o.data, {
              'diagnosis_ids': ['screening'],
            });
            added = true;
            return (200, {'added': 1, 'already_present': 0});
          }
          return (200, datasets.page(added ? [datasets.screening()] : []));
        }
        if (o.method == 'PATCH') {
          archived = true;
          return (200, {...entry, 'status': 'archived'});
        }
        return (200, entry);
      });
      final auth = AuthProvider(_Auth(), initialProfile: actor);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider.value(value: api),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            Provider<DatasetRepository>.value(
              value: HttpDatasetRepository(api),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: LiveDatasetScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create dataset'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Synthetic collection',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic collection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add screenings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add (1)'));
      await tester.pumpAndSettle();
      expect(added, isTrue);
      expect(find.text('SYN001'), findsOneWidget);
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(archived, isTrue);
      expect(find.text('Add screenings'), findsNothing);
      expect(find.text('Reopen'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(calls, contains('POST /datasets/dataset/items'));
      expect(calls, contains('PATCH /datasets/dataset'));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'password replacement rejects responses from the revoked token generation',
    () async {
      final waiting = Completer<(int, Object?)>();
      final started = Completer<void>();
      final api = client((o) {
        if (o.path == '/auth/login') {
          return (200, tokenPair(required: true, access: 'synthetic-before'));
        }
        if (o.path == '/auth/change-password') return (200, tokenPair());
        started.complete();
        return waiting.future;
      });
      final auth = AuthProvider(HttpAuthRepository(api));
      addTearDown(auth.dispose);
      await auth.login(email: 'tech@example.invalid', password: 'synthetic');
      final stale = api.dio.get<Object?>('/users');
      final rejected = expectLater(stale, throwsA(isA<DioException>()));
      await started.future;
      final before = api.tokens.generation;
      await auth.changePassword(
        currentPassword: 'synthetic',
        newPassword: 'synthetic-after',
      );
      expect(api.tokens.generation, greaterThan(before));
      waiting.complete((200, {}));
      await rejected;
      expect(api.tokens.accessToken, 'synthetic-replacement');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.mustChangePassword, isFalse);
    },
  );
  testWidgets('doctor dataset remains read-only; technician sees create', (
    tester,
  ) async {
    final api = client(
      (_) => (200, {'items': [], 'total': 0, 'limit': 20, 'offset': 0}),
    );
    for (final role in ['doctor', 'technician']) {
      final auth = AuthProvider(
        _Auth(),
        initialProfile: UserProfile(
          userId: 'synthetic-$role',
          tenantId: 'hospital',
          displayName: 'Synthetic',
          email: '$role@example.invalid',
          role: role,
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          key: ValueKey(role),
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            Provider<DatasetRepository>.value(
              value: HttpDatasetRepository(api),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: LiveDatasetScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Create dataset'),
        role == 'doctor' ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    }
  });
}

// A valid parsed DTO from another institution must never become active state.
DatasetEntry datasetsEntryOtherTenant() => DatasetEntry(
  id: 'other',
  tenantId: 'other-hospital',
  name: 'Synthetic',
  description: null,
  status: 'active',
  itemCount: 0,
  sizeBytes: 0,
  lastUpdated: DateTime.utc(2026),
);
