import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';

const String kSecureAccessToken = 'tbscreen_access_token';
const String kSecureRefreshToken = 'tbscreen_refresh_token';
const String requestBodyFactoryKey = 'request_body_factory';

typedef RequestBodyFactory = Object? Function();

enum SessionEndReason { refreshRejected, repeatedUnauthorized }

class SessionExpiredEvent {
  const SessionExpiredEvent(this.reason);

  final SessionEndReason reason;
}

/// Owns the in-memory token snapshot and its encrypted at-rest copy.
///
/// [settings] contains non-secret identity metadata only. It is consulted when
/// restoring a session so a token for one account cannot open another
/// account's cache.
class TokenStore {
  TokenStore({SecureTokenStorage? secureStorage, SettingsStore? settings})
    : _secureStorage = secureStorage ?? MemorySecureTokenStorage(),
      _settings = settings;

  final SecureTokenStorage _secureStorage;
  final SettingsStore? _settings;

  String? accessToken;
  String? refreshToken;
  int generation = 0;
  Future<void>? _secureOperation;

  bool get hasSession =>
      accessToken != null &&
      accessToken!.isNotEmpty &&
      refreshToken != null &&
      refreshToken!.isNotEmpty;

  /// Restoring offline access is fail-closed until product selects a local
  /// PIN/biometric policy. Callers must prove local authentication explicitly.
  Future<bool> restore({required bool localAuthenticationGranted}) {
    if (!localAuthenticationGranted) return Future<bool>.value(false);
    final expectedGeneration = generation;
    return _serializeSecure(() async {
      final access = await _secureStorage.read(kSecureAccessToken);
      final refresh = await _secureStorage.read(kSecureRefreshToken);
      final owner = await _settings?.readSessionOwner();
      if (generation != expectedGeneration) return false;
      if (!_matchesOwnerAndExpiry(access, owner) ||
          refresh == null ||
          refresh.isEmpty) {
        generation++;
        accessToken = null;
        refreshToken = null;
        await _deleteSecureValues();
        return false;
      }
      accessToken = access;
      refreshToken = refresh;
      return true;
    });
  }

  Future<void> update({required String access, required String refresh}) {
    if (access.isEmpty || refresh.isEmpty) {
      throw ArgumentError('Tokens must not be empty');
    }
    final expectedGeneration = generation;
    return _serializeSecure(() async {
      if (generation != expectedGeneration) {
        throw StateError('Session changed before saving tokens');
      }
      try {
        await _secureStorage.write(kSecureRefreshToken, refresh);
        await _secureStorage.write(kSecureAccessToken, access);
        if (generation != expectedGeneration) {
          throw StateError('Session changed while saving tokens');
        }
      } catch (_) {
        // A queued clear owns cleanup after a generation change. Otherwise,
        // remove a partially written pair before later operations can run.
        if (generation == expectedGeneration) {
          await _deleteSecureValues();
        }
        rethrow;
      }
      accessToken = access;
      refreshToken = refresh;
    });
  }

  Future<void> clear() {
    generation++;
    accessToken = null;
    refreshToken = null;
    return _serializeSecure(_deleteSecureValues);
  }

