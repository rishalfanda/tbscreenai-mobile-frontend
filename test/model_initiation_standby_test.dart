import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/data/mock/mock_validation_repository.dart';
import 'package:myapp/data/models_ota/model_store.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/shared/presentation/app_shell.dart';
import 'package:myapp/features/shared/presentation/model_initiation_dialog.dart';

class MockModelStore extends ModelStore {
  MockModelStore({this.mockActiveDir});

  final Directory? mockActiveDir;

  @override
  Future<Directory?> activeBundleDir() async => mockActiveDir;
}

class FakeOnnxInferenceEngine extends OnnxInferenceEngine {
  FakeOnnxInferenceEngine({
    this.mockHasBundle = false,
    this.mockIsStandbyReady = false,
    this.mockReady = true,
    super.modelStore,
  });

  bool mockHasBundle;
  bool mockIsStandbyReady;
  bool mockReady;
  Completer<void>? standbyCompleter;
  int initiateCalls = 0;

  @override
  bool get hasBundle => mockHasBundle;

  @override
  bool get isStandbyReady => mockHasBundle && mockIsStandbyReady;

  @override
  Future<bool> get ready => Future.value(mockReady);

  @override
  Future<bool> initiateStandby({dynamic sampleBytes}) async {
    initiateCalls++;
    if (standbyCompleter != null) {
      await standbyCompleter!.future;
    }
    if (mockHasBundle) {
      mockIsStandbyReady = true;
      return true;
    }
    return false;
  }
}

void main() {
  group('OnnxInferenceEngine initiateStandby', () {
    test('returns false when no bundle is installed', () async {
      final store = MockModelStore(mockActiveDir: null);
      final engine = OnnxInferenceEngine(modelStore: store);
      expect(engine.hasBundle, isFalse);
      expect(engine.isStandbyReady, isFalse);

      final result = await engine.initiateStandby();
      expect(result, isFalse);
      expect(engine.isStandbyReady, isFalse);
    });
  });

  group('initiateModelStandbyWithDialog', () {
    testWidgets('skips dialog silently if active model does not exist', (tester) async {
      final engine = FakeOnnxInferenceEngine(mockHasBundle: false);
      final store = MockModelStore(mockActiveDir: null);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => initiateModelStandbyWithDialog(
                context,
                engine,
                modelStore: store,
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(engine.initiateCalls, 0);
    });

    testWidgets('skips dialog if model is already standby ready', (tester) async {
      final engine = FakeOnnxInferenceEngine(
        mockHasBundle: true,
        mockIsStandbyReady: true,
      );
      final store = MockModelStore(mockActiveDir: Directory('/dummy/model'));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => initiateModelStandbyWithDialog(
                context,
                engine,
                modelStore: store,
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(engine.initiateCalls, 0);
    });

    testWidgets('shows non-dismissible loading dialog during initiation and pops when done', (tester) async {
      final completer = Completer<void>();
      final engine = FakeOnnxInferenceEngine(
        mockHasBundle: true,
        mockIsStandbyReady: false,
      )..standbyCompleter = completer;

      final store = MockModelStore(mockActiveDir: Directory('/dummy/model'));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => initiateModelStandbyWithDialog(
                context,
                engine,
                modelStore: store,
                title: 'Menginisialisasi Model AI',
                message: 'Memuat model ke memori...',
              ),
              child: const Text('Start'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start'));
      // Pump frame for dialog to appear
      await tester.pump();

      // Dialog is visible
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Menginisialisasi Model AI'), findsOneWidget);
      expect(find.text('Memuat model ke memori...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify non-dismissible (PopScope canPop is false)
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);

      // Complete standby
      completer.complete();
      await tester.pumpAndSettle();

      // Dialog has closed
      expect(find.byType(Dialog), findsNothing);
      expect(engine.isStandbyReady, isTrue);
      expect(engine.initiateCalls, 1);
    });
  });

  group('AppShell initiation integration', () {
    testWidgets('AppShell safely mounts when no model is installed', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final engine = FakeOnnxInferenceEngine(mockHasBundle: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ValidationRepository>.value(value: MockValidationRepository()),
            Provider<OnnxInferenceEngine>.value(value: engine),
          ],
          child: const MaterialApp(
            home: AppShell(
              location: '/dashboard',
              child: Text('Dashboard Content'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dashboard Content'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });
  });
}

