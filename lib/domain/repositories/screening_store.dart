import 'package:myapp/domain/models/screening_result.dart';

abstract interface class ScreeningStore {
  /// Encrypts the X-ray, writes the immutable snapshots, and queues the exact
  /// backend create payload before returning.
  Future<ScreeningResult> persist(ScreeningResult result);

  /// Restores the latest owner-scoped durable result after login/restart.
  Future<ScreeningResult?> restoreLatest();

  Stream<ScreeningSaveStatus> watchSaveStatus(String id);
}
