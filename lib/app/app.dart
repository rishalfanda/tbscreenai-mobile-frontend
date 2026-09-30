import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/router/app_router.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/config/scroll_behavior.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/http/http_repositories.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/encrypted_xray_store.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/data/offline/offline_patient_repository.dart';
import 'package:myapp/data/offline/offline_screening_store.dart';
import 'package:myapp/data/offline/offline_sync_repository.dart';
import 'package:myapp/data/offline/offline_validation_repository.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/repositories/repositories.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/dashboard_provider.dart';
import 'package:myapp/state/diagnosis_provider.dart';

class TBScreenApp extends StatelessWidget {
  const TBScreenApp({
    super.key,
    this.database,
    this.secureTokenStorage,
    this.useHttpOverride,
  });

  /// Injected so tests (and future flavors) can supply an in-memory database.
  final AppDatabase? database;

  /// Production injects platform secure storage. Tests default to an isolated
  /// memory implementation; there is never a plaintext persistence fallback.
  final SecureTokenStorage? secureTokenStorage;

  @visibleForTesting
  final bool? useHttpOverride;

  @override
  Widget build(BuildContext context) {
    // Toggle Mock ↔ Http/Offline per repository via --dart-define=USE_HTTP=true.
    // HTTP mode uses live inference and durable offline doctor validation.
    // Dashboard/Dataset remain mock pending their Sprint 3 API contracts.
    final useHttp = useHttpOverride ?? AppConfig.useHttp;
    final db = database ?? AppDatabase();
    final secureStorage = secureTokenStorage ?? MemorySecureTokenStorage();

    return MultiProvider(
      providers: [
        // === Section: Local storage & networking ===
        Provider<AppDatabase>.value(value: db),
        Provider<SecureTokenStorage>.value(value: secureStorage),
        Provider<SettingsStore>(create: (_) => SettingsStore(db)),
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
        // === Section: Repositories ===
        Provider<AuthRepository>(
          create: (c) => useHttp
              ? HttpAuthRepository(
                  c.read<ApiClient>(),
                  settings: c.read<SettingsStore>(),
                  db: db,
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
                  client: c.read<ApiClient>(),
                  settings: c.read<SettingsStore>(),
                  engine: c.read<SyncEngine>(),
                )
              : MockSyncRepository(),
        ),
        Provider<DashboardRepository>(create: (_) => MockDashboardRepository()),
        Provider<DiagnosisRepository>(
          create: (c) => useHttp
              ? HttpDiagnosisRepository(c.read<ApiClient>())
              : MockDiagnosisRepository(),
        ),
        Provider<ValidationRepository>(
          create: (c) => useHttp
              ? OfflineValidationRepository(
                  db: db,
                  client: c.read<ApiClient>(),
                  syncEngine: c.read<SyncEngine>(),
                )
              : MockValidationRepository(),
        ),
        Provider<DatasetRepository>(create: (_) => MockDatasetRepository()),
        // === Section: State providers (depend on interfaces only) ===
        ChangeNotifierProvider(
          create: (context) => AuthProvider(context.read<AuthRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final auth = context.read<AuthProvider>();
            return DiagnosisProvider(
              context.read<DiagnosisRepository>(),
              screeningStore: useHttp ? context.read<ScreeningStore>() : null,
              deviceId: context.read<SettingsStore>().readOrCreateDeviceId,
              session: auth,
              hasActiveSession: () => auth.isLoggedIn,
            );
          },
        ),
        ChangeNotifierProvider(
          create: (context) =>
              DashboardProvider(context.read<DashboardRepository>()),
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

class _RouterViewState extends State<_RouterView> {
  GoRouter? _router;
  ApiClient? _client;
  StreamSubscription<SessionExpiredEvent>? _sessionSubscription;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    _router ??= AppRouter.create(auth);
    final client = context.read<ApiClient>();
    if (!identical(_client, client)) {
      unawaited(_sessionSubscription?.cancel());
      _client = client;
      _sessionSubscription = client.sessionExpired.listen((_) {
        unawaited(auth.expireSession().catchError((_) {}));
      });
    }
  }

  @override
  void dispose() {
    unawaited(_sessionSubscription?.cancel());
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppConfig.validate();
    return MaterialApp.router(
      title: 'TBScreen',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      builder: (context, child) => Banner(
        message: 'DEMO',
        location: BannerLocation.topEnd,
        child: child!,
      ),
      scrollBehavior: AppScrollBehavior(),
    );
  }
}
