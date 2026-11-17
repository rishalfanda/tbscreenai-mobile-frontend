import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/domain/models/xray_image.dart';

Future<List<Map<String, dynamic>>> _decryptXrayBatch(
  Map<String, dynamic> input,
) async {
  final secretKey = SecretKey(input['key'] as List<int>);
  final aes = AesGcm.with256bits();
  final rows = input['rows'] as List<Map<String, dynamic>>;
  final out = <Map<String, dynamic>>[];
  for (final row in rows) {
    final clearBytes = await aes.decrypt(
      SecretBox(
        row['cipherText'] as List<int>,
        nonce: row['nonce'] as List<int>,
        mac: Mac(row['mac'] as List<int>),
      ),
      secretKey: secretKey,
    );
    final rawSource = row['source'] as String;
    final sourceMatches = XrayImageSource.values.where(
      (candidate) => candidate.name == rawSource,
    );
    final source = sourceMatches.isEmpty
        ? XrayImageSource.gallery
        : sourceMatches.first;
    final rawBytes = Uint8List.fromList(clearBytes);
    final image = XrayImage.fromBytes(
      bytes: rawBytes,
      filename: row['filename'] as String,
      source: source,
    );
    if (image.checksumSha256 != row['checksum'] ||
        image.sizeBytes != row['sizeBytes'] ||
        image.mimeType != row['mimeType']) {
      throw StateError('Stored X-ray integrity check failed.');
    }
    out.add({
      'id': row['id'],
      'bytes': TransferableTypedData.fromList([rawBytes]),
      'filename': image.filename,
      'mimeType': image.mimeType,
      'formatIndex': image.format.index,
      'sourceIndex': image.source.index,
      'checksum': image.checksumSha256,
    });
  }
  return out;
}

class EncryptedXrayStore {
  EncryptedXrayStore({
    required AppDatabase db,
    required SecureTokenStorage secureStorage,
    AesGcm? algorithm,
  }) : _db = db,
       _secureStorage = secureStorage,
       _usesCustomAlgorithm = algorithm != null,
       _algorithm = algorithm ?? AesGcm.with256bits();

  static const _keyName = 'clinical_xray_aes_key_v1';
  static const _referencePrefix = 'local-encrypted://';

  final AppDatabase _db;
  final SecureTokenStorage _secureStorage;
  final bool _usesCustomAlgorithm;
  final AesGcm _algorithm;
  List<int>? _cachedKeyBytes;
  Future<List<int>>? _keyReadInFlight;

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

  static String _parseArtifactId(String reference) {
    if (!reference.startsWith(_referencePrefix)) {
      throw const FormatException('Unsupported X-ray artifact reference.');
    }
    final artifactId = reference.substring(_referencePrefix.length);
    if (artifactId.isEmpty) {
      throw const FormatException('X-ray artifact reference is empty.');
    }
    return artifactId;
  }

  Future<XrayImage> read(String reference) async {
    final artifactId = _parseArtifactId(reference);
    final row = await _db.findEncryptedArtifact(artifactId);
    if (row == null) {
      throw StateError('Encrypted X-ray artifact is missing.');
    }
    return decodeArtifact(row);
  }

  /// Fetches and decrypts multiple artifacts in one SQLite query and one
  /// background isolate batch, returning images keyed by [references].
  Future<Map<String, XrayImage>> readMany(List<String> references) async {
    if (references.isEmpty) return const {};
    final idsByRef = <String, String>{};
    for (final reference in references) {
      idsByRef[reference] = _parseArtifactId(reference);
    }
    final uniqueIds = idsByRef.values.toSet().toList(growable: false);
    final rows = await _db.findEncryptedArtifacts(uniqueIds);
    final byId = {for (final row in rows) row.id: row};
    if (byId.length != uniqueIds.length) {
      throw StateError('Encrypted X-ray artifact is missing.');
    }
    final orderedRows = [for (final id in uniqueIds) byId[id]!];
    final decoded = await decodeArtifactsBatch(orderedRows);
    final decodedById = <String, XrayImage>{
      for (var i = 0; i < orderedRows.length; i++) orderedRows[i].id: decoded[i],
    };
    return {
      for (final entry in idsByRef.entries) entry.key: decodedById[entry.value]!,
    };
  }

