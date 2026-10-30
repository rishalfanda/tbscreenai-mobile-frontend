import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/domain/models/validation_case.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/validation/presentation/validation_screen.dart';
import 'package:myapp/state/auth_provider.dart';

const _doctor = UserProfile(
  userId: 'synthetic-doctor',
  tenantId: 'synthetic-tenant',
  displayName: 'Synthetic',
  email: 'doctor@example.invalid',
  role: 'doctor',
);

class _Auth implements AuthRepository {
  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async => _doctor;
  @override
  Future<void> logout() async {}
}

class _Repo extends ValidationRepository
    implements NumericValidationRepository {
  int? score;
  final images = <String, Completer<XrayImage?>>{};
  @override
  Future<List<ValidationCase>> getCases() async => [
    for (final id in ['one', 'two'])
      ValidationCase(
        id: id,
        name: 'Synthetic $id',
        initials: 'S',
        age: 30,
        gender: 'Female',
        aiScore: 80,
        diagnosisDate: '2026-10-30',
        isPositive: true,
        status: 'pending',
        validationScore: id == 'one' ? score : null,
        findings: const ValidationFindings(
          consolidation: 1,
          cavity: 2,
          effusion: 3,
          fibrotic: 4,
          calcification: 5,
        ),
      ),
  ];
  @override
  Future<XrayImage?> loadCaseImage(String id) =>
      (images[id] ??= Completer()).future;
  @override
  Future<void> submitScore({
    required String id,
    required int score,
    String? status,
    String? note,
  }) async {
    this.score = score;
  }

  @override
  Future<ValidationSubmission> submitValidation({
    required String id,
    required String status,
    String? note,
  }) => throw StateError('Legacy verdict must not be used');
}

void main() {
  testWidgets(
    'numeric UI requires explicit score and clears previous X-ray during selection',
    (tester) async {
      final repo = _Repo();
      final auth = AuthProvider(_Auth(), initialProfile: _doctor);
      addTearDown(auth.dispose);
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ValidationRepository>.value(value: repo),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ValidationScreen(caseId: 'one')),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('confirm-validation-score')),
            )
            .onPressed,
        isNull,
      );
      repo.images['one']!.complete(XrayImage.placeholder());
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      tester
          .widget<Slider>(find.byKey(const Key('validation-score-slider')))
          .onChanged!(0);
      await tester.pump();
      tester
          .widget<DropdownButtonFormField<bool>>(
            find.byType(DropdownButtonFormField<bool>),
          )
          .onChanged!(true);
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('confirm-validation-score')),
      );
      await tester.tap(find.byKey(const Key('confirm-validation-score')));
      await tester.pumpAndSettle();
      expect(repo.score, 0);
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged!('two');
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      repo.images['two']!.complete(null);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
