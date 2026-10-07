/// Build-time environment policy. Production remains locked until clinical review.
class AppConfig {
  AppConfig._();
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'demo',
  );
  static const flavor = String.fromEnvironment(
    'FLUTTER_APP_FLAVOR',
    defaultValue: 'demo',
  );
  static const useHttp =
      environment != 'demo' || bool.fromEnvironment('USE_HTTP');
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const _gate = _BuildGate(environment, useHttp, apiBaseUrl);
  static bool get isDemo => environment == 'demo';
  static void validate() {
    _gate.check();
    validateValues(environment, useHttp, apiBaseUrl);
    if (flavor != environment) {
      throw StateError('Native flavor must match APP_ENV.');
    }
  }

  static void validateValues(String env, bool http, String url) {
    if (!['demo', 'staging', 'production'].contains(env)) {
      throw StateError('Unknown APP_ENV');
    }
    if (env == 'production') {
      throw StateError('Clinical gate incomplete: production locked.');
    }
    if (env != 'demo' && !http) {
      throw StateError('Mock repositories prohibited.');
    }
    if (env == 'demo' && http) {
      throw StateError(
        'Demo must use synthetic repositories; use staging for backend access.',
      );
    }
    if (http) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          !RegExp(r'/v[1-9][0-9]*$').hasMatch(uri.path)) {
        throw StateError(
          'API_BASE_URL must be HTTPS with a versioned /api/vN path.',
        );
      }
    }
  }

  /// Dev-time fallback bundle-zip URL, for exercising the real OTA model
  /// download path before the backend serves `download_url` on
  /// `/sync/model-version`. Empty/absent means "use whatever the backend
  /// returns, or fall back to the old no-op simulation."
  ///
  ///   flutter run --dart-define=USE_HTTP=true \
  ///     --dart-define=MODEL_BUNDLE_URL=https://.../bundle_v1.3.1.zip
  static const String _modelBundleUrlRaw = String.fromEnvironment(
    'MODEL_BUNDLE_URL',
  );
  static String? get modelBundleUrl =>
      _modelBundleUrlRaw.isEmpty ? null : _modelBundleUrlRaw;
}

class _BuildGate {
  const _BuildGate(String env, bool http, String url)
    : assert(
        env == 'demo' || env == 'staging',
        'Clinical gate incomplete: production locked.',
      ),
      assert(env == 'demo' || http, 'Mock repositories prohibited.'),
      assert(env != 'demo' || !http, 'Demo must use synthetic repositories.'),
      assert(!http || url != '', 'API_BASE_URL required.');
  void check() {}
}
