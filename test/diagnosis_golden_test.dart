import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_screen.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('diagnosis form 1900x982 reference viewport', (tester) async {
    tester.view.physicalSize = const Size(1900, 982);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DiagnosisProvider(MockDiagnosisRepository()),
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: DiagnosisScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DiagnosisScreen),
      matchesGoldenFile('goldens/diagnosis_form_1900x982.png'),
    );
  }, tags: ['golden']);
}
