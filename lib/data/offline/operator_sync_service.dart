import 'package:myapp/data/sync/validation_score_contract.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/local/encrypted_xray_store.dart';
import 'package:myapp/data/local/settings_store.dart';
import 'package:myapp/data/sync/sync_engine.dart';
import 'package:myapp/domain/models/access_scope.dart';
import 'package:myapp/state/auth_provider.dart';
import 'package:myapp/core/utils/uuid.dart';
import 'device_operator_outbox.dart';

class OperatorSyncService {
  OperatorSyncService({
    required this.db,
    required this.client,
    required this.outbox,
    required this.xray,
    required this.auth,
  });
  final AppDatabase db;
  final ApiClient client;
  final DeviceOperatorOutbox outbox;
  final EncryptedXrayStore xray;
  final AuthProvider auth;
  bool _running = false;
  Future<void>? _preparingImageRepairs;

  /// Re-check images retained by older APKs without replaying clinical edits.
  /// Old successful metadata receipts did not track X-ray/lung upload receipts.
  Future<void> prepareImageRepairs() {
    final running = _preparingImageRepairs;
    if (running != null) return running;
    final next = _prepareImageRepairs();
    _preparingImageRepairs = next;
    return next.whenComplete(() {
      if (identical(_preparingImageRepairs, next)) {
        _preparingImageRepairs = null;
      }
    });
  }

  Future<void> _prepareImageRepairs() async {
    final pending = await queued();
    final actor = auth.profile!;
    final generation = db.sessionGeneration;
    void current() {
      if (!identical(auth.profile, actor) ||
          generation != db.sessionGeneration) {
        throw StateError('Session changed');
      }
    }

    final device = await SettingsStore(db).readOrCreateDeviceId();
    final all = await outbox.entries(
      actor.tenantId,
      device,
      includeReceived: true,
    );
    current();
    final occupied = {
      for (final entry in pending)
        if ((entry['op'] as Map)['entityType'] == 'diagnosis')
          (entry['op'] as Map)['entityId'],
    };
    for (final entry in all) {
      final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
      if (op.status != syncSynced ||
          op.entityType != 'diagnosis' ||
          entry['retired'] == true ||
          entry['artifact'] == null ||
          occupied.contains(op.entityId)) {
        continue;
      }
      final artifact = entry['artifact'] as Map;
      final receipt = entry['image_receipt'] as Map?;
      final missingXray =
          entry['xray_synced'] != true ||
          receipt?['sha256'] != artifact['checksum'] ||
          receipt?['size_bytes'] != artifact['sizeBytes'];
      var missing = missingXray;
      for (final raw in entry['segmentation_artifacts'] as List? ?? const []) {
        final id = (raw as Map)['id'];
        if (id == '${op.entityId}:lung' && entry['lung_map_synced'] != true ||
            id == '${op.entityId}:lesion' && entry['heatmap_synced'] != true) {
          missing = true;
        }
      }
      if (!missing) continue;
      current();
      await outbox.save({
        ...entry,
        'record_synced': true,
        if (missingXray) 'xray_synced': false,
        'op': {
          ...op.toJson(),
          'clientOpId': uuidV4(),
          'status': syncPending,
          'operation': 'create',
          'payload': '{}',
        },
      });
      current();
      occupied.add(op.entityId);
    }
  }

  Future<List<Map<String, dynamic>>> queued() async {
    if (!auth.isLoggedIn ||
        auth.mustChangePassword ||
        auth.mobileRole != MobileRole.technician) {
      throw StateError('Technician session required');
    }
    final actor = auth.profile;
    final generation = db.sessionGeneration;
    final device = await SettingsStore(db).readOrCreateDeviceId();
    final entries = await outbox.entries(auth.tenantId, device);
    if (!identical(auth.profile, actor) || generation != db.sessionGeneration) {
      throw StateError('Session changed');
    }
    return entries;
  }

  Future<int> queuedCount() async => (await queueSummary()).total;

  Future<OperatorQueueSummary> queueSummary() async {
    if (!auth.isLoggedIn ||
        auth.mustChangePassword ||
        auth.mobileRole != MobileRole.technician) {
      throw StateError('Technician session required');
    }
    final actor = auth.profile;
    final generation = db.sessionGeneration;
    final device = await SettingsStore(db).readOrCreateDeviceId();
    final count = await outbox.summary(auth.tenantId, device);
    if (!identical(auth.profile, actor) || generation != db.sessionGeneration) {
      throw StateError('Session changed');
    }
    return count;
  }

