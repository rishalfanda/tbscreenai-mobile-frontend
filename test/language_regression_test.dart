import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/localization/app_text.dart';
import 'package:myapp/core/localization/language_toggle.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/data/mock/mock_validation_repository.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/diagnosis_input_tab.dart';
import 'package:myapp/features/diagnosis/presentation/widgets/diagnosis_result_tab.dart';
import 'package:myapp/features/shared/presentation/app_shell.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:myapp/data/mock/mock_auth_repository.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/state/auth_provider.dart';

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets('shell language toggle preserves route and input at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/dashboard',
        routes: [
          ShellRoute(
            builder: (_, state, child) =>
                AppShell(location: state.uri.path, child: child),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const TextField(key: Key('draft')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                MockAuthRepository(),
                initialProfile: const UserProfile(
                  userId: 'synthetic-doctor',
                  tenantId: 'synthetic-tenant',
                  displayName: 'Synthetic doctor',
                  email: 'doctor@example.invalid',
                  role: 'doctor',
                ),
              ),
            ),
            Provider<ValidationRepository>(
              create: (_) => MockValidationRepository(),
            ),
          ],
          child: Builder(
            builder: (context) => MaterialApp.router(
              locale: context.watch<AppLanguage>().locale,
              supportedLocales: const [Locale('en'), Locale('id')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('draft')), 'Keep this draft');
      await tester.tap(find.text('ID'));
      await tester.pumpAndSettle();
      expect(find.text('Dasbor'), findsWidgets);
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/dashboard');
      expect(
        Localizations.localeOf(tester.element(find.byKey(const Key('draft')))),
        const Locale('id'),
      );
      await tester.tap(find.text('ENG'));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('screening translates display without altering draft or result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final language = AppLanguage();
    final diagnosis = DiagnosisProvider(MockDiagnosisRepository())
      ..updatePatientName('Normal')
      ..updateGender('Female')
      ..updateAge(36)
      ..updateHeight(160)
      ..updateWeight(54)
      ..updateComorbidity('Diabetes');
    final draft = diagnosis.draft;
    var showResult = false;
    late StateSetter updatePage;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider.value(value: diagnosis),
        ],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              updatePage = setState;
              return Scaffold(
                appBar: AppBar(actions: const [LanguageToggle()]),
                body: showResult
                    ? DiagnosisResultTab(onNewScreening: () {})
                    : DiagnosisInputTab(
                        hasModelOverride: true,
                        onAnalyzeSuccess: () {},
                      ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Analyze'), findsOneWidget);
    await tester.tap(find.text('ID'));
    await tester.pumpAndSettle();
    expect(find.text('Analisis'), findsOneWidget);
    expect(identical(diagnosis.draft, draft), isTrue);
    expect(find.text('Normal'), findsOneWidget);

    diagnosis.lastOutcome = DiagnosisOutcome(
      isPositive: false,
      confidence: 73,
      processingTime: '2.9s',
      modelVersion: 'Dashboard',
      createdAt: DateTime(2026, 10, 28),
      isMock: false,
    );
    final result = diagnosis.lastResult;
    updatePage(() => showResult = true);
    await tester.pumpAndSettle();
    expect(find.text('Identitas Pasien'), findsOneWidget);
    expect(find.text('Level Indikasi TB: Low'), findsOneWidget);
    expect(
      find.text(
        'Kemungkinan TB rendah, namun belum dapat sepenuhnya dikesampingkan.',
      ),
      findsOneWidget,
    );
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('27%'), findsOneWidget);
    await tester.tap(find.text('ENG'));
    await tester.pumpAndSettle();
    expect(find.text('Patient Identity'), findsOneWidget);
    expect(find.text('Female · 36 years'), findsOneWidget);
    expect(find.text('TB Indication Level: Low'), findsOneWidget);
    expect(
      find.text('TB likelihood is low, but cannot be ruled out completely.'),
      findsOneWidget,
    );
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('27%'), findsOneWidget);
    expect(identical(diagnosis.lastResult, result), isTrue);
    expect(diagnosis.lastResult!.draft.comorbidity, 'Diabetes');
    expect(tester.takeException(), isNull);
  });

  testWidgets('newly added UI strings translate correctly in both languages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final language = AppLanguage();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return ListView(
                children: [
                  AppText('Pilih Sumber Citra'),
                  AppText('Flashdisk USB / Berkas'),
                  AppText('Galeri Foto'),
                  AppText('Hapus Rontgen'),
                  AppText('Close camera'),
                  AppText('Turn flash off'),
                  AppText('Turn flash on'),
                  AppText('Switch camera'),
                  AppText('Tenant'),
                  AppText('Doctor Review'),
                  AppText('Validate AI screening results'),
                  AppText('The server changed after this device loaded the diagnosis.'),
                  AppText('Screening volume, last 14 days'),
                  AppText('Added 2026-11-04'),
                  AppText(
                    'Apakah Anda yakin ingin menghapus DS-1? Tindakan ini tidak dapat dibatalkan.',
                  ),
                  AppText('Validation was not saved: timeout'),
                  AppText('Conflict was not resolved: 409'),
                  AppText('Verdict: agreed'),
                  AppText('Note: cough'),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Default English assertions
    expect(find.text('Select Image Source'), findsOneWidget);
    expect(find.text('USB Flash Drive / Files'), findsOneWidget);
    expect(find.text('Photo Gallery'), findsOneWidget);
    expect(find.text('Remove X-Ray'), findsOneWidget);
    expect(find.text('Close camera'), findsOneWidget);
    expect(find.text('Turn flash off'), findsOneWidget);
    expect(find.text('Turn flash on'), findsOneWidget);
    expect(find.text('Switch camera'), findsOneWidget);
    expect(find.text('Tenant'), findsOneWidget);
    expect(find.text('Doctor Review'), findsOneWidget);
    expect(find.text('Validate AI screening results'), findsOneWidget);
    expect(
      find.text('The server changed after this device loaded the diagnosis.'),
      findsOneWidget,
    );
    expect(find.text('Screening volume, last 14 days'), findsOneWidget);
    expect(find.text('Added 2026-11-04'), findsOneWidget);
    expect(
      find.text('Are you sure you want to delete DS-1? This action cannot be undone.'),
      findsOneWidget,
    );
    expect(find.text('Validation was not saved: timeout'), findsOneWidget);
    expect(find.text('Conflict was not resolved: 409'), findsOneWidget);
    expect(find.text('Verdict: agreed'), findsOneWidget);
    expect(find.text('Note: cough'), findsOneWidget);

    // Switch to Indonesian
    language.select('id');
    await tester.pumpAndSettle();

    expect(find.text('Pilih Sumber Citra'), findsOneWidget);
    expect(find.text('Flashdisk USB / Berkas'), findsOneWidget);
    expect(find.text('Galeri Foto'), findsOneWidget);
    expect(find.text('Hapus Rontgen'), findsOneWidget);
    expect(find.text('Tutup kamera'), findsOneWidget);
    expect(find.text('Matikan lampu kilat'), findsOneWidget);
    expect(find.text('Nyalakan lampu kilat'), findsOneWidget);
    expect(find.text('Ganti kamera'), findsOneWidget);
    expect(find.text('Instansi / Tenant'), findsOneWidget);
    expect(find.text('Tinjauan Dokter'), findsOneWidget);
    expect(find.text('Validasi hasil skrining AI'), findsOneWidget);
    expect(
      find.text('Data di server telah berubah setelah perangkat ini memuat diagnosis.'),
      findsOneWidget,
    );
    expect(find.text('Jumlah skrining, 14 hari terakhir'), findsOneWidget);
    expect(find.text('Ditambahkan 2026-11-04'), findsOneWidget);
    expect(
      find.text('Apakah Anda yakin ingin menghapus DS-1? Tindakan ini tidak dapat dibatalkan.'),
      findsOneWidget,
    );
    expect(find.text('Validasi gagal disimpan: timeout'), findsOneWidget);
    expect(find.text('Konflik gagal diselesaikan: 409'), findsOneWidget);
    expect(find.text('Keputusan: Disetujui'), findsOneWidget);
    expect(find.text('Catatan: cough'), findsOneWidget);
  });
}
