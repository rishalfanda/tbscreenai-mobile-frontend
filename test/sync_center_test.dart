// Widget tests for SyncCenterScreen — the two flows CLAUDE.md specifies:
//   ModelUpdateCard state machine (idle → checking → updateAvailable)
//   DataBackupCard consent dialog (non-dismissible, Lanjutkan gated on checkbox)
//
// Uses the mock SyncRepository so timings are deterministic and no backend is
// needed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';
import 'package:myapp/features/sync/presentation/sync_center_screen.dart';

Widget _wrap() {
  return Provider<SyncRepository>(
    create: (_) => MockSyncRepository(),
    child: const MaterialApp(home: Scaffold(body: SyncCenterScreen())),
  );
}

void main() {
  // The cards lay out side by side above 880px — give tests the room.
  void sizeTablet(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('ModelUpdateCard state machine', () {
    testWidgets('starts idle with a check button', (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('Periksa Pembaruan Model'), findsOneWidget);
      expect(find.text('Perbarui Sekarang'), findsNothing);
    });

    testWidgets('idle → checking → updateAvailable shows version table',
        (tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(find.text('Periksa Pembaruan Model'));
      await tester.pump(); // enter checking

      expect(find.text('Memeriksa server...'), findsOneWidget);

      // Mock resolves the check after 2s.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('Versi Baru Tersedia'), findsOneWidget);
      expect(find.text('Perbarui Sekarang'), findsOneWidget);
      expect(find.text('v1.3.1'), findsOneWidget);
    });
  });

  group('DataBackupCard consent dialog', () {
    Future<void> openDialog(WidgetTester tester) async {
      sizeTablet(tester);
      await tester.pumpWidget(_wrap());
      await tester.pump();
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

      // Tap top-left, well outside the dialog.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Still open — barrierDismissible is false for sensitive medical data.
      expect(find.text('Konfirmasi Pengiriman Data'), findsOneWidget);
    });

    testWidgets('Batal closes the dialog without proceeding', (tester) async {
      await openDialog(tester);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi Pengiriman Data'), findsNothing);
      // Back to idle — no patient selection list shown.
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
