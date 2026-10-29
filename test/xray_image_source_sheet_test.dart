import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_screen.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:provider/provider.dart';

Widget _createTestApp({required DiagnosisProvider provider}) {
  return ChangeNotifierProvider.value(
    value: provider,
    child: const MaterialApp(
      home: Scaffold(
        body: DiagnosisScreen(hasModelOverride: true),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping upload button opens source selection bottom sheet with USB hint badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = DiagnosisProvider(MockDiagnosisRepository());
    await tester.pumpWidget(_createTestApp(provider: provider));
    await tester.pumpAndSettle();

    final uploadButton = find.byKey(const Key('upload-xray'));
    expect(uploadButton, findsOneWidget);

    await tester.tap(uploadButton);
    await tester.pumpAndSettle();

    // Verify bottom sheet title and options
    expect(find.text('Pilih Sumber Citra'), findsOneWidget);
    expect(find.text('Flashdisk USB / Berkas'), findsOneWidget);
    expect(
      find.text('Buka pengelola berkas untuk memilih citra dari flashdisk USB atau memori'),
      findsOneWidget,
    );
    expect(
      find.text('Pastikan flashdisk USB sudah terpasang di perangkat'),
      findsOneWidget,
    );
    expect(find.text('Galeri Foto'), findsOneWidget);
    expect(find.text('Pilih citra dari galeri foto perangkat'), findsOneWidget);
  });

  testWidgets('dismissing bottom sheet by tapping barrier does not show snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final provider = DiagnosisProvider(MockDiagnosisRepository());
    await tester.pumpWidget(_createTestApp(provider: provider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('upload-xray')));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Sumber Citra'), findsOneWidget);

    // Tap outside bottom sheet barrier
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Sumber Citra'), findsNothing);
    expect(
      find.text('Tidak ada citra yang dipilih. Jika menggunakan flashdisk USB, pastikan sudah terpasang dengan baik.'),
      findsNothing,
    );
  });
}

