import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/mock/mock_dashboard_repository.dart';
import 'package:myapp/features/dashboard/presentation/dashboard_screen.dart';
import 'package:myapp/state/dashboard_provider.dart';
import 'package:provider/provider.dart';

Future<void> mountDashboard(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => DashboardProvider(MockDashboardRepository()),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: DashboardScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [375.0, 768.0, 1280.0]) {
    testWidgets('dashboard has no layout exception at ${width.toInt()}px', (
      tester,
    ) async {
      await mountDashboard(tester, width);

      expect(find.text('Agreement Level'), findsOneWidget);
      expect(find.text('Screening volume, last 30 days'), findsOneWidget);
      expect(find.text('TB Case Distribution'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
