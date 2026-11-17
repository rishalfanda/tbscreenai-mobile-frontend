import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math' as math;
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
  static const prefix = 'device_operator_outbox_v1:';
  static const cachePrefix = 'doctor_received_cache_v1:';
  static const _keyName = 'device_operator_outbox_aes_v1';
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
    return jsonEncode({
      ...encrypted,
      'tenant_id': op['tenantId'],
      'device_id': op['deviceId'],
      'owner_id': op['userId'],
      'op_status': op['status'],
      'entity_type': op['entityType'],
      'operation': op['operation'],
    });
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

  Future<void> save(Map<String, dynamic> entry, {String? cacheKey}) async {
    final id = (entry['op'] as Map)['clientOpId'] as String;
    final key = await _key(create: true);
    final encrypted = (await compute(_encryptArchiveBatch, {
      'entries': [entry],
      'key': await key.extractBytes(),
    })).single;
    await db.putSetting(
      cacheKey ?? '$prefix$id',
      _encodeArchiveRow(entry, encrypted),
    );
  }

  Future<void> retainReceived(Map<String, dynamic> original) async {
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
      final cacheKey =
          '$cachePrefix${op.userId}:${op.entityType}:${op.entityId}';
      if (retired || (received && missing)) {
        if (received) {
          await db.deleteSetting(cacheKey);
        } else {
          entry['retired'] = true;
          entry['op'] = op
              .copyWith(
                status: syncConflict,
                detail: const Value('server_deleted'),
              )
              .toJson();
          await save(entry);
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
      for (final entry in await entries(tenantId, deviceId)) {
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
          keyed.add((op.createdAt, entry));
        }
      }
    }
    keyed.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final item in keyed) item.$2];
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

      final artifactsById = <String, EncryptedXrayArtifact>{
        for (final row in await _chunkedByIds(artifactIds, (slice) {
          final q = db.select(db.encryptedXrayArtifacts)
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

      final entriesToSave = <Map<String, dynamic>>[];
      final keysToDelete = <String>[];
      for (final op in activeOps) {
        final diagnosis = op.entityType == 'diagnosis'
            ? diagnosesById[op.entityId]
            : null;
        final patient = patientsById[diagnosis?.patientId ?? op.entityId];
        final artifact = diagnosis == null ? null : artifactsById[diagnosis.id];
        if ((diagnosis != null &&
                (diagnosis.tenantId != owner.tenantId ||
                    diagnosis.userId != owner.userId ||
                    diagnosis.deviceId != owner.deviceId)) ||
            (patient != null &&
                (patient.tenantId != owner.tenantId ||
                    patient.userId != owner.userId ||
                    patient.deviceId != owner.deviceId)) ||
            (artifact != null &&
                (artifact.tenantId != owner.tenantId ||
                    artifact.userId != owner.userId ||
                    artifact.deviceId != owner.deviceId))) {
          throw StateError('Clinical snapshot ownership mismatch');
        }
        final imagePending =
            op.status == syncSynced &&
            op.entityType == 'diagnosis' &&
            op.operation == 'create' &&
            artifact != null;
        if (op.status == syncSynced && !imagePending) {
          keysToDelete.add('$prefix${op.clientOpId}');
          continue;
        }
        final serialized = op.toJson();
        if (imagePending) serialized['status'] = syncPending;
        final overlays = <Map<String, dynamic>>[];
        if (diagnosis != null) {
          for (final artifactId
              in overlayOrderByDiag[diagnosis.id] ?? const <String>[]) {
            final overlay = artifactsById[artifactId];
            if (overlay == null) continue;
            if (overlay.tenantId != owner.tenantId ||
                overlay.userId != owner.userId ||
                overlay.deviceId != owner.deviceId) {
              throw StateError('Segmentation ownership mismatch');
            }
            overlays.add(overlay.toJson());
          }
        }
        entriesToSave.add({
          'op': serialized,
          if (overlays.isNotEmpty) 'segmentation_artifacts': overlays,
          if (imagePending) 'record_synced': true,
          'patient': patient?.toJson(),
          'diagnosis': diagnosis?.toJson(),
          'artifact': artifact?.toJson(),
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
        await db.putSettings(encodedRows);
      }
      if (keysToDelete.isNotEmpty) {
        await db.deleteSettings(keysToDelete);
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
    );
    if (saved.isEmpty || generation != db.sessionGeneration) return;
    await db.writeForSession(generation, () async {
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
      final patients = <String, LocalPatientsCompanion>{};
      final diagnoses = <String, LocalDiagnosesCompanion>{};
      final artifacts = <String, EncryptedXrayArtifactsCompanion>{};
      final operations = <String, SyncQueueCompanion>{};
      final conflictPatientIds = <String>{};
      final conflictDiagnosisIds = <String>{};
      final failedDiagnosisIds = <String>{};

      for (final entry in saved) {
        if (entry['retired'] == true) continue;
        final archivedOp = SyncQueueData.fromJson(
          entry['op'] as Map<String, dynamic>,
        );
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
        if (entry['artifact'] != null) {
          final artifactMap = entry['artifact'] as Map<String, dynamic>;
          final artifact = EncryptedXrayArtifact.fromJson(artifactMap);
          artifacts[artifact.id] = artifact.toCompanion(true);
        }
        for (final raw
            in (entry['segmentation_artifacts'] as List? ?? const [])) {
          final overlay = EncryptedXrayArtifact.fromJson(
            (raw as Map).cast<String, dynamic>(),
          );
          if (overlay.tenantId != owner.tenantId ||
              overlay.userId != owner.userId ||
              overlay.deviceId != owner.deviceId) {
            throw StateError('Segmentation ownership mismatch');
          }
          artifacts[overlay.id] = overlay.toCompanion(true);
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
    });
  }

  Future<void> remove(String opId) => db.deleteSetting('$prefix$opId');
}
