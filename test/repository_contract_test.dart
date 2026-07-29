// Contract tests for the mock repositories. These lock the behaviour every
// implementation must honour, so an Http*/Offline* variant can be checked
// against the same expectations later.

import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';
import 'package:myapp/domain/repositories/dataset_repository.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';
import 'package:myapp/domain/repositories/patient_repository.dart';
import 'package:myapp/domain/repositories/sync_repository.dart';
import 'package:myapp/domain/repositories/validation_repository.dart';

void main() {
  group('PatientRepository contract', () {
    final PatientRepository repo = MockPatientRepository();

    test('returns a non-empty, well-formed list', () async {
      final patients = await repo.getPatients();

      expect(patients, isNotEmpty);
      for (final p in patients) {
        expect(p.id, isNotEmpty);
        expect(p.name, isNotEmpty);
        expect(p.age, greaterThanOrEqualTo(0));
      }
    });

    test('patient ids are unique', () async {
      final patients = await repo.getPatients();
      final ids = patients.map((p) => p.id).toSet();

      expect(ids.length, patients.length);
    });
  });

  group('AuthRepository contract', () {
    final AuthRepository repo = MockAuthRepository();

    test('login derives a display name and echoes the email', () async {
      final profile = await repo.login(email: 'maya.rizki@rs.co.id', password: 'x');

      expect(profile.email, 'maya.rizki@rs.co.id');
      expect(profile.displayName, isNotEmpty);
      expect(profile.role, 'doctor');
    });

    test('logout completes without throwing', () async {
      await expectLater(repo.logout(), completes);
    });
  });

  group('DiagnosisRepository contract', () {
    final DiagnosisRepository repo = MockDiagnosisRepository();

    test('symptom options are provided', () async {
      expect(await repo.getSymptomOptions(), isNotEmpty);
    });

    test('inference returns an in-range, self-consistent outcome', () async {
      final outcome = await repo.runInference(image: XrayImage.placeholder());

      expect(outcome.confidence, inInclusiveRange(0, 100));
      expect(outcome.processingTime, isNotEmpty);
      expect(outcome.modelVersion, isNotEmpty);
      // A negative result must not carry a cavity finding.
      if (!outcome.isPositive) {
        expect(outcome.cavity, 0.0);
      }
    });
  });

  group('ValidationRepository contract', () {
    final ValidationRepository repo = MockValidationRepository();

    test('cases expose only the three known statuses', () async {
      final cases = await repo.getCases();

      expect(cases, isNotEmpty);
      for (final c in cases) {
        expect(['pending', 'agreed', 'disagreed'], contains(c.status));
      }
    });

    test('submitValidation completes', () async {
      final cases = await repo.getCases();
      await expectLater(
        repo.submitValidation(id: cases.first.id, status: 'agreed', note: 'ok'),
        completes,
      );
    });
  });

  group('DatasetRepository contract', () {
    final DatasetRepository repo = MockDatasetRepository();

    test('datasets and records are provided', () async {
      expect(await repo.getDatasets(), isNotEmpty);
      expect(await repo.getRecords(), isNotEmpty);
    });

    test('dataset status is ACTIVE or ARCHIVED', () async {
      for (final d in await repo.getDatasets()) {
        expect(['ACTIVE', 'ARCHIVED'], contains(d.status));
      }
    });
  });

  group('SyncRepository contract', () {
    final SyncRepository repo = MockSyncRepository();

    test('installed version and update info are consistent', () async {
      final installed = await repo.getInstalledModelVersion();
      final info = await repo.checkForUpdate();

      expect(installed, isNotEmpty);
      expect(info.currentVersion, installed);
      expect(info.latestVersion, isNotEmpty);
    });

    test('downloadModel progress is monotonic and ends at 1.0', () async {
      final progress = await repo.downloadModel().toList();

      expect(progress, isNotEmpty);
      expect(progress.last, closeTo(1.0, 0.0001));
      for (var i = 1; i < progress.length; i++) {
        expect(progress[i], greaterThanOrEqualTo(progress[i - 1]));
      }
    });

    test('uploadPatients emits an increasing count up to the total', () async {
      final counts = await repo.uploadPatients(['a', 'b', 'c']).toList();

      expect(counts, [1, 2, 3]);
    });

    test('summary counts are non-negative', () async {
      final summary = await repo.getSyncSummary();

      expect(summary.totalPatients, greaterThanOrEqualTo(0));
      expect(summary.totalDiagnoses, greaterThanOrEqualTo(0));
    });
  });
}