  Future<SyncReport> push({
    void Function(int, int)? onProgress,
    bool refreshCache = true,
  }) async {
    if (_running) throw StateError('Sync is already running');
    _running = true;
    try {
      await prepareImageRepairs();
      final entries = await queued();
      final actor = auth.profile!;
      final generation = db.sessionGeneration;
      void current() {
        if (!auth.isLoggedIn ||
            !identical(auth.profile, actor) ||
            generation != db.sessionGeneration) {
          throw StateError('Session changed');
        }
      }

      final registered = await client.deviceIdentity.read();
      current();
      if (registered == null || registered.tenantId != actor.tenantId) {
        throw StateError(
          'Activate this tablet and sign in again before syncing',
        );
      }
      entries.sort((a, b) {
        final x = SyncQueueData.fromJson(a['op'] as Map<String, dynamic>),
            y = SyncQueueData.fromJson(b['op'] as Map<String, dynamic>);
        final type = (x.entityType == 'patient' ? 0 : 1).compareTo(
          y.entityType == 'patient' ? 0 : 1,
        );
        if (type != 0) return type;
        final operation = (x.operation == 'create' ? 0 : 1).compareTo(
          y.operation == 'create' ? 0 : 1,
        );
        return operation != 0 ? operation : x.createdAt.compareTo(y.createdAt);
      });
      var applied = 0,
          skipped = 0,
          conflict = 0,
          failed = 0,
          blocked = 0,
          done = 0;
      bool? scoreSupported, ratingSupported, lungMapSupported;
      for (final entry in entries) {
        current();
        final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
        final payload = jsonDecode(op.payload);
        if (op.operation == 'delete_validation' ||
            (payload is Map && payload.containsKey('lesion_rating'))) {
          ratingSupported ??= await supportsValidationScore(
            client,
            lesion: true,
          );
          current();
          if (!ratingSupported) {
            blocked++;
            onProgress?.call(++done, entries.length);
            continue;
          }
        }
        if (op.operation == 'update' &&
            payload is Map &&
            payload.containsKey('validation_score')) {
          scoreSupported ??= await supportsValidationScore(client);
          current();
          if (!scoreSupported) {
            blocked++;
            onProgress?.call(++done, entries.length);
            continue;
          }
        }
        if (op.status == syncBlockedContract ||
            op.operation == 'validate_score') {
          blocked++;
          onProgress?.call(++done, entries.length);
          continue;
        }
        if (op.status == syncConflict) {
          conflict++;
          onProgress?.call(++done, entries.length);
          continue;
        }
        if (op.status == syncPermanentFailure) {
          failed++;
          onProgress?.call(++done, entries.length);
          continue;
        }
        try {
          var resultStatus = 'skipped';
          if (entry['record_synced'] != true) {
            final response = await client.dio.post<Object?>(
              '/sync/operator/push',
              data: {
                'items': [
                  {
                    'client_op_id': op.clientOpId,
                    'entity_type': op.entityType,
                    'entity_id': op.entityId,
                    'operation': op.operation,
                    'owner_user_id': op.userId,
                    'payload': jsonDecode(op.payload),
                    if (op.baseVersion != null) 'base_version': op.baseVersion,
                    if (op.baseUpdatedAt != null)
                      'base_updated_at': op.baseUpdatedAt!
                          .toUtc()
                          .toIso8601String(),
                  },
                ],
              },
            );
            current();
            final data = response.data;
            if (data is! Map<String, dynamic> ||
                data['device_id'] != registered.id ||
                data['operator_user_id'] != actor.userId ||
                data['results'] is! List ||
                (data['results'] as List).length != 1) {
              throw const FormatException(
                'Operator response identity mismatch',
              );
            }
            final result = (data['results'] as List).single;
            if (result is! Map<String, dynamic> ||
                result['client_op_id'] != op.clientOpId ||
                ![
                  'applied',
                  'skipped',
                  'conflict',
                  'failed',
                ].contains(result['status']) ||
                (result['entity_id'] != null &&
                    result['entity_id'] != op.entityId) ||
                (result['entity_type'] != null &&
                    result['entity_type'] != op.entityType) ||
                [
                  result['op_version'],
                  result['server_version'],
                ].any((v) => v != null && (v is! int || v < 1)) ||
                (result['owner_user_id'] != null &&
                    result['owner_user_id'] != op.userId) ||
                (['applied', 'skipped'].contains(result['status']) &&
                    result['owner_user_id'] != op.userId)) {
              throw const FormatException('Invalid operator item result');
            }
            resultStatus = result['status'] as String;
            if (resultStatus == 'conflict' || resultStatus == 'failed') {
              final row = Map<String, dynamic>.from(entry['op'] as Map);
              row['status'] = resultStatus == 'conflict'
                  ? syncConflict
                  : syncPermanentFailure;
              row['detail'] = result['code'] is String
                  ? result['code']
                  : 'operator_refused';
              entry['op'] = row;
              await outbox.save(entry);
              current();
              if (resultStatus == 'conflict') {
                conflict++;
              } else {
                failed++;
              }
              onProgress?.call(++done, entries.length);
              continue;
            }
            entry['record_synced'] = true;
            outbox.applyReceipt(entry, result);
            await outbox.save(entry);
            current();
          }
          if (op.entityType == 'diagnosis' && op.operation == 'create') {
            // Upload the original first: an unavailable map endpoint must not
            // prevent the original screening image reaching the server.
            if (entry['artifact'] == null) {
              throw const FormatException('Original X-ray archive is missing.');
            }
            if (entry['xray_synced'] != true) {
              final artifact = EncryptedXrayArtifact.fromJson(
                (entry['artifact'] as Map).cast<String, dynamic>(),
              );
              _checkArtifact(artifact, op, actor.tenantId, op.entityId);
              final image = await xray.decodeArtifact(artifact);
              current();
              final receipt = await _upload(
                op.entityId,
                image.bytes,
                image.checksumSha256,
                current,
              );
              entry['xray_synced'] = true;
              entry['image_receipt'] = {
                ...receipt,
                'sha256': image.checksumSha256,
                'size_bytes': image.sizeBytes,
              };
              await outbox.save(entry);
              current();
            }
            var mapBlocked = false;
            for (final raw
                in entry['segmentation_artifacts'] as List? ?? const []) {
              final artifact = EncryptedXrayArtifact.fromJson(
                (raw as Map).cast<String, dynamic>(),
              );
              final isLung = artifact.id == '${op.entityId}:lung';
              if (!isLung && artifact.id != '${op.entityId}:lesion') continue;
              final flag = isLung ? 'lung_map_synced' : 'heatmap_synced';
              if (entry[flag] == true) continue;
              _checkArtifact(
                artifact,
                op,
                actor.tenantId,
                '${op.entityId}:${isLung ? 'lung' : 'lesion'}',
              );
              if (artifact.mimeType != 'image/png') {
                throw const FormatException('Map is not PNG.');
              }
              if (isLung) {
                lungMapSupported ??= await _supportsLungMap();
                current();
                if (!lungMapSupported) {
                  mapBlocked = true;
                  continue;
                }
              }
              final image = await xray.decodeArtifact(artifact);
              current();
              final receipt = (await client.dio.put<Object?>(
                '/diagnoses/${Uri.encodeComponent(op.entityId)}/${isLung ? 'lung-map' : 'heatmap'}',
                data: image.bytes,
                options: Options(
                  contentType: 'image/png',
                  headers: {'X-Content-SHA256': image.checksumSha256},
                ),
              )).data;
              current();
              if (receipt is! Map ||
                  receipt['diagnosis_id'] != op.entityId ||
                  receipt['sha256'] != image.checksumSha256 ||
                  receipt['size_bytes'] != image.sizeBytes ||
                  receipt['created'] is! bool) {
                throw const FormatException('Invalid segmentation receipt.');
              }
              entry[flag] = true;
              entry[isLung ? 'lung_map_receipt' : 'heatmap_receipt'] =
                  Map<String, dynamic>.from(receipt);
              await outbox.save(entry);
              current();
            }
            if (mapBlocked) {
              blocked++;
              onProgress?.call(++done, entries.length);
              continue;
            }
          }
          current();
          await outbox.retainReceived(entry);
          current();
          await outbox.remove(op.clientOpId);
          if (resultStatus == 'applied') {
            applied++;
          } else {
            skipped++;
          }
        } catch (_) {
          current();
          failed++;
        }
        onProgress?.call(++done, entries.length);
      }
      if (refreshCache) await _refreshCache(current);
      return SyncReport(
        applied: applied,
        skipped: skipped,
        conflicts: conflict,
        failed: failed,
        blocked: blocked,
      );
    } finally {
      _running = false;
    }
  }

