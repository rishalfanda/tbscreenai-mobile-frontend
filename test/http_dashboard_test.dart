import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_dashboard_repository.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/features/dashboard/presentation/dashboard_screen.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/dashboard_provider.dart';

Map<String, dynamic> summary({int days = 30, bool empty = false}) => {
  'period': {
    'days': days,
    'start': '2026-09-29T00:00:00Z',
    'end': '2026-10-29T00:00:00Z',
    'tz_offset_minutes': 420,
  },
  for (final key in ['patients', 'screenings', 'validated', 'pending'])
    key: {
      'value': empty ? 0 : 7,
      'previous': 0,
      'change_pct': null,
      if (key == 'patients') 'total': empty ? 0 : 7,
    },
  'agreement': {
    'agreed': empty ? 0 : 1,
    'disagreed': empty ? 0 : 1,
    'rate': empty ? null : 50.0,
  },
  'distribution': {
    for (final key in ['ai', 'doctor'])
      key: {
        'positive': empty ? 0 : 1,
        'negative': empty ? 0 : 1,
        'positive_pct': empty ? null : 50.0,
      },
  },
  'trend': [
    {
      'date': '2026-10-29',
      'screenings': empty ? 0 : 7,
      'patients': empty ? 0 : 3,
    },
  ],
};

List<Map<String, dynamic>> activities() => [
  {
    'diagnosis_id': 'synthetic-diagnosis',
    'patient_id': 'synthetic-patient',
    'patient_name': 'Normal',
    'patient_code': 'SYN001',
    'hospital_name': 'Synthetic hospital',
    'diagnosed_at': '2026-10-29T01:00:00Z',
    'is_positive': false,
    'confidence': 73,
    'status': 'pending',
  },
];

class _Adapter implements HttpClientAdapter {
  _Adapter(this.answer);
  final Future<Object?> Function(RequestOptions) answer;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(await answer(options)),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _Auth extends AuthRepository {
  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) => throw UnimplementedError();
  @override
  Future<void> logout() => SynchronousFuture(null);
}

void main() {
  late ApiClient client;
  late HttpDashboardRepository repository;
  setUp(() {
    client = ApiClient(baseUrl: 'https://synthetic.example/api/v1');
    repository = HttpDashboardRepository(client);
  });
  tearDown(() => client.close());

  test(
    'adapter uses documented queries and preserves null rates and counts',
    () async {
      final requests = <RequestOptions>[];
      client.dio.httpClientAdapter = _Adapter((request) async {
        requests.add(request);
        return request.path.endsWith('/summary')
            ? summary(days: 60, empty: true)
            : [];
      });
      final result = await repository.load(days: 60, tzOffsetMinutes: 420);
      expect(requests.length, 2);
      expect(requests.first.queryParameters, {
        'days': 60,
        'tz_offset_minutes': 420,
      });
      expect(requests.last.queryParameters, {'limit': 10, 'offset': 0});
      expect(
        requests.every((r) => !r.headers.containsKey('X-Tenant-Id')),
        isTrue,
      );
      expect(result.agreementRate, isNull);
      expect(result.ai.positivePct, isNull);
      expect(result.metrics.first.value, '0');
      expect(result.metrics.first.change, '—');
    },
  );

  test('malformed response fails instead of inventing values', () async {
    client.dio.httpClientAdapter = _Adapter(
      (request) async => request.path.endsWith('/summary')
          ? {
              ...summary(),
              'agreement': {'agreed': 1, 'disagreed': 0, 'rate': 150},
            }
          : [],
    );
    await expectLater(
      repository.load(days: 30, tzOffsetMinutes: 420),
      throwsFormatException,
    );
  });

  test('logout clears dashboard and rejects a late response', () async {
    final delayed = Completer<Object?>();
    client.dio.httpClientAdapter = _Adapter(
      (request) async =>
          request.path.endsWith('/summary') ? delayed.future : activities(),
    );
    final auth = AuthProvider(
      _Auth(),
      initialProfile: const UserProfile(
        userId: 'synthetic-doctor',
        tenantId: 'synthetic-tenant',
        displayName: 'Synthetic doctor',
        email: 'doctor@example.invalid',
        role: 'doctor',
      ),
    );
    final provider = DashboardProvider(repository, session: auth);
    addTearDown(provider.dispose);
    addTearDown(auth.dispose);
    await auth.logout();
    delayed.complete(summary());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(provider.snapshot, isNull);
    expect(provider.metrics, isEmpty);
    expect(provider.recentActivities, isEmpty);
    expect(provider.isLoading, isFalse);
  });

  test('latest period wins when requests complete out of order', () async {
    final old = Completer<Object?>();
    client.dio.httpClientAdapter = _Adapter((request) async {
      if (!request.path.endsWith('/summary')) return [];
      return request.queryParameters['days'] == 30
          ? old.future
          : summary(days: 60);
    });
    final provider = DashboardProvider(repository);
    addTearDown(provider.dispose);
    provider.setTimePeriod('Last 60 days');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(provider.snapshot?.days, 60);
    old.complete(summary());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(provider.snapshot?.days, 60);
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets(
      'live dashboard displays real values and clears them on error at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var fail = false;
        var empty = false;
        client.dio.httpClientAdapter = _Adapter((request) async {
          if (fail && request.path.endsWith('/activity')) {
            throw DioException.connectionError(
              requestOptions: request,
              reason: 'synthetic offline',
            );
          }
          return request.path.endsWith('/summary')
              ? summary(empty: empty)
              : empty
              ? []
              : activities();
        });
        final provider = DashboardProvider(repository);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => provider),
              ChangeNotifierProvider(create: (_) => AppLanguage()),
            ],
            child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('50.0%'), findsWidgets);
        expect(find.text('Normal'), findsOneWidget);
        expect(find.text('88.8%'), findsNothing);
        expect(find.textContaining('Dr. Anderson'), findsNothing);
        expect(find.text('428 cases'), findsNothing);
        expect(find.text('All Institutions'), findsNothing);
        expect(tester.takeException(), isNull);
        final language = tester
            .element(find.byType(DashboardScreen))
            .read<AppLanguage>();
        language.select('id');
        await tester.pumpAndSettle();
        expect(find.text('Pasien terdaftar'), findsOneWidget);
        expect(find.text('Normal'), findsOneWidget);
        language.select('en');
        await tester.pumpAndSettle();
        fail = true;
        unawaited(provider.refresh());
        await tester.pumpAndSettle();
        expect(provider.snapshot, isNull);
        expect(find.text('Normal'), findsNothing);
        expect(find.text('50.0%'), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
        fail = false;
        empty = true;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('No validated screenings'), findsOneWidget);
        expect(find.text('No screening activity yet.'), findsOneWidget);
        expect(find.text('0.0%'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
