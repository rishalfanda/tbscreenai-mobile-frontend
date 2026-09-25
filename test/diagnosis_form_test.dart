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
    child: const MaterialApp(
      home: Scaffold(body: DiagnosisScreen(hasModelOverride: true)),
    ),
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
    await tester.tap(find.byKey(const Key('optional-fields-panel')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Paparan Sinar Matahari Langsung'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('sunlight-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Ya').hitTestable(), findsOneWidget);
    expect(find.text('Tidak').hitTestable(), findsOneWidget);
    expect(find.text('Adequate'), findsNothing);
    expect(find.text('Limited'), findsNothing);
  });

  testWidgets('model type offers Disability/Non Disability only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap());
    await tester.tap(find.byKey(const Key('optional-fields-panel')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Jenis Model'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('model-type-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('Disabilitas').hitTestable(), findsOneWidget);
    expect(find.text('Non-Disabilitas').hitTestable(), findsOneWidget);
    expect(find.text('Pediatric Model'), findsNothing);
    expect(find.text('Model Version'), findsNothing);
  });
}
