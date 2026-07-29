// Smoke test: verifies the app boots with the repository/provider wiring
// (MultiProvider + go_router) and lands on the LoginScreen.

import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/app/app.dart';

void main() {
  testWidgets('TBScreen app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TBScreenApp());
    await tester.pumpAndSettle();

    // Not logged in — router must redirect to the login screen.
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
