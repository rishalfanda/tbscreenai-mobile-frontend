import 'package:myapp/domain/models/user_profile.dart';

/// Contract for authentication. Mock now, HTTP (JWT) in a later phase.
abstract class AuthRepository {
  Future<UserProfile> login({required String email, required String password});

  Future<void> logout();
}
