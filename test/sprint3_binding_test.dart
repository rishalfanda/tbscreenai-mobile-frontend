import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drift/native.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/mock/mock_repositories.dart';
import 'package:myapp/data/http/http_repositories.dart';
import 'package:myapp/data/offline/offline_patient_repository.dart';
import 'package:myapp/data/offline/offline_sync_repository.dart';
import 'package:myapp/data/offline/offline_validation_repository.dart';
import 'package:myapp/data/models_ota/hybrid_sync_repository.dart';
import 'package:myapp/data/onnx/hybrid_diagnosis_repository.dart';
import 'package:myapp/data/unavailable_repositories.dart';
import 'package:myapp/domain/repositories/repositories.dart';

void main() {
  testWidgets('repository override cannot cross environment boundary', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(
      TBScreenApp(database: db, useHttpOverride: !AppConfig.useHttp),
    );
    expect(tester.takeException(), isA<StateError>());
    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  for (final live in [AppConfig.useHttp]) {
    testWidgets('repository bindings live=$live', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      await tester.pumpWidget(TBScreenApp(database: db, useHttpOverride: live));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(MaterialApp));
      expect(
        context.read<AuthRepository>(),
        live ? isA<HttpAuthRepository>() : isA<MockAuthRepository>(),
      );
      expect(
        context.read<DiagnosisRepository>(),
        isA<HybridDiagnosisRepository>(),
      );
      expect(
        context.read<PatientRepository>(),
        live ? isA<OfflinePatientRepository>() : isA<MockPatientRepository>(),
      );
      expect(
        context.read<SyncRepository>(),
        live ? isA<OfflineSyncRepository>() : isA<HybridSyncRepository>(),
      );
      expect(
        context.read<ValidationRepository>(),
        live
            ? isA<OfflineValidationRepository>()
            : isA<MockValidationRepository>(),
      );
      expect(
        context.read<DashboardRepository>(),
        live
            ? isA<UnavailableDashboardRepository>()
            : isA<MockDashboardRepository>(),
      );
      expect(
        context.read<DatasetRepository>(),
        live
            ? isA<UnavailableDatasetRepository>()
            : isA<MockDatasetRepository>(),
      );
      await tester.pumpWidget(const SizedBox());
      await db.close();
    });
  }
}
