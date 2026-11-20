import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:cryptography/cryptography.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/domain/models/access_scope.dart';

enum OutboxRestoreScope { pendingOnly, receivedOnly, all }

Future<List<Map<String, dynamic>>> _encryptArchiveBatch(
  Map<String, dynamic> input,
) async {
  final secretKey = SecretKey(input['key'] as List<int>);
  final aes = AesGcm.with256bits();
  final entries = input['entries'] as List<Map<String, dynamic>>;
  final out = <Map<String, dynamic>>[];
  for (final entry in entries) {
    final box = await aes.encrypt(
      utf8.encode(jsonEncode(entry)),
      secretKey: secretKey,
    );
    out.add({
      'cipher': base64Encode(box.cipherText),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
    });
  }
  return out;
}

Future<List<Map<String, dynamic>>> _decryptArchiveBatch(
  Map<String, dynamic> input,
) async {
  final secretKey = SecretKey(input['key'] as List<int>);
  final aes = AesGcm.with256bits();
  final values = input['values'] as List<String>;
  final out = <Map<String, dynamic>>[];
  for (final value in values) {
    final box = jsonDecode(value) as Map;
    final clear = await aes.decrypt(
      SecretBox(
        base64Decode(box['cipher'] as String),
        nonce: base64Decode(box['nonce'] as String),
        mac: Mac(base64Decode(box['mac'] as String)),
      ),
      secretKey: secretKey,
    );
    out.add(jsonDecode(utf8.decode(clear)) as Map<String, dynamic>);
  }
  return out;
}

/// Device handoff storage, separate from every account's visible clinical cache.
/// Only ciphertext survives logout. All reads require an explicit tenant/device.
class OperatorQueueSummary {
  const OperatorQueueSummary({
    this.patients = 0,
    this.screenings = 0,
    this.validations = 0,
    this.other = 0,
  });
  final int patients, screenings, validations, other;
  int get total => patients + screenings + validations + other;
}

class DeviceOperatorOutbox {
  DeviceOperatorOutbox(this.db, this.storage);
  final AppDatabase db;
  final SecureTokenStorage storage;
  final _aes = AesGcm.with256bits();
  final Expando<String> _archiveKeyOfEntry = Expando<String>('archiveKey');
  static const prefix = 'device_operator_outbox_v1:';
  static const cachePrefix = 'doctor_received_cache_v1:';
  static const _keyName = 'device_operator_outbox_aes_v1';

  String? archiveKeyFor(Map<String, dynamic> entry) =>
      _archiveKeyOfEntry[entry];

  Future<SecretKey> _key({bool create = false}) async {
    final raw = await storage.read(_keyName);
    if (raw != null) {
      final bytes = base64Decode(raw);
      if (bytes.length != 32) throw StateError('Invalid outbox key');
      return SecretKey(bytes);
    }
    final existing =
        await (db.select(db.appSettings)..where(
              (t) => t.key.like('$prefix%') | t.key.like('$cachePrefix%'),
            ))
            .get();
    if (!create || existing.isNotEmpty) {
      throw StateError(
        'Outbox encryption key unavailable; queued work retained',
      );
    }
    final key = await _aes.newSecretKey();
    await storage.write(_keyName, base64Encode(await key.extractBytes()));
    return key;
  }

  String _encodeArchiveRow(
    Map<String, dynamic> entry,
    Map<String, dynamic> encrypted,
  ) {
    final op = entry['op'] as Map;
    // Place filterable metadata keys before 'cipher' so SQLite json_extract
    // hits them at the start of each JSON row without scanning ciphertext.
    return jsonEncode({
      'tenant_id': op['tenantId'],
      'device_id': op['deviceId'],
      'owner_id': op['userId'],
      'op_status': op['status'],
      'entity_type': op['entityType'],
      'operation': op['operation'],
      ...encrypted,
    });
  }

  static bool _hasInlineArtifactBytes(Map<String, dynamic> raw) =>
      raw['cipherText'] != null && raw['nonce'] != null && raw['mac'] != null;

  static Map<String, dynamic> _stripArtifactBytes(Map<String, dynamic> raw) {
    return <String, dynamic>{
      for (final entry in raw.entries)
        if (entry.key != 'cipherText' &&
            entry.key != 'nonce' &&
            entry.key != 'mac')
          entry.key: entry.value,
    };
  }

  static Uint8List _toUint8List(Object? raw) {
    if (raw is Uint8List) return raw;
    if (raw is List) return Uint8List.fromList(raw.cast<int>());
    if (raw is String) return base64Decode(raw);
    throw const FormatException('Invalid artifact byte buffer');
  }

  static DateTime _parseDateTime(Object? raw) {
    if (raw is DateTime) return raw.toUtc();
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    if (raw is String) return DateTime.parse(raw).toUtc();
    throw const FormatException('Invalid artifact timestamp');
  }

  static ArchivedXrayArtifactsCompanion _toArchivedCompanion(
    String archiveKey,
    Map<String, dynamic> raw, {
    required DataOwner fallbackOwner,
  }) {
    return ArchivedXrayArtifactsCompanion.insert(
      archiveKey: archiveKey,
      artifactId: raw['id'] as String,
      cipherText: _toUint8List(raw['cipherText']),
      nonce: _toUint8List(raw['nonce']),
      mac: _toUint8List(raw['mac']),
      filename: raw['filename'] as String,
      mimeType: raw['mimeType'] as String,
      source: raw['source'] as String,
      checksum: raw['checksum'] as String,
      sizeBytes: (raw['sizeBytes'] as num).toInt(),
      createdAt: _parseDateTime(raw['createdAt']),
      tenantId: (raw['tenantId'] as String?) ?? fallbackOwner.tenantId,
      userId: (raw['userId'] as String?) ?? fallbackOwner.userId,
      deviceId: (raw['deviceId'] as String?) ?? fallbackOwner.deviceId,
    );
  }

