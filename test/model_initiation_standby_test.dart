import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/data/mock/mock_validation_repository.dart';
import 'package:myapp/data/models_ota/model_store.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/auth/presentation/auth_frame.dart';
import 'package:myapp/features/auth/presentation/login_screen.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/diagnosis_input_tab.dart';
import 'package:myapp/features/shared/presentation/app_shell.dart';
import 'package:myapp/features/shared/presentation/model_initiation_dialog.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/diagnosis_provider.dart';

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
    ModelStore? modelStore,
  }) : super(
          modelStore: modelStore ??
              MockModelStore(
                mockActiveDir:
                    mockHasBundle ? Directory('/dummy/active') : null,
              ),
        );

  bool mockHasBundle;
  bool mockIsStandbyReady;
  bool mockReady;
  Completer<void>? standbyCompleter;
  int readyCalls = 0;
  int initiateCalls = 0;
  int releaseStandbyCalls = 0;
  int _generation = 0;

  @override
  bool get hasBundle => mockHasBundle;

  @override
  bool get isStandbyReady => mockHasBundle && mockIsStandbyReady;

  @override
  Future<bool> get ready {
    readyCalls++;
    return Future.value(mockReady && mockHasBundle);
  }

  @override
  Future<bool> initiateStandby({dynamic sampleBytes}) async {
    if (isStandbyReady) return true;
    final gen = _generation;
    initiateCalls++;
    isWarmingUp.value = true;
    try {
      if (standbyCompleter != null) {
        await standbyCompleter!.future;
      }
      if (mockHasBundle && gen == _generation) {
        mockIsStandbyReady = true;
        return true;
      }
      return false;
    } finally {
      isWarmingUp.value = false;
    }
  }

  @override
  Future<void> releaseStandby() async {
    _generation++;
    releaseStandbyCalls++;
    mockIsStandbyReady = false;
    isWarmingUp.value = false;
  }
}

