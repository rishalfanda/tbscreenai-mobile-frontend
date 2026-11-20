import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_auth_repository.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';

class _LogoutAdapter implements HttpClientAdapter {
  _LogoutAdapter({this.logoutStatus = 204, this.logoutGate});

  final int logoutStatus;
  final Completer<void>? logoutGate;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.path == '/auth/logout') {
      await logoutGate?.future;
      return ResponseBody.fromBytes(<int>[], logoutStatus);
    }
    if (options.path == '/auth/login') {
      return ResponseBody.fromString(
        jsonEncode(<String, Object>{
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
          'user': <String, Object>{
            'id': 'doctor-new',
            'tenant_id': 'tenant-1',
            'full_name': 'Doctor New',
            'email': 'doctor@example.invalid',
            'role': 'doctor',
          },
        }),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    if (options.path == '/auth/refresh') {
      return ResponseBody.fromBytes(<int>[], 500);
    }
    return ResponseBody.fromBytes(<int>[], 404);
  }

  @override
  void close({bool force = false}) {}
}

Future<ApiClient> _client(_LogoutAdapter adapter) async {
  final claims = base64Url
      .encode(
        utf8.encode(
          jsonEncode(<String, Object>{
            'sub': 'doctor-old',
            'tenant_id': 'tenant-1',
            'exp':
                DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
          }),
        ),
      )
      .replaceAll('=', '');
  final client = ApiClient(
    baseUrl: 'https://synthetic.invalid/api/v1',
    secureStorage: MemorySecureTokenStorage(),
    initialAccessToken: 'synthetic.$claims.signature',
    initialRefreshToken: 'old-refresh',
  );
  client.dio.httpClientAdapter = adapter;
  await client.deviceIdentity.saveActivation(<String, dynamic>{
    'device_id': 'device-1',
    'tenant_id': 'tenant-1',
    'credential': 'device-secret',
    'label': 'Synthetic tablet',
    'status': 'active',
  });
  return client;
}

void main() {
  test('logout revokes current server session with device binding', () async {
    final adapter = _LogoutAdapter();
    final client = await _client(adapter);
    final repository = HttpAuthRepository(client);

    await repository.logout();

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/auth/logout');
    expect(request.data, isNull);
    expect(request.headers['Authorization'], startsWith('Bearer synthetic.'));
    expect(request.headers['X-Device-ID'], 'device-1');
    expect(request.headers['X-Device-Credential'], 'device-secret');
    expect(client.tokens.hasSession, isFalse);
    await client.close();
  });

  test('logout rejection clears locally without attempting refresh', () async {
    final adapter = _LogoutAdapter(logoutStatus: 401);
    final client = await _client(adapter);
    final repository = HttpAuthRepository(client);

    await expectLater(repository.logout(), completes);

    expect(
      adapter.requests.where((request) => request.path == '/auth/logout'),
      hasLength(1),
    );
    expect(
      adapter.requests.where((request) => request.path == '/auth/refresh'),
      isEmpty,
    );
    expect(client.tokens.hasSession, isFalse);
    await client.close();
  });

  test(
    'a new login waits until the previous session revoke finishes',
    () async {
      final gate = Completer<void>();
      final adapter = _LogoutAdapter(logoutGate: gate);
      final client = await _client(adapter);
      final repository = HttpAuthRepository(client);

      final logout = repository.logout();
      await Future<void>.delayed(Duration.zero);
      final login = repository.login(
        email: 'doctor@example.invalid',
        password: 'synthetic-password',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        adapter.requests.where((request) => request.path == '/auth/login'),
        isEmpty,
        reason: 'A late legacy logout must not revoke a newly-created session',
      );

      gate.complete();
      await logout;
      final profile = await login;
      expect(profile.userId, 'doctor-new');
      expect(client.tokens.accessToken, 'new-access');
      expect(adapter.requests.map((request) => request.path), <String>[
        '/auth/logout',
        '/auth/login',
      ]);
      await client.close();
    },
  );
}
