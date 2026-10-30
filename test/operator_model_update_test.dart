import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/mock/mock_sync_repository.dart';
import 'package:myapp/data/models_ota/model_update_pipeline.dart';
import 'package:myapp/data/models_ota/model_update_service.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/model_version_info.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';
import 'package:myapp/features/sync/presentation/sync_center_screen.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final Object? body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? s,
    Future<void>? c,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _ModelRepository extends MockSyncRepository {
  _ModelRepository(this.throwError);
  final bool throwError;
  @override
  Future<String> getInstalledModelVersion() async => 'installed-one';
  @override
  Future<ModelVersionInfo> checkForUpdate() async => const ModelVersionInfo(
    currentVersion: 'installed-one',
    latestVersion: 'candidate-two',
    fileSize: '1 MB',
    releaseDate: '-',
    changelog: [],
  );
  @override
  Stream<double> downloadModel() async* {
    yield .5;
    if (throwError) {
      throw ModelInstallException(
        ModelInstallPhase.downloading,
        'Synthetic failure',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('model download credentials are limited to the API model namespace', () {
    final base = Uri.parse('https://api.example.org/api/v1');
    expect(
      ModelUpdatePipeline.isApiBundle(
        'https://api.example.org/api/v1/models/stable/v1/bundle.zip',
        base,
      ),
      isTrue,
    );
    for (final url in [
      'https://cdn.example.org/bundle.zip',
      'https://api.example.org/other/bundle.zip',
      'https://api.example.org.evil.invalid/api/v1/models/a',
      'http://api.example.org/api/v1/models/a',
      'https://user:secret@api.example.org/api/v1/models/a',
      '/models/a',
    ]) {
      expect(ModelUpdatePipeline.isApiBundle(url, base), isFalse, reason: url);
    }
  });
  test(
    'server policy prevents unsupported or disallowed model installation',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final settings = SettingsStore(db);
      final client = ApiClient(baseUrl: 'https://synthetic.invalid/api/v1');
      addTearDown(db.close);
      addTearDown(client.close);
      await settings.saveInstalledModelVersion('installed-one');
      final service = ModelUpdateService(
        client: client,
        settings: settings,
        db: db,
        modelPipeline: ModelUpdatePipeline(
          downloadDio: Dio(),
          engine: OnnxInferenceEngine(),
        ),
      );
      client.dio.httpClientAdapter = _Adapter({
        'latest': 'candidate-two',
        'app_supported': false,
        'update_available': false,
      });
      await expectLater(
        service.checkForUpdate(),
        throwsA(isA<ModelInstallException>()),
      );
      client.dio.httpClientAdapter = _Adapter({
        'latest': 'candidate-two',
        'app_supported': true,
        'update_available': false,
      });
      expect((await service.checkForUpdate()).hasUpdate, isFalse);
      await expectLater(
        service.downloadModel().toList(),
        throwsA(isA<ModelInstallException>()),
      );
      client.dio.httpClientAdapter = _Adapter({'unexpected': 'response'});
      await expectLater(service.checkForUpdate(), throwsFormatException);
      expect(await settings.readInstalledModelVersion(), 'installed-one');
    },
  );
  for (final error in [true, false]) {
    testWidgets(
      'model ${error ? 'download error' : 'unconfirmed activation'} cannot show success',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          Provider<SyncRepository>.value(
            value: _ModelRepository(error),
            child: const MaterialApp(
              home: Scaffold(body: SyncCenterScreen(modelsOnly: true)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Periksa Pembaruan Model'));
        await tester.pumpAndSettle();
        expect(find.text('Perbarui Sekarang'), findsOneWidget);
        await tester.tap(find.text('Perbarui Sekarang'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Model berhasil diperbarui'), findsNothing);
        expect(
          find.textContaining(
            error ? 'Gagal mengunduh model' : 'Gagal menghubungi server',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
