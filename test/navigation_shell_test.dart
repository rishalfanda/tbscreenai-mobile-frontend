import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/data/mock/mock_validation_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/shared/presentation/app_shell.dart';

Future<GoRouter> mountShell(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, _) => const TextField(key: ValueKey('draft')),
          ),
          GoRoute(
            path: '/patients',
            builder: (_, _) => const Text('Patient page'),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    Provider<ValidationRepository>.value(
      value: MockValidationRepository(),
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('tablet toggle expands content without clearing input', (
    tester,
  ) async {
    await mountShell(tester, 1200);
    final field = find.byKey(const ValueKey('draft'));
    await tester.enterText(field, 'Keep this draft');
    final width = tester.getSize(field).width;
    await tester.tap(find.byTooltip('Hide navigation'));
    await tester.pumpAndSettle();
    expect(tester.getSize(field).width, width + 84);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(find.text('Patients'), findsNothing);
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();
    expect(tester.getSize(field).width, width);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact drawer dismisses outside and after navigation', (
    tester,
  ) async {
    final router = await mountShell(tester, 600);
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Patients'), findsOneWidget);
    await tester.tapAt(const Offset(500, 500));
    await tester.pumpAndSettle();
    expect(find.text('Patients'), findsNothing);
    await tester.tap(find.byTooltip('Show navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patients'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/patients');
    expect(find.text('Patient page'), findsOneWidget);
    expect(
      tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
