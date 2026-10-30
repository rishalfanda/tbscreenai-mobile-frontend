import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';
import 'package:myapp/domain/models/models.dart';
import 'package:myapp/features/sync/presentation/sync_center_screen.dart';

class _EmptyModelSyncRepository extends MockSyncRepository {
  @override
  Future<String?> getInstalledModelVersion() async => null;

  @override
  Future<ModelVersionInfo> checkForUpdate() async {
    return const ModelVersionInfo(
      currentVersion: '',
      latestVersion: '',
      fileSize: '-',
      releaseDate: '-',
      changelog: [],
    );
  }

  @override
  Future<List<AvailableModelBundle>> getAvailableModels({
    String? channel,
    bool? quantized,
    bool localOnly = false,
  }) async =>
      const [];

  @override
  Future<(ModelVersionInfo, DateTime)?> lastKnownUpdateInfo() async => null;
}

Widget _wrap([SyncRepository? repo]) {
  return Provider<SyncRepository>(
    create: (_) => repo ?? MockSyncRepository(),
    child: MaterialApp(
      theme: AppTheme.lightTheme.copyWith(
        splashFactory: InkRipple.splashFactory,
      ),
      home: const Scaffold(body: SyncCenterScreen()),
    ),
  );
}

void main() {
  void sizeTablet(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('SyncCenterScreen single-page layout', () {
    testWidgets('displays both Model Update and Data Backup cards simultaneously',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // No TabBar tabs
      expect(find.byType(TabBar), findsNothing);

      // Both cards are visible on the same page
      expect(find.text('Pembaruan Model AI'), findsOneWidget);
      expect(find.text('Cadangan Data Medis'), findsOneWidget);
      expect(find.text('Sync Center'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);
    });
  });

  group('ModelUpdateCard state machine & Latest Model Lifecycle', () {
    testWidgets('starts idle with active model banner and check button',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Model AI Aktif'), findsOneWidget);
      expect(find.text('stable_2026.09.04'), findsOneWidget);
      expect(find.text('SIAP INFERENSI'), findsOneWidget);
      expect(find.text('Periksa Pembaruan Model'), findsOneWidget);
      expect(find.text('Perbarui Sekarang'), findsNothing);
    });

    testWidgets('idle -> checking -> updateAvailable shows version table',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Periksa Pembaruan Model'));
      await tester.pump(); // enters checking

      expect(find.text('Memeriksa server...'), findsOneWidget);

      // Mock resolves after 2s
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Versi Baru Tersedia'), findsOneWidget);
      expect(find.text('Perbarui Sekarang'), findsOneWidget);
      expect(find.text('v1.3.1'), findsOneWidget);
    });

    testWidgets(
        'shows noModelAvailable message when server has no models and device has none',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap(_EmptyModelSyncRepository()));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Model Aktif'), findsOneWidget);

      await tester.tap(find.text('Periksa Pembaruan Model'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Model AI di Server'), findsOneWidget);
      expect(
        find.text(
          'Server belum memiliki berkas model AI yang dirilis untuk channel ini. '
          'Hubungi administrator sistem untuk mengunggah bundle model AI ke server.',
        ),
        findsOneWidget,
      );
      expect(find.text('Periksa Lagi'), findsOneWidget);
    });

    testWidgets(
        'downloading displays transfer speed and can be cancelled via Batal button',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Check update
      await tester.tap(find.text('Periksa Pembaruan Model'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Start download
      await tester.tap(find.text('Perbarui Sekarang'));
      await tester.pump(); // start stream
      await tester.pump(const Duration(milliseconds: 200));

      // Downloading state displays progress, speed badge, and Batal button
      expect(find.text('Mengunduh model AI...'), findsOneWidget);
      expect(find.text('2.4 MB/s'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Batal'), findsOneWidget);

      // Tap Batal
      await tester.tap(find.widgetWithText(OutlinedButton, 'Batal'));
      await tester.pumpAndSettle();

      // Download is cancelled and UI returns to updateAvailable with snackbar
      expect(find.text('Unduhan model dibatalkan.'), findsOneWidget);
      expect(find.text('Perbarui Sekarang'), findsOneWidget);
    });

    testWidgets('full download completes and activates new model',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Check update
      await tester.tap(find.text('Periksa Pembaruan Model'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Start download
      await tester.tap(find.text('Perbarui Sekarang'));
      await tester.pump();

      // Let download finish (10 ticks x 100ms)
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pumpAndSettle();

      expect(find.text('Pembaruan Selesai'), findsOneWidget);
    });
  });

  group('Stored Models Show/Hide container & deletion', () {
    testWidgets(
        'stored models list is collapsed by default and expands on tap',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Header is visible showing 2 models
      expect(find.text('Model Tersimpan di Perangkat (2)'), findsOneWidget);
      // Individual items are hidden
      expect(find.text('Gagal Verifikasi'), findsNothing);
      expect(find.text('Verify Ulang'), findsNothing);

      // Tap header to expand
      await tester.tap(find.text('Model Tersimpan di Perangkat (2)'));
      await tester.pumpAndSettle();

      // Now items are visible
      expect(find.text('Gagal Verifikasi'), findsOneWidget);
      expect(find.text('Verify Ulang'), findsOneWidget);
      expect(find.text('Aktif'), findsOneWidget);
    });

    testWidgets('can re-verify failed model in stored models list',
        (tester) async {
      sizeTablet(tester);
      final repo = MockSyncRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Expand list
      await tester.tap(find.text('Model Tersimpan di Perangkat (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Verify Ulang'), findsOneWidget);
      expect(find.text('Gunakan'), findsNothing);

      // Tap Verify Ulang
      await tester.tap(find.text('Verify Ulang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verified and Gunakan button appears
      expect(find.text('Terverifikasi'), findsWidgets);
      expect(find.text('Gunakan'), findsOneWidget);
    });

    testWidgets('deleting a stored model shows confirmation dialog and removes it',
        (tester) async {
      sizeTablet(tester);
      final repo = MockSyncRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      // Expand list
      await tester.tap(find.text('Model Tersimpan di Perangkat (2)'));
      await tester.pumpAndSettle();

      // Tap delete on active model (first delete icon)
      final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
      expect(deleteButtons, findsWidgets);

      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();

      // Delete confirmation dialog is shown
      expect(find.text('Hapus Model v2026.09.04?'), findsOneWidget);

      // Confirm delete
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Active model banner now shows no active model
      expect(find.text('Belum Ada Model Aktif'), findsOneWidget);
      expect(find.text('TIDAK ADA MODEL AKTIF'), findsOneWidget);
      expect(find.text('Model Tersimpan di Perangkat (1)'), findsOneWidget);
    });
  });

  group('DataBackupCard consent dialog and upload', () {
    Future<void> openDialog(WidgetTester tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih Data & Unggah'));
      await tester.pumpAndSettle();
    }

    testWidgets('opens with Lanjutkan disabled until consent is checked',
        (tester) async {
      await openDialog(tester);

      expect(find.text('Konfirmasi Pengiriman Data'), findsOneWidget);

      final continueButton = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Lanjutkan'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(continueButton.onPressed, isNull); // disabled

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      final enabled = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Lanjutkan'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(enabled.onPressed, isNotNull); // enabled
    });

    testWidgets('cannot be dismissed by tapping the barrier', (tester) async {
      await openDialog(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi Pengiriman Data'), findsOneWidget);
    });

    testWidgets('Batal closes the dialog without proceeding', (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi Pengiriman Data'), findsNothing);
      expect(find.text('Pilih Data & Unggah'), findsOneWidget);
    });

    testWidgets('consent -> selection list appears', (tester) async {
      await openDialog(tester);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Pasien untuk Dicadangkan'), findsOneWidget);
      expect(find.text('Batal Semua'), findsOneWidget);
    });
  });
}
