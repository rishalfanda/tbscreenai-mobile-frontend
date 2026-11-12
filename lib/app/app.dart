import 'package:myapp/data/secure/doctor_session_store.dart';
import 'package:myapp/data/models_ota/model_store.dart';
import 'package:dio/dio.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';
import 'package:myapp/core/connectivity/connectivity_service.dart';
import 'package:myapp/data/http/online_session_check.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/router/app_router.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/config/scroll_behavior.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/http/http_repositories.dart';
import 'package:myapp/data/offline/offline_dashboard_repository.dart';
import 'package:myapp/data/http/http_dataset_repository.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/encrypted_xray_store.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/data/models_ota/hybrid_sync_repository.dart';
import 'package:myapp/data/models_ota/model_update_pipeline.dart';
import 'package:myapp/data/models_ota/model_update_service.dart';
import 'package:myapp/data/offline/offline_patient_repository.dart';
import 'package:myapp/data/offline/device_operator_outbox.dart';
import 'package:myapp/data/offline/operator_sync_service.dart';
import 'package:myapp/data/offline/offline_screening_store.dart';
import 'package:myapp/data/offline/offline_sync_repository.dart';
import 'package:myapp/data/offline/offline_validation_repository.dart';
import 'package:myapp/data/onnx/hybrid_diagnosis_repository.dart';
import 'package:myapp/data/onnx/on_device_diagnosis_repository.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/data/backup/device_backup_restore_service.dart';
import 'package:myapp/domain/repositories/repositories.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/institution_provider.dart';
import 'package:myapp/state/dashboard_provider.dart';
import 'package:myapp/state/diagnosis_provider.dart';

class TBScreenApp extends StatelessWidget {
  const TBScreenApp({
    super.key,
    this.database,
    this.secureTokenStorage,
    this.useHttpOverride,
    this.hasActiveModelOverride,
  });

  /// Injected so tests (and future flavors) can supply an in-memory database.
  final AppDatabase? database;

  /// Production injects platform secure storage. Tests default to an isolated
  /// memory implementation; there is never a plaintext persistence fallback.
  final SecureTokenStorage? secureTokenStorage;

  @visibleForTesting
  final bool? useHttpOverride;

  /// Injected so tests can simulate presence or absence of an active model.
  @visibleForTesting
  final Future<bool> Function()? hasActiveModelOverride;

