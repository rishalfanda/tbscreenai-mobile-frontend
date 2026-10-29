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
import 'http_dashboard_test.dart' as fixture;

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
      '/dashboard/summary' => fixture.summary(),
      '/dashboard/activity' => fixture.activities(),
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
    'staging doctor can navigate Dashboard, Screening, and Dataset',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final database = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => database.customSelect('SELECT 1').get());
      await tester.pumpWidget(TBScreenApp(database: database));
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
      await tester.tap(find.byTooltip('Dataset'));
      await pumpApp(tester);
      expect(router.routeInformationProvider.value.uri.path, '/dataset');
      expect(find.byKey(const Key('live-dataset-content')), findsOneWidget);
      expect(find.text('No matching datasets.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpApp(tester);
      await tester.runAsync(database.close);
    },
    skip: !AppConfig.useHttp,
  );
}
