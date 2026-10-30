import 'dart:convert';
import 'dart:math';
import 'secure_token_storage.dart';

class DeviceIdentity {
  const DeviceIdentity({
    required this.id,
    required this.credential,
    required this.tenantId,
    required this.label,
  });
  final String id, credential, tenantId, label;
  Map<String, String> get headers => {
    'X-Device-Id': id,
    'X-Device-Credential': credential,
  };
}

/// Registration survives logout; credentials never enter SQLite or UI output.
class DeviceIdentityStore {
  DeviceIdentityStore(this.storage);
  final SecureTokenStorage storage;
  static const _identityKey = 'registered_tablet_identity_v1';
  static const _nonceKey = 'tablet_activation_nonce_v1';
  Future<DeviceIdentity?> read() async {
    final raw = await storage.read(_identityKey);
    if (raw == null) return null;
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['device_id'] is! String ||
        data['credential'] is! String ||
        data['tenant_id'] is! String ||
        data['label'] is! String ||
        (data['credential'] as String).isEmpty) {
      throw const FormatException('Invalid device identity');
    }
    return DeviceIdentity(
      id: data['device_id'] as String,
      credential: data['credential'] as String,
      tenantId: data['tenant_id'] as String,
      label: data['label'] as String,
    );
  }

  Future<String> activationNonce() async {
    final existing = await storage.read(_nonceKey);
    if (existing != null) return existing;
    final nonce = base64UrlEncode(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    ).replaceAll('=', '');
    await storage.write(_nonceKey, nonce);
    return nonce;
  }

  Future<void> saveActivation(Object? raw) async {
    if (raw is! Map<String, dynamic> ||
        raw['status'] != 'active' ||
        raw['device_id'] is! String ||
        raw['tenant_id'] is! String ||
        raw['credential'] is! String ||
        (raw['credential'] as String).isEmpty ||
        raw['label'] is! String) {
      throw const FormatException('Invalid tablet activation response');
    }
    if (await read() != null) throw StateError('Tablet already activated');
    await storage.write(
      _identityKey,
      jsonEncode({
        'device_id': raw['device_id'],
        'tenant_id': raw['tenant_id'],
        'credential': raw['credential'],
        'label': raw['label'],
      }),
    );
    await storage.delete(_nonceKey);
  }
}
