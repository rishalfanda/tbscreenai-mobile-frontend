import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
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
import 'staging_doctor_navigation_test.dart' as app_fixture;

class _Adapter implements HttpClientAdapter {
  final calls = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options.path);
    final Object body;
    if (options.path.startsWith('/auth/')) {
      body = {
        'access_token': 'synthetic-access',
        'refresh_token': 'synthetic-refresh',
        'user': {
          'id': 'synthetic-technician',
          'tenant_id': 'synthetic-hospital',
          'full_name': 'Synthetic technician',
          'email': 'tech@example.invalid',
          'role': 'technician',
          'must_change_password': options.path == '/auth/login',
        },
      };
    } else if (options.path == '/users' || options.path == '/datasets') {
      body = {'items': [], 'total': 0, 'limit': 20, 'offset': 0};
    } else {
      throw StateError('Unexpected synthetic request: ${options.path}');
    }
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory modelSupport;
  setUp(() {
    modelSupport = Directory.systemTemp.createTempSync(
      'tbscreen_model_widget_',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => modelSupport.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
  });
  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'plugins.flutter.io/path_provider',
      'dev.fluttercommunity.plus/connectivity_status',
      'dev.fluttercommunity.plus/connectivity',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
    final models = Directory('${modelSupport.path}/models');
    if (await models.exists()) await models.delete();
    await modelSupport.delete();
  });
  testWidgets(
    'full staging technician login forces password change before users and dataset',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final database = AppDatabase(NativeDatabase.memory());
      await tester.runAsync(() => database.customSelect('SELECT 1').get());
      await tester.pumpWidget(TBScreenApp(database: database));
      await app_fixture.pumpApp(tester);
      final context = tester.element(find.byType(MaterialApp));
      final adapter = _Adapter();
      context.read<ApiClient>().dio.httpClientAdapter = adapter;
      await tester.runAsync(
        () => context.read<AuthProvider>().login(
          email: 'tech@example.invalid',
          password: 'synthetic-before',
        ),
      );
      await app_fixture.pumpApp(tester);
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      expect(
        router.routeInformationProvider.value.uri.path,
        '/change-password',
      );
      expect(adapter.calls, ['/auth/login']);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'synthetic-before',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-after',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'synthetic-after',
      );
      await tester.tap(find.text('Save password'));
      await app_fixture.pumpApp(tester);
      expect(router.routeInformationProvider.value.uri.path, '/technician');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Users'));
      await app_fixture.pumpApp(tester);
      expect(find.text('Add doctor'), findsOneWidget);
      expect(find.text('No matching users.'), findsOneWidget);
      await tester.tap(find.byTooltip('Dataset'));
      await app_fixture.pumpApp(tester);
      expect(find.text('Create dataset'), findsOneWidget);
      router.go('/models');
      await app_fixture.pumpApp(tester);
      expect(router.routeInformationProvider.value.uri.path, '/models');
      expect(find.text('Pilih Data & Unggah'), findsNothing);
      router.go('/sync');
      await app_fixture.pumpApp(tester);
      expect(router.routeInformationProvider.value.uri.path, '/sync');
      expect(find.text('Sync user data'), findsOneWidget);
      expect(
        find.textContaining('This tablet is not activated'),
        findsOneWidget,
      );
      for (final route in ['/diagnosis', '/validation', '/camera']) {
        router.go(route);
        await app_fixture.pumpApp(tester);
        expect(router.routeInformationProvider.value.uri.path, '/technician');
      }
      expect(find.byTooltip('Screening'), findsNothing);
      expect(find.byTooltip('Sync'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await app_fixture.pumpApp(tester);
      await tester.runAsync(database.close);
    },
    skip: !AppConfig.useHttp,
  );
}
