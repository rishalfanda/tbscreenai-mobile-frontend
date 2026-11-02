import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/router/app_router.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/mock/mock_auth_repository.dart';
import 'package:myapp/state/auth_provider.dart';

class _Activation implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? body,
    Future<void>? cancel,
  ) async {
    calls++;
    expect(options.path, '/devices/activation');
    return ResponseBody.fromString(
      jsonEncode({
        'device_id': 'synthetic-device',
        'tenant_id': 'synthetic-tenant',
        'credential': 'synthetic-credential',
        'label': 'Synthetic tablet',
        'status': 'active',
      }),
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
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (await font.exists()) {
      await (FontLoader('Roboto')..addFont(
            font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
    }
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'activation blocks sign-in, then exposes only login at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final auth = AuthProvider(MockAuthRepository())
          ..setDeviceActivated(false);
        final client = ApiClient(baseUrl: 'https://synthetic.invalid/api/v1');
        final adapter = _Activation();
        client.dio.httpClientAdapter = adapter;
        final router = AppRouter.create(auth, requireActivation: true);
        addTearDown(() async {
          router.dispose();
          auth.dispose();
          await client.close();
        });
        final preview = GlobalKey();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider.value(value: client),
              ChangeNotifierProvider(create: (_) => AppLanguage()),
            ],
            child: RepaintBoundary(
              key: preview,
              child: MaterialApp.router(
                theme: AppTheme.lightTheme,
                routerConfig: router,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/activate-tablet',
        );
        router.go('/login');
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/activate-tablet',
        );
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.text('Email'), findsNothing);
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).obscureText,
          isTrue,
        );
        await tester.tap(find.byIcon(Icons.visibility_outlined));
        await tester.pump();
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).obscureText,
          isFalse,
        );
        await expectLater(
          auth.login(email: 'doctor@example.invalid', password: 'synthetic'),
          throwsA(isA<StateError>()),
        );
        if (width == 1280) {
          await tester.runAsync(() async {
            final picture =
                await (preview.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'artifacts/nov02-activation-preview.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        await tester.enterText(
          find.byType(TextFormField),
          'synthetic-activation',
        );
        await tester.ensureVisible(find.byType(FilledButton));
        await tester.tap(find.byType(FilledButton));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
        expect(adapter.calls, 1);
        expect(router.routeInformationProvider.value.uri.path, '/login');
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('Activation code'), findsNothing);
        if (width == 1280) {
          await tester.runAsync(() async {
            final picture =
                await (preview.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'artifacts/nov02-login-preview.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            picture.dispose();
          });
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
