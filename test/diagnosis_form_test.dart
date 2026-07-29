// Verifies the Diagnosis form dropdown options:
// - Direct Sunlight Exposure: Yes / No only
// - Model Type: Disability / Non Disability
// - Model Version: Version 1 / 2 / 3

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_screen.dart';
import 'package:myapp/state/diagnosis_provider.dart';

Widget _wrap() {
  return ChangeNotifierProvider(
    create: (_) => DiagnosisProvider(MockDiagnosisRepository()),
    child: const MaterialApp(home: Scaffold(body: DiagnosisScreen())),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('sunlight exposure offers Yes/No only', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap());
    await tester.scrollUntilVisible(find.text('Direct Sunlight Exposure'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Direct Sunlight Exposure'));
    await tester.pumpAndSettle();

    expect(find.text('Yes').hitTestable(), findsOneWidget);
    expect(find.text('No').hitTestable(), findsOneWidget);
    expect(find.text('Adequate'), findsNothing);
    expect(find.text('Limited'), findsNothing);
  });

  testWidgets('model type offers Disability/Non Disability; model version 1-3',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap());

    await tester.scrollUntilVisible(find.text('Model Type'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Model Type'));
    await tester.pumpAndSettle();
    expect(find.text('Disability').hitTestable(), findsOneWidget);
    expect(find.text('Non Disability').hitTestable(), findsOneWidget);
    expect(find.text('Pediatric Model'), findsNothing);
    await tester.tap(find.text('Non Disability').hitTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Model Version'));
    await tester.pumpAndSettle();
    expect(find.text('Version 1').hitTestable(), findsOneWidget);
    expect(find.text('Version 2').hitTestable(), findsOneWidget);
    expect(find.text('Version 3').hitTestable(), findsOneWidget);
  });
}
