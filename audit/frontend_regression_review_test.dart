// Audit 2026-09-09: desired safety behavior. Failures reproduce open findings.
// Explicit invocation keeps this review suite separate from baseline test/.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_diagnosis_repository.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/mappers.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/data/offline/offline_patient_repository.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';
import 'package:myapp/features/result/presentation/result_screen.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/diagnosis_provider.dart';

const responseJson = <String, dynamic>{
  'is_positive': true,
  'confidence': 87,
  'processing_time_ms': 100,
  'model_version': 'audit-mock',
  'findings': <String, dynamic>{},
  'is_mock': true,
};

// The default HttpOverrides implementation creates real clients. Only the
// loopback fixture tests opt out of Flutter's blanket HTTP 400 test stub.
class LoopbackHttp extends HttpOverrides {}

class Adapter implements HttpClientAdapter {
  Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  int calls = 0;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    last = options;
    if (stream != null) await stream.drain<void>();
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

LocalPatientsCompanion patient(String id, String name) =>
    LocalPatientsCompanion.insert(
      id: id,
      code: id,
      name: name,
      age: 40,
      gender: 'Male',
      updatedAt: Value(DateTime.utc(2026, 9, 1)),
    );

class DelayedInference implements DiagnosisRepository {
  final result = Completer<DiagnosisOutcome>();
  @override
  Future<List<String>> getSymptomOptions() async => [];
  @override
  Future<DiagnosisOutcome> runInference({required XrayImage image}) =>
      result.future;
}

DiagnosisOutcome outcome() => DiagnosisOutcome(
  isPositive: true,
  confidence: 87,
  processingTime: '0.1s',
  modelVersion: 'audit',
  createdAt: DateTime.utc(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ApiClient client;
  late SyncEngine engine;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = ApiClient(baseUrl: 'http://audit.invalid/api/v1');
    engine = SyncEngine(db: db, client: client, settings: SettingsStore(db));
  });
  tearDown(() async {
    client.dio.close(force: true);
    await db.close();
  });

  test(
    'R01 network recovery retries the existing operation automatically',
    () async {
      client.dio.httpClientAdapter = Adapter(
        (o) => throw DioException.connectionError(
          requestOptions: o,
          reason: 'synthetic offline',
        ),
      );
      await engine.enqueuePatientUpdate('p1', {'name': 'local edit'});
      expect((await engine.push()).failed, 1);
      final recovered = Adapter(
        (o) => jsonBody({
          'results': [
            for (final item in (o.data as Map)['items'])
              {'client_op_id': item['client_op_id'], 'status': 'applied'},
          ],
        }),
      );
      client.dio.httpClientAdapter = recovered;
      final retried = await engine.push();
      expect(
        retried.applied,
        1,
        reason: 'No manual database status rewrite is available in the app',
      );
    },
  );

  test(
    'R02 refresh preserves edited fields on an existing queued patient',
    () async {
      await db.upsertPatient(patient('p1', 'LOCAL EDIT'));
      await engine.enqueuePatientUpdate('p1', {'name': 'LOCAL EDIT'});
      await db.replacePatientCache([patient('p1', 'OLD SERVER')]);
      expect((await db.findPatient('p1'))!.name, 'LOCAL EDIT');
    },
  );

  test(
    'R03 refresh preserves failed or conflicted records pending resolution',
    () async {
      await db.upsertPatient(patient('p1', 'UNSYNCED'));
      await engine.enqueuePatientUpdate('p1', {'name': 'UNSYNCED'});
      await db.markOp((await db.pendingOps()).single.clientOpId, syncConflict);
      await db.markPatientConflict('p1', true);
      await db.replacePatientCache([]);
      expect(await db.findPatient('p1'), isNotNull);
    },
  );

