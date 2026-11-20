import 'package:myapp/data/secure/device_identity_store.dart';
import 'package:myapp/domain/models/user_profile.dart';

/// Thrown when a clinician attempts to log in but no active verified model is
/// present on the device.
class NoActiveModelException implements Exception {
  const NoActiveModelException();

  @override
  String toString() =>
      'NoActiveModelException: Active AI model is required for clinician login.';
}

/// Contract for authentication. Mock now, HTTP (JWT) in a later phase.
abstract class AuthRepository {
  Future<UserProfile> login({required String email, required String password});

  Future<void> logout();
}

abstract interface class PasswordChangeRepository {
  Future<UserProfile> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

abstract interface class PersistentDoctorAuthRepository {
  Future<UserProfile?> restoreDoctorSession({DeviceIdentity? knownDevice});
}

abstract interface class ReceivedCacheHydratingRepository {
  Future<void> hydrateReceivedCache();
}

abstract interface class ModelGatedAuthRepository {
  bool get enforcesActiveModelOnLogin;
}
