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

  Future<SyncReport> push({void Function(int, int)? onProgress}) async {
    if (_running) throw StateError('Sync is already running');
    _running = true;
    try {
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
      var applied = 0, skipped = 0, conflict = 0, failed = 0, done = 0;
      for (final entry in entries) {
        current();
        final op = SyncQueueData.fromJson(entry['op'] as Map<String, dynamic>);
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
            await outbox.save(entry);
            current();
          }
          if (op.entityType == 'diagnosis' &&
              op.operation == 'create' &&
              entry['artifact'] != null) {
            final artifact = EncryptedXrayArtifact.fromJson(
              entry['artifact'] as Map<String, dynamic>,
            );
            if (artifact.tenantId != actor.tenantId ||
                artifact.userId != op.userId ||
                artifact.deviceId != op.deviceId ||
                artifact.id != op.entityId) {
              throw const FormatException('Archived image ownership mismatch');
            }
            final image = await xray.decodeArtifact(artifact);
            current();
            await _upload(
              op.entityId,
              image.bytes,
              image.checksumSha256,
              current,
            );
          }
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
      return SyncReport(
        applied: applied,
        skipped: skipped,
        conflicts: conflict,
        failed: failed,
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _upload(
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
      return;
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
  }
}