  test(
    'R04 response started before logout cannot repopulate cleared cache',
    () async {
      final response = Completer<ResponseBody>();
      final started = Completer<void>();
      client.dio.httpClientAdapter = Adapter((_) {
        started.complete();
        return response.future;
      });
      final pending = OfflinePatientRepository(db, client).getPatients();
      await started.future;
      await db.clearAll();
      response.complete(
        jsonBody([
          {
            'id': 'old-user-patient',
            'code': 'OLD',
            'name': 'Previous Account',
            'age': 40,
            'gender': 'Male',
          },
        ]),
      );
      await pending;
      expect(await db.countPatients(), 0);
    },
  );

  test('R05 changing patient invalidates the preceding outcome', () async {
    final provider = DiagnosisProvider(HttpDiagnosisRepository(client));
    addTearDown(provider.dispose);
    client.dio.httpClientAdapter = Adapter((_) => jsonBody(responseJson));
    provider.updatePatientName('Patient A');
    provider.attachPlaceholderImage('audit.png');
    expect(await provider.runDiagnosis(), isTrue);
    provider.updatePatientName('Patient B');
    expect(provider.lastOutcome, isNull);
  });

  test('R06 completion after reset cannot restore an old outcome', () async {
    final repo = DelayedInference();
    final provider = DiagnosisProvider(repo)
      ..attachPlaceholderImage('audit.png');
    addTearDown(provider.dispose);
    final running = provider.runDiagnosis();
    provider.resetForNewDiagnosis();
    repo.result.complete(outcome());
    await running;
    expect(provider.lastOutcome, isNull);
  });

  test(
    'R07 server version survives cache and is sent as base_version',
    () async {
      await db.upsertPatient(
        patientRowFromJson({
          'id': 'p1',
          'code': 'P1',
          'name': 'Audit',
          'age': 40,
          'gender': 'Male',
          'version': 7,
          'updated_at': '2026-09-01T00:00:00.999Z',
        }),
      );
      final row = (await db.findPatient('p1'))!;
      await engine.enqueuePatientUpdate(
        row.id,
        patientPayloadFromRow(row),
        baseUpdatedAt: row.updatedAt,
      );
      final adapter = Adapter((_) => jsonBody({'results': []}));
      client.dio.httpClientAdapter = adapter;
      await engine.push();
      final item = ((adapter.last!.data as Map)['items'] as List).single as Map;
      expect(item['base_version'], 7);
    },
  );

  test(
    'R08 access and refresh tokens are absent from ordinary SQLite',
    () async {
      await TokenStore(
        settings: SettingsStore(db),
      ).update(access: 'synthetic-access', refresh: 'synthetic-refresh');
      expect(
        await db.getSetting(kRefreshToken),
        isNull,
        reason: 'Synthetic token is retrievable as plain database text',
      );
    },
  );

  test(
    'R09 incomplete push response does not report an empty successful result',
    () async {
      await engine.enqueuePatientUpdate('p1', {'name': 'Audit'});
      client.dio.httpClientAdapter = Adapter((_) => jsonBody({'results': []}));
      expect((await engine.push()).hasProblems, isTrue);
    },
  );

  test(
    'R14 patient list reads beyond the server default page of 100',
    () async {
      final records = [
        for (var i = 0; i < 101; i++)
          {
            'id': 'p$i',
            'code': 'P$i',
            'name': 'Patient $i',
            'age': 40,
            'gender': 'Male',
          },
      ];
      client.dio.httpClientAdapter = Adapter((o) {
        final offset = (o.queryParameters['offset'] as int?) ?? 0;
        final limit = (o.queryParameters['limit'] as int?) ?? 100;
        return jsonBody(records.skip(offset).take(limit).toList());
      });
      final patients = await OfflinePatientRepository(db, client).getPatients();
      expect(
        patients.length,
        101,
        reason: 'Backend /patients defaults to limit=100',
      );
    },
  );

