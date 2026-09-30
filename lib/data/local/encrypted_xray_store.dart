import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/domain/models/xray_image.dart';

class EncryptedXrayStore {
  EncryptedXrayStore({
    required AppDatabase db,
    required SecureTokenStorage secureStorage,
    AesGcm? algorithm,
  }) : _db = db,
       _secureStorage = secureStorage,
       _algorithm = algorithm ?? AesGcm.with256bits();

  static const _keyName = 'clinical_xray_aes_key_v1';
  static const _referencePrefix = 'local-encrypted://';

  final AppDatabase _db;
  final SecureTokenStorage _secureStorage;
  final AesGcm _algorithm;

  Future<String> persist({
    required String artifactId,
    required XrayImage image,
  }) async {
    final secretKey = await _readOrCreateKey();
    final box = await _algorithm.encrypt(image.bytes, secretKey: secretKey);
    await _db.upsertEncryptedArtifact(
      EncryptedXrayArtifactsCompanion.insert(
        id: artifactId,
        cipherText: Uint8List.fromList(box.cipherText),
        nonce: Uint8List.fromList(box.nonce),
        mac: Uint8List.fromList(box.mac.bytes),
        filename: image.filename,
        mimeType: image.mimeType,
        source: image.source.name,
        checksum: image.checksumSha256,
        sizeBytes: image.sizeBytes,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return '$_referencePrefix$artifactId';
  }

  Future<XrayImage> read(String reference) async {
    if (!reference.startsWith(_referencePrefix)) {
      throw const FormatException('Unsupported X-ray artifact reference.');
    }
    final artifactId = reference.substring(_referencePrefix.length);
    if (artifactId.isEmpty) {
      throw const FormatException('X-ray artifact reference is empty.');
    }
    final row = await _db.findEncryptedArtifact(artifactId);
    if (row == null) {
      throw StateError('Encrypted X-ray artifact is missing.');
    }
    final clearBytes = await _algorithm.decrypt(
      SecretBox(row.cipherText, nonce: row.nonce, mac: Mac(row.mac)),
      secretKey: await _readExistingKey(),
    );
    final source = XrayImageSource.values.where(
      (candidate) => candidate.name == row.source,
    );
    final image = XrayImage.fromBytes(
      bytes: Uint8List.fromList(clearBytes),
      filename: row.filename,
      source: source.isEmpty ? XrayImageSource.gallery : source.first,
    );
    if (image.checksumSha256 != row.checksum ||
        image.sizeBytes != row.sizeBytes ||
        image.mimeType != row.mimeType) {
      throw StateError('Stored X-ray integrity check failed.');
    }
    return image;
  }

  Future<SecretKey> _readOrCreateKey() async {
    final encoded = await _secureStorage.read(_keyName);
    if (encoded != null) return _decodeKey(encoded);
    final key = await _algorithm.newSecretKey();
    final bytes = await key.extractBytes();
    await _secureStorage.write(_keyName, base64Encode(bytes));
    return SecretKey(bytes);
  }

  Future<SecretKey> _readExistingKey() async {
    final encoded = await _secureStorage.read(_keyName);
    if (encoded == null) {
      throw StateError('X-ray encryption key is unavailable.');
    }
    return _decodeKey(encoded);
  }

  SecretKey _decodeKey(String encoded) {
    late final List<int> bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      throw StateError('X-ray encryption key is corrupted.');
    }
    if (bytes.length != 32) {
      throw StateError('X-ray encryption key has an invalid length.');
    }
    return SecretKey(bytes);
  }
}