  @override
  Widget build(BuildContext context) {
    // Live environments bind only HTTP/offline or unavailable repositories.
    final useHttp = useHttpOverride ?? AppConfig.useHttp;
    if (useHttp != AppConfig.useHttp) {
      throw StateError('Repository override must match APP_ENV.');
    }
    final db = database ?? AppDatabase();
    final secureStorage = secureTokenStorage ?? MemorySecureTokenStorage();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppLanguage()),
        ChangeNotifierProvider(create: (_) => InstitutionProvider()),
        // === Section: Local storage & networking ===
        Provider<AppDatabase>.value(value: db),
        Provider<SecureTokenStorage>.value(value: secureStorage),
        Provider<SettingsStore>(create: (_) => SettingsStore(db)),
        if (useHttp)
          Provider<DeviceOperatorOutbox>(
            create: (c) =>
                DeviceOperatorOutbox(db, c.read<SecureTokenStorage>()),
          ),
        Provider<ApiClient>(
          create: (c) => ApiClient(
            baseUrl: AppConfig.apiBaseUrl,
            settings: c.read<SettingsStore>(),
            secureStorage: c.read<SecureTokenStorage>(),
          ),
          dispose: (_, client) => unawaited(client.close()),
        ),
        Provider<SyncEngine>(
          create: (c) => SyncEngine(
            db: db,
            client: c.read<ApiClient>(),
            settings: c.read<SettingsStore>(),
          ),
        ),
        if (useHttp)
          Provider<EncryptedXrayStore>(
            create: (c) => EncryptedXrayStore(
              db: db,
              secureStorage: c.read<SecureTokenStorage>(),
            ),
          ),
        if (useHttp)
          Provider<ScreeningStore>(
            create: (c) => OfflineScreeningStore(
              db: db,
              syncEngine: c.read<SyncEngine>(),
              xrayStore: c.read<EncryptedXrayStore>(),
              deviceId: c.read<SettingsStore>().readOrCreateDeviceId,
            ),
          ),
        // === Section: On-device inference ===
        Provider<OnnxInferenceEngine>(
          create: (_) => OnnxInferenceEngine(),
          dispose: (_, engine) => unawaited(engine.dispose()),
        ),
        Provider<ModelUpdatePipeline>(
          create: (c) => ModelUpdatePipeline(
            // External bundle URLs must never inherit account/device headers.
            downloadDio: Dio(),
            authenticatedDio: c.read<ApiClient>().dio,
            apiBase: useHttp ? Uri.parse(AppConfig.apiBaseUrl) : null,
            engine: c.read<OnnxInferenceEngine>(),
          ),
        ),
        Provider<ModelUpdateService>(
          create: (c) => ModelUpdateService(
            client: c.read<ApiClient>(),
            settings: c.read<SettingsStore>(),
            db: db,
            modelPipeline: c.read<ModelUpdatePipeline>(),
          ),
        ),
        // === Section: Repositories ===
        Provider<AuthRepository>(
          create: (c) => useHttp
              ? HttpAuthRepository(
                  c.read<ApiClient>(),
                  settings: c.read<SettingsStore>(),
                  db: db,
                  outbox: c.read<DeviceOperatorOutbox>(),
                  doctorSession: DoctorSessionStore(
                    c.read<SecureTokenStorage>(),
                  ),
                )
              : MockAuthRepository(),
        ),
        Provider<PatientRepository>(
          create: (c) => useHttp
              ? OfflinePatientRepository(db, c.read<ApiClient>())
              : MockPatientRepository(),
        ),
        Provider<SyncRepository>(
          create: (c) => useHttp
              ? OfflineSyncRepository(
                  db: db,
                  settings: c.read<SettingsStore>(),
                  engine: c.read<SyncEngine>(),
                  modelUpdate: c.read<ModelUpdateService>(),
                )
              : HybridSyncRepository(
                  modelUpdate: c.read<ModelUpdateService>(),
                  backup: MockSyncRepository(),
                ),
        ),
        Provider<DashboardRepository>(
          create: (c) => useHttp
              ? OfflineDashboardRepository(db)
              : MockDashboardRepository(),
        ),
        Provider<DiagnosisRepository>(
          create: (c) => useHttp
              ? OnDeviceDiagnosisRepository(c.read<OnnxInferenceEngine>())
              : HybridDiagnosisRepository(
                  engine: c.read<OnnxInferenceEngine>(),
                  fallback: MockDiagnosisRepository(),
                ),
        ),
        Provider<ValidationRepository>(
          create: (c) => useHttp
              ? OfflineValidationRepository(
                  db: db,
                  client: c.read<ApiClient>(),
                  syncEngine: c.read<SyncEngine>(),
                  xrayStore: c.read<EncryptedXrayStore>(),
                  localOnly: true,
                )
              : MockValidationRepository(),
        ),
        Provider<DatasetRepository>(
          create: (c) => useHttp
              ? HttpDatasetRepository(c.read<ApiClient>())
              : MockDatasetRepository(),
        ),
        // === Section: State providers (depend on interfaces only) ===
        ChangeNotifierProvider(
          create: (context) {
            final engine = context.read<OnnxInferenceEngine>();
            return AuthProvider(
              context.read<AuthRepository>(),
              hasActiveModel:
                  hasActiveModelOverride ??
                  () async {
                    if (!useHttp) return true;
                    try {
                      final store = ModelStore();
                      final dir = await store.activeBundleDir();
                      return dir != null;
                    } catch (_) {
                      return false;
                    }
                  },
              onSessionEnded: () async {
                await engine.releaseStandby();
              },
            );
          },
        ),
        if (useHttp)
          Provider<OperatorSyncService>(
            create: (c) => OperatorSyncService(
              db: db,
              client: c.read<ApiClient>(),
              outbox: c.read<DeviceOperatorOutbox>(),
              xray: c.read<EncryptedXrayStore>(),
              auth: c.read<AuthProvider>(),
            ),
          ),
        if (useHttp)
          Provider<DeviceBackupRestoreService>(
            create: (c) {
              final auth = c.read<AuthProvider>();
              return DeviceBackupRestoreService(
                client: c.read<ApiClient>(),
                db: db,
                outbox: c.read<DeviceOperatorOutbox>(),
                secureStorage: c.read<SecureTokenStorage>(),
                localDeviceId: c.read<SettingsStore>().readOrCreateDeviceId,
                actor: () => auth.isLoggedIn && !auth.mustChangePassword
                    ? auth.profile
                    : null,
              );
            },
          ),
        ChangeNotifierProvider(
          create: (context) {
            final auth = context.read<AuthProvider>();
            return DiagnosisProvider(
              context.read<DiagnosisRepository>(),
              screeningStore: useHttp ? context.read<ScreeningStore>() : null,
              deviceId: context.read<SettingsStore>().readOrCreateDeviceId,
              session: auth,
              hasActiveSession: () =>
                  auth.isLoggedIn && !auth.mustChangePassword,
            );
          },
        ),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(
            context.read<DashboardRepository>(),
            session: context.read<AuthProvider>(),
          ),
        ),
      ],
      child: const _RouterView(),
    );
  }
}

