import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/offline/offline_patient_repository.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/repositories/patient_repository.dart';
import 'package:myapp/features/patients/presentation/patients_screen.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions options) respond;
  final List<int> offsets = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    offsets.add((options.queryParameters['offset'] as int?) ?? 0);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

Map<String, Object> _patient(int index) => {
  'id': 'patient-$index',
  'code': 'P$index',
  'name': 'Patient $index',
  'age': 40,
  'gender': 'Male',
  'version': 1,
};

class _PatientStateRepository extends PatientRepository {
  final controller = StreamController<PatientListSnapshot>(sync: true);

  @override
  Future<List<Patient>> getPatients() async => const [];

  @override
  Stream<PatientListSnapshot> watchPatientList() => controller.stream;
}

const _cachedPatient = Patient(
  id: 'P1',
  name: 'Cached Patient',
  age: 45,
  gender: 'Female',
  status: 'Normal',
  confidence: 80,
  lastVisit: '2026-09-28',
  history: [],
);

void main() {
  late AppDatabase db;
  late ApiClient client;
  late OfflinePatientRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = ApiClient(baseUrl: 'http://patients.test/api/v1');
    repository = OfflinePatientRepository(db, client);
  });

  tearDown(() async {
    await client.close();
    await db.close();
  });

  test(
    'pagination exposes more than 500 patients without replacing pages',
    () async {
      final records = [
        for (var index = 0; index < 550; index++) _patient(index),
      ];
      final adapter = _Adapter((options) {
        final offset = options.queryParameters['offset'] as int;
        final limit = options.queryParameters['limit'] as int;
        return _json(records.skip(offset).take(limit).toList());
      });
      client.dio.httpClientAdapter = adapter;

      final patients = await repository.getPatients();

      expect(patients, hasLength(550));
      expect(adapter.offsets, [0, 100, 200, 300, 400, 500]);
      expect(await db.countPatients(), 550);
    },
  );

  test(
    'reactive cache reports offline state without discarding cached rows',
    () async {
      await db.upsertPatient(
        LocalPatientsCompanion.insert(
          id: 'cached',
          code: 'CACHED',
          name: 'Cached Patient',
          age: 45,
          gender: 'Female',
        ),
      );
      client.dio.httpClientAdapter = _Adapter(
        (options) => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      final offline = Completer<PatientListSnapshot>();
      final subscription = repository.watchPatientList().listen((snapshot) {
        if (snapshot.status == PatientListStatus.offlineCache &&
            !offline.isCompleted) {
          offline.complete(snapshot);
        }
      });
      addTearDown(subscription.cancel);

      final snapshot = await offline.future.timeout(const Duration(seconds: 2));

      expect(snapshot.patients.single.id, 'CACHED');
      expect(snapshot.message, contains('cache lokal'));
      expect(await db.countPatients(), 1);
    },
  );

  testWidgets(
    'patient screen distinguishes loading, empty, offline and refresh',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final states = _PatientStateRepository();

      await tester.pumpWidget(
        Provider<PatientRepository>.value(
          value: states,
          child: const MaterialApp(home: Scaffold(body: PatientsScreen())),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      states.controller.add(
        const PatientListSnapshot(
          status: PatientListStatus.empty,
          patients: [],
        ),
      );
      await tester.pump();
      expect(find.text('No patients found'), findsOneWidget);

      states.controller.add(
        const PatientListSnapshot(
          status: PatientListStatus.offlineCache,
          patients: [_cachedPatient],
          message: 'Offline cache is active',
        ),
      );
      await tester.pump();
      expect(find.text('Offline cache is active'), findsOneWidget);
      expect(find.text('Cached Patient'), findsWidgets);

      states.controller.add(
        PatientListSnapshot(
          status: PatientListStatus.ready,
          patients: [_cachedPatient.copyWith(name: 'Refreshed Patient')],
        ),
      );
      await tester.pump();
      expect(find.text('Refreshed Patient'), findsWidgets);
      expect(find.text('Cached Patient'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