  static Map<String, dynamic> _archivedRowToJson(ArchivedXrayArtifact row) => {
    'id': row.artifactId,
    'cipherText': row.cipherText,
    'nonce': row.nonce,
    'mac': row.mac,
    'filename': row.filename,
    'mimeType': row.mimeType,
    'source': row.source,
    'checksum': row.checksum,
    'sizeBytes': row.sizeBytes,
    'createdAt': row.createdAt.millisecondsSinceEpoch,
    'tenantId': row.tenantId,
    'userId': row.userId,
    'deviceId': row.deviceId,
  };

  static EncryptedXrayArtifact _archivedRowToActive(ArchivedXrayArtifact row) =>
      EncryptedXrayArtifact(
        id: row.artifactId,
        cipherText: row.cipherText,
        nonce: row.nonce,
        mac: row.mac,
        filename: row.filename,
        mimeType: row.mimeType,
        source: row.source,
        checksum: row.checksum,
        sizeBytes: row.sizeBytes,
        createdAt: row.createdAt,
        tenantId: row.tenantId,
        userId: row.userId,
        deviceId: row.deviceId,
      );

  /// Loads a single [EncryptedXrayArtifact] on demand for an entry returned by
  /// [entries] with `includeArtifacts: false` (or inline legacy entries).
  Future<EncryptedXrayArtifact?> loadArchivedArtifact(
    Map<String, dynamic> entry,
    String artifactId, {
    DataOwner? owner,
  }) async {
    final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
    final primary = entry['artifact'];
    if (primary is Map &&
        primary['id'] == artifactId &&
        _hasInlineArtifactBytes(primary.cast<String, dynamic>())) {
      return EncryptedXrayArtifact.fromJson(primary.cast<String, dynamic>());
    }
    for (final raw
        in (entry['segmentation_artifacts'] as List? ?? const [])) {
      if (raw is Map &&
          raw['id'] == artifactId &&
          _hasInlineArtifactBytes(raw.cast<String, dynamic>())) {
        return EncryptedXrayArtifact.fromJson(raw.cast<String, dynamic>());
      }
    }
    final key =
        _archiveKeyOfEntry[entry] ??
        (op.status == syncSynced
            ? '$cachePrefix${op.userId}:${op.entityType}:${op.entityId}'
            : '$prefix${op.clientOpId}');
    final rows = await db.findArchivedArtifacts(
      key,
      artifactIds: [artifactId],
      owner: owner,
    );
    if (rows.isEmpty) return null;
    return _archivedRowToActive(rows.first);
  }

  List<List<T>> _chunkItems<T>(List<T> items, {int itemsPerWorker = 8}) {
    final workerCount = items.length <= itemsPerWorker
        ? 1
        : math.min(4, (items.length + itemsPerWorker - 1) ~/ itemsPerWorker);
    final chunkSize = (items.length + workerCount - 1) ~/ workerCount;
    return [
      for (var i = 0; i < items.length; i += chunkSize)
        items.sublist(i, math.min(i + chunkSize, items.length)),
    ];
  }

  Future<List<T>> _chunkedByIds<T>(
    Iterable<String> ids,
    Future<List<T>> Function(List<String> slice) query,
  ) async {
    final list = ids.toList();
    if (list.isEmpty) return const [];
    final out = <T>[];
    const maxVars = 500;
    for (var i = 0; i < list.length; i += maxVars) {
      out.addAll(await query(list.sublist(i, math.min(i + maxVars, list.length))));
    }
    return out;
  }

  /// Extracts inline binary artifact payloads from [entry] into [outCompanions]
  /// for [targetKey] and returns a slim copy carrying metadata only.
  Map<String, dynamic> _extractSlimEntry(
    Map<String, dynamic> entry,
    String targetKey,
    DataOwner fallbackOwner,
    List<ArchivedXrayArtifactsCompanion> outCompanions,
  ) {
    final slim = Map<String, dynamic>.from(entry);
    final rawArtifact = slim.remove('artifact');
    if (rawArtifact is Map) {
      final artifactMap = rawArtifact.cast<String, dynamic>();
      slim['artifact_meta'] = _stripArtifactBytes(artifactMap);
      if (_hasInlineArtifactBytes(artifactMap)) {
        outCompanions.add(
          _toArchivedCompanion(
            targetKey,
            artifactMap,
            fallbackOwner: fallbackOwner,
          ),
        );
      }
    }
    final rawOverlays = slim.remove('segmentation_artifacts');
    if (rawOverlays is List) {
      final metas = <Map<String, dynamic>>[];
      for (final item in rawOverlays) {
        final overlayMap = (item as Map).cast<String, dynamic>();
        metas.add(_stripArtifactBytes(overlayMap));
        if (_hasInlineArtifactBytes(overlayMap)) {
          outCompanions.add(
            _toArchivedCompanion(
              targetKey,
              overlayMap,
              fallbackOwner: fallbackOwner,
            ),
          );
        }
      }
      if (metas.isNotEmpty) {
        slim['segmentation_artifact_metas'] = metas;
      }
    }
    return slim;
  }

