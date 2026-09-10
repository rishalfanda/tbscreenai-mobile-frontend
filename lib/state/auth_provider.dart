import 'package:flutter/foundation.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authRepository, {bool initiallyLoggedIn = false})
    : _isLoggedIn = initiallyLoggedIn;

  final AuthRepository _authRepository;

  bool _isLoggedIn;
  String _displayName = 'Dr. Maya Rizki';
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _logoutInProgress;

  bool get isLoggedIn => _isLoggedIn;
  String get displayName => _displayName;

  /// A new login waits for cleanup; a logout invalidates any pending login.
  Future<void> login({required String email, String password = ''}) async {
    final generation = ++_generation;
    _isLoggedIn = false;
    _displayName = '';
    if (!_disposed) notifyListeners();
    await _logoutInProgress;
    if (_disposed || generation != _generation) {
      throw StateError('Session changed');
    }
    final profile = await _authRepository.login(
      email: email,
      password: password,
    );
    if (_disposed || generation != _generation) {
      throw StateError('Session changed');
    }
    _displayName = profile.displayName;
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() {
    _generation++;
    _isLoggedIn = false;
    _displayName = '';
    if (!_disposed) notifyListeners();
    if (_logoutInProgress != null) return _logoutInProgress!;
    final cleanup = Future<void>.sync(_authRepository.logout);
    _logoutInProgress = cleanup;
    return cleanup.whenComplete(() {
      if (identical(_logoutInProgress, cleanup)) _logoutInProgress = null;
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
