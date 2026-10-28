import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/state/institution_provider.dart';

UserProfile actor(String tenant, String role) => UserProfile(
  userId: '$tenant-$role',
  tenantId: tenant,
  displayName: 'Synthetic user',
  email: 'synthetic@example.invalid',
  role: role,
);

void main() {
  test('institution data never falls back to demo in HTTP mode', () {
    final store = InstitutionProvider();
    addTearDown(store.dispose);
    final technician = actor('sardjito', 'technician');
    expect(store.available, !AppConfig.useHttp);
    if (AppConfig.useHttp) {
      expect(() => store.read(technician), throwsStateError);
      expect(
        () => store.saveUser(
          technician,
          name: 'Synthetic doctor',
          email: 'doctor@example.invalid',
          role: 'doctor',
        ),
        throwsStateError,
      );
    } else {
      expect(store.read(technician).users, isEmpty);
    }
  });

  test('demo technician changes stay in their institution', () {
    final store = InstitutionProvider();
    addTearDown(store.dispose);
    final first = actor('sardjito', 'technician');
    final second = actor('papua', 'technician');
    if (AppConfig.useHttp) {
      expect(() => store.read(first), throwsStateError);
      expect(() => store.read(second), throwsStateError);
      return;
    }
    store.saveUser(
      first,
      name: 'Synthetic doctor',
      email: 'doctor@example.invalid',
      role: 'doctor',
    );
    final id = store.read(first).users.single.id;
    expect(store.read(second).users, isEmpty);
    expect(() => store.deleteUser(second, id), throwsStateError);
    store.resetPassword(first, id);
    expect(store.read(first).users.single.resetRequested, isTrue);
    store.deleteModel(first, 'TBScreen demo v1');
    expect(store.read(first).models, isEmpty);
    expect(store.read(second).models, isNotEmpty);
    store.deleteUser(first, id);
    expect(store.read(first).users, isEmpty);
  });

  test(
    'doctor, deferred management and unknown roles cannot read workspace',
    () {
      final store = InstitutionProvider();
      addTearDown(store.dispose);
      for (final role in ['doctor', 'management', 'admin', 'unknown']) {
        final user = actor('sardjito', role);
        expect(() => store.read(user), throwsStateError);
        expect(
          () => store.deleteModel(user, 'TBScreen demo v1'),
          throwsStateError,
        );
      }
    },
  );
}