  Future<void> save(
    Map<String, dynamic> entry, {
    String? cacheKey,
    String? sourceArchiveKey,
  }) async {
    final op = entry['op'] as Map;
    final id = op['clientOpId'] as String;
    final targetKey = cacheKey ?? '$prefix$id';
    final originKey = sourceArchiveKey ?? _archiveKeyOfEntry[entry];
    final opOwner = DataOwner(
      tenantId: op['tenantId'] as String,
      userId: op['userId'] as String,
      deviceId: op['deviceId'] as String,
    );
    final artifactsToWrite = <ArchivedXrayArtifactsCompanion>[];
    final slimEntry = _extractSlimEntry(
      entry,
      targetKey,
      opOwner,
      artifactsToWrite,
    );
    final key = await _key(create: true);
    final encrypted = (await compute(_encryptArchiveBatch, {
      'entries': [slimEntry],
      'key': await key.extractBytes(),
    })).single;
    final encoded = _encodeArchiveRow(slimEntry, encrypted);
    await db.transaction(() async {
      if (artifactsToWrite.isNotEmpty) {
        await db.upsertArchivedArtifacts(artifactsToWrite);
      } else if (originKey != null && originKey != targetKey) {
        await db.rekeyArchivedArtifacts(
          fromKey: originKey,
          toKey: targetKey,
          owner: opOwner,
        );
      }
      await db.putSetting(targetKey, encoded);
    });
  }

  Future<void> retainReceived(Map<String, dynamic> original) async {
    final originKey = _archiveKeyOfEntry[original];
    final entry = Map<String, dynamic>.from(original);
    final op = Map<String, dynamic>.from(entry['op'] as Map);
    op['status'] = syncSynced;
    entry['op'] = op;
    if (entry['diagnosis'] is Map) {
      entry['diagnosis'] = {
        ...entry['diagnosis'] as Map,
        'saveStatus': 'saved',
      };
    }
    await save(
      entry,
      cacheKey:
          '$cachePrefix${op['userId']}:${op['entityType']}:${op['entityId']}',
      sourceArchiveKey: originKey,
    );
  }

  /// A receipt proves our operation's version, never a later server edit.
  void applyReceipt(Map<String, dynamic> entry, Map<String, dynamic> receipt) {
    final version = receipt['op_version'];
    final server = receipt['server_version'];
    entry['receipt'] = {
      'op_version': version,
      'server_version': server,
      'entity_type': receipt['entity_type'],
    };
    final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
    final field = op.entityType == 'patient' ? 'patient' : 'diagnosis';
    final raw = entry[field];
    if (raw is Map) {
      entry[field] = {
        ...raw,
        'serverVersion': version,
        if (version == null || server != version) 'hasConflict': true,
      };
    }
    entry['op'] = op.copyWith(baseVersion: Value(version as int?)).toJson();
  }

  /// Updates only received snapshots. Queued clinical edits retain their old
  /// baseline; server tombstones prevent restoration without losing the queue.
  Future<void> reconcileState(
    List<Map<String, dynamic>> archived,
    Map<String, Map<String, dynamic>> records,
    Map<String, String> gone, {
    required void Function() current,
  }) async {
    String identity(Map<String, dynamic> entry) {
      final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
      return '${op.entityType}:${op.entityId}';
    }

    final pending = {
      for (final e in archived)
        if ((e['op'] as Map)['status'] != syncSynced) identity(e),
    };
    for (final entry in archived) {
      current();
      final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
      final received = op.status == syncSynced;
      final key = identity(entry);
      final patientId = (entry['patient'] as Map?)?['id'];
      final retired =
          gone[key] == 'deleted' ||
          (patientId != null && gone['patient:$patientId'] == 'deleted');
      final missing = gone[key] == 'not_found' && !pending.contains(key);
      final originKey = _archiveKeyOfEntry[entry];
      final cacheKey =
          '$cachePrefix${op.userId}:${op.entityType}:${op.entityId}';
      if (retired || (received && missing)) {
        if (received) {
          await db.deleteSetting(cacheKey);
          await db.deleteArchivedArtifactsForKeys([cacheKey]);
        } else {
          entry['retired'] = true;
          entry['op'] = op
              .copyWith(
                status: syncConflict,
                detail: const Value('server_deleted'),
              )
              .toJson();
          await save(entry, sourceArchiveKey: originKey);
        }
        continue;
      }
      if (!received) continue;
      final patient = records['patient:$patientId'];
      if (patient != null && !pending.contains('patient:$patientId')) {
        final local = LocalPatient.fromJson(
          entry['patient'] as Map<String, dynamic>,
        );
        entry['patient'] = local
            .copyWith(
              code: patient['code'] as String,
              name: patient['name'] as String,
              age: patient['age'] as int,
              gender: patient['gender'] as String,
              status: patient['status'] as String? ?? 'Normal',
              confidence: Value(patient['confidence'] as int?),
              lastVisit: Value(patient['last_visit'] as String?),
              history: jsonEncode(patient['history'] ?? []),
              serverVersion: Value(patient['version'] as int),
              updatedAt: Value(DateTime.parse(patient['updated_at'] as String)),
              hasConflict: false,
            )
            .toJson();
      }
      final diagnosisId = (entry['diagnosis'] as Map?)?['id'];
      final diagnosis = records['diagnosis:$diagnosisId'];
      if (diagnosis != null && !pending.contains('diagnosis:$diagnosisId')) {
        final local = LocalDiagnose.fromJson(
          entry['diagnosis'] as Map<String, dynamic>,
        );
        final clinical =
            jsonDecode(local.clinicalSnapshot) as Map<String, dynamic>;
        clinical.remove('local_validation_v1');
        entry['diagnosis'] = local
            .copyWith(
              isPositive: diagnosis['is_positive'] as bool,
              confidence: diagnosis['confidence'] as int,
              modelVersion: diagnosis['model_version'] as String,
              status: diagnosis['status'] as String,
              doctorNote: Value(diagnosis['doctor_note'] as String?),
              validationScore: Value(diagnosis['validation_score'] as int?),
              lesionRating: Value(diagnosis['lesion_rating'] as int?),
              validationDeletedAt: Value(
                DateTime.tryParse(
                  diagnosis['validation_deleted_at'] as String? ?? '',
                ),
              ),
              validationDeletedBy: Value(
                diagnosis['validation_deleted_by'] as String?,
              ),
              validatedBy: Value(diagnosis['validated_by'] as String?),
              validatedAt: Value(
                DateTime.tryParse(diagnosis['validated_at'] as String? ?? ''),
              ),
              serverVersion: Value(diagnosis['version'] as int),
              updatedAt: Value(
                DateTime.parse(diagnosis['updated_at'] as String),
              ),
              findings: jsonEncode(diagnosis['findings']),
              clinicalSnapshot: jsonEncode(clinical),
              hasConflict: false,
              saveStatus: 'saved',
            )
            .toJson();
      }
      final record = records[key];
      if (record != null && !pending.contains(key)) {
        entry['op'] = op
            .copyWith(baseVersion: Value(record['version'] as int))
            .toJson();
      }
      current();
      await save(entry, cacheKey: cacheKey);
    }
    current();
  }

