import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';
import 'package:myapp/features/sync/presentation/sync_center_screen.dart';

Widget _wrap([SyncRepository? repo]) {
  return Provider<SyncRepository>(
    create: (_) => repo ?? MockSyncRepository(),
    child: const MaterialApp(home: Scaffold(body: SyncCenterScreen())),
  );
}

void main() {
  void sizeTablet(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('SyncCenterScreen TabView navigation', () {
    testWidgets('displays Model AI and Data Medis tabs', (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Model AI'), findsOneWidget);
      expect(find.text('Data Medis'), findsOneWidget);
      expect(find.text('Model AI Aktif'), findsOneWidget);
    });

    testWidgets('can switch between Model AI and Data Medis tabs',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // On Tab 1 (Model AI) initially
      expect(find.text('Model AI Aktif'), findsOneWidget);

      // Switch to Tab 2 (Data Medis)
      await tester.tap(find.text('Data Medis'));
      await tester.pumpAndSettle();

      expect(find.text('Cadangan Data Medis'), findsOneWidget);
      expect(find.text('Pilih Data & Unggah'), findsOneWidget);

      // Switch back to Tab 1 (Model AI)
      await tester.tap(find.text('Model AI'));
      await tester.pumpAndSettle();

      expect(find.text('Model AI Aktif'), findsOneWidget);
    });
  });

  group('Model AI Tab catalog and interactions', () {
    testWidgets('initially displays only downloaded models without auto-syncing',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Periksa Pembaruan Model'), findsOneWidget);
      expect(find.text('Model Tersimpan di Perangkat (2)'), findsOneWidget);
      expect(find.text('LOKAL'), findsOneWidget);
      expect(find.text('Sedang Digunakan'), findsOneWidget);
      expect(find.text('Gagal Verifikasi'), findsOneWidget);
      expect(find.text('Verify Ulang'), findsOneWidget);
      // Unduh Model is not visible until user checks remote catalog
      expect(find.text('Unduh Model'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);
    });

    testWidgets('tapping Periksa Pembaruan Model fetches full remote catalog',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Tap Periksa Pembaruan Model
      await tester.tap(find.text('Periksa Pembaruan Model'));
      await tester.pump();

      expect(find.text('Memeriksa server...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Full catalog of 3 models is now visible including undownloaded model
      expect(find.text('Katalog Model Tersedia (3)'), findsOneWidget);
      expect(find.text('Unduh Model'), findsOneWidget);
    });

    testWidgets('filter chips filter models by channel and quantization',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Check remote first to have all 3 models
      await tester.tap(find.text('Periksa Pembaruan Model'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Tap Beta filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Beta'));
      await tester.pumpAndSettle();

      expect(find.text('Katalog Model Tersedia (1)'), findsOneWidget);
      expect(find.text('Gagal Verifikasi'), findsOneWidget);

      // Tap Semua channel filter chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Semua').first);
      await tester.pumpAndSettle();

      expect(find.text('Katalog Model Tersedia (3)'), findsOneWidget);
    });

    testWidgets(
        'Verify Ulang button verifies bundle and switches to Gunakan Model',
        (tester) async {
      sizeTablet(tester);
      final repo = MockSyncRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('Verify Ulang'), findsOneWidget);
      expect(find.text('Gunakan Model'), findsNothing);

      // Tap Verify Ulang
      await tester.tap(find.text('Verify Ulang'));
      await tester.pump(); // starts verifying
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Verification passed -> status verified -> Gunakan Model button appears
      expect(find.text('Terverifikasi'), findsOneWidget);
      expect(find.text('Gunakan Model'), findsOneWidget);
    });

    testWidgets(
        'deleting active model clears active model banner and leaves no model selected',
        (tester) async {
      sizeTablet(tester);
      final repo = MockSyncRepository();
      await tester.pumpWidget(_wrap(repo));
      await tester.pumpAndSettle();

      expect(find.text('SIAP INFERENSI'), findsOneWidget);
      expect(find.text('Sedang Digunakan'), findsOneWidget);

      // First delete icon button is for the active model
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
      expect(find.text('Sedang Digunakan'), findsNothing);
    });
  });

  group('Data Medis Tab (DataBackupCard)', () {
    Future<void> openDialog(WidgetTester tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Navigate to Tab 2
      await tester.tap(find.text('Data Medis'));
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
      expect(enabled.onPressed, isNotNull); // now enabled
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

    testWidgets('consent → selection list appears', (tester) async {
      await openDialog(tester);

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Pasien untuk Dicadangkan'), findsOneWidget);
      expect(find.text('Pilih Semua'), findsOneWidget);
    });
  });
}