  void _checkArtifact(
    EncryptedXrayArtifact artifact,
    SyncQueueData op,
    String tenantId,
    String expectedId,
  ) {
    if (artifact.id != expectedId ||
        artifact.tenantId != tenantId ||
        artifact.userId != op.userId ||
        artifact.deviceId != op.deviceId) {
      throw const FormatException('Archived image ownership mismatch');
    }
  }

  Future<bool> _supportsLungMap() async {
    try {
      final uri = Uri.parse(
        client.baseUrl,
      ).replace(path: '/openapi.json', query: '', fragment: '');
      final doc = (await client.dio.getUri<Object?>(
        uri,
        options: Options(
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 10),
        ),
      )).data;
      if (doc is! Map || doc['paths'] is! Map) return false;
      return (doc['paths'] as Map).entries.any(
        (entry) =>
            entry.key is String &&
            RegExp(
              r'/diagnoses/\{[^/]+\}/lung-map$',
            ).hasMatch(entry.key as String) &&
            entry.value is Map &&
            (entry.value as Map)['put'] is Map,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshCache(void Function() current) async {
    current();
    final device = await SettingsStore(db).readOrCreateDeviceId();
    final archived = await outbox.entries(
      auth.tenantId,
      device,
      includeReceived: true,
    );
    current();
    final patients = <String>{}, diagnoses = <String>{};
    for (final entry in archived) {
      final patient = (entry['patient'] as Map?)?['id'];
      final diagnosis = (entry['diagnosis'] as Map?)?['id'];
      if (patient is String) patients.add(patient);
      if (diagnosis is String) diagnoses.add(diagnosis);
    }
    final records = <String, Map<String, dynamic>>{};
    final gone = <String, String>{};
    final patientIds = patients.toList(), diagnosisIds = diagnoses.toList();
    for (
      var start = 0;
      start < max(patientIds.length, diagnosisIds.length);
      start += 500
    ) {
      final p = patientIds.skip(start).take(500).toList();
      final d = diagnosisIds.skip(start).take(500).toList();
      final requested = {
        for (final id in p) 'patient:$id',
        for (final id in d) 'diagnosis:$id',
      };
      final data = (await client.dio.post<Object?>(
        '/sync/operator/state',
        data: {'patient_ids': p, 'diagnosis_ids': d},
      )).data;
      current();
      if (data is! Map ||
          data['patients'] is! List ||
          data['diagnoses'] is! List ||
          data['gone'] is! List ||
          data['server_time'] is! String ||
          DateTime.tryParse(data['server_time'] as String) == null) {
        throw const FormatException('Invalid operator state');
      }
      final seen = <String>{};
      for (final kind in ['patient', 'diagnosis']) {
        for (final raw
            in data[kind == 'patient' ? 'patients' : 'diagnoses'] as List) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Invalid state record');
          }
          final key = '$kind:${raw['id']}';
          if (!requested.contains(key) ||
              !seen.add(key) ||
              raw['tenant_id'] != auth.tenantId ||
              raw['version'] is! int ||
              (raw['version'] as int) < 1 ||
              raw['updated_at'] is! String ||
              DateTime.tryParse(raw['updated_at'] as String) == null) {
            throw const FormatException('State record identity mismatch');
          }
          if (kind == 'diagnosis') {
            if (!patients.contains(raw['patient_id']) ||
                raw['is_positive'] is! bool ||
                raw['confidence'] is! int ||
                raw['model_version'] is! String ||
                raw['status'] is! String ||
                raw['findings'] is! Map ||
                (raw['lesion_rating'] != null &&
                    (raw['lesion_rating'] is! int ||
                        (raw['lesion_rating'] as int) < 0 ||
                        (raw['lesion_rating'] as int) > 10)) ||
                (raw['validation_deleted_at'] != null &&
                    (raw['validation_deleted_at'] is! String ||
                        DateTime.tryParse(
                              raw['validation_deleted_at'] as String,
                            ) ==
                            null)) ||
                (raw['validation_deleted_by'] != null &&
                    raw['validation_deleted_by'] is! String) ||
                (raw['validation_score'] != null &&
                    (raw['validation_score'] is! int ||
                        (raw['validation_score'] as int) < 0 ||
                        (raw['validation_score'] as int) > 10))) {
              throw const FormatException('Invalid diagnosis state');
            }
            // A server record may not rebind a retained doctor's diagnosis.
            for (final entry in archived) {
              final local = entry['diagnosis'] as Map?;
              if (local?['id'] == raw['id'] &&
                  (local?['patientId'] != raw['patient_id'] ||
                      (raw['created_by'] != null &&
                          raw['created_by'] != local?['userId']))) {
                throw const FormatException(
                  'Diagnosis state ownership mismatch',
                );
              }
            }
          } else if (raw['name'] is! String ||
              raw['code'] is! String ||
              raw['age'] is! int ||
              raw['gender'] is! String) {
            throw const FormatException('Invalid patient state');
          }
          records[key] = raw;
        }
      }
      for (final raw in data['gone'] as List) {
        if (raw is! Map) throw const FormatException('Invalid state tombstone');
        final key = '${raw['entity_type']}:${raw['id']}';
        if (!requested.contains(key) ||
            !seen.add(key) ||
            !['deleted', 'not_found'].contains(raw['reason'])) {
          throw const FormatException('Invalid state tombstone');
        }
        gone[key] = raw['reason'] as String;
      }
      if (seen.length != requested.length) {
        throw const FormatException('Incomplete operator state');
      }
    }
    final generation = db.sessionGeneration;
    await db.writeForSession(
      generation,
      () => outbox.reconcileState(archived, records, gone, current: current),
    );
    current();
  }