  /// Platform key stores are async. Serialize mutations so a delayed write
  /// from an obsolete login can never delete or replace a newer token pair.
  Future<T> _serializeSecure<T>(Future<T> Function() action) {
    final previous = _secureOperation;
    final current = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // The prior caller receives its own error; the queue must continue.
        }
      }
      return action();
    }();
    final barrier = current.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _secureOperation = barrier;
    unawaited(
      barrier.whenComplete(() {
        if (identical(_secureOperation, barrier)) _secureOperation = null;
      }),
    );
    return current;
  }

  Future<void> _deleteSecureValues() async {
    Object? firstError;
    StackTrace? firstStack;
    for (final key in [kSecureAccessToken, kSecureRefreshToken]) {
      try {
        await _secureStorage.delete(key);
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  bool _matchesOwnerAndExpiry(String? token, String? owner) {
    if (token == null || token.isEmpty || owner == null || owner.isEmpty) {
      return false;
    }
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final claims =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final subject = claims['sub'];
      final expiresAt = claims['exp'];
      if (subject is! String || expiresAt is! num) return false;
      final tokenOwner = '${claims['tenant_id'] ?? ''}:$subject';
      return tokenOwner == owner &&
          expiresAt > DateTime.now().millisecondsSinceEpoch / 1000;
    } catch (_) {
      return false;
    }
  }
}

/// Dio wrapper shared by every HTTP repository.
///
/// Guarantees:
/// - concurrent 401 responses share one refresh request;
/// - each request is replayed at most once;
/// - multipart callers can provide a fresh body through
///   [requestBodyFactoryKey];
/// - a rejected refresh clears secrets before emitting one centralized
///   session-expired event.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    SettingsStore? settings,
    SecureTokenStorage? secureStorage,
    String? initialAccessToken,
    String? initialRefreshToken,
  }) : tokens = TokenStore(settings: settings, secureStorage: secureStorage),
       dio = Dio(_options(baseUrl)),
       _refreshDio = Dio(_options(baseUrl)) {
    tokens
      ..accessToken = initialAccessToken
      ..refreshToken = initialRefreshToken;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  );

  static const _sessionGenerationKey = 'session_generation';
  static const _authRetryCountKey = 'auth_retry_count';

  final String baseUrl;
  final Dio dio;
  final Dio _refreshDio;
  final TokenStore tokens;
  final StreamController<SessionExpiredEvent> _sessionEvents =
      StreamController<SessionExpiredEvent>.broadcast(sync: true);

  Future<void>? _refreshInFlight;
  Future<void>? _expiryInFlight;

  Stream<SessionExpiredEvent> get sessionExpired => _sessionEvents.stream;

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra.putIfAbsent(_sessionGenerationKey, () => tokens.generation);
    options.extra.putIfAbsent(_authRetryCountKey, () => 0);
    if (options.extra[_sessionGenerationKey] != tokens.generation) {
      return handler.reject(_sessionChanged(options));
    }
    final token = tokens.accessToken;
    if (token != null && token.isNotEmpty && !_isAuthPath(options.path)) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  void _onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.requestOptions.extra[_sessionGenerationKey] !=
        tokens.generation) {
      return handler.reject(_sessionChanged(response.requestOptions));
    }
    handler.next(response);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;
    final generation = options.extra[_sessionGenerationKey];
    if (generation != tokens.generation ||
        error.response?.statusCode != 401 ||
        _isAuthPath(options.path)) {
      return handler.next(error);
    }

    final retryCount = options.extra[_authRetryCountKey] as int? ?? 0;
    if (retryCount >= 1) {
      await _expire(SessionEndReason.repeatedUnauthorized);
      return handler.next(error);
    }

    final refresh = tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      await _expire(SessionEndReason.refreshRejected);
      return handler.next(error);
    }

    try {
      final currentAuthorization = 'Bearer ${tokens.accessToken}';
      final requestAuthorization = options.headers['Authorization'];
      if (requestAuthorization == currentAuthorization) {
        await _refreshSingleFlight(refresh, generation as int);
      }
      if (generation != tokens.generation) return handler.next(error);

      final retryOptions = _rebuildForRetry(options, retryCount + 1);
      final response = await dio.fetch<dynamic>(retryOptions);
      return handler.resolve(response);
    } on DioException catch (refreshError) {
      await _expire(SessionEndReason.refreshRejected);
      return handler.next(refreshError);
    } catch (_) {
      await _expire(SessionEndReason.refreshRejected);
      return handler.next(error);
    }
  }

  Future<void> _refreshSingleFlight(String refresh, int generation) {
    final running = _refreshInFlight;
    if (running != null) return running;

    final future = _performRefresh(refresh, generation);
    _refreshInFlight = future;
    return future.whenComplete(() {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    });
  }

  Future<void> _performRefresh(String refresh, int generation) async {
    final response = await _refreshDio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refresh},
    );
    if (generation != tokens.generation) {
      throw StateError('Session changed during refresh');
    }
    final data = response.data;
    final access = data?['access_token'];
    final nextRefresh = data?['refresh_token'];
    if (access is! String ||
        access.isEmpty ||
        nextRefresh is! String ||
        nextRefresh.isEmpty) {
      throw const FormatException('Refresh response is missing token pair');
    }
    await tokens.update(access: access, refresh: nextRefresh);
  }

  RequestOptions _rebuildForRetry(RequestOptions options, int retryCount) {
    final extra = Map<String, dynamic>.from(options.extra)
      ..[_authRetryCountKey] = retryCount;
    final headers = Map<String, dynamic>.from(options.headers)
      ..['Authorization'] = 'Bearer ${tokens.accessToken}';
    final bodyFactory = extra[requestBodyFactoryKey];
    final data = bodyFactory is RequestBodyFactory
        ? bodyFactory()
        : options.data;
    return options.copyWith(data: data, headers: headers, extra: extra);
  }

  Future<void> _expire(SessionEndReason reason) {
    final running = _expiryInFlight;
    if (running != null) return running;

    final future = () async {
      try {
        await tokens.clear();
      } finally {
        if (!_sessionEvents.isClosed) {
          _sessionEvents.add(SessionExpiredEvent(reason));
        }
      }
    }();
    _expiryInFlight = future;
    return future.whenComplete(() {
      if (identical(_expiryInFlight, future)) _expiryInFlight = null;
    });
  }

  bool _isAuthPath(String path) => path.startsWith('/auth/');

  DioException _sessionChanged(RequestOptions options) => DioException(
    requestOptions: options,
    type: DioExceptionType.cancel,
    error: 'Session changed',
  );

  Future<void> close() async {
    dio.close(force: true);
    _refreshDio.close(force: true);
    await _sessionEvents.close();
  }
}
