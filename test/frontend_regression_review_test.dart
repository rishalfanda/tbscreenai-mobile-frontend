// Keeps the approved audit regressions in the default `flutter test` / CI gate
// while retaining the dated audit source as historical review evidence.
import '../audit/frontend_regression_review_test.dart' as audit_regression;

void main() => audit_regression.main();
