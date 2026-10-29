import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_dataset_repository.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/domain/repositories/dataset_repository.dart';
import 'package:myapp/features/dataset/presentation/live_dataset_screen.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/live_dataset_provider.dart';

Map<String, dynamic> entry(String id, {String tenant = 'hospital'}) => {
  'id': id,
  'tenant_id': tenant,
  'name': 'Normal',
  'description': null,
  'status': 'active',
  'created_by': null,
  'created_at': '2026-10-29T00:00:00Z',
  'last_updated': '2026-10-29T00:00:00Z',
  'size_bytes': 0,
  'counts': {
    'items': 1,
    'ai_positive': 0,
    'ai_negative': 1,
    'validated': 0,
    'agreed': 0,
    'disagreed': 0,
    'pending': 1,
  },
};
Map<String, dynamic> page(List<Object?> items, {int? total, int offset = 0}) =>
    {
      'items': items,
      'total': total ?? items.length,
      'offset': offset,
      'limit': 20,
    };
Map<String, dynamic> screening() => {
  'diagnosis_id': 'diagnosis',
  'patient_id': 'patient',
  'patient_code': 'SYN001',
  'diagnosed_at': '2026-10-29T00:00:00Z',
  'model_version': 'synthetic-model',
  'is_positive': false,
  'confidence': 73,
  'status': 'pending',
  'has_image': false,
  'has_heatmap': false,
  'added_at': '2026-10-29T00:00:00Z',
};

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

AuthProvider doctor() => AuthProvider(
  _Auth(),
  initialProfile: const UserProfile(
    userId: 'doctor',
    tenantId: 'hospital',
    displayName: 'Synthetic doctor',
    email: 'doctor@example.invalid',
    role: 'doctor',
  ),
);

void main() {
  late ApiClient client;
  late HttpDatasetRepository repository;
  setUp(() {
    client = ApiClient(baseUrl: 'https://synthetic.example/api/v1');
    repository = HttpDatasetRepository(client);
  });
  tearDown(() => client.close());

  test('list and items use documented search and page offsets', () async {
    final requests = <RequestOptions>[];
    client.dio.httpClientAdapter = _Adapter((request) async {
      requests.add(request);
      return request.path.endsWith('/items')
          ? page([screening()], total: 21, offset: 20)
          : page([entry('dataset')], total: 21, offset: 20);
    });
    final result = await repository.list(query: ' test ', offset: 20);
    expect(result.hasMore, isFalse);
    expect(result.items.single.description, isNull);
    expect(requests.first.queryParameters, {
      'limit': 20,
      'offset': 20,
      'q': 'test',
    });
    final items = await repository.items('dataset', offset: 20);
    expect(items.items.single.confidence, 73);
    expect(requests.last.queryParameters, {'limit': 20, 'offset': 20});
    expect(
      requests.every((r) => !r.headers.containsKey('X-Tenant-Id')),
      isTrue,
    );
  });

  test(
    'invalid pagination and mismatched detail identity fail closed',
    () async {
      client.dio.httpClientAdapter = _Adapter(
        (request) async =>
            request.path == '/datasets' ? page([], total: 5) : entry('other'),
      );
      await expectLater(repository.list(), throwsFormatException);
      await expectLater(repository.detail('dataset'), throwsFormatException);
    },
  );

  test(
    'logout discards delayed data and foreign institution is never shown',
    () async {
      final auth = doctor();
      final delayed = Completer<Object?>();
      client.dio.httpClientAdapter = _Adapter((_) => delayed.future);
      final state = LiveDatasetProvider(repository, auth);
      addTearDown(state.dispose);
      addTearDown(auth.dispose);
      await auth.logout();
      delayed.complete(page([entry('dataset')]));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(state.page, isNull);
      expect(state.busy, isFalse);
      final otherAuth = doctor();
      client.dio.httpClientAdapter = _Adapter(
        (_) async => page([entry('dataset', tenant: 'other-hospital')]),
      );
      final otherState = LiveDatasetProvider(repository, otherAuth);
      addTearDown(otherState.dispose);
      addTearDown(otherAuth.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(otherState.page, isNull);
      expect(otherState.error, isNotNull);
    },
  );

  test('late search response cannot overwrite newer search', () async {
    final auth = doctor();
    final old = Completer<Object?>();
    client.dio.httpClientAdapter = _Adapter(
      (request) async => request.queryParameters['q'] == 'new'
          ? page([entry('new')])
          : old.future,
    );
    final state = LiveDatasetProvider(repository, auth);
    addTearDown(state.dispose);
    addTearDown(auth.dispose);
    await state.loadList(search: 'new');
    old.complete(page([entry('old')]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(state.page!.items.single.id, 'new');
  });

  for (final width in [320.0, 1280.0]) {
    testWidgets('live list/detail, empty and error states at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var fail = false;
      client.dio.httpClientAdapter = _Adapter((request) async {
        if (fail) {
          throw DioException.connectionError(
            requestOptions: request,
            reason: 'synthetic offline',
          );
        }
        if (request.path.endsWith('/items')) return page([screening()]);
        if (request.path == '/datasets/dataset') return entry('dataset');
        return request.queryParameters['q'] == 'none'
            ? page([])
            : page([entry('dataset')]);
      });
      final auth = doctor();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            Provider<DatasetRepository>.value(value: repository),
          ],
          child: const MaterialApp(home: Scaffold(body: LiveDatasetScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Create Dataset'), findsNothing);
      await tester.tap(find.text('Normal'));
      await tester.pumpAndSettle();
      expect(find.text('SYN001'), findsOneWidget);
      expect(find.text('synthetic-model'), findsOneWidget);
      expect(find.text('Add Images'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Back to Datasets'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'none');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('No matching datasets.'), findsOneWidget);
      fail = true;
      await tester.tap(find.byTooltip('Refresh datasets'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Normal'), findsNothing);
      expect(find.text('SYN001'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
