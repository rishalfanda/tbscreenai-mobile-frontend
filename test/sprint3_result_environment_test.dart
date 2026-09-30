import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/features/result/presentation/result_screen.dart';
import 'package:myapp/state/diagnosis_provider.dart';

void main() {
  testWidgets('empty result respects environment and opens screening', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(
          path: '/result',
          builder: (_, _) => const Scaffold(body: ResultScreen()),
        ),
        GoRoute(
          path: '/diagnosis',
          builder: (_, _) => const Scaffold(body: Text('Screening form')),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DiagnosisProvider(MockDiagnosisRepository()),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('TB Suspected'),
      AppConfig.isDemo ? findsOneWidget : findsNothing,
    );
    expect(
      find.textContaining('Confidence 78%'),
      AppConfig.isDemo ? findsOneWidget : findsNothing,
    );
    expect(
      find.text('No screening result yet.'),
      AppConfig.isDemo ? findsNothing : findsOneWidget,
    );
    await tester.tap(find.text('Mulai Screening'));
    await tester.pumpAndSettle();
    expect(find.text('Screening form'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
