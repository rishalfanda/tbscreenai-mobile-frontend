import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:myapp/core/localization/app_language.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/http/http_auth_repository.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/encrypted_xray_store.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/offline/device_operator_outbox.dart';
import 'package:myapp/data/secure/device_identity_store.dart';
import 'package:myapp/data/secure/doctor_session_store.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/features/auth/presentation/auth_frame.dart';
import 'package:myapp/features/auth/presentation/startup_recovery_screen.dart';

void main() {
  test(
    'B3: DeviceIdentityStore rejects corrupted registration and clearRegistration preserves clinical keys and SQLite archives',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final store = DeviceIdentityStore(secure);
      addTearDown(db.close);

      await secure.write('device_operator_outbox_aes_v1', 'outbox-key-b64');
      await secure.write('tbscreen_xray_aes_key_v1', 'xray-key-b64');
      await db.upsertPatient(
        LocalPatientsCompanion.insert(
          id: 'pat-1',
          code: 'P001',
          name: 'Saved Patient',
          age: 35,
          gender: 'Female',
        ),
      );

      await secure.write('registered_tablet_identity_v1', '{not-valid-json');
      await expectLater(store.read(), throwsFormatException);

      await secure.write(
        'registered_tablet_identity_v1',
        jsonEncode({'device_id': 'dev-1'}),
      );
      await expectLater(store.read(), throwsFormatException);

      await store.activationNonce();
      await store.clearRegistration();

      expect(await secure.read('registered_tablet_identity_v1'), isNull);
      expect(await secure.read('tablet_activation_nonce_v1'), isNull);
      expect(await secure.read('device_operator_outbox_aes_v1'), 'outbox-key-b64');
      expect(await secure.read('tbscreen_xray_aes_key_v1'), 'xray-key-b64');
      expect(await db.countPatients(), 1);
      // Keep EncryptedXrayStore reference verified as unimpacted symbol.
      expect(EncryptedXrayStore(db: db, secureStorage: secure), isNotNull);
      expect(DeviceOperatorOutbox(db, secure), isNotNull);
    },
  );

  test(
    'B3: HttpAuthRepository.restoreDoctorSession fails closed with null on corrupted device identity',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final secure = MemorySecureTokenStorage();
      final settings = SettingsStore(db);
      final client = ApiClient(
        baseUrl: 'https://synthetic.invalid/api/v1',
        settings: settings,
        secureStorage: secure,
      );
      addTearDown(() async {
        await client.close();
        await db.close();
      });

      await secure.write('registered_tablet_identity_v1', 'corrupted');
      final repo = HttpAuthRepository(
        client,
        settings: settings,
        db: db,
        doctorSession: DoctorSessionStore(secure),
      );

      expect(await repo.restoreDoctorSession(), isNull);
      expect(client.tokens.hasSession, isFalse);
    },
  );

  testWidgets(
    'B3: StartupRecoveryScreen handles corrupted identity reset confirmation, localization, and retry',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var retries = 0;
      var resets = 0;
      final language = AppLanguage();
      addTearDown(language.dispose);

      Widget harness({
        required StartupErrorKind kind,
        bool busy = false,
        String? recoveryError,
      }) => ChangeNotifierProvider.value(
        value: language,
        child: MaterialApp(
          home: StartupRecoveryScreen(
            errorKind: kind,
            busy: busy,
            recoveryError: recoveryError,
            onRetry: () => retries++,
            onResetActivation: () => resets++,
          ),
        ),
      );

      await tester.pumpWidget(harness(kind: StartupErrorKind.corruptedIdentity));
      expect(find.text('Tablet activation data corrupted'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(
          find.byKey(const Key('startup-reset-activation-button')),
        ),
        isNotNull,
      );

      // Language toggle updates recovery copy live.
      language.select('id');
      await tester.pump();
      expect(find.text('Data aktivasi tablet rusak'), findsOneWidget);

      language.select('en');
      await tester.pump();

      // Cancelling confirmation dialog leaves registration untouched.
      await tester.tap(find.byKey(const Key('startup-reset-activation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(resets, 0);

      // Confirming reset invokes recovery callback.
      await tester.tap(find.byKey(const Key('startup-reset-activation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('startup-confirm-reset-button')));
      await tester.pumpAndSettle();
      expect(resets, 1);

      // Transient storage unavailability prioritizes Retry and surfaces reset errors.
      await tester.pumpWidget(
        harness(
          kind: StartupErrorKind.storageUnavailable,
          recoveryError: 'reset_failed',
        ),
      );
      expect(find.text('Device storage unavailable'), findsOneWidget);
      expect(find.byType(AuthErrorBanner), findsOneWidget);
      await tester.tap(find.byKey(const Key('startup-retry-button')));
      expect(retries, 1);

      // Busy disables actions and shows progress spinner.
      await tester.pumpWidget(
        harness(kind: StartupErrorKind.corruptedIdentity, busy: true),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final resetWidget = tester.widget<FilledButton>(
        find.byKey(const Key('startup-reset-activation-button')),
      );
      expect(resetWidget.onPressed, isNull);
    },
  );
}
