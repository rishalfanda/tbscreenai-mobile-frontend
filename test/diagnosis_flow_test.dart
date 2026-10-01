import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/data/mock/mock_diagnosis_repository.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';
import 'package:myapp/features/diagnosis/presentation/diagnosis_screen.dart';
import 'package:myapp/state/diagnosis_provider.dart';
import 'package:provider/provider.dart';

class _FailingDiagnosisRepository implements DiagnosisRepository {
  @override
  Future<List<String>> getSymptomOptions() async => const [];

  @override
  Future<DiagnosisOutcome> runInference({required XrayImage image}) async {
    throw Exception('server unavailable');
  }
}

Widget _app({
  required DiagnosisProvider provider,
  required Future<XrayImage?> Function() picker,
}) {
  final router = GoRouter(
    initialLocation: '/diagnosis',
    routes: [
      GoRoute(
        path: '/diagnosis',
        builder: (context, state) => Scaffold(
          body: DiagnosisScreen(pickImage: picker, hasModelOverride: true),
        ),
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('camera-route'))),
      ),
    ],
  );
  return ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp.router(routerConfig: router),
  );
}

void _seedRequiredFields(DiagnosisProvider provider) {
  provider
    ..updatePatientName('Patient A')
    ..updateGender('Female')
    ..updateAge(34)
    ..updateHeight(160)
    ..updateWeight(55);
}

void main() {
  testWidgets('reference layout exposes upload and camera actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        provider: DiagnosisProvider(MockDiagnosisRepository()),
        picker: () async => null,
      ),
    );
    await tester.tap(find.byKey(const Key('optional-fields-panel')));
    await tester.pumpAndSettle();

    expect(find.text('Analisis Rontgen TB dengan AI'), findsOneWidget);
    expect(find.text('Jenis Gejala'), findsOneWidget);
    expect(find.byKey(const Key('upload-xray')), findsOneWidget);
    expect(find.byKey(const Key('capture-xray')), findsOneWidget);
    expect(find.byKey(const Key('analyze-button')), findsOneWidget);
  });

  testWidgets('name, gender, and age are required before screening', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        provider: DiagnosisProvider(MockDiagnosisRepository()),
        picker: () async => null,
      ),
    );

    await tester.ensureVisible(find.byKey(const Key('analyze-button')));
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();

    expect(find.text('Nama wajib diisi'), findsOneWidget);
    expect(find.text('Jenis kelamin wajib dipilih'), findsOneWidget);
    expect(find.text('Wajib diisi'), findsWidgets);
    // The result tab only ever renders the real-outcome header once an
    // outcome exists; otherwise it's the neutral empty-state placeholder.
    expect(find.text('Hasil Screening'), findsNothing);
  });

  testWidgets(
    'chosen image is attached and successful inference switches to the result tab',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = DiagnosisProvider(MockDiagnosisRepository());
      _seedRequiredFields(provider);

      await tester.pumpWidget(
        _app(
          provider: provider,
          picker: () async => XrayImage.placeholder('selected_xray.png'),
        ),
      );

      await tester.tap(find.byKey(const Key('upload-xray')));
      await tester.pumpAndSettle();
      expect(provider.imageLabel, 'selected_xray.png');

      await tester.ensureVisible(find.byKey(const Key('analyze-button')));
      await tester.tap(find.byKey(const Key('analyze-button')));
      await tester.pumpAndSettle();

      expect(find.text('Hasil Screening').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('failed inference stays on form and exposes actionable error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = DiagnosisProvider(_FailingDiagnosisRepository());
    _seedRequiredFields(provider);
    provider.attachPlaceholderImage('selected_xray.png');

    await tester.pumpWidget(_app(provider: provider, picker: () async => null));

    await tester.ensureVisible(find.byKey(const Key('analyze-button')));
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();

    expect(find.text('Hasil Screening'), findsNothing);
    expect(find.text('Analisis Rontgen TB dengan AI'), findsOneWidget);
    expect(provider.lastOutcome, isNull);
    expect(provider.lastError, contains('Check the server connection'));
  });
}
