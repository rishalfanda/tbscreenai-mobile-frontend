import 'package:flutter/foundation.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';

/// Mock auth — accepts any credentials, derives the display name from the
/// email (same behavior as the old AuthProvider). SynchronousFuture keeps the
/// login flow synchronous so the router redirect works exactly as before.
class MockAuthRepository implements AuthRepository {
  @override
  Future<UserProfile> login({required String email, required String password}) {
    final displayName = email.split('@').first.replaceAll('.', ' ');
    return SynchronousFuture(UserProfile(displayName: displayName, email: email));
  }

  @override
  Future<void> logout() => SynchronousFuture(null);
}
