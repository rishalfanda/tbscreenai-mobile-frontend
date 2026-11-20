import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:myapp/data/http/backend_refusal.dart';
import 'package:myapp/data/secure/device_identity_store.dart';

import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/domain/models/user_profile.dart';
import 'package:myapp/domain/repositories/auth_repository.dart';

export 'package:myapp/domain/repositories/auth_repository.dart'
    show NoActiveModelException;

enum AuthStatus { loggedOut, authenticating, authenticated, loggingOut }

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
  bool _isHydratingReceivedCache = false;
  int _receivedCacheRevision = 0;
  String? sessionRefusalCode;

  bool get isLoggedIn => _status == AuthStatus.authenticated;
  bool get isBusy =>
      _status == AuthStatus.authenticating || _status == AuthStatus.loggingOut;
  bool get isHydratingReceivedCache => _isHydratingReceivedCache;
  int get receivedCacheRevision => _receivedCacheRevision;
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

  void clearSessionRefusal() {
    if (sessionRefusalCode == null) return;
    sessionRefusalCode = null;
    _notifyIfAlive();
  }

  Future<void> restoreSession({DeviceIdentity? knownDevice}) async {
    final repo = _authRepository;
    if (repo is! PersistentDoctorAuthRepository) return;
    final generation = ++_generation;
    final profile = await (repo as PersistentDoctorAuthRepository)
        .restoreDoctorSession(knownDevice: knownDevice);
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
    _isHydratingReceivedCache = false;
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
    _isHydratingReceivedCache = _canHydrateReceivedCache;
    _notifyIfAlive();
    _scheduleReceivedCacheHydration(generation);
  }

  bool get _canHydrateReceivedCache =>
      isLoggedIn &&
      !mustChangePassword &&
      mobileRole == MobileRole.clinician &&
      _authRepository is ReceivedCacheHydratingRepository;

  void _scheduleReceivedCacheHydration(int generation) {
    unawaited(_hydrateReceivedCacheIfEligible(generation));
  }

  /// A new login waits for cleanup; a logout invalidates any pending login.
  Future<void> login({required String email, String password = ''}) async {
    if (!_deviceActivated) throw StateError('Tablet activation required');
    final generation = ++_generation;
    _profile = null;
    _status = AuthStatus.authenticating;
    _isHydratingReceivedCache = false;
    _notifyIfAlive();
    if (_logoutInProgress != null) {
      await _logoutInProgress;
      _ensureCurrent(generation);
    }

    try {
      final profile = await _authRepository.login(
        email: email,
        password: password,
      );
      _ensureCurrent(generation);

      final repo = _authRepository;
      final alreadyGated =
          repo is ModelGatedAuthRepository &&
          (repo as ModelGatedAuthRepository).enforcesActiveModelOnLogin;
      if (!alreadyGated &&
          profile.mobileRole == MobileRole.clinician &&
          _hasActiveModel != null) {
        final hasModel = await _hasActiveModel();
        _ensureCurrent(generation);
        if (!hasModel) {
          await _authRepository.logout();
          await _onSessionEnded?.call();
          throw const NoActiveModelException();
        }
      }

      _profile = profile;
      sessionRefusalCode = null;
      _status = AuthStatus.authenticated;
      _isHydratingReceivedCache = _canHydrateReceivedCache;
      _notifyIfAlive();
      _scheduleReceivedCacheHydration(generation);
    } catch (error) {
      if (!_disposed && generation == _generation) {
        sessionRefusalCode = error is NoActiveModelException
            ? 'no_active_model'
            : refusalFromError(error);
        if (requiresTabletActivation(sessionRefusalCode)) {
          _deviceActivated = false;
        }
        _profile = null;
        _isHydratingReceivedCache = false;
        _status = AuthStatus.loggedOut;
        _notifyIfAlive();
      }
      rethrow;
    }
  }

  Future<void> _hydrateReceivedCacheIfEligible(int generation) async {
    final repo = _authRepository;
    if (_disposed ||
        generation != _generation ||
        !_canHydrateReceivedCache) {
      return;
    }
    _isHydratingReceivedCache = true;
    try {
      await (repo as ReceivedCacheHydratingRepository).hydrateReceivedCache();
    } catch (_) {
      // Stale session switches, rapid logout, or DB teardown are expected to
      // abort background cache hydration safely without escaping the zone.
    } finally {
      if (!_disposed && generation == _generation) {
        _isHydratingReceivedCache = false;
        _receivedCacheRevision++;
        _notifyIfAlive();
      }
    }
  }

  /// Locks the router immediately; any later login waits for cleanup and
  /// session-end hooks to finish.
  Future<void> logout() {
    final running = _logoutInProgress;
    if (running != null) return running;

    _generation++;
    _isHydratingReceivedCache = false;
    _status = AuthStatus.loggingOut;
    _notifyIfAlive();
    final completion = Completer<void>();
    final tracked = completion.future;
    _logoutInProgress = tracked;

    unawaited(() async {
      Object? caughtError;
      StackTrace? caughtStack;
      try {
        await Future<void>.sync(_authRepository.logout);
      } catch (error, stack) {
        caughtError = error;
        caughtStack = stack;
      }
      try {
        await Future<void>.sync(() => _onSessionEnded?.call());
      } catch (error, stack) {
        caughtError ??= error;
        caughtStack ??= stack;
      }

      if (identical(_logoutInProgress, tracked)) _logoutInProgress = null;
      if (caughtError != null) {
        sessionRefusalCode ??= 'logout_cleanup_failed';
      }
      _profile = null;
      _status = AuthStatus.loggedOut;
      _notifyIfAlive();

      if (caughtError != null) {
        completion.completeError(caughtError, caughtStack);
      } else {
        completion.complete();
      }
    }());
    return tracked;
  }

  Future<void> expireSession({String? code}) {
    final running = _logoutInProgress;
    if (running != null) {
      _generation++;
      sessionRefusalCode = code;
      if (requiresTabletActivation(code)) _deviceActivated = false;
      _notifyIfAlive();
      return running;
    }
    if (_status == AuthStatus.authenticating &&
        !requiresTabletActivation(code)) {
      return Future<void>.value();
    }
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
