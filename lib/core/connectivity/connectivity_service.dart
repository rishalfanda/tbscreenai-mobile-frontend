import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether this device currently has network connectivity, for the Sync
/// Center's connection chip.
///
/// A thin wrapper around `connectivity_plus` (the one dependency that reports
/// network status across every platform this app targets, including web via
/// `navigator.onLine` — `dart:io`'s `InternetAddress.lookup` doesn't compile
/// there). Every plugin call is guarded: a missing platform channel (e.g. in
/// a widget test, which registers no real connectivity channel) fails open to
/// "online" rather than throwing, so this never breaks a test that doesn't
/// care about connectivity.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

  /// One-shot check of the current connectivity state.
  Future<bool> checkNow() async {
    try {
      return _isOnline(await _connectivity.checkConnectivity());
    } catch (_) {
      return true;
    }
  }

  /// Fires whenever the device's connectivity changes.
  Stream<bool> get onStatusChange {
    try {
      return _connectivity.onConnectivityChanged
          .map(_isOnline)
          .handleError((Object _) {});
    } catch (_) {
      return const Stream<bool>.empty();
    }
  }
}
