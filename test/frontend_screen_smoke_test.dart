// Keeps the approved screen smoke suite in the default `flutter test` / CI
// gate while retaining the dated audit source as historical review evidence.
import '../audit/frontend_screen_smoke_test.dart' as audit_smoke;

void main() => audit_smoke.main();
