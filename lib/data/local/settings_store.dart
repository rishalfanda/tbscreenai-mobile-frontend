import 'dart:convert';
import 'package:myapp/data/local/app_database.dart';

/// Device-local facts that must survive an app restart: JWT tokens, the
/// installed AI model version, and the last successful sync time.
///
/// Closes two FASE 3 gaps: tokens were in memory only (reload = login again)
/// and the installed model version was hardcoded to v1.2.0.
class SettingsStore {
  SettingsStore(this._db);

  final AppDatabase _db;

  // === Section: Session ===

  Future<String?> readAccessToken() => _db.getSetting(kAccessToken);
  Future<String?> readRefreshToken() => _db.getSetting(kRefreshToken);

  /// Only restore the cached owner's unexpired session. This is a local
  /// consistency check; the server remains responsible for JWT verification.
  Future<String?> readRestorableAccessToken() async {
    final token = await readAccessToken();
    final owner = await _db.getSetting('session_owner');
    if (token == null || owner == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final claims =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      if (claims['sub'] is! String || claims['exp'] is! num) return null;
      if ('${claims['tenant_id'] ?? ''}:${claims['sub']}' != owner) return null;
      if ((claims['exp'] as num) <=
          DateTime.now().millisecondsSinceEpoch / 1000) {
        return null;
      }
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    String? displayName,
    String? email,
  }) async {
    final generation = _db.sessionGeneration;
    await _db.writeForSession(generation, () async {
      await _db.putSetting(kAccessToken, accessToken);
      await _db.putSetting(kRefreshToken, refreshToken);
      if (displayName != null) {
        await _db.putSetting(kUserDisplayName, displayName);
      }
      if (email != null) await _db.putSetting(kUserEmail, email);
    });
  }

  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final generation = _db.sessionGeneration;
    await _db.writeForSession(generation, () async {
      await _db.putSetting(kAccessToken, accessToken);
      await _db.putSetting(kRefreshToken, refreshToken);
    });
  }

  Future<String?> readDisplayName() => _db.getSetting(kUserDisplayName);
  Future<String?> readEmail() => _db.getSetting(kUserEmail);

  // === Section: AI model ===

  /// Defaults to v1.2.0 — the version shipped with the app image.
  Future<String> readInstalledModelVersion() async =>
      await _db.getSetting(kInstalledModelVersion) ?? 'v1.2.0';

  Future<void> saveInstalledModelVersion(String version) =>
      _db.putSetting(kInstalledModelVersion, version);

  // === Section: Sync ===

  Future<DateTime?> readLastSyncAt() async {
    final raw = await _db.getSetting(kLastSyncAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveLastSyncAt(DateTime at) =>
      _db.putSetting(kLastSyncAt, at.toIso8601String());
}
