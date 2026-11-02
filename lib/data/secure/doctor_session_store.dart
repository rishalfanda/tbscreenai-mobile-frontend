import 'dart:convert';
import 'package:myapp/domain/models/user_profile.dart';
import 'secure_token_storage.dart';

/// Product-approved persistent local doctor session. Server token lifetimes
/// and authorization remain controlled by the backend.
class DoctorSessionStore {
  DoctorSessionStore(this.storage);
  final SecureTokenStorage storage;
  static const key = 'doctor_offline_session_v1';
  int _generation = 0;
  Future<void>? _tail;
  Future<void> _serialize(Future<void> Function() action) {
    final previous = _tail;
    final next = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          /* The previous caller receives its own error. */
        }
      }
      await action();
    }();
    _tail = next;
    return next.whenComplete(() {
      if (identical(_tail, next)) _tail = null;
    });
  }

  Future<void> save(
    UserProfile profile,
    String deviceId,
    String apiBase,
  ) async {
    if (profile.role != 'doctor' || profile.mustChangePassword) {
      await clear();
      return;
    }
    final generation = _generation;
    await _serialize(() async {
      if (generation != _generation) return;
      await storage.write(
        key,
        jsonEncode({
          'user_id': profile.userId,
          'tenant_id': profile.tenantId,
          'name': profile.displayName,
          'email': profile.email,
          'role': profile.role,
          'device_id': deviceId,
          'api_base': apiBase,
        }),
      );
    });
  }

  Future<UserProfile?> read(String deviceId, String apiBase) async {
    final raw = await storage.read(key);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['role'] != 'doctor' ||
        data['device_id'] != deviceId ||
        data['api_base'] != apiBase ||
        [
          'user_id',
          'tenant_id',
          'name',
          'email',
        ].any((k) => data[k] is! String || (data[k] as String).isEmpty)) {
      return null;
    }
    return UserProfile(
      userId: data['user_id'] as String,
      tenantId: data['tenant_id'] as String,
      displayName: data['name'] as String,
      email: data['email'] as String,
      role: 'doctor',
    );
  }

  Future<void> clear() {
    _generation++;
    return _serialize(() => storage.delete(key));
  }
}
