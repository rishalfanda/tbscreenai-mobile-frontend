import 'package:dio/dio.dart';

import 'package:myapp/data/local/settings_store.dart';

/// JWT storage. Kept in memory for fast access on every request and mirrored
/// to the local database (FASE 4) so a session survives an app restart.
class TokenStore {
  TokenStore({SettingsStore? settings}) : _settings = settings;

  final SettingsStore? _settings;

  String? accessToken;
  String? refreshToken;

  bool get hasSession => accessToken != null;

  /// Loads a previously saved session from disk. Returns true if one existed.
  Future<bool> restore() async {
    if (_settings == null) return false;
    accessToken = await _settings.readAccessToken();
    refreshToken = await _settings.readRefreshToken();
    return hasSession;
  }

  Future<void> update({required String access, required String refresh}) async {
    accessToken = access;
    refreshToken = refresh;
    await _settings?.updateTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    await _settings?.updateTokens(accessToken: '', refreshToken: '');
  }
}

/// Dio wrapper shared by every Http* repository:
/// - attaches Authorization: Bearer on every non-auth request
/// - on 401, tries one refresh-token round-trip, then retries the request
class ApiClient {
  ApiClient({
    required this.baseUrl,
    SettingsStore? settings,
    String? initialAccessToken,
    String? initialRefreshToken,
  })  : tokens = TokenStore(settings: settings)
          ..accessToken = initialAccessToken
          ..refreshToken = initialRefreshToken,
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokens.accessToken;
          if (token != null && token.isNotEmpty && !options.path.startsWith('/auth/')) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isAuthPath = error.requestOptions.path.startsWith('/auth/');
          final refresh = tokens.refreshToken;
          if (error.response?.statusCode == 401 &&
              refresh != null &&
              refresh.isNotEmpty &&
              !isAuthPath) {
            try {
              // Bare Dio: the refresh call must not recurse into this interceptor.
              final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
              final response = await refreshDio.post<Map<String, dynamic>>(
                '/auth/refresh',
                data: {'refresh_token': refresh},
              );
              final data = response.data!;
              await tokens.update(
                access: data['access_token'] as String,
                refresh: data['refresh_token'] as String,
              );
              final retryOptions = error.requestOptions
                ..headers['Authorization'] = 'Bearer ${tokens.accessToken}';
              final retryResponse = await dio.fetch<dynamic>(retryOptions);
              return handler.resolve(retryResponse);
            } on DioException {
              await tokens.clear(); // refresh failed → session is over
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final String baseUrl;
  final Dio dio;
  final TokenStore tokens;
}
