import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether this device currently has network connectivity, for the Sync
/// Center's connection chip.
///
/// A thin wrapper around `connectivity_plus` (the one dependency that reports
/// network status across every platform this app targets, including web via
/// `navigator.onLine` — `dart:io`'s `InternetAddress.lookup` doesn't compile
/// there). A missing platform channel is treated as unavailable/offline;
/// the status widget starts the event stream only after a successful check.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  bool _available = true;

  bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

  /// One-shot check of the current connectivity state.
  Future<bool> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _available = true;
      return _isOnline(results);
    } catch (_) {
      _available = false;
      return false;
    }
  }

  /// Fires whenever the device's connectivity changes.
  Stream<bool> get onStatusChange {
    if (!_available) return const Stream<bool>.empty();
    try {
      return _connectivity.onConnectivityChanged
          .map(_isOnline)
          .handleError((Object _) {});
    } catch (_) {
      return const Stream<bool>.empty();
    }
  }
}