class _TestAuthRepo implements AuthRepository {
  _TestAuthRepo({required this.profile});
  final UserProfile profile;
  int logoutCalls = 0;

  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) => SynchronousFuture(profile);

  @override
  Future<void> logout() {
    logoutCalls++;
    return SynchronousFuture(null);
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
      expect(engine.isWarmingUp.value, isFalse);
    });

    test('releaseStandby during in-flight warmup prevents isStandbyReady from turning true', () async {
      final completer = Completer<void>();
      final engine = FakeOnnxInferenceEngine(
        mockHasBundle: true,
        mockIsStandbyReady: false,
      )..standbyCompleter = completer;

      final pending = engine.initiateStandby();
      expect(engine.isWarmingUp.value, isTrue);

      await engine.releaseStandby();
      completer.complete();
      final result = await pending;

      expect(result, isFalse);
      expect(engine.isStandbyReady, isFalse);
      expect(engine.isWarmingUp.value, isFalse);
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

  group('Doctor vs Technician model initiation and login gate', () {
    testWidgets('Doctor login without active model fails and shows guidance SnackBar', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _TestAuthRepo(
        profile: const UserProfile(
          userId: 'doc-1',
          tenantId: 'tenant-1',
          displayName: 'Dr. Test',
          email: 'doctor@example.test',
          role: 'doctor',
        ),
      );

      final auth = AuthProvider(
        repo,
        hasActiveModel: () async => false, // No active model on device
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'doctor@example.test');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Login must fail
      expect(auth.isLoggedIn, isFalse);
      expect(auth.status, AuthStatus.loggedOut);
      expect(auth.sessionRefusalCode, 'no_active_model');
      expect(repo.logoutCalls, 1);

      // Verify guidance message shown once in AuthErrorBanner (no duplicate SnackBar)
      expect(find.byType(AuthErrorBanner), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.text(
          'Login failed — no active AI model found. Please activate a model first or contact a technician.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Doctor login defers warmup on /dashboard and warms in background without modal on /diagnosis', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _TestAuthRepo(
        profile: const UserProfile(
          userId: 'doc-1',
          tenantId: 'tenant-1',
          displayName: 'Dr. Test',
          email: 'doctor@example.test',
          role: 'doctor',
        ),
      );

      final engine = FakeOnnxInferenceEngine(
        mockHasBundle: true,
        mockIsStandbyReady: false,
      );
      final language = AppLanguage();
      final auth = AuthProvider(
        repo,
        hasActiveModel: () async => true,
      );

      await auth.login(email: 'doctor@example.test', password: 'password123');
      expect(auth.isLoggedIn, isTrue);

      Widget shell(String location, String title) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: language),
          Provider<ValidationRepository>.value(value: MockValidationRepository()),
          Provider<OnnxInferenceEngine>.value(value: engine),
        ],
        child: MaterialApp(
          home: AppShell(
            location: location,
            child: Text(title),
          ),
        ),
      );

      // Landing on /dashboard stays responsive with zero dialog and zero ONNX warmup.
      await tester.pumpWidget(shell('/dashboard', 'Doctor Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Doctor Dashboard'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(engine.initiateCalls, 0);
      expect(engine.isStandbyReady, isFalse);

      // Navigating to /diagnosis starts non-blocking background warmup without a modal Dialog.
      await tester.pumpWidget(shell('/diagnosis', 'Doctor Diagnosis'));
      await tester.pumpAndSettle();

      expect(find.text('Doctor Diagnosis'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(engine.initiateCalls, 1);
      expect(engine.isStandbyReady, isTrue);

      // Dependency rebuilds (e.g. toggling language) do not re-trigger standby checks.
      language.select('id');
      await tester.pumpAndSettle();
      expect(engine.initiateCalls, 1);
      expect(engine.readyCalls, 0);
    });

    testWidgets('AppShell stops re-polling didChangeDependencies when no bundle is installed', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _TestAuthRepo(
        profile: const UserProfile(
          userId: 'doc-1',
          tenantId: 'tenant-1',
          displayName: 'Dr. Test',
          email: 'doctor@example.test',
          role: 'doctor',
        ),
      );
      final engine = FakeOnnxInferenceEngine(mockHasBundle: false);
      final language = AppLanguage();
      final auth = AuthProvider(repo, hasActiveModel: () async => true);
      await auth.login(email: 'doctor@example.test', password: 'password123');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: language),
            Provider<ValidationRepository>.value(value: MockValidationRepository()),
            Provider<OnnxInferenceEngine>.value(value: engine),
          ],
          child: const MaterialApp(
            home: AppShell(
              location: '/diagnosis',
              child: Text('Doctor Diagnosis'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(engine.readyCalls, 1);
      expect(engine.initiateCalls, 0);

      language.select('id');
      await tester.pumpAndSettle();
      expect(engine.readyCalls, 1);
      expect(engine.initiateCalls, 0);
    });

    testWidgets('DiagnosisInputTab shows non-blocking warmup banner while engine warms up and keeps form interactive', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final completer = Completer<void>();
      final engine = FakeOnnxInferenceEngine(
        mockHasBundle: true,
        mockIsStandbyReady: false,
      )..standbyCompleter = completer;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            Provider<OnnxInferenceEngine>.value(value: engine),
            ChangeNotifierProvider(
              create: (_) => DiagnosisProvider(MockDiagnosisRepository()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DiagnosisInputTab(onAnalyzeSuccess: () {}),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('model-warmup-indicator')), findsOneWidget);
      expect(find.text('Preparing AI model in background...'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);

      // Clinician can immediately type into patient name while warmup runs in background.
      await tester.enterText(find.byType(TextFormField).first, 'Budi');
      expect(find.text('Budi'), findsOneWidget);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('model-warmup-indicator')), findsNothing);
      expect(engine.isStandbyReady, isTrue);
    });

    testWidgets('Technician login never initiates model standby', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _TestAuthRepo(
        profile: const UserProfile(
          userId: 'tech-1',
          tenantId: 'tenant-1',
          displayName: 'Technician Test',
          email: 'tech@example.test',
          role: 'technician',
        ),
      );

      final engine = FakeOnnxInferenceEngine(
        mockHasBundle: true,
        mockIsStandbyReady: false,
      );

      final auth = AuthProvider(
        repo,
        hasActiveModel: () async => false, // Even if false, technician does not require model
      );

      await auth.login(email: 'tech@example.test', password: 'password123');
      expect(auth.isLoggedIn, isTrue);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            Provider<ValidationRepository>.value(value: MockValidationRepository()),
            Provider<OnnxInferenceEngine>.value(value: engine),
          ],
          child: const MaterialApp(
            home: AppShell(
              location: '/technician',
              child: Text('Technician Dashboard'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Technician Dashboard'), findsOneWidget);
      expect(engine.initiateCalls, 0);
      expect(engine.isStandbyReady, isFalse);
    });
  });

  group('AppLifecycleState management and memory leak prevention', () {
    testWidgets('App paused releases standby and resumed restores standby when on /diagnosis for doctor', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _TestAuthRepo(
        profile: const UserProfile(
          userId: 'doc-1',
          tenantId: 'tenant-1',
          displayName: 'Dr. Test',
          email: 'doctor@example.test',
          role: 'doctor',
        ),
      );

      final engine = FakeOnnxInferenceEngine(
        mockHasBundle: true,
        mockIsStandbyReady: false,
      );

      final auth = AuthProvider(
        repo,
        hasActiveModel: () async => true,
        onSessionEnded: () async => engine.releaseStandby(),
      );

      await auth.login(email: 'doctor@example.test', password: 'password123');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            Provider<ValidationRepository>.value(value: MockValidationRepository()),
            Provider<OnnxInferenceEngine>.value(value: engine),
          ],
          child: const MaterialApp(
            home: AppShell(
              location: '/diagnosis',
              child: Text('Doctor Diagnosis'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(engine.isStandbyReady, isTrue);
      expect(engine.initiateCalls, 1);
      expect(find.byType(Dialog), findsNothing);

      // App is paused / backgrounded
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(engine.releaseStandbyCalls, 1);
      expect(engine.isStandbyReady, isFalse);

      // App is resumed on /diagnosis -> restores in background with no Dialog
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(engine.initiateCalls, 2);
      expect(engine.isStandbyReady, isTrue);
      expect(find.byType(Dialog), findsNothing);

      // Logout releases standby
      await auth.logout();
      await tester.pumpAndSettle();

      expect(engine.releaseStandbyCalls, greaterThanOrEqualTo(2));
      expect(engine.isStandbyReady, isFalse);
    });

    testWidgets('App resumed on /dashboard keeps standby lazy for doctor', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _TestAuthRepo(
        profile: const UserProfile(
          userId: 'doc-1',
          tenantId: 'tenant-1',
          displayName: 'Dr. Test',
          email: 'doctor@example.test',
          role: 'doctor',
        ),
      );
      final engine = FakeOnnxInferenceEngine(
        mockHasBundle: true,
        mockIsStandbyReady: false,
      );
      final auth = AuthProvider(repo, hasActiveModel: () async => true);
      await auth.login(email: 'doctor@example.test', password: 'password123');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            Provider<ValidationRepository>.value(value: MockValidationRepository()),
            Provider<OnnxInferenceEngine>.value(value: engine),
          ],
          child: const MaterialApp(
            home: AppShell(
              location: '/dashboard',
              child: Text('Doctor Dashboard'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(engine.initiateCalls, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(engine.initiateCalls, 0);
      expect(engine.isStandbyReady, isFalse);
    });

    testWidgets('App resumed for technician does not initiate standby', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = _TestAuthRepo(
        profile: const UserProfile(
          userId: 'tech-1',
          tenantId: 'tenant-1',
          displayName: 'Technician Test',
          email: 'tech@example.test',
          role: 'technician',
        ),
      );

      final engine = FakeOnnxInferenceEngine(
        mockHasBundle: true,
        mockIsStandbyReady: false,
      );

      final auth = AuthProvider(
        repo,
        hasActiveModel: () async => true,
      );

      await auth.login(email: 'tech@example.test', password: 'password123');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            Provider<ValidationRepository>.value(value: MockValidationRepository()),
            Provider<OnnxInferenceEngine>.value(value: engine),
          ],
          child: const MaterialApp(
            home: AppShell(
              location: '/technician',
              child: Text('Technician Dashboard'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(engine.initiateCalls, 0);

      // Resume app
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(engine.initiateCalls, 0);
      expect(engine.isStandbyReady, isFalse);
    });
  });
}

