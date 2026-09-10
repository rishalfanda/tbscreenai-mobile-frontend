import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_auth_repository.dart';
import 'package:myapp/data/http/http_diagnosis_repository.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/offline/offline_patient_repository.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';
import 'package:myapp/features/result/presentation/result_screen.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/diagnosis_provider.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final FutureOr<ResponseBody> Function(RequestOptions) reply;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? stream,
    Future<void>? cancel,
  ) async {
    if (stream != null) await stream.drain<void>();
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object data, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Inference implements DiagnosisRepository {
  final calls = <Completer<DiagnosisOutcome>>[];
  @override
  Future<List<String>> getSymptomOptions() async => [];
  @override
  Future<DiagnosisOutcome> runInference({required XrayImage image}) {
    final call = Completer<DiagnosisOutcome>();
    calls.add(call);
    return call.future;
  }
}

DiagnosisOutcome _outcome() => DiagnosisOutcome(
  isPositive: true,
  confidence: 87,
  processingTime: '1s',
  modelVersion: 'test',
  createdAt: DateTime.utc(2026),
  isMock: true,
);

Map<String, Object> _patient() => {
  'id': 'patient-A',
  'code': 'A',
  'name': 'Patient A',
  'age': 40,
  'gender': 'Male',
};

String _jwt(String id, {int? exp}) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': id, 'tenant_id': 'hospital', 'exp': exp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';

Map<String, Object> _login(String id) => {
  'access_token': _jwt(id),
  'refresh_token': 'synthetic-refresh',
  'user': {
    'id': id,
    'tenant_id': 'hospital',
    'full_name': 'Doctor $id',
    'email': '$id@example.test',
    'role': 'doctor',
  },
};

void main() {
  late AppDatabase db;
  late ApiClient client;
  late SettingsStore settings;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsStore(db);
    client = ApiClient(
      baseUrl: 'http://fixture.invalid/api/v1',
      settings: settings,
    );
  });
  tearDown(() async {
    client.dio.close(force: true);
    await db.close();
  });

  test('F01 draft edits invalidate the old patient result', () async {
    final repo = _Inference();
    final provider = DiagnosisProvider(repo)
      ..updatePatientName('Patient A')
      ..attachPlaceholderImage('A.png');
    addTearDown(provider.dispose);
    final running = provider.runDiagnosis();
    repo.calls.single.complete(_outcome());
    expect(await running, isTrue);
    final snapshot = provider.lastResult!;
    provider.updatePatientName('Patient B');
    expect(provider.lastOutcome, isNull);
    expect(snapshot.draft.patientName, 'Patient A');
    expect(snapshot.draft.image!.filename, 'A.png');
  });

  test('F01 old completion cannot replace a newer run after reset', () async {
    final repo = _Inference();
    final provider = DiagnosisProvider(repo)..attachPlaceholderImage('A.png');
    addTearDown(provider.dispose);
    final first = provider.runDiagnosis();
    provider.resetForNewDiagnosis();
    provider.attachPlaceholderImage('B.png');
    final second = provider.runDiagnosis();
    repo.calls.first.complete(_outcome());
    expect(await first, isFalse);
    expect(provider.isRunning, isTrue);
    expect(provider.lastOutcome, isNull);
    repo.calls.last.complete(_outcome());
    expect(await second, isTrue);
    expect(provider.lastResult!.draft.image!.filename, 'B.png');
  });

  test('F01 disposed provider ignores completion without notifying', () async {
    final repo = _Inference();
    final provider = DiagnosisProvider(repo)..attachPlaceholderImage('A.png');
    final running = provider.runDiagnosis();
    provider.dispose();
    repo.calls.single.complete(_outcome());
    expect(await running, isFalse);
  });

  test('F01 image checksum and snapshot bytes cannot be changed by caller', () {
    final source = XrayImage.placeholder().bytes.sublist(0);
    final image = XrayImage.fromBytes(
      bytes: source,
      filename: 'A.png',
      source: XrayImageSource.gallery,
    );
    source[0] = 0;
    expect(image.bytes.first, 0x89);
    expect(() => image.bytes[0] = 0, throwsUnsupportedError);
  });

  test('F02 late patient refresh cannot refill cache after logout', () async {
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    client.dio.httpClientAdapter = _Adapter((_) {
      started.complete();
      return response.future;
    });
    final pending = OfflinePatientRepository(db, client).getPatients();
    await started.future;
    await db.clearAll();
    response.complete(_json([_patient()]));
    expect(await pending, isEmpty);
    expect(await db.countPatients(), 0);
  });

  test('F02 late sync pull cannot refill cache after logout', () async {
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    client.dio.httpClientAdapter = _Adapter((_) {
      started.complete();
      return response.future;
    });
    final engine = SyncEngine(db: db, client: client, settings: settings);
    final pending = engine.pull();
    await started.future;
    await db.clearAll();
    response.complete(
      _json({
        'patients': [_patient()],
        'diagnoses': [],
      }),
    );
    await pending;
    expect(await db.countPatients(), 0);
    expect(await settings.readLastSyncAt(), isNull);
  });

  test(
    'F02 failed login preserves offline records but cannot restore session',
    () async {
      await db.putSetting('session_owner', 'hospital:A');
      await db.upsertPatient(
        LocalPatientsCompanion.insert(
          id: 'A',
          code: 'A',
          name: 'Saved',
          age: 40,
          gender: 'Male',
        ),
      );
      client.dio.httpClientAdapter = _Adapter((_) => _json({}, 401));
      final auth = HttpAuthRepository(client, settings: settings, db: db);
      await expectLater(
        auth.login(email: 'B@example.test', password: 'synthetic'),
        throwsA(isA<DioException>()),
      );
      expect(await db.countPatients(), 1);
      expect(await settings.readRestorableAccessToken(), isNull);
    },
  );

  test(
    'F02 same owner retains offline data; another owner receives an empty cache',
    () async {
      await db.putSetting('session_owner', 'hospital:A');
      await db.upsertPatient(
        LocalPatientsCompanion.insert(
          id: 'A',
          code: 'A',
          name: 'Saved',
          age: 40,
          gender: 'Male',
        ),
      );
      final auth = HttpAuthRepository(client, settings: settings, db: db);
      client.dio.httpClientAdapter = _Adapter((_) => _json(_login('A')));
      await auth.login(email: 'A@example.test', password: 'synthetic');
      expect(await db.countPatients(), 1);
      expect(await settings.readRestorableAccessToken(), isNotNull);
      client.dio.httpClientAdapter = _Adapter((_) => _json(_login('B')));
      await auth.login(email: 'B@example.test', password: 'synthetic');
      expect(await db.countPatients(), 0);
      expect(await db.getSetting('session_owner'), 'hospital:B');
    },
  );

  test('F02 delayed login cannot reactivate session after logout', () async {
    final started = Completer<void>();
    final response = Completer<ResponseBody>();
    client.dio.httpClientAdapter = _Adapter((_) {
      started.complete();
      return response.future;
    });
    final auth = HttpAuthRepository(client, settings: settings, db: db);
    final pending = auth.login(email: 'A@example.test', password: 'synthetic');
    final rejected = expectLater(pending, throwsA(isA<DioException>()));
    await started.future;
    await auth.logout();
    response.complete(_json(_login('A')));
    await rejected;
    expect(client.tokens.accessToken, isNull);
    expect(await settings.readAccessToken(), isNull);
  });

  test('F02 restore rejects unknown owner and expired token', () async {
    await db.putSetting(kAccessToken, _jwt('A'));
    expect(await settings.readRestorableAccessToken(), isNull);
    await db.putSetting('session_owner', 'hospital:B');
    expect(await settings.readRestorableAccessToken(), isNull);
    await db.putSetting('session_owner', 'hospital:A');
    expect(await settings.readRestorableAccessToken(), isNotNull);
    await db.putSetting(kAccessToken, _jwt('A', exp: 1));
    expect(await settings.readRestorableAccessToken(), isNull);
  });

  for (final flag in [true, false, null]) {
    test(
      'F03 HTTP preserves provenance is_mock=$flag; unknown is demo',
      () async {
        client.dio.httpClientAdapter = _Adapter(
          (_) => _json({
            'is_positive': true,
            'confidence': 87,
            'model_version': 'test',
            'is_mock': ?flag,
          }),
        );
        final result = await HttpDiagnosisRepository(
          client,
        ).runInference(image: XrayImage.placeholder());
        expect(result.isMock, flag != false);
      },
    );
  }

  testWidgets('F02 application clears patient state across logout/login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1900, 982);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TBScreenApp(database: db));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(MaterialApp));
    final auth = context.read<AuthProvider>();
    await auth.login(email: 'A@example.test');
    await tester.pumpAndSettle();
    final diagnosis = context.read<DiagnosisProvider>()
      ..updatePatientName('Private A');
    await auth.logout();
    expect(diagnosis.patientName, isEmpty);
    await tester.pumpAndSettle();
    await auth.login(email: 'B@example.test');
    await tester.pumpAndSettle();
    expect(diagnosis.patientName, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'F03 computed demo result is labelled and displays its own image',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _Inference();
      final provider = DiagnosisProvider(repo)..attachPlaceholderImage('A.png');
      final pending = provider.runDiagnosis();
      repo.calls.single.complete(_outcome());
      await pending;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: Scaffold(body: ResultScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('DUMMY / DEMO — BUKAN HASIL KLINIS'), findsOneWidget);
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .map((w) => w.image)
            .whereType<MemoryImage>(),
        isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    },
  );
}
