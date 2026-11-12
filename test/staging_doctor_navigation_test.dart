import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/data/secure/device_identity_store.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/dashboard_provider.dart';

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async {
    final Object body = switch (options.path) {
      '/auth/login' => {
        'access_token': 'synthetic-access',
        'refresh_token': 'synthetic-refresh',
        'user': {
          'id': 'synthetic-doctor',
          'tenant_id': 'synthetic-hospital',
          'full_name': 'Synthetic doctor',
          'email': 'doctor@example.invalid',
          'role': 'doctor',
        },
      },
      '/datasets' => {'items': [], 'total': 0, 'limit': 20, 'offset': 0},
      _ => throw StateError('Unexpected test request: ${options.path}'),
    };
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<MemorySecureTokenStorage> activatedStorage() async {
  final storage = MemorySecureTokenStorage();
  await DeviceIdentityStore(storage).saveActivation({
    'device_id': 'synthetic-device',
    'tenant_id': 'synthetic-hospital',
    'credential': 'synthetic-credential',
    'label': 'Synthetic tablet',
    'status': 'active',
  });
  return storage;
}

Future<void> pumpApp(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
}

void main() {
  testWidgets(
    'staging doctor can navigate Dashboard, Screening, and Validation',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final database = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => database.customSelect('SELECT 1').get());
      await tester.pumpWidget(
        TBScreenApp(
          database: database,
          secureTokenStorage: await activatedStorage(),
          hasActiveModelOverride: () async => true,
        ),
      );
      await pumpApp(tester);
      final context = tester.element(find.byType(MaterialApp));
      context.read<ApiClient>().dio.httpClientAdapter = _Adapter();
      await tester.runAsync(
        () => context.read<AuthProvider>().login(
          email: 'doctor@example.invalid',
          password: 'synthetic-test',
        ),
      );
      await pumpApp(tester);
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
      expect(find.text('Local data - current doctor'), findsOneWidget);
      final dashboard = context.read<DashboardProvider>();
      expect(dashboard.isOffline, isTrue);
      expect(dashboard.error, isNull);
      expect(dashboard.snapshot!.metrics.map((m) => m.value), [
        '0',
        '0',
        '0',
        '0',
      ]);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Screening'));
      await pumpApp(tester);
      expect(router.routeInformationProvider.value.uri.path, '/diagnosis');
      expect(
        find.byKey(const Key('diagnosis-input-content')).hitTestable(),
        findsOneWidget,
      );
      expect(find.byKey(const Key('patient-name')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Patients'), findsNothing);
      expect(find.byTooltip('Dataset'), findsNothing);
      await tester.tap(find.byTooltip('Validation'));
      await pumpApp(tester);
      expect(router.routeInformationProvider.value.uri.path, '/validation');
      expect(find.byKey(const Key('live-dataset-content')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(tester);
      await tester.runAsync(database.close);
    },
    skip: !AppConfig.useHttp,
  );
}
