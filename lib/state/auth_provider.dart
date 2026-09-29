import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';

enum AuthStatus { loggedOut, authenticating, authenticated, loggingOut }

/// Single source of truth for the active user and session lifecycle.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authRepository, {UserProfile? initialProfile})
    : _profile = initialProfile,
      _status = initialProfile == null
          ? AuthStatus.loggedOut
          : AuthStatus.authenticated;

  final AuthRepository _authRepository;

  UserProfile? _profile;
  AuthStatus _status;
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _logoutInProgress;

  bool get isLoggedIn => _status == AuthStatus.authenticated;
  bool get isBusy =>
      _status == AuthStatus.authenticating || _status == AuthStatus.loggingOut;
  AuthStatus get status => _status;
  UserProfile? get profile => _profile;
  String get userId => _profile?.userId ?? '';
  String get tenantId => _profile?.tenantId ?? '';
  String get role => _profile?.role ?? '';
  String get email => _profile?.email ?? '';
  String get displayName => _profile?.displayName ?? '';

  /// A new login waits for cleanup; a logout invalidates any pending login.
  Future<void> login({required String email, String password = ''}) async {
    final generation = ++_generation;
    _profile = null;
    _status = AuthStatus.authenticating;
    _notifyIfAlive();
    await _logoutInProgress;
    _ensureCurrent(generation);

    try {
      final profile = await _authRepository.login(
        email: email,
        password: password,
      );
      _ensureCurrent(generation);
      _profile = profile;
      _status = AuthStatus.authenticated;
      _notifyIfAlive();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _profile = null;
        _status = AuthStatus.loggedOut;
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Locks the router immediately; any later login waits for cleanup to finish.
  Future<void> logout() {
    final running = _logoutInProgress;
    if (running != null) return running;

    _generation++;
    _status = AuthStatus.loggingOut;
    _notifyIfAlive();
    final cleanup = Future<void>.sync(_authRepository.logout);
    final completion = Completer<void>();
    final tracked = completion.future;
    _logoutInProgress = tracked;

    void finish() {
      if (identical(_logoutInProgress, tracked)) _logoutInProgress = null;
      _profile = null;
      _status = AuthStatus.loggedOut;
      _notifyIfAlive();
    }

    unawaited(
      cleanup.then<void>(
        (_) {
          finish();
          completion.complete();
        },
        onError: (Object error, StackTrace stack) {
          finish();
          completion.completeError(error, stack);
        },
      ),
    );
    return tracked;
  }

  Future<void> expireSession() => logout();

  void _ensureCurrent(int generation) {
    if (_disposed || generation != _generation) {
      throw StateError('Session changed');
    }
  }

  void _notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