  testWidgets(
    'R15 computed result displays the uploaded image rather than a sample asset',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = DiagnosisProvider(MockDiagnosisRepository())
        ..attachPlaceholderImage('patient-specific.png')
        // Audit suite lives outside test/, but this is a test fixture only.
        // ignore: invalid_use_of_visible_for_testing_member
        ..lastOutcome = outcome();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: Scaffold(body: ResultScreen())),
        ),
      );
      await tester.pumpAndSettle();
      final images = tester
          .widgetList<Image>(find.byType(Image))
          .map((w) => w.image);
      expect(images.whereType<MemoryImage>(), isNotEmpty);
    },
  );

  test(
    'R12 a repeated unauthorized response triggers at most one refresh',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var refreshes = 0;
      var requests = 0;
      server.listen((request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/auth/refresh')) {
          refreshes++;
          request.response.write(
            jsonEncode({'access_token': 'new', 'refresh_token': 'refresh'}),
          );
        } else {
          requests++;
          // Bound the fixture: a third refresh must never happen in the client.
          request.response.statusCode = requests <= 3 ? 401 : 403;
          request.response.write('{}');
        }
        await request.response.close();
      });
      final local = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
        initialAccessToken: 'old',
        initialRefreshToken: 'refresh',
      );
      try {
        await expectLater(
          local.dio.get<dynamic>('/patients'),
          throwsA(isA<DioException>()),
        );
        expect(
          requests,
          greaterThanOrEqualTo(1),
          reason: 'Loopback fixture must actually receive traffic',
        );
        expect(refreshes, 1);
      } finally {
        local.dio.close(force: true);
        await server.close(force: true);
      }
    }, LoopbackHttp()),
  );

  test(
    'R13 image multipart is replayable after successful token refresh',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var inferences = 0;
      server.listen((request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/auth/refresh')) {
          request.response.write(
            jsonEncode({'access_token': 'new', 'refresh_token': 'refresh'}),
          );
        } else {
          inferences++;
          request.response.statusCode = inferences == 1 ? 401 : 200;
          request.response.write(
            jsonEncode(inferences == 1 ? {} : responseJson),
          );
        }
        await request.response.close();
      });
      final local = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}/api/v1',
        initialAccessToken: 'old',
        initialRefreshToken: 'refresh',
      );
      try {
        final provider = DiagnosisProvider(HttpDiagnosisRepository(local))
          ..attachPlaceholderImage('audit.png');
        final success = await provider.runDiagnosis();
        provider.dispose();
        expect(
          inferences,
          greaterThanOrEqualTo(1),
          reason: 'Loopback fixture must actually receive traffic',
        );
        expect(
          success,
          isTrue,
          reason: 'A consumed FormData must be rebuilt or cloned before replay',
        );
      } finally {
        local.dio.close(force: true);
        await server.close(force: true);
      }
    }, LoopbackHttp()),
  );

  testWidgets('R10 logout and second login clear previous patient state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1900, 982);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(TBScreenApp(database: db));
    await tester.pumpAndSettle();
    var context = tester.element(find.byType(MaterialApp));
    final auth = context.read<AuthProvider>();
    await auth.login(email: 'first@example.test');
    await tester.pumpAndSettle();
    context = tester.element(find.byType(MaterialApp));
    context.read<DiagnosisProvider>().updatePatientName(
      'Previous User Patient',
    );
    await auth.logout();
    await tester.pumpAndSettle();
    await auth.login(email: 'second@example.test');
    await tester.pumpAndSettle();
    final name = tester
        .element(find.byType(MaterialApp))
        .read<DiagnosisProvider>()
        .patientName;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(name, isEmpty);
  });

  testWidgets('R11 computed mock result remains visibly labelled as demo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = DiagnosisProvider(MockDiagnosisRepository())
      ..attachPlaceholderImage('audit.png');
    final running = provider.runDiagnosis();
    await tester.pump(const Duration(seconds: 3));
    await running;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: ResultScreen())),
      ),
    );
    await tester.pumpAndSettle();
    final warning = find.textContaining(
      RegExp('DUMMY|DEMO|BUKAN HASIL KLINIS'),
    );
    expect(warning, findsWidgets);
  });
}
