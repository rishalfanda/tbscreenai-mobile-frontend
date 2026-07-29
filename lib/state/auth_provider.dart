import 'package:flutter/foundation.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authRepository, {bool initiallyLoggedIn = false})
      : _isLoggedIn = initiallyLoggedIn;

  final AuthRepository _authRepository;

  bool _isLoggedIn;
  String _displayName = 'Dr. Maya Rizki';

  bool get isLoggedIn => _isLoggedIn;
  String get displayName => _displayName;

  /// Uses .then instead of await so a synchronous repository (mock) completes
  /// before this method returns — the login screen navigates right after
  /// calling login(), exactly like the pre-refactor synchronous flow.
  Future<void> login({required String email, String password = ''}) {
    return _authRepository.login(email: email, password: password).then((profile) {
      _displayName = profile.displayName;
      _isLoggedIn = true;
      notifyListeners();
    });
  }

  Future<void> logout() {
    return _authRepository.logout().then((_) {
      _isLoggedIn = false;
      notifyListeners();
    });
  }
}
