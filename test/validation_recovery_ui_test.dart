import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/domain/models/clinical_conflict.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/models/validation_case.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/domain/repositories/validation_conflict_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';
import 'package:myapp/features/validation/presentation/offline_validation_screen.dart';
import 'package:myapp/state/auth_provider.dart';

const _doctor = UserProfile(
  userId: 'doctor',
  tenantId: 'tenant',
  displayName: 'Doctor',
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

class _ConflictRepo extends ValidationRepository
    implements
        NumericValidationRepository,
        NumericValidationConflictRepository {
  @override
  Future<List<ValidationCase>> getCases() async => const [];

  @override
  Future<List<ClinicalConflict>> getConflicts() async => const [
    ClinicalConflict(
      clientOpId: 'delete-op',
      diagnosisId: 'hidden-diagnosis',
      localStatus: 'agreed',
      localNote: null,
      baseVersion: 3,
      detail: 'version_conflict',
      serverStatus: 'agreed',
      serverVersion: 4,
      operation: 'delete_validation',
    ),
  ];

  @override
  Future<XrayImage?> loadCaseImage(String id) async => null;

  @override
  Future<void> resolveNumericConflict({
    required ClinicalConflict conflict,
    required ConflictDecision decision,
    String? status,
    int? lesionRating,
    String? note,
  }) async {}

  @override
  Future<void> submitScore({
    required String id,
    required int score,
    String? status,
    String? note,
  }) async {}

  @override
  Future<ValidationSubmission> submitValidation({
    required String id,
    required String status,
    String? note,
  }) async => const ValidationSubmission(ValidationSubmissionState.queued);
}

void main() {
  testWidgets('hidden row still exposes its delete conflict recovery', (
    tester,
  ) async {
    final auth = AuthProvider(_Auth(), initialProfile: _doctor);
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ValidationRepository>.value(value: _ConflictRepo()),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider(create: (_) => AppLanguage()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: OfflineValidationScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('validation-conflict-delete-op')),
      findsOneWidget,
    );
    expect(find.textContaining('hidden-diagnosis'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('resolve-validation-conflict-delete-op')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resolve validation conflict'), findsOneWidget);
    expect(
      find.textContaining(RegExp('Kirim ulang penghapusan|Retry deletion')),
      findsOneWidget,
    );
  });
}
