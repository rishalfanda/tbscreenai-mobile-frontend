import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/offline/offline_dashboard_repository.dart';
import 'package:myapp/state/dashboard_provider.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';

class _Auth extends AuthRepository {
  @override
  Future<UserProfile> login({
    required String email,
    required String password,
  }) async => throw UnimplementedError();
  @override
  Future<void> logout() async {}
}

void main() {
  late AppDatabase db;
  late OfflineDashboardRepository repo;
  final now = DateTime.utc(2026, 11, 12, 12);
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.activateOwner(
      db.sessionGeneration,
      const DataOwner(tenantId: 'tenant', userId: 'doctor', deviceId: 'device'),
    );
    await db.putSetting(kUserRole, 'doctor');
    repo = OfflineDashboardRepository(db, now: () => now);
    await db.upsertPatient(
      LocalPatientsCompanion.insert(
        id: 'patient',
        code: 'SYN',
        name: 'Synthetic patient',
        age: 30,
        gender: 'Male',
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> row(
    String id, {
    String status = 'pending',
    bool positive = true,
    bool mock = false,
    bool deleted = false,
    DateTime? at,
    String user = 'doctor',
    String tenant = 'tenant',
    String device = 'device',
  }) => db
      .into(db.localDiagnoses)
      .insert(
        LocalDiagnosesCompanion.insert(
          id: id,
          patientId: 'patient',
          isPositive: positive,
          confidence: 80,
          modelVersion: 'synthetic-test',
          diagnosedAt: at ?? now,
          status: Value(status),
          isMock: Value(mock),
          validationDeletedAt: Value(deleted ? now : null),
          tenantId: Value(tenant),
          userId: Value(user),
          deviceId: Value(device),
        ),
      )
      .then((_) {});

  test(
    'device counts include unsynced work, exclude other owners and preserve validation tombstones',
    () async {
      await row('pending');
      await row('agreed', status: 'agreed', positive: false);
      await row('disagreed', status: 'disagreed');
      await row('deleted', status: 'agreed', deleted: true);
      await row('mock', mock: true);
      await row('other-doctor', user: 'other');
      await row('other-tenant', tenant: 'other');
      await row('other-device', device: 'other');
      await row('previous', at: now.subtract(const Duration(days: 40)));
      final result = await repo.load(days: 30, tzOffsetMinutes: 420);
      expect(result.metrics.map((m) => m.value), ['1', '4', '2', '1']);
      expect(result.agreementRate, 50);
      expect(result.ai.positive, 3);
      expect(result.doctor.positive, 0);
      expect(result.doctor.negative, 2);
      expect(result.activities, hasLength(4));
      expect(result.activities.first.name, 'Synthetic patient');
      expect(result.activities.first.timestamp, '2026-11-12 19:00');
      expect(result.trend.fold<int>(0, (sum, p) => sum + p.totalDiagnoses), 4);
    },
  );

  test(
    'period boundaries use local midnight and distinct screened patients',
    () async {
      await row('inside', at: DateTime.utc(2026, 11, 11, 18));
      await row('inside2');
      await row('before', at: DateTime.utc(2026, 11, 11, 16));
      await row('after', at: DateTime.utc(2026, 11, 12, 18));
      final result = await repo.load(days: 1, tzOffsetMinutes: 420);
      expect(result.metrics[1].value, '2');
      expect(result.metrics[1].change, '+100.0%');
      expect(result.trend.single.date, '2026-11-12');
      expect(result.trend.single.totalPatients, 1);
    },
  );

  test(
    'empty local diagnosis data has zero counts and no invented percentages',
    () async {
      final result = await repo.load(days: 30, tzOffsetMinutes: 420);
      expect(result.metrics.map((m) => m.value), ['1', '0', '0', '0']);
      expect(result.ai.positivePct, isNull);
      expect(result.agreementRate, isNull);
      expect(result.activities, isEmpty);
    },
  );

  test(
    'no active owner or technician cannot read local clinical aggregates',
    () async {
      await db.putSetting(kUserRole, 'technician');
      await expectLater(
        repo.load(days: 30, tzOffsetMinutes: 420),
        throwsStateError,
      );
      await db.clearSessionData();
      await expectLater(
        repo.load(days: 30, tzOffsetMinutes: 420),
        throwsStateError,
      );
    },
  );

  test(
    'dashboard updates on SQLite writes and clears immediately at logout',
    () async {
      final auth = AuthProvider(
        _Auth(),
        initialProfile: const UserProfile(
          userId: 'doctor',
          tenantId: 'tenant',
          displayName: 'Synthetic doctor',
          email: 'doctor@example.invalid',
          role: 'doctor',
        ),
      );
      final provider = DashboardProvider(repo, session: auth);
      addTearDown(provider.dispose);
      addTearDown(auth.dispose);
      Future<void> until(bool Function() ready) async {
        for (var i = 0; i < 200 && !ready(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(ready(), isTrue);
      }

      await until(() => provider.snapshot != null);
      expect(provider.isOffline, isTrue);
      await row('new-offline');
      await until(
        () => provider.metrics.length == 4 && provider.metrics[1].value == '1',
      );
      await auth.logout();
      expect(provider.snapshot, isNull);
      expect(provider.metrics, isEmpty);
      await row('late-write');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(provider.snapshot, isNull);
    },
  );
}