  /// Only the encrypted device handoff service passes archived artifacts here.
  Future<XrayImage> decodeArtifact(EncryptedXrayArtifact row) async =>
      (await decodeArtifactsBatch([row])).single;

  Future<List<XrayImage>> decodeArtifactsBatch(
    List<EncryptedXrayArtifact> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final keyBytes = await _readExistingKeyBytes();
    if (_usesCustomAlgorithm) {
      final secretKey = SecretKey(keyBytes);
      final images = <XrayImage>[];
      for (final row in rows) {
        images.add(await _decodeInline(row, secretKey));
      }
      return images;
    }
    final payload = [
      for (final row in rows)
        <String, dynamic>{
          'id': row.id,
          'cipherText': row.cipherText,
          'nonce': row.nonce,
          'mac': row.mac,
          'filename': row.filename,
          'mimeType': row.mimeType,
          'source': row.source,
          'checksum': row.checksum,
          'sizeBytes': row.sizeBytes,
        },
    ];
    final results = await compute(_decryptXrayBatch, {
      'key': keyBytes,
      'rows': payload,
    });
    return [
      for (final item in results)
        XrayImage.verified(
          bytes: (item['bytes'] as TransferableTypedData)
              .materialize()
              .asUint8List(),
          filename: item['filename'] as String,
          mimeType: item['mimeType'] as String,
          format: XrayImageFormat.values[item['formatIndex'] as int],
          source: XrayImageSource.values[item['sourceIndex'] as int],
          checksumSha256: item['checksum'] as String,
        ),
    ];
  }

  Future<XrayImage> _decodeInline(
    EncryptedXrayArtifact row,
    SecretKey secretKey,
  ) async {
    final clearBytes = await _algorithm.decrypt(
      SecretBox(row.cipherText, nonce: row.nonce, mac: Mac(row.mac)),
      secretKey: secretKey,
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
    final bytes = await _readOrCreateKeyBytes();
    return SecretKey(bytes);
  }

  Future<List<int>> _readOrCreateKeyBytes() async {
    final cached = _cachedKeyBytes;
    if (cached != null) return cached;
    final encoded = await _secureStorage.read(_keyName);
    if (encoded != null) {
      final decoded = _decodeKeyBytes(encoded);
      _cachedKeyBytes = decoded;
      return decoded;
    }
    final key = await _algorithm.newSecretKey();
    final bytes = await key.extractBytes();
    await _secureStorage.write(_keyName, base64Encode(bytes));
    _cachedKeyBytes = bytes;
    return bytes;
  }

  Future<List<int>> _readExistingKeyBytes() {
    final cached = _cachedKeyBytes;
    if (cached != null) return Future.value(cached);
    final inFlight = _keyReadInFlight;
    if (inFlight != null) return inFlight;
    final future = () async {
      final encoded = await _secureStorage.read(_keyName);
      if (encoded == null) {
        throw StateError('X-ray encryption key is unavailable.');
      }
      final bytes = _decodeKeyBytes(encoded);
      _cachedKeyBytes = bytes;
      return bytes;
    }();
    _keyReadInFlight = future.whenComplete(() {
      if (identical(_keyReadInFlight, future)) {
        _keyReadInFlight = null;
      }
    });
    return _keyReadInFlight!;
  }

  List<int> _decodeKeyBytes(String encoded) {
    late final List<int> bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      throw StateError('X-ray encryption key is corrupted.');
    }
    if (bytes.length != 32) {
      throw StateError('X-ray encryption key has an invalid length.');
    }
    return bytes;
  }
}
