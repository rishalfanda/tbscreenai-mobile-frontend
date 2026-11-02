import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:cryptography/cryptography.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';

Future<Map<String, dynamic>> _encryptArchive(Map<String, dynamic> input) async {
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(input['entry'])),
    secretKey: SecretKey(input['key'] as List<int>),
  );
  return {
    'cipher': base64Encode(box.cipherText),
    'nonce': base64Encode(box.nonce),
    'mac': base64Encode(box.mac.bytes),
  };
}

Future<Map<String, dynamic>> _decryptArchive(Map<String, dynamic> input) async {
  final box = jsonDecode(input['value'] as String) as Map;
  final clear = await AesGcm.with256bits().decrypt(
    SecretBox(
      base64Decode(box['cipher'] as String),
      nonce: base64Decode(box['nonce'] as String),
      mac: Mac(base64Decode(box['mac'] as String)),
    ),
    secretKey: SecretKey(input['key'] as List<int>),
  );
  return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
}

/// Device handoff storage, separate from every account's visible clinical cache.
/// Only ciphertext survives logout. All reads require an explicit tenant/device.
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

  Future<void> save(Map<String, dynamic> entry, {String? cacheKey}) async {
    final id = (entry['op'] as Map)['clientOpId'] as String;
    final key = await _key(create: true);
    final encrypted = await compute(_encryptArchive, {
      'entry': entry,
      'key': await key.extractBytes(),
    });
    final op = entry['op'] as Map;
    await db.putSetting(
      cacheKey ?? '$prefix$id',
      jsonEncode({
        ...encrypted,
        'tenant_id': op['tenantId'],
        'device_id': op['deviceId'],
        'owner_id': op['userId'],
        'op_status': op['status'],
      }),
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

  /// Counts metadata in SQLite without loading/decrypting image archives.
  Future<int> count(String tenantId, String deviceId) async {
    final legacy = await db
        .customSelect(
          "SELECT key FROM app_settings WHERE key LIKE ? AND json_extract(value, '\$.tenant_id') IS NULL",
          variables: [Variable.withString('$prefix%')],
        )
        .get();
    if (legacy.isNotEmpty) {
      // One-time upgrade for existing encrypted archives; no patient data is
      // copied into the summary metadata.
      for (final entry in await entries(tenantId, deviceId)) {
        final op = entry['op'] as Map;
        await db.customUpdate(
          "UPDATE app_settings SET value = json_set(value, '\$.tenant_id', ?, '\$.device_id', ?, '\$.owner_id', ?, '\$.op_status', ?) WHERE key = ?",
          variables: [
            Variable.withString(op['tenantId'] as String),
            Variable.withString(op['deviceId'] as String),
            Variable.withString(op['userId'] as String),
            Variable.withString(op['status'] as String),
            Variable.withString('$prefix${op['clientOpId']}'),
          ],
          updates: {db.appSettings},
        );
      }
    }
    final result = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM app_settings WHERE key LIKE ? AND json_extract(value, '\$.tenant_id') = ? AND json_extract(value, '\$.device_id') = ?",
          variables: [
            Variable.withString('$prefix%'),
            Variable.withString(tenantId),
            Variable.withString(deviceId),
          ],
        )
        .getSingle();
    return result.read<int>('n');
  }

  Future<List<Map<String, dynamic>>> entries(
    String tenantId,
    String deviceId, {
    String? ownerId,
    bool includeReceived = false,
  }) async {
    final rows =
        await (db.select(db.appSettings)..where(
              (t) =>
                  t.key.like('$prefix%') |
                  (includeReceived
                      ? t.key.like('$cachePrefix%')
                      : const Constant(false)),
            ))
            .get();
    if (rows.isEmpty) return [];
    final key = await _key();
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final entry = await compute(_decryptArchive, {
        'value': row.value,
        'key': await key.extractBytes(),
      });
      final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
      if (row.key != '$prefix${op.clientOpId}' &&
          (!includeReceived ||
              row.key !=
                  '$cachePrefix${op.userId}:${op.entityType}:${op.entityId}')) {
        throw const FormatException('Outbox identity mismatch');
      }
      if (op.tenantId == tenantId &&
          op.deviceId == deviceId &&
          (ownerId == null || op.userId == ownerId)) {
        result.add(entry);
      }
    }
    result.sort(
      (a, b) => SyncQueueData.fromJson(a['op'] as Map<String, dynamic>)
          .createdAt
          .compareTo(
            SyncQueueData.fromJson(b['op'] as Map<String, dynamic>).createdAt,
          ),
    );
    return result;
  }

  Future<void> captureDoctorQueue() async {
    if (await db.getSetting(kUserRole) != 'doctor') return;
    final savedUser = await db.getSetting(kUserId),
        savedTenant = await db.getSetting(kTenantId),
        savedDevice = await db.getSetting(kDeviceId);
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
      final ops = <SyncQueueData>[];
      for (final state in [
        syncPending,
        syncSending,
        syncRetryable,
        syncBlockedContract,
        syncConflict,
        syncPermanentFailure,
        syncSynced,
      ]) {
        ops.addAll(
          await (db.select(db.syncQueue)..where(
                (t) =>
                    t.status.equals(state) &
                    t.tenantId.equals(owner.tenantId) &
                    t.userId.equals(owner.userId) &
                    t.deviceId.equals(owner.deviceId),
              ))
              .get(),
        );
      }
      for (final op in ops) {
        if (op.tenantId != owner.tenantId ||
            op.userId != owner.userId ||
            op.deviceId != owner.deviceId) {
          throw StateError('Queue ownership mismatch');
        }
        final diagnosis = op.entityType == 'diagnosis'
            ? await db.findDiagnosis(op.entityId)
            : null;
        final patient = await db.findPatient(
          diagnosis?.patientId ?? op.entityId,
        );
        final artifact = diagnosis == null
            ? null
            : await db.findEncryptedArtifact(diagnosis.id);
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
          await remove(op.clientOpId);
          continue;
        }
        final serialized = op.toJson();
        if (imagePending) serialized['status'] = syncPending;
        final overlays = <Map<String, dynamic>>[];
        if (diagnosis != null) {
          for (final kind in ['xray', 'lung', 'lesion']) {
            final overlay = await db.findEncryptedArtifact(
              '${diagnosis.id}:$kind',
            );
            if (overlay == null) continue;
            if (overlay.tenantId != owner.tenantId ||
                overlay.userId != owner.userId ||
                overlay.deviceId != owner.deviceId) {
              throw StateError('Segmentation ownership mismatch');
            }
            overlays.add(overlay.toJson());
          }
        }
        await save({
          'op': serialized,
          if (overlays.isNotEmpty) 'segmentation_artifacts': overlays,
          if (imagePending) 'record_synced': true,
          'patient': patient?.toJson(),
          'diagnosis': diagnosis?.toJson(),
          'artifact': artifact?.toJson(),
        });
      }
    });
  }

  Future<void> restoreDoctorQueue() async {
    final owner = db.activeOwner;
    if (owner == null || await db.getSetting(kUserRole) != 'doctor') return;
    final generation = db.sessionGeneration;
    final saved = await entries(
      owner.tenantId,
      owner.deviceId,
      ownerId: owner.userId,
      includeReceived: true,
    );
    await db.writeForSession(generation, () async {
      for (final entry in saved) {
        final archivedOp = SyncQueueData.fromJson(
          entry['op'] as Map<String, dynamic>,
        );
        final received = archivedOp.status == syncSynced;
        if (entry['patient'] != null &&
            (!received ||
                await db.findPatient(
                      (entry['patient'] as Map)['id'] as String,
                    ) ==
                    null)) {
          await db.upsertPatient(
            LocalPatient.fromJson(
              entry['patient'] as Map<String, dynamic>,
            ).toCompanion(true),
          );
        }
        if (entry['diagnosis'] != null &&
            (!received ||
                await db.findDiagnosis(
                      (entry['diagnosis'] as Map)['id'] as String,
                    ) ==
                    null)) {
          await db.upsertDiagnosis(
            LocalDiagnose.fromJson(
              entry['diagnosis'] as Map<String, dynamic>,
            ).toCompanion(true),
          );
        }
        if (entry['artifact'] != null) {
          await db.upsertEncryptedArtifact(
            EncryptedXrayArtifact.fromJson(
              entry['artifact'] as Map<String, dynamic>,
            ).toCompanion(true),
          );
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
          await db.upsertEncryptedArtifact(overlay.toCompanion(true));
        }
        await db.enqueue(
          SyncQueueData.fromJson(
            entry['op'] as Map<String, dynamic>,
          ).toCompanion(true),
        );
      }
      for (final entry in saved) {
        final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
        if (op.status == syncConflict) {
          if (op.entityType == 'patient') {
            await db.markPatientConflict(op.entityId, true);
          } else {
            await db.markDiagnosisConflict(op.entityId, true);
            await db.updateDiagnosisSaveStatus(op.entityId, 'conflict');
          }
        } else if (op.entityType == 'diagnosis' &&
            op.status == syncPermanentFailure) {
          await db.updateDiagnosisSaveStatus(op.entityId, 'failed');
        }
      }
    });
  }

  Future<void> remove(String opId) => db.deleteSetting('$prefix$opId');
}