  /// Counts metadata in SQLite without loading/decrypting image archives.
  Future<int> count(String tenantId, String deviceId) async =>
      (await summary(tenantId, deviceId)).total;

  Future<OperatorQueueSummary> summary(String tenantId, String deviceId) async {
    final legacy = await db
        .customSelect(
          "SELECT key FROM app_settings WHERE key LIKE ? AND (json_extract(value, '\$.tenant_id') IS NULL OR (json_extract(value, '\$.tenant_id') = ? AND json_extract(value, '\$.device_id') = ? AND json_extract(value, '\$.entity_type') IS NULL))",
          variables: [
            Variable.withString('$prefix%'),
            Variable.withString(tenantId),
            Variable.withString(deviceId),
          ],
        )
        .get();
    if (legacy.isNotEmpty) {
      // One-time upgrade for existing encrypted archives; no patient data is
      // copied into the summary metadata.
      for (final entry in await entries(
        tenantId,
        deviceId,
        includeArtifacts: false,
      )) {
        final op = entry['op'] as Map;
        await db.customUpdate(
          "UPDATE app_settings SET value = json_set(value, '\$.tenant_id', ?, '\$.device_id', ?, '\$.owner_id', ?, '\$.op_status', ?, '\$.entity_type', ?, '\$.operation', ?) WHERE key = ?",
          variables: [
            Variable.withString(op['tenantId'] as String),
            Variable.withString(op['deviceId'] as String),
            Variable.withString(op['userId'] as String),
            Variable.withString(op['status'] as String),
            Variable.withString(op['entityType'] as String),
            Variable.withString(op['operation'] as String),
            Variable.withString('$prefix${op['clientOpId']}'),
          ],
          updates: {db.appSettings},
        );
      }
    }
    final groups = await db
        .customSelect(
          "SELECT json_extract(value, '\$.entity_type') AS kind, json_extract(value, '\$.operation') AS operation, COUNT(*) AS n FROM app_settings WHERE key LIKE ? AND json_extract(value, '\$.tenant_id') = ? AND json_extract(value, '\$.device_id') = ? GROUP BY kind, operation",
          variables: [
            Variable.withString('$prefix%'),
            Variable.withString(tenantId),
            Variable.withString(deviceId),
          ],
        )
        .get();
    var patients = 0, screenings = 0, validations = 0, other = 0;
    for (final group in groups) {
      final n = group.read<int>('n');
      final kind = group.readNullable<String>('kind');
      final operation = group.readNullable<String>('operation');
      if (kind == 'patient') {
        patients += n;
      } else if (kind == 'diagnosis' && operation == 'create') {
        screenings += n;
      } else if (kind == 'diagnosis' &&
          const [
            'update',
            'validate_score',
            'delete_validation',
          ].contains(operation)) {
        validations += n;
      } else {
        other += n;
      }
    }
    return OperatorQueueSummary(
      patients: patients,
      screenings: screenings,
      validations: validations,
      other: other,
    );
  }

