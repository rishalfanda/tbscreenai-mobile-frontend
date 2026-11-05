import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:myapp/data/http/backend_refusal.dart';

import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';

enum AuthStatus { loggedOut, authenticating, authenticated, loggingOut }

/// Thrown when a clinician attempts to log in but no active verified model is
/// present on the device.
class NoActiveModelException implements Exception {
  const NoActiveModelException();

  @override
  String toString() =>
      'NoActiveModelException: Active AI model is required for clinician login.';
}

/// Single source of truth for the active user and session lifecycle.
class AuthProvider extends ChangeNotifier {
  AuthProvider(
    this._authRepository, {
    UserProfile? initialProfile,
    Future<bool> Function()? hasActiveModel,
    Future<void> Function()? onSessionEnded,
  }) : _profile = initialProfile,
       _hasActiveModel = hasActiveModel,
       _onSessionEnded = onSessionEnded,
       _status = initialProfile == null
           ? AuthStatus.loggedOut
           : AuthStatus.authenticated;

  final AuthRepository _authRepository;
  final Future<bool> Function()? _hasActiveModel;
  final Future<void> Function()? _onSessionEnded;

  UserProfile? _profile;
  AuthStatus _status;
  int _generation = 0;
  bool _disposed = false;
  Future<void>? _logoutInProgress;
  String? sessionRefusalCode;

  bool get isLoggedIn => _status == AuthStatus.authenticated;
  bool get isBusy =>
      _status == AuthStatus.authenticating || _status == AuthStatus.loggingOut;
  AuthStatus get status => _status;
  UserProfile? get profile => _profile;
  String get userId => _profile?.userId ?? '';
  String get tenantId => _profile?.tenantId ?? '';
  String get role => _profile?.role ?? '';
  MobileRole get mobileRole => _profile?.mobileRole ?? MobileRole.unsupported;
  String get email => _profile?.email ?? '';
  String get displayName => _profile?.displayName ?? '';
  bool get mustChangePassword => _profile?.mustChangePassword ?? false;

  bool _deviceActivated = true;
  bool get deviceActivated => _deviceActivated;
  void setDeviceActivated(bool value) {
    _deviceActivated = value;
    if (value) sessionRefusalCode = null;
    _notifyIfAlive();
  }

  Future<void> restoreSession() async {
    final repo = _authRepository;
    if (repo is! PersistentDoctorAuthRepository) return;
    final generation = ++_generation;
    final profile = await (repo as PersistentDoctorAuthRepository)
        .restoreDoctorSession();
    _ensureCurrent(generation);
    if (profile != null && _hasActiveModel != null) {
      final hasModel = await _hasActiveModel();
      _ensureCurrent(generation);
      if (!hasModel) {
        await _authRepository.logout();
        _ensureCurrent(generation);
        _profile = null;
        _status = AuthStatus.loggedOut;
        sessionRefusalCode = 'no_active_model';
        _notifyIfAlive();
        return;
      }
    }
    _profile = profile;
    _status = profile == null ? AuthStatus.loggedOut : AuthStatus.authenticated;
    _notifyIfAlive();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final repository = _authRepository;
    if (!isLoggedIn || repository is! PasswordChangeRepository) {
      throw StateError('Password change unavailable');
    }
    final generation = _generation;
    final previous = _profile!;
    final updated = await (repository as PasswordChangeRepository)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
    _ensureCurrent(generation);
    if (updated.userId != previous.userId ||
        updated.tenantId != previous.tenantId ||
        updated.role != previous.role ||
        updated.mustChangePassword) {
      await logout();
      throw StateError('Password change identity mismatch');
    }
    _profile = updated;
    _notifyIfAlive();
  }

  /// A new login waits for cleanup; a logout invalidates any pending login.
  Future<void> login({required String email, String password = ''}) async {
    if (!_deviceActivated) throw StateError('Tablet activation required');
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

      if (profile.mobileRole == MobileRole.clinician &&
          _hasActiveModel != null) {
        final hasModel = await _hasActiveModel();
        _ensureCurrent(generation);
        if (!hasModel) {
          await _authRepository.logout();
          throw const NoActiveModelException();
        }
      }

      _profile = profile;
      sessionRefusalCode = null;
      _status = AuthStatus.authenticated;
      _notifyIfAlive();
    } catch (error) {
      if (!_disposed && generation == _generation) {
        sessionRefusalCode = refusalFromError(error);
        if (requiresTabletActivation(sessionRefusalCode)) {
          _deviceActivated = false;
        }
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
      unawaited(_onSessionEnded?.call());
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

  Future<void> expireSession({String? code}) {
    sessionRefusalCode = code;
    if (requiresTabletActivation(code)) _deviceActivated = false;
    return logout();
  }

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
