import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:cryptography/cryptography.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';

/// Device handoff storage, separate from every account's visible clinical cache.
/// Only ciphertext survives logout. All reads require an explicit tenant/device.
class DeviceOperatorOutbox {
  DeviceOperatorOutbox(this.db, this.storage);
  final AppDatabase db;
  final SecureTokenStorage storage;
  final _aes = AesGcm.with256bits();
  static const prefix = 'device_operator_outbox_v1:';
  static const _keyName = 'device_operator_outbox_aes_v1';
  Future<SecretKey> _key({bool create = false}) async {
    final raw = await storage.read(_keyName);
    if (raw != null) {
      final bytes = base64Decode(raw);
      if (bytes.length != 32) throw StateError('Invalid outbox key');
      return SecretKey(bytes);
    }
    final existing = await (db.select(
      db.appSettings,
    )..where((t) => t.key.like('$prefix%'))).get();
    if (!create || existing.isNotEmpty) {
      throw StateError(
        'Outbox encryption key unavailable; queued work retained',
      );
    }
    final key = await _aes.newSecretKey();
    await storage.write(_keyName, base64Encode(await key.extractBytes()));
    return key;
  }

  Future<void> save(Map<String, dynamic> entry) async {
    final id = (entry['op'] as Map)['clientOpId'] as String;
    final key = await _key(create: true);
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(entry)),
      secretKey: key,
    );
    await db.putSetting(
      '$prefix$id',
      jsonEncode({
        'cipher': base64Encode(box.cipherText),
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
      }),
    );
  }

  Future<List<Map<String, dynamic>>> entries(
    String tenantId,
    String deviceId, {
    String? ownerId,
  }) async {
    final rows = await (db.select(
      db.appSettings,
    )..where((t) => t.key.like('$prefix%'))).get();
    if (rows.isEmpty) return [];
    final key = await _key();
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final box = jsonDecode(row.value) as Map<String, dynamic>;
      final clear = await _aes.decrypt(
        SecretBox(
          base64Decode(box['cipher'] as String),
          nonce: base64Decode(box['nonce'] as String),
          mac: Mac(base64Decode(box['mac'] as String)),
        ),
        secretKey: key,
      );
      final entry = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
      if (row.key != '$prefix${op.clientOpId}') {
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
        await save({
          'op': serialized,
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
    );
    await db.writeForSession(generation, () async {
      for (final entry in saved) {
        if (entry['patient'] != null) {
          await db.upsertPatient(
            LocalPatient.fromJson(
              entry['patient'] as Map<String, dynamic>,
            ).toCompanion(true),
          );
        }
        if (entry['diagnosis'] != null) {
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