  Future<List<Map<String, dynamic>>> entries(
    String tenantId,
    String deviceId, {
    String? ownerId,
    bool includePending = true,
    bool includeReceived = false,
    bool includeArtifacts = true,
  }) async {
    final keyClauses = <String>[
      if (includePending) 'key LIKE ?',
      if (includeReceived) 'key LIKE ?',
    ];
    if (keyClauses.isEmpty) return [];
    final variables = <Variable<Object>>[
      if (includePending) Variable.withString('$prefix%'),
      if (includeReceived) Variable.withString('$cachePrefix%'),
      Variable.withString(tenantId),
      Variable.withString(deviceId),
      if (ownerId != null) Variable.withString(ownerId),
    ];
    final ownerClause = ownerId == null
        ? ''
        : " AND (json_extract(value, '\$.owner_id') IS NULL OR json_extract(value, '\$.owner_id') = ?)";
    final rows = await db
        .customSelect(
          'SELECT key, value FROM app_settings '
          'WHERE (${keyClauses.join(' OR ')}) '
          "AND (NOT json_valid(value) OR json_extract(value, '\$.tenant_id') IS NULL OR ("
          "json_extract(value, '\$.tenant_id') = ? "
          "AND json_extract(value, '\$.device_id') = ?$ownerClause))",
          variables: variables,
          readsFrom: {db.appSettings},
        )
        .get();
    if (rows.isEmpty) return [];
    final keyBytes = await (await _key()).extractBytes();
    final chunks = _chunkItems(rows);
    final decryptedChunks = await Future.wait([
      for (final chunk in chunks)
        compute(_decryptArchiveBatch, {
          'values': [for (final r in chunk) r.read<String>('value')],
          'key': keyBytes,
        }),
    ]);
    final keyed = <(DateTime, Map<String, dynamic>)>[];
    for (var c = 0; c < chunks.length; c++) {
      final chunk = chunks[c];
      final entries = decryptedChunks[c];
      for (var i = 0; i < chunk.length; i++) {
        final rowKey = chunk[i].read<String>('key');
        final entry = entries[i];
        final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
        if (rowKey != '$prefix${op.clientOpId}' &&
            (!includeReceived ||
                rowKey !=
                    '$cachePrefix${op.userId}:${op.entityType}:${op.entityId}')) {
          throw const FormatException('Outbox identity mismatch');
        }
        if (op.tenantId == tenantId &&
            op.deviceId == deviceId &&
            (ownerId == null || op.userId == ownerId)) {
          _archiveKeyOfEntry[entry] = rowKey;
          if (includeArtifacts) {
            await _hydrateEntryArtifacts(
              entry,
              rowKey,
              DataOwner(
                tenantId: op.tenantId ?? tenantId,
                userId: op.userId ?? '',
                deviceId: op.deviceId ?? deviceId,
              ),
            );
          }
          keyed.add((op.createdAt, entry));
        }
      }
    }
    keyed.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final item in keyed) item.$2];
  }

  Future<void> _hydrateEntryArtifacts(
    Map<String, dynamic> entry,
    String rowKey,
    DataOwner owner,
  ) async {
    final primaryMeta = entry['artifact_meta'];
    final overlayMetas = entry['segmentation_artifact_metas'];
    final needPrimary = entry['artifact'] == null && primaryMeta is Map;
    final needOverlays =
        entry['segmentation_artifacts'] == null && overlayMetas is List;
    if (!needPrimary && !needOverlays) return;

    final requestedIds = <String>[
      if (needPrimary && primaryMeta['id'] is String)
        primaryMeta['id'] as String,
      if (needOverlays)
        for (final item in overlayMetas)
          if (item is Map && item['id'] is String) item['id'] as String,
    ];
    if (requestedIds.isEmpty) return;

    final byId = {
      for (final row in await db.findArchivedArtifacts(
        rowKey,
        artifactIds: requestedIds,
        owner: owner,
      ))
        row.artifactId: row,
    };
    if (needPrimary && primaryMeta['id'] is String) {
      final row = byId[primaryMeta['id'] as String];
      if (row != null) {
        entry['artifact'] = _archivedRowToJson(row);
      }
    }
    if (needOverlays) {
      final list = <Map<String, dynamic>>[];
      for (final item in overlayMetas) {
        if (item is Map && item['id'] is String) {
          final row = byId[item['id'] as String];
          if (row != null) {
            list.add(_archivedRowToJson(row));
          }
        }
      }
      if (list.isNotEmpty) {
        entry['segmentation_artifacts'] = list;
      }
    }
  }

  Future<void> captureDoctorQueue() async {
    final identitySettings = await db.getSettings(const [
      kUserRole,
      kUserId,
      kTenantId,
      kDeviceId,
    ]);
    if (MobileRole.parse(identitySettings[kUserRole]) !=
        MobileRole.clinician) {
      return;
    }
    final savedUser = identitySettings[kUserId],
        savedTenant = identitySettings[kTenantId],
        savedDevice = identitySettings[kDeviceId];
    final owner =
        db.activeOwner ??
        (savedUser != null && savedTenant != null && savedDevice != null
            ? DataOwner(
                tenantId: savedTenant,
                userId: savedUser,
                deviceId: savedDevice,
              )
            : null);
    if (owner == null) throw StateError('Pending work has no verified owner');
    await db.transaction(() async {
      final ops =
          await (db.select(db.syncQueue)..where(
                (t) =>
                    t.status.isIn(const [
                      syncPending,
                      syncSending,
                      syncRetryable,
                      syncBlockedContract,
                      syncConflict,
                      syncPermanentFailure,
                      syncSynced,
                    ]) &
                    t.tenantId.equals(owner.tenantId) &
                    t.userId.equals(owner.userId) &
                    t.deviceId.equals(owner.deviceId),
              ))
              .get();
      if (ops.isEmpty) return;

      final syncedCacheKeys = <String>[
        for (final op in ops)
          if (op.status == syncSynced)
            '$cachePrefix${op.userId}:${op.entityType}:${op.entityId}',
      ];
      final retainedCacheKeys = (await _chunkedByIds(
        syncedCacheKeys.toSet(),
        (slice) => (db.select(
          db.appSettings,
        )..where((t) => t.key.isIn(slice))).get(),
      )).map((row) => row.key).toSet();

      final activeOps = <SyncQueueData>[];
      final diagnosisIds = <String>{};
      for (final op in ops) {
        if (op.status == syncSynced &&
            retainedCacheKeys.contains(
              '$cachePrefix${op.userId}:${op.entityType}:${op.entityId}',
            )) {
          // An acknowledged retained snapshot is not pending upload work.
          continue;
        }
        if (op.tenantId != owner.tenantId ||
            op.userId != owner.userId ||
            op.deviceId != owner.deviceId) {
          throw StateError('Queue ownership mismatch');
        }
        activeOps.add(op);
        if (op.entityType == 'diagnosis') {
          diagnosisIds.add(op.entityId);
        }
      }
      if (activeOps.isEmpty) return;

      final dbOwner = db.activeOwner;
      final diagnosesById = <String, LocalDiagnose>{
        for (final row in await _chunkedByIds(diagnosisIds, (slice) {
          final q = db.select(db.localDiagnoses)
            ..where((t) => t.id.isIn(slice));
          if (dbOwner != null) {
            q.where(
              (t) =>
                  t.tenantId.equals(dbOwner.tenantId) &
                  t.userId.equals(dbOwner.userId) &
                  t.deviceId.equals(dbOwner.deviceId),
            );
          }
          return q.get();
        }))
          row.id: row,
      };

      final patientIds = <String>{
        for (final op in activeOps)
          (op.entityType == 'diagnosis'
                  ? diagnosesById[op.entityId]?.patientId
                  : null) ??
              op.entityId,
      };
      final patientsById = <String, LocalPatient>{
        for (final row in await _chunkedByIds(patientIds, (slice) {
          final q = db.select(db.localPatients)..where((t) => t.id.isIn(slice));
          if (dbOwner != null) {
            q.where(
              (t) =>
                  t.tenantId.equals(dbOwner.tenantId) &
                  t.userId.equals(dbOwner.userId) &
                  t.deviceId.equals(dbOwner.deviceId),
            );
          }
          return q.get();
        }))
          row.id: row,
      };

      final overlayOrderByDiag = <String, List<String>>{};
      final artifactIds = <String>{};
      for (final diagnosis in diagnosesById.values) {
        artifactIds.add(diagnosis.id);
        final overlaysForDiag = <String>[
          '${diagnosis.id}:xray',
          '${diagnosis.id}:lung',
          '${diagnosis.id}:lesion',
        ];
        try {
          final decoded = jsonDecode(diagnosis.clinicalSnapshot);
          final refs = decoded is Map ? decoded['segmentation_v1'] : null;
          final rawLayers = refs is Map ? refs['lesion_layers'] : null;
          if (rawLayers is Map) {
            final keys =
                rawLayers.keys
                    .map((key) => key.toString().toLowerCase())
                    .toList()
                  ..sort();
            for (final key in keys) {
              overlaysForDiag.add('${diagnosis.id}:lesion:$key');
            }
          }
        } on FormatException catch (_) {}
        overlayOrderByDiag[diagnosis.id] = overlaysForDiag;
        artifactIds.addAll(overlaysForDiag);
      }

      final artifactMetaById = <String, Map<String, dynamic>>{};
      for (final sliceRow
          in await _chunkedByIds(artifactIds, (slice) {
            final placeholders = List.filled(slice.length, '?').join(',');
            final ownerSql = dbOwner == null
                ? ''
                : ' AND tenant_id = ? AND user_id = ? AND device_id = ?';
            return db.customSelect(
              'SELECT id, filename, mime_type, source, checksum, size_bytes, '
              'created_at, tenant_id, user_id, device_id '
              'FROM encrypted_xray_artifacts '
              'WHERE id IN ($placeholders)$ownerSql',
              variables: [
                for (final id in slice) Variable.withString(id),
                if (dbOwner != null) ...[
                  Variable.withString(dbOwner.tenantId),
                  Variable.withString(dbOwner.userId),
                  Variable.withString(dbOwner.deviceId),
                ],
              ],
              readsFrom: {db.encryptedXrayArtifacts},
            ).get();
          })) {
        final id = sliceRow.read<String>('id');
        artifactMetaById[id] = {
          'id': id,
          'filename': sliceRow.read<String>('filename'),
          'mimeType': sliceRow.read<String>('mime_type'),
          'source': sliceRow.read<String>('source'),
          'checksum': sliceRow.read<String>('checksum'),
          'sizeBytes': sliceRow.read<int>('size_bytes'),
          'createdAt': sliceRow
              .read<DateTime>('created_at')
              .toUtc()
              .millisecondsSinceEpoch,
          'tenantId': sliceRow.readNullable<String>('tenant_id'),
          'userId': sliceRow.readNullable<String>('user_id'),
          'deviceId': sliceRow.readNullable<String>('device_id'),
        };
      }

      final entriesToSave = <Map<String, dynamic>>[];
      final keysToDelete = <String>[];
      final artifactIdsByArchiveKey = <String, List<String>>{};
      for (final op in activeOps) {
        final diagnosis = op.entityType == 'diagnosis'
            ? diagnosesById[op.entityId]
            : null;
        final patient = patientsById[diagnosis?.patientId ?? op.entityId];
        final artifactMeta = diagnosis == null
            ? null
            : artifactMetaById[diagnosis.id];
        if ((diagnosis != null &&
                (diagnosis.tenantId != owner.tenantId ||
                    diagnosis.userId != owner.userId ||
                    diagnosis.deviceId != owner.deviceId)) ||
            (patient != null &&
                (patient.tenantId != owner.tenantId ||
                    patient.userId != owner.userId ||
                    patient.deviceId != owner.deviceId)) ||
            (artifactMeta != null &&
                (artifactMeta['tenantId'] != owner.tenantId ||
                    artifactMeta['userId'] != owner.userId ||
                    artifactMeta['deviceId'] != owner.deviceId))) {
          throw StateError('Clinical snapshot ownership mismatch');
        }
        final imagePending =
            op.status == syncSynced &&
            op.entityType == 'diagnosis' &&
            op.operation == 'create' &&
            artifactMeta != null;
        if (op.status == syncSynced && !imagePending) {
          keysToDelete.add('$prefix${op.clientOpId}');
          continue;
        }
        final serialized = op.toJson();
        if (imagePending) serialized['status'] = syncPending;
        final archiveKey = '$prefix${op.clientOpId}';
        final archiveArtifactIds = <String>[
          if (artifactMeta != null) diagnosis!.id,
        ];
        final overlayMetas = <Map<String, dynamic>>[];
        if (diagnosis != null) {
          for (final artifactId
              in overlayOrderByDiag[diagnosis.id] ?? const <String>[]) {
            final overlay = artifactMetaById[artifactId];
            if (overlay == null) continue;
            if (overlay['tenantId'] != owner.tenantId ||
                overlay['userId'] != owner.userId ||
                overlay['deviceId'] != owner.deviceId) {
              throw StateError('Segmentation ownership mismatch');
            }
            overlayMetas.add(overlay);
            archiveArtifactIds.add(artifactId);
          }
        }
        if (archiveArtifactIds.isNotEmpty) {
          artifactIdsByArchiveKey[archiveKey] = archiveArtifactIds;
        }
        entriesToSave.add({
          'op': serialized,
          if (overlayMetas.isNotEmpty)
            'segmentation_artifact_metas': overlayMetas,
          if (imagePending) 'record_synced': true,
          'patient': patient?.toJson(),
          'diagnosis': diagnosis?.toJson(),
          'artifact_meta': ?artifactMeta,
        });
      }

      if (entriesToSave.isNotEmpty) {
        final keyBytes = await (await _key(create: true)).extractBytes();
        final entryChunks = _chunkItems(entriesToSave, itemsPerWorker: 4);
        final encryptedChunks = await Future.wait([
          for (final chunk in entryChunks)
            compute(_encryptArchiveBatch, {
              'entries': chunk,
              'key': keyBytes,
            }),
        ]);
        final encodedRows = <String, String>{};
        for (var c = 0; c < entryChunks.length; c++) {
          final chunk = entryChunks[c];
          final encryptedList = encryptedChunks[c];
          for (var i = 0; i < chunk.length; i++) {
            final entry = chunk[i];
            final id = (entry['op'] as Map)['clientOpId'] as String;
            encodedRows['$prefix$id'] = _encodeArchiveRow(
              entry,
              encryptedList[i],
            );
          }
        }
        if (artifactIdsByArchiveKey.isNotEmpty) {
          await db.copyEncryptedArtifactsToArchive(
            artifactIdsByArchiveKey,
            owner,
          );
        }
        await db.putSettings(encodedRows);
      }
      if (keysToDelete.isNotEmpty) {
        await db.deleteSettings(keysToDelete);
        await db.deleteArchivedArtifactsForKeys(keysToDelete);
      }
    });
  }

  Future<void> restoreDoctorQueue({
    OutboxRestoreScope scope = OutboxRestoreScope.all,
  }) async {
    final owner = db.activeOwner;
    if (owner == null ||
        MobileRole.parse(await db.getSetting(kUserRole)) !=
            MobileRole.clinician) {
      return;
    }
    final generation = db.sessionGeneration;
    final saved = await entries(
      owner.tenantId,
      owner.deviceId,
      ownerId: owner.userId,
      includePending: scope != OutboxRestoreScope.receivedOnly,
      includeReceived: scope != OutboxRestoreScope.pendingOnly,
      includeArtifacts: false,
    );
    if (saved.isEmpty || generation != db.sessionGeneration) return;

    final keyBytes = saved.any(
      (entry) =>
          entry['artifact'] is Map || entry['segmentation_artifacts'] is List,
    )
        ? await (await _key()).extractBytes()
        : null;

    final chunkSize = scope == OutboxRestoreScope.receivedOnly
        ? 15
        : saved.length;
    final legacyToCompact =
        <(String archiveKey, Map<String, dynamic> slimEntry)>[];
    final legacyCompanions = <ArchivedXrayArtifactsCompanion>[];

    final needsExistingLookup = saved.any(
      (entry) =>
          entry['retired'] != true &&
          (entry['op'] as Map)['status'] == syncSynced,
    );
    final existingPatients = needsExistingLookup
        ? <String>{
            for (final row
                in await (db.select(db.localPatients)..where(
                      (t) =>
                          t.tenantId.equals(owner.tenantId) &
                          t.userId.equals(owner.userId) &
                          t.deviceId.equals(owner.deviceId),
                    ))
                    .get())
              row.id,
          }
        : <String>{};
    final existingDiagnoses = needsExistingLookup
        ? <String>{
            for (final row
                in await (db.select(db.localDiagnoses)..where(
                      (t) =>
                          t.tenantId.equals(owner.tenantId) &
                          t.userId.equals(owner.userId) &
                          t.deviceId.equals(owner.deviceId),
                    ))
                    .get())
              row.id,
          }
        : <String>{};

    for (var start = 0; start < saved.length; start += chunkSize) {
      if (generation != db.sessionGeneration) return;
      final slice = saved.sublist(
        start,
        math.min(start + chunkSize, saved.length),
      );
      await db.writeForSession(generation, () async {
        final patients = <String, LocalPatientsCompanion>{};
        final diagnoses = <String, LocalDiagnosesCompanion>{};
        final artifacts = <String, EncryptedXrayArtifactsCompanion>{};
        final operations = <String, SyncQueueCompanion>{};
        final conflictPatientIds = <String>{};
        final conflictDiagnosisIds = <String>{};
        final failedDiagnosisIds = <String>{};
        final archiveArtifactIdsByKey = <String, List<String>>{};

        for (final entry in slice) {
          if (entry['retired'] == true) continue;
          final archivedOp = SyncQueueData.fromJson(
            entry['op'] as Map<String, dynamic>,
          );
          final archiveKey =
              _archiveKeyOfEntry[entry] ??
              (archivedOp.status == syncSynced
                  ? '$cachePrefix${archivedOp.userId}:${archivedOp.entityType}:${archivedOp.entityId}'
                  : '$prefix${archivedOp.clientOpId}');
          final received = archivedOp.status == syncSynced;
          if (entry['patient'] != null) {
            final patientMap = entry['patient'] as Map<String, dynamic>;
            final patientId = patientMap['id'] as String;
            if (!received || !existingPatients.contains(patientId)) {
              patients[patientId] = LocalPatient.fromJson(
                patientMap,
              ).toCompanion(true);
              existingPatients.add(patientId);
            }
          }
          if (entry['diagnosis'] != null) {
            final diagMap = entry['diagnosis'] as Map<String, dynamic>;
            final diagId = diagMap['id'] as String;
            if (!received || !existingDiagnoses.contains(diagId)) {
              diagnoses[diagId] = LocalDiagnose.fromJson(
                diagMap,
              ).toCompanion(true);
              existingDiagnoses.add(diagId);
            }
          }

          var hadInlineArtifact = false;
          final archiveIds = <String>[];
          if (entry['artifact'] != null) {
            final artifactMap = (entry['artifact'] as Map)
                .cast<String, dynamic>();
            final artifact = EncryptedXrayArtifact.fromJson(artifactMap);
            artifacts[artifact.id] = artifact.toCompanion(true);
            hadInlineArtifact = true;
          } else if (entry['artifact_meta'] is Map) {
            final meta = (entry['artifact_meta'] as Map)
                .cast<String, dynamic>();
            if (meta['tenantId'] != owner.tenantId ||
                meta['userId'] != owner.userId ||
                meta['deviceId'] != owner.deviceId) {
              throw StateError('Clinical snapshot ownership mismatch');
            }
            archiveIds.add(meta['id'] as String);
          }

          if (entry['segmentation_artifacts'] is List) {
            for (final raw in entry['segmentation_artifacts'] as List) {
              final overlay = EncryptedXrayArtifact.fromJson(
                (raw as Map).cast<String, dynamic>(),
              );
              if (overlay.tenantId != owner.tenantId ||
                  overlay.userId != owner.userId ||
                  overlay.deviceId != owner.deviceId) {
                throw StateError('Segmentation ownership mismatch');
              }
              artifacts[overlay.id] = overlay.toCompanion(true);
              hadInlineArtifact = true;
            }
          } else if (entry['segmentation_artifact_metas'] is List) {
            for (final raw in entry['segmentation_artifact_metas'] as List) {
              final meta = (raw as Map).cast<String, dynamic>();
              if (meta['tenantId'] != owner.tenantId ||
                  meta['userId'] != owner.userId ||
                  meta['deviceId'] != owner.deviceId) {
                throw StateError('Segmentation ownership mismatch');
              }
              archiveIds.add(meta['id'] as String);
            }
          }

          if (archiveIds.isNotEmpty) {
            archiveArtifactIdsByKey[archiveKey] = archiveIds;
          }
          if (hadInlineArtifact) {
            final slim = _extractSlimEntry(
              entry,
              archiveKey,
              owner,
              legacyCompanions,
            );
            legacyToCompact.add((archiveKey, slim));
          }

          operations[archivedOp.clientOpId] = archivedOp.toCompanion(true);
          if (archivedOp.status == syncConflict) {
            if (archivedOp.entityType == 'patient') {
              conflictPatientIds.add(archivedOp.entityId);
            } else {
              conflictDiagnosisIds.add(archivedOp.entityId);
              failedDiagnosisIds.remove(archivedOp.entityId);
            }
          } else if (archivedOp.entityType == 'diagnosis' &&
              archivedOp.status == syncPermanentFailure) {
            failedDiagnosisIds.add(archivedOp.entityId);
          }
        }

        await db.applyOutboxRestoreBatch(
          patients: patients.values.toList(),
          diagnoses: diagnoses.values.toList(),
          artifacts: artifacts.values.toList(),
          operations: operations.values.toList(),
          conflictPatientIds: conflictPatientIds.toList(),
          conflictDiagnosisIds: conflictDiagnosisIds.toList(),
          failedDiagnosisIds: failedDiagnosisIds.toList(),
        );
        if (archiveArtifactIdsByKey.isNotEmpty) {
          await db.copyArchiveArtifactsToActive(archiveArtifactIdsByKey, owner);
        }
      });
      if (start + chunkSize < saved.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    // One-time lazy compaction for legacy inline [int, ...] outbox rows
    // runs isolate encryption outside SQLite write transactions.
    if (legacyToCompact.isNotEmpty &&
        keyBytes != null &&
        generation == db.sessionGeneration) {
      final compactChunks = _chunkItems(legacyToCompact, itemsPerWorker: 4);
      final encryptedChunks = await Future.wait([
        for (final chunk in compactChunks)
          compute(_encryptArchiveBatch, {
            'entries': [for (final item in chunk) item.$2],
            'key': keyBytes,
          }),
      ]);
      final updates = <String, String>{};
      for (var c = 0; c < compactChunks.length; c++) {
        final chunk = compactChunks[c];
        final encryptedList = encryptedChunks[c];
        for (var i = 0; i < chunk.length; i++) {
          updates[chunk[i].$1] = _encodeArchiveRow(
            chunk[i].$2,
            encryptedList[i],
          );
        }
      }
      await db.writeForSession(generation, () async {
        await db.upsertArchivedArtifacts(legacyCompanions);
        await db.putSettings(updates);
      });
    }
  }

  Future<void> remove(String opId) async {
    final key = '$prefix$opId';
    await db.transaction(() async {
      await db.deleteSetting(key);
      await db.deleteArchivedArtifactsForKeys([key]);
    });
  }
}
