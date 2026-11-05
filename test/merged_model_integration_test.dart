import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/models_ota/model_update_pipeline.dart';
import 'package:myapp/state/auth_provider.dart';
import 'staging_doctor_navigation_test.dart' as fixture;

class _Network extends HttpOverrides {}

class _LoginAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'access_token': 'synthetic-access',
      'refresh_token': 'synthetic-refresh',
      'user': {
        'id': 'synthetic-doctor',
        'tenant_id': 'synthetic-hospital',
        'full_name': 'Synthetic',
        'email': 'doctor@example.invalid',
        'role': 'doctor',
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('tbscreen-merge-integration-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => temp.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['none'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
  });
  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'plugins.flutter.io/path_provider',
      'dev.fluttercommunity.plus/connectivity',
      'dev.fluttercommunity.plus/connectivity_status',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    await temp.delete(recursive: true);
  });

  testWidgets(
    'merged staging app gates doctor login without an active model',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = await fixture.activatedStorage();
      await tester.pumpWidget(
        TBScreenApp(database: db, secureTokenStorage: secure),
      );
      await fixture.pumpApp(tester);
      final context = tester.element(find.byType(MaterialApp));
      final client = context.read<ApiClient>();
      client.dio.httpClientAdapter = _LoginAdapter();
      final auth = context.read<AuthProvider>();
      await tester.runAsync(
        () => expectLater(
          auth.login(email: 'doctor@example.invalid', password: 'synthetic'),
          throwsA(isA<NoActiveModelException>()),
        ),
      );
      expect(auth.isLoggedIn, false);
      expect(client.tokens.hasSession, false);
      await tester.pumpWidget(const SizedBox.shrink());
      await fixture.pumpApp(tester);
      await tester.runAsync(db.close);
    },
    skip: !AppConfig.useHttp,
  );

  testWidgets(
    'external model bundle download never receives user or tablet credentials',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(
        TBScreenApp(
          database: db,
          secureTokenStorage: await fixture.activatedStorage(),
        ),
      );
      await fixture.pumpApp(tester);
      final context = tester.element(find.byType(MaterialApp));
      final client = context.read<ApiClient>();
      await client.tokens.update(
        access: 'synthetic-access',
        refresh: 'synthetic-refresh',
      );
      final pipeline = context.read<ModelUpdatePipeline>();
      await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(() async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          final received = Completer<HttpHeaders>();
          server.listen((request) async {
            if (!received.isCompleted) received.complete(request.headers);
            await request.drain<void>();
            request.response.headers.contentType = ContentType.binary;
            request.response.add([1, 2, 3]);
            await request.response.close();
          });
          try {
            await expectLater(
              pipeline
                  .installBundleWithProgress(
                    bundleKey: 'synthetic-model',
                    version: 'synthetic',
                    downloadUrl: 'http://127.0.0.1:${server.port}/external.zip',
                    sha256: '0' * 64,
                    smokeTestSampleBytes: Uint8List.fromList([1]),
                  )
                  .toList(),
              throwsA(isA<ModelInstallException>()),
            );
            final headers = await received.future.timeout(
              const Duration(seconds: 5),
            );
            expect(headers.value(HttpHeaders.authorizationHeader), isNull);
            expect(headers.value('x-device-id'), isNull);
            expect(headers.value('x-device-credential'), isNull);
          } finally {
            await server.close(force: true);
          }
        }, _Network()),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await fixture.pumpApp(tester);
      await tester.runAsync(db.close);
    },
    skip: !AppConfig.useHttp,
  );
}
