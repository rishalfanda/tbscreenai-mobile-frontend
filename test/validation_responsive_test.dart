import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/mock/mock_validation_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/validation/presentation/validation_screen.dart';

void main() {
  for (final size in [const Size(1024, 768), const Size(1900, 982)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'validation has no overflow at ${size.width}x${size.height}, ${scale}x text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          // Scope overflow assertions to the Sprint 1 Validation route. Login
          // and Dashboard have independent responsive acceptance criteria.
          final originalError = FlutterError.onError;
          final errors = <FlutterErrorDetails>[];
          FlutterError.onError = errors.add;
          await tester.pumpWidget(
            Provider<ValidationRepository>(
              create: (_) => MockValidationRepository(),
              child: const MaterialApp(home: ValidationScreen()),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text("Doctor's Note"), findsOneWidget);
          expect(find.text('Disagree'), findsOneWidget);
          expect(find.text('Agree with AI Result'), findsOneWidget);

          await tester.pumpWidget(const SizedBox.shrink());
          FlutterError.onError = originalError;
          expect(errors, isEmpty, reason: errors.join('\n'));
        },
      );
    }
  }
}
