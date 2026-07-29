import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/app/router/app_router.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/config/scroll_behavior.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/http/http_repositories.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/data/offline/offline_patient_repository.dart';
import 'package:myapp/data/offline/offline_sync_repository.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/repositories/repositories.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/state/dashboard_provider.dart';
import 'package:myapp/state/diagnosis_provider.dart';

class TBScreenApp extends StatelessWidget {
  const TBScreenApp({
    super.key,
    this.database,
    this.restoredAccessToken,
    this.restoredRefreshToken,
  });

  /// Injected so tests (and future flavors) can supply an in-memory database.
  final AppDatabase? database;

  /// JWTs restored from disk at startup. When present the router skips the
  /// login screen and the very first request already carries the header.
  final String? restoredAccessToken;
  final String? restoredRefreshToken;

  bool get restoredSession =>
      restoredAccessToken != null && restoredAccessToken!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    // Toggle Mock ↔ Http/Offline per repository via --dart-define=USE_HTTP=true.
    // Dashboard/Diagnosis/Validation/Dataset stay mock — their backend
    // endpoints don't exist yet.
    const useHttp = AppConfig.useHttp;
    final db = database ?? AppDatabase();

    return MultiProvider(
      providers: [
        // === Section: Local storage & networking ===
        Provider<AppDatabase>.value(value: db),
        Provider<SettingsStore>(create: (_) => SettingsStore(db)),
        Provider<ApiClient>(
          create: (c) => ApiClient(
            baseUrl: AppConfig.apiBaseUrl,
            settings: c.read<SettingsStore>(),
            initialAccessToken: restoredAccessToken,
            initialRefreshToken: restoredRefreshToken,
          ),
        ),
        Provider<SyncEngine>(
          create: (c) => SyncEngine(
            db: db,
            client: c.read<ApiClient>(),
            settings: c.read<SettingsStore>(),
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
        Provider<DiagnosisRepository>(create: (_) => MockDiagnosisRepository()),
        Provider<ValidationRepository>(create: (_) => MockValidationRepository()),
        Provider<DatasetRepository>(create: (_) => MockDatasetRepository()),
        // === Section: State providers (depend on interfaces only) ===
        ChangeNotifierProvider(
          create: (context) => AuthProvider(
            context.read<AuthRepository>(),
            initiallyLoggedIn: restoredSession,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => DiagnosisProvider(context.read<DiagnosisRepository>()),
        ),
        ChangeNotifierProvider(
          create: (context) => DashboardProvider(context.read<DashboardRepository>()),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          final router = AppRouter.create(authProvider);

          return MaterialApp.router(
            title: 'TBScreen',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: router,
            scrollBehavior: AppScrollBehavior(),
          );
        },
      ),
    );
  }
}
