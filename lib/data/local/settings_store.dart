import 'package:myapp/core/utils/uuid.dart';
import 'package:myapp/data/local/app_database.dart';

/// Non-secret, device-local settings.
///
/// Session tokens deliberately do not pass through this class. They live in
/// secure platform storage, outside ordinary SQLite. Account identity remains
/// here only to scope encrypted tokens and cached clinical rows.
class SettingsStore {
  SettingsStore(this._db);

  final AppDatabase _db;

  Future<String?> readSessionOwner() => _db.getSetting(kSessionOwner);

  Future<void> saveIdentity({
    required String userId,
    required String tenantId,
    required String role,
    required String displayName,
    required String email,
  }) async {
    await _db.putSetting(kSessionOwner, '$tenantId:$userId');
    await _db.putSetting(kUserId, userId);
    await _db.putSetting(kTenantId, tenantId);
    await _db.putSetting(kUserRole, role);
    await _db.putSetting(kUserDisplayName, displayName);
    await _db.putSetting(kUserEmail, email);
  }

  Future<void> clearIdentity() async {
    for (final key in [
      kSessionOwner,
      kUserId,
      kTenantId,
      kUserRole,
      kUserDisplayName,
      kUserEmail,
    ]) {
      await _db.deleteSetting(key);
    }
  }

  Future<String?> readDisplayName() => _db.getSetting(kUserDisplayName);
  Future<String?> readEmail() => _db.getSetting(kUserEmail);
  Future<String?> readUserId() => _db.getSetting(kUserId);
  Future<String?> readTenantId() => _db.getSetting(kTenantId);
  Future<String?> readRole() => _db.getSetting(kUserRole);

  Future<String> readOrCreateDeviceId() async {
    final existing = await _db.getSetting(kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = uuidV4();
    await _db.putSetting(kDeviceId, created);
    return created;
  }

  /// `null` means no model bundle is installed on this device yet — the app
  /// ships without one.
  Future<String?> readInstalledModelVersion() =>
      _db.getSetting(kInstalledModelVersion);

  Future<void> saveInstalledModelVersion(String version) =>
      _db.putSetting(kInstalledModelVersion, version);

  /// The last `/models/check` response, cached as JSON so the Sync Center can
  /// restore its Model Update card without re-querying the server on every
  /// open. `null` if no check has ever completed on this device.
  Future<String?> readLastModelCheckJson() =>
      _db.getSetting(kLastModelCheck);

  Future<void> saveLastModelCheckJson(String json) =>
      _db.putSetting(kLastModelCheck, json);

  // === Section: Sync ===

  Future<DateTime?> readLastSyncAt() async {
    final raw = await _db.getSetting(kLastSyncAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveLastSyncAt(DateTime at) =>
      _db.putSetting(kLastSyncAt, at.toUtc().toIso8601String());
}
