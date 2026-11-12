import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/core/theme/app_theme.dart';
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
    implements
        NumericValidationRepository,
        ValidationResetRepository,
        LesionRatingValidationRepository {
  @override
  Future<void> submitLesionRating({
    required String id,
    required int rating,
    required String status,
    String? note,
  }) => submitScore(id: id, score: rating, status: status, note: note);
  int resetCalls = 0;
  final hidden = <String>{};
  @override
  Future<void> resetValidation(String id) async {
    resetCalls++;
    hidden.add(id);
    savedStatus = "pending";
    score = null;
    savedNote = null;
  }

  int? score;
  bool firstPending = false;
  final times = <String, DateTime>{};
  String? savedStatus;
  String? savedNote;
  final images = <String, Completer<XrayImage?>>{};
  @override
  Future<List<ValidationCase>> getCases() async => [
    for (final id in ['one', 'two'].where((id) => !hidden.contains(id)))
      ValidationCase(
        id: id,
        name: 'Synthetic $id',
        initials: 'S',
        age: 30,
        gender: 'Female',
        aiScore: id == 'one' ? 80 : 40,
        diagnosisDate: times.containsKey(id)
            ? '2026-11-11'
            : id == 'one'
            ? '2026-10-30'
            : '2026-11-01',
        diagnosedAt: times[id],
        isPositive: true,
        status: savedStatus != null && id == 'one'
            ? savedStatus!
            : id == 'one' && !firstPending
            ? 'agreed'
            : 'pending',
        lesionRating: id == 'one' ? score : null,
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
    savedStatus = status;
    savedNote = note;
  }

  @override
  Future<ValidationSubmission> submitValidation({
    required String id,
    required String status,
    String? note,
  }) => throw StateError('Legacy verdict must not be used');
}

Future<void> _mount(WidgetTester tester, _Repo repo, {String? caseId}) async {
  final auth = AuthProvider(_Auth(), initialProfile: _doctor);
  addTearDown(auth.dispose);
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ValidationRepository>.value(value: repo),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => AppLanguage()),
      ],
      child: MaterialApp(
        home: Scaffold(body: ValidationScreen(caseId: caseId)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _choose(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

void main() {
  testWidgets(
    'same-day screenings sort by actual time and timezone rather than UUID or display date',
    (tester) async {
      final repo = _Repo()..firstPending = true;
      repo.times['one'] = DateTime.parse('2026-11-11T08:00:02+07:00');
      repo.times['two'] = DateTime.parse('2026-11-11T02:00:01Z');
      await _mount(tester, repo);
      List<String> ids() => tester
          .widget<DataTable>(find.byType(DataTable))
          .rows
          .map((row) => (row.key! as ValueKey<String>).value)
          .toList();
      // Both have the same display date, but two is almost an hour later.
      expect(ids(), ['validation-case-two', 'validation-case-one']);
      for (final sort in ['earliest', 'latest']) {
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const Key('validation-sort')),
            )
            .onChanged!(sort);
        await tester.pump();
        expect(
          ids(),
          sort == 'earliest'
              ? ['validation-case-one', 'validation-case-two']
              : ['validation-case-two', 'validation-case-one'],
        );
      }
      final one = (await repo.getCases()).firstWhere((row) => row.id == 'one');
      expect(find.text(one.screeningDateTimeLabel), findsOneWidget);
      expect(one.copyWith(status: 'agreed').diagnosedAt, one.diagnosedAt);
      // Times only one second apart must also sort independently of the ID.
      repo.times['one'] = DateTime.parse('2026-11-11T02:00:02Z');
      await tester.pumpWidget(const SizedBox.shrink());
      await _mount(tester, repo);
      expect(ids(), ['validation-case-one', 'validation-case-two']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'deleting only a validation requires confirmation and removes the row from the validation list',
    (tester) async {
      final repo = _Repo()..score = 7;
      await _mount(tester, repo);
      await _choose(tester, 'delete-one');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.resetCalls, 0);
      await _choose(tester, 'delete-one');
      await _choose(tester, 'confirm-delete-validation');
      await tester.pumpAndSettle();
      expect(repo.resetCalls, 1);
      expect(repo.savedStatus, 'pending');
      expect(repo.score, isNull);
      expect(
        tester.widget<DataTable>(find.byType(DataTable)).rows,
        hasLength(1),
      );
      expect(find.byKey(const ValueKey('validate-one')), findsNothing);
      expect(find.byKey(const ValueKey('delete-one')), findsNothing);
    },
  );
  testWidgets(
    'radio review requires explicit rating, saves disagreement without a note, and isolates images by screening',
    (tester) async {
      final repo = _Repo()..firstPending = true;
      await _mount(tester, repo, caseId: 'one');
      repo.images['one']!.complete(XrayImage.placeholder());
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('Consolidation:'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('confirm-validation-score')),
            )
            .onPressed,
        isNull,
      );
      await _choose(tester, 'verdict-disagreed');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('confirm-validation-score')),
            )
            .onPressed,
        isNull,
      );
      await _choose(tester, 'lesion-rating-0');
      await _choose(tester, 'confirm-validation-score');
      await tester.pumpAndSettle();
      expect(repo.score, 0);
      expect(repo.savedStatus, 'disagreed');
      expect(repo.savedNote, '');
      expect(find.byType(Dialog), findsNothing);
      await _choose(tester, 'view-two');
      expect(find.byType(Image), findsNothing);
      repo.images['two']!.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Local X-ray unavailable.'), findsOneWidget);
      expect(find.byKey(const Key('confirm-validation-score')), findsNothing);
      expect(
        tester
            .widget<Radio<int>>(find.byKey(const ValueKey('lesion-rating-10')))
            .enabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(600, 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('table searches names and filters status and AI score order', (
    tester,
  ) async {
    final repo = _Repo();
    await _mount(tester, repo);
    List<String> ids() => tester
        .widget<DataTable>(find.byType(DataTable))
        .rows
        .map((row) => (row.key! as ValueKey<String>).value)
        .toList();
    expect(ids(), ['validation-case-two', 'validation-case-one']);
    await tester.enterText(find.byKey(const Key('validation-search')), 'ONE');
    await tester.pump();
    expect(ids(), ['validation-case-one']);
    await tester.enterText(find.byKey(const Key('validation-search')), '');
    await tester.pump();
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const Key('validation-status-filter')),
        )
        .onChanged!('agreed');
    await tester.pump();
    expect(ids(), ['validation-case-one']);
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const Key('validation-status-filter')),
        )
        .onChanged!('all');
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const Key('validation-sort')),
        )
        .onChanged!('lowest');
    await tester.pump();
    expect(ids(), ['validation-case-two', 'validation-case-one']);
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const Key('validation-sort')),
        )
        .onChanged!('highest');
    await tester.pump();
    expect(ids(), ['validation-case-one', 'validation-case-two']);
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const Key('validation-sort')),
        )
        .onChanged!('earliest');
    await tester.pump();
    expect(ids(), ['validation-case-one', 'validation-case-two']);
    tester
        .widget<DropdownButtonFormField<String>>(
          find.byKey(const Key('validation-sort')),
        )
        .onChanged!('latest');
    await tester.pump();
    expect(ids(), ['validation-case-two', 'validation-case-one']);
    tester.view.physicalSize = const Size(600, 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'validation screen shows high-contrast status chips and visible action buttons that open the form dialog',
    (tester) async {
      final repo = _Repo();
      final auth = AuthProvider(_Auth(), initialProfile: _doctor);
      addTearDown(auth.dispose);
      // Width matching a 1024px tablet minus the 84px navigation rail.
      tester.view.physicalSize = const Size(940, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ValidationRepository>.value(value: repo),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider(create: (_) => AppLanguage()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: ValidationScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Verify validation screening status chips have high-contrast dark label colors.
      final agreeChip = tester.widget<Chip>(
        find.ancestor(
          of: find.text('Agree'),
          matching: find.byType(Chip),
        ),
      );
      final agreeText = agreeChip.label as Text;
      expect(agreeText.style?.color, AppTheme.successDark);

      final unvalidatedChip = tester.widget<Chip>(
        find.ancestor(
          of: find.text('Unvalidated'),
          matching: find.byType(Chip),
        ),
      );
      final unvalidatedText = unvalidatedChip.label as Text;
      expect(unvalidatedText.style?.color, const Color(0xFF92400E));

      // Verify Validate & Edit buttons are visible within tablet viewport without horizontal clipping.
      final validateBtnFinder = find.byKey(const ValueKey('validate-two'));
      final editBtnFinder = find.byKey(const ValueKey('edit-one'));
      expect(validateBtnFinder, findsOneWidget);
      expect(editBtnFinder, findsOneWidget);
      expect(tester.getTopRight(validateBtnFinder).dx, lessThanOrEqualTo(940));
      expect(tester.getTopRight(editBtnFinder).dx, lessThanOrEqualTo(940));

      // Tap Validate button to open editable form dialog for pending row.
      await tester.tap(validateBtnFinder);
      await tester.pump();
      repo.images['two']!.complete(XrayImage.placeholder());
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byKey(const Key('confirm-validation-score')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Synthetic two'),
        ),
        findsOneWidget,
      );

      // Submit a disagreement on 'two' and close, then verify Disagree chip contrast.
      await _choose(tester, 'verdict-disagreed');
      await _choose(tester, 'lesion-rating-3');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      // Tapping Edit button on validated row opens editable form dialog too.
      await tester.tap(editBtnFinder);
      await tester.pump();
      repo.images['one']!.complete(XrayImage.placeholder());
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byKey(const Key('confirm-validation-score')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Synthetic one'),
        ),
        findsOneWidget,
      );

      await _choose(tester, 'verdict-disagreed');
      await _choose(tester, 'lesion-rating-2');
      await _choose(tester, 'confirm-validation-score');
      await tester.pumpAndSettle();

      final disagreeChip = tester.widget<Chip>(
        find.ancestor(
          of: find.text('Disagree'),
          matching: find.byType(Chip),
        ),
      );
      expect((disagreeChip.label as Text).style?.color, AppTheme.errorDark);
      expect(tester.takeException(), isNull);
    },
  );
}