  Future<Map<String, dynamic>> _upload(
    String diagnosisId,
    Uint8List bytes,
    String checksum,
    void Function() current,
  ) async {
    const chunkSize = 1024 * 1024;
    final chunks = <Uint8List>[
      for (var start = 0; start < bytes.length; start += chunkSize)
        Uint8List.sublistView(
          bytes,
          start,
          min(start + chunkSize, bytes.length),
        ),
    ];
    final response = await client.dio.post<Object?>(
      '/blobs/init',
      data: {
        'diagnosis_id': diagnosisId,
        'size_bytes': bytes.length,
        'sha256': checksum,
        'chunk_size': chunkSize,
        'chunk_count': chunks.length,
        'chunk_sha256': chunks
            .map((b) => sha256.convert(b).toString())
            .toList(),
      },
    );
    current();
    final upload = response.data;
    if (upload is! Map<String, dynamic> ||
        upload['diagnosis_id'] != diagnosisId ||
        upload['size_bytes'] != bytes.length ||
        upload['chunk_count'] != chunks.length ||
        upload['chunk_size'] != chunkSize ||
        upload['upload_id'] is! String ||
        upload['received_chunks'] is! List) {
      throw const FormatException('Invalid image upload response');
    }
    if (upload['status'] == 'completed') {
      if (upload['image_id'] is! String) {
        throw const FormatException('Missing image receipt');
      }
      return upload;
    }
    if (upload['status'] != 'receiving') {
      throw StateError('Image upload unavailable');
    }
    final received = (upload['received_chunks'] as List).toSet();
    if (received.any((i) => i is! int || i < 0 || i >= chunks.length)) {
      throw const FormatException('Invalid received chunk indexes');
    }
    final id = Uri.encodeComponent(upload['upload_id'] as String);
    for (var i = 0; i < chunks.length; i++) {
      current();
      if (received.contains(i)) continue;
      await client.dio.put<void>(
        '/blobs/$id/chunks/$i',
        data: chunks[i],
        options: Options(contentType: 'application/octet-stream'),
      );
      current();
    }
    final complete = (await client.dio.post<Object?>(
      '/blobs/$id/complete',
    )).data;
    current();
    if (complete is! Map<String, dynamic> ||
        complete['diagnosis_id'] != diagnosisId ||
        complete['upload_id'] != upload['upload_id'] ||
        complete['status'] != 'completed' ||
        complete['image_id'] is! String) {
      throw const FormatException('Image completion was not confirmed');
    }
    return complete;
  }
}
