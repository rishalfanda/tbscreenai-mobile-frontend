import 'package:drift/native.dart';
// Platform interface is supplied by the pinned camera dependency; audit-only fake.
// ignore: depend_on_referenced_packages
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/state/auth_provider.dart';

class NoCamera extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async => [];
}

void main() {
  for (final size in [const Size(1900, 982), const Size(1024, 768)]) {
    for (final route in [
      '/login',
      '/dashboard',
      '/patients',
      '/diagnosis',
      '/result',
      '/validation',
      '/dataset',
      '/sync',
      '/account',
      '/camera',
    ]) {
      testWidgets('$route renders at ${size.width}x${size.height}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final camera = CameraPlatform.instance;
        CameraPlatform.instance = NoCamera();
        addTearDown(() => CameraPlatform.instance = camera);
        final originalError = FlutterError.onError;
        final errors = <String>[];
        FlutterError.onError = (details) => errors.add(details.toString());
        await tester.pumpWidget(TBScreenApp(database: db));
        await tester.pumpAndSettle();
        if (route != '/login') {
          await tester
              .element(find.byType(MaterialApp))
              .read<AuthProvider>()
              .login(email: 'audit@example.test');
          await tester.pumpAndSettle();
          // Dashboard is the post-login route. Its layout is tested separately.
          if (route != '/dashboard') errors.clear();
          final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
          (app.routerConfig! as GoRouter).go(route);
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        FlutterError.onError = originalError;
        expect(errors, isEmpty, reason: '$route at $size');
      });
    }
  }
}