class _RouterView extends StatefulWidget {
  const _RouterView();
  @override
  State<_RouterView> createState() => _RouterViewState();
}

class _RouterViewState extends State<_RouterView> with WidgetsBindingObserver {
  final _connectivity = ConnectivityService();
  StreamSubscription<bool>? _connectivitySubscription;
  bool _checkingSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_checkSession());
  }

  Future<void> _checkSession() async {
    if (!AppConfig.useHttp || !mounted || _checkingSession || _client == null) {
      return;
    }
    _checkingSession = true;
    try {
      if (await _connectivity.checkNow() && mounted) {
        await checkOnlineSession(_client!, context.read<AuthProvider>());
      }
    } finally {
      _checkingSession = false;
    }
  }

  Future<void> _watchConnectivity() async {
    // Check platform availability before subscribing, including desktop tests
    // where connectivity_plus has no native implementation.
    final online = await _connectivity.checkNow();
    if (!mounted) return;
    _connectivitySubscription ??= _connectivity.onStatusChange
        .distinct()
        .listen((online) {
          if (online) unawaited(_checkSession());
        });
    if (online) unawaited(_checkSession());
  }

  bool _ready = !AppConfig.useHttp;
  bool _starting = false;
  String? _startupError;
  GoRouter? _router;
  ApiClient? _client;
  StreamSubscription<SessionExpiredEvent>? _sessionSubscription;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    _router ??= AppRouter.create(auth, requireActivation: AppConfig.useHttp);
    if (!_starting && !_ready) {
      _starting = true;
      unawaited(_initialize(auth));
    }
    final client = context.read<ApiClient>();
    if (!identical(_client, client)) {
      unawaited(_sessionSubscription?.cancel());
      _client = client;
      _sessionSubscription = client.sessionExpired.listen((event) {
        unawaited(auth.expireSession(code: event.code).catchError((_) {}));
      });
    }
  }

  Future<void> _initialize(AuthProvider auth) async {
    try {
      final client = context.read<ApiClient>();
      auth.setDeviceActivated(await client.deviceIdentity.read() != null);
      if (auth.deviceActivated) await auth.restoreSession();
      if (mounted) {
        unawaited(_watchConnectivity());
      }
      if (mounted) {
        setState(() {
          _ready = true;
          _startupError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _startupError =
              'Penyimpanan perangkat belum dapat dibaca. Tutup dan buka kembali aplikasi.',
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_sessionSubscription?.cancel());
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppConfig.validate();
    if (!_ready) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: _startupError == null
                ? const CircularProgressIndicator()
                : Text(_startupError!),
          ),
        ),
      );
    }
    return MaterialApp.router(
      title: 'TBScreen',
      locale: context.watch<AppLanguage>().locale,
      supportedLocales: const [Locale('en'), Locale('id')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      builder: (context, child) {
        if (!AppConfig.isDemo) {
          return child!;
        }

        return Banner(
          message: 'DEMO - SYNTHETIC',
          location: BannerLocation.topEnd,
          child: child!,
        );
      },
      scrollBehavior: AppScrollBehavior(),
    );
  }
}
