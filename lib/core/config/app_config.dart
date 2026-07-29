/// Build-time configuration.
///
/// Default = mock (demo works without a backend). Switch to the live
/// backend with:
///   flutter run -d chrome --dart-define=USE_HTTP=true
///   flutter run -d chrome --dart-define=USE_HTTP=true --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
/// (10.0.2.2 = host loopback when running on the Android emulator)
class AppConfig {
  AppConfig._();

  /// true → Http* repositories (live FastAPI backend); false → Mock*.
  static const bool useHttp = bool.fromEnvironment('USE_HTTP');

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );
}
