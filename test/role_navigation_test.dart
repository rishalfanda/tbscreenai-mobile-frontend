import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/router/app_router.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/mock/mock_dashboard_repository.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/data/mock/mock_sync_repository.dart';
import 'package:myapp/data/mock/mock_validation_repository.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_screen.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/dashboard_provider.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:myapp/state/institution_provider.dart';

UserProfile actor(String role) => UserProfile(
  userId: 'synthetic-$role',
  tenantId: 'sardjito',
  displayName: 'Synthetic $role',
  email: '$role@example.invalid',
  role: role,
);

class _AuthRepository implements AuthRepository {
  _AuthRepository(this.profile);
  UserProfile profile;
  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) => SynchronousFuture(profile);
  @override
  Future<void> logout() => SynchronousFuture(null);
}

class _ValidationRepository extends MockValidationRepository {
  int subscriptions = 0;
  @override
  Stream<int> watchPendingCount() {
    subscriptions++;
    return Stream.value(7);
  }
}

class _NoModelEngine extends OnnxInferenceEngine {
  @override
  Future<bool> get ready => SynchronousFuture(false);
}

class _UserAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'items': [], 'total': 0, 'limit': 20, 'offset': 0}),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

Future<(GoRouter, AuthProvider, _ValidationRepository)> mountRole(
  WidgetTester tester,
  String role,
  double width,
) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = AuthProvider(
    _AuthRepository(actor(role)),
    initialProfile: actor(role),
  );
  final validation = _ValidationRepository();
  final router = AppRouter.create(auth);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => auth),
        ChangeNotifierProvider(create: (_) => AppLanguage()),
        ChangeNotifierProvider(create: (_) => InstitutionProvider()),
        Provider<ApiClient>(
          create: (_) =>
              ApiClient(baseUrl: 'https://synthetic.invalid')
                ..dio.httpClientAdapter = _UserAdapter(),
          dispose: (_, api) => api.close(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(MockDashboardRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => DiagnosisProvider(MockDiagnosisRepository()),
        ),
        Provider<ValidationRepository>.value(value: validation),
        Provider<SyncRepository>(create: (_) => MockSyncRepository()),
        Provider<OnnxInferenceEngine>(create: (_) => _NoModelEngine()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (router, auth, validation);
}

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('technician cannot open clinical deep links at $width', (
      tester,
    ) async {
      final (router, auth, validation) = await mountRole(
        tester,
        'technician',
        width,
      );
      expect(router.routeInformationProvider.value.uri.path, '/technician');
      expect(tester.takeException(), isNull, reason: 'technician workspace');
      expect(find.text('Technician workspace'), findsOneWidget);
      expect(find.byTooltip('Screening'), findsNothing);
      router.go('/users');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/users');
      if (AppConfig.useHttp) {
        expect(find.text('Add user'), findsNothing);
        expect(find.text('Add doctor'), findsOneWidget);
      } else {
        await tester.tap(find.text('Add user'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Synthetic doctor',
        );
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'doctor@example.invalid',
        );
        await tester.ensureVisible(find.text('Save demo'));
        await tester.tap(find.text('Save demo'));
        await tester.pumpAndSettle();
        expect(find.text('Synthetic doctor'), findsOneWidget);
        await tester.tap(find.text('ID'));
        await tester.pumpAndSettle();
        expect(find.text('Tambah pengguna'), findsOneWidget);
        expect(find.text('Synthetic doctor'), findsOneWidget);
        await tester.tap(find.text('ENG'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: 'technician users');
      for (final path in [
        '/diagnosis',
        '/patients',
        '/validation',
        '/sync',
        '/models',
        '/result',
        '/camera',
      ]) {
        router.go('$path?source=audit');
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/technician');
        expect(find.byKey(const Key('diagnosis-input-content')), findsNothing);
      }
      expect(validation.subscriptions, 0);
      router.go('/models');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/technician');
      expect(
        tester.takeException(),
        isNull,
        reason: 'technician model catalog',
      );
      expect(find.text('TBScreen demo v1'), findsNothing);
      router.go('/sync');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/technician');
      expect(tester.takeException(), isNull, reason: 'technician sync center');
      expect(auth.role, 'technician');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('doctor cannot open technician routes at $width', (
      tester,
    ) async {
      final (router, _, validation) = await mountRole(tester, 'doctor', width);
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
      expect(find.byTooltip('Sync'), findsNothing);
      for (final path in ['/technician', '/users', '/models', '/sync']) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/dashboard');
      }
      expect(validation.subscriptions, 1);
      expect(tester.takeException(), isNull, reason: 'doctor dashboard');
      router.go('/result');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/diagnosis');
      expect(
        find.byKey(const Key('diagnosis-input-content')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Open Sync Center'), findsNothing);
      expect(find.text('Buka Pusat Sinkronisasi'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final role in ['admin', 'admin_rs', 'unknown', 'management']) {
    testWidgets('$role stays restricted to account', (tester) async {
      final (router, _, validation) = await mountRole(tester, role, 1280);
      expect(router.routeInformationProvider.value.uri.path, '/account');
      for (final path in [
        '/diagnosis',
        '/technician',
        '/sync',
        '/management',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/account');
      }
      expect(validation.subscriptions, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('logout prevents reentering a protected role route', (
    tester,
  ) async {
    final (router, auth, _) = await mountRole(tester, 'technician', 1280);
    await auth.logout();
    await tester.pumpAndSettle();
    router.go('/technician');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
    expect(auth.mobileRole, MobileRole.unsupported);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('missing model directs doctor to institution technician', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DiagnosisProvider(MockDiagnosisRepository()),
        child: const MaterialApp(
          home: Scaffold(body: DiagnosisScreen(hasModelOverride: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Hubungi teknisi'),
      AppConfig.useHttp ? findsNothing : findsOneWidget,
    );
    expect(find.text('Buka Pusat Sinkronisasi'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
