import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/mock/mock_dataset_repository.dart';
import 'package:myapp/domain/repositories/dataset_repository.dart';
import 'package:myapp/features/dataset/presentation/dataset_screen.dart';
import 'package:provider/provider.dart';

Future<void> mountDataset(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Provider<DatasetRepository>.value(
      value: MockDatasetRepository(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: DatasetScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [375.0, 725.0, 1024.0]) {
    testWidgets('dataset list has no layout exception at ${width.toInt()}px', (
      tester,
    ) async {
      await mountDataset(tester, width);

      expect(find.text('Datasets'), findsOneWidget);
      expect(find.text('Create Dataset'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
