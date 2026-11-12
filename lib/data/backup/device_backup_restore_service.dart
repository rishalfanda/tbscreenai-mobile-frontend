import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

import 'package:myapp/core/utils/uuid.dart';
import 'package:myapp/data/backup/backup_restore_models.dart';
import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/local/app_database.dart';
import 'package:myapp/data/offline/device_operator_outbox.dart';
import 'package:myapp/data/secure/secure_token_storage.dart';
import 'package:myapp/domain/models/user_profile.dart';

typedef BackupActorReader = UserProfile? Function();
typedef LocalDeviceIdReader = Future<String> Function();

/// Implements the deployed backup/restore contract without inventing local
/// success. A backup is accepted only after every local record is synced. A
/// restore is accepted only on an empty device and is archived per clinician,
/// so technician data can never become visible as that technician's data.
class DeviceBackupRestoreService {
  DeviceBackupRestoreService({
    required ApiClient client,
    required AppDatabase db,
    required DeviceOperatorOutbox outbox,
    required SecureTokenStorage secureStorage,
    required BackupActorReader actor,
    required LocalDeviceIdReader localDeviceId,
  }) : _client = client,
       _db = db,
       _outbox = outbox,
       _secureStorage = secureStorage,
       _actor = actor,
       _localDeviceId = localDeviceId;

  static const _xrayKeyName = 'clinical_xray_aes_key_v1';
  static const _restoreStageKey = 'backup_restore_staged_v1';

  final ApiClient _client;
  final AppDatabase _db;
  final DeviceOperatorOutbox _outbox;
  final SecureTokenStorage _secureStorage;
  final BackupActorReader _actor;
  final LocalDeviceIdReader _localDeviceId;

  bool _busy = false;
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    if (_busy) {
      throw const BackupRestoreException(
        'Operasi backup/restore masih berjalan.',
      );
    }
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }

  Future<BackupResult> createBackup() => _exclusive(_createBackup);
  Future<RestoreResult> restorePending() => _exclusive(_restorePending);

  Future<BackupResult> _createBackup() async {
    final context = await _context();
    final archived = await _outbox.entries(
      context.tenantId,
      context.localDeviceId,
      includeReceived: true,
    );
    await _assertCurrent(context);
    final pendingDb = await _db.pendingOps();
    final unsynced = archived.where((entry) {
      final op = (entry['op'] as Map).cast<String, dynamic>();
      if (op['status'] != syncSynced) return true;
      if (op['entityType'] != 'diagnosis') return false;
      final artifact = (entry['artifact'] as Map?)?.cast<String, dynamic>();
      if (artifact != null) {
        final receipt = (entry['image_receipt'] as Map?)
            ?.cast<String, dynamic>();
        if (entry['xray_synced'] != true ||
            receipt?['sha256'] != artifact['checksum'] ||
            receipt?['size_bytes'] != artifact['sizeBytes']) {
          return true;
        }
      }
      for (final raw in entry['segmentation_artifacts'] as List? ?? const []) {
        final overlay = (raw as Map).cast<String, dynamic>();
        final id = overlay['id'] as String? ?? '';
        final flag = id.endsWith(':lung')
            ? 'lung_map_synced'
            : id.endsWith(':lesion')
            ? 'heatmap_synced'
            : null;
        if (flag != null && entry[flag] != true) return true;
      }
      return false;
    }).length;
    if (pendingDb.isNotEmpty || unsynced > 0) {
      throw const BackupRestoreException(
        'Sinkronkan seluruh data dokter sebelum membuat backup.',
      );
    }

    final patients = <String, int>{};
    final diagnoses = <String, ({int version, String? checksum})>{};
    final diagnosedPatientIds = <String>{};
    for (final entry in archived) {
      final patient = (entry['patient'] as Map?)?.cast<String, dynamic>();
      final diagnosis = (entry['diagnosis'] as Map?)?.cast<String, dynamic>();
      if (patient != null) {
        final id = patient['id'] as String?;
        final version = patient['serverVersion'] as int?;
        if (id == null || version == null || version < 1) {
          throw const BackupRestoreException(
            'Backup ditolak: versi pasien lokal belum terkonfirmasi server.',
          );
        }
        patients[id] = version;
      }
      if (diagnosis != null) {
        final id = diagnosis['id'] as String?;
        final version = diagnosis['serverVersion'] as int?;
        if (id == null || version == null || version < 1) {
          throw const BackupRestoreException(
            'Backup ditolak: versi skrining lokal belum terkonfirmasi server.',
          );
        }
        final checksum = diagnosis['imageChecksum'] as String?;
        diagnoses[id] = (version: version, checksum: checksum);
        final patientId = diagnosis['patientId'] as String?;
        if (patientId != null) diagnosedPatientIds.add(patientId);
      }
    }
    if (patients.isEmpty && diagnoses.isEmpty) {
      throw const BackupRestoreException(
        'Tidak ada data tersinkron untuk dibackup.',
      );
    }
    if (patients.keys.any((id) => !diagnosedPatientIds.contains(id))) {
      throw const BackupRestoreException(
        'Backup ditolak: ada pasien tanpa skrining sehingga pemilik restore tidak dapat diverifikasi.',
      );
    }

    await _assertCurrent(context);
    final started = await _jsonRequest(
      'POST',
      '/backups',
      data: {
        'client_utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      },
    );
    final backupId = started['backup_id'] as String?;
    if (backupId == null) {
      throw const BackupRestoreException(
        'Server tidak mengembalikan ID backup.',
      );
    }
    await _assertCurrent(context);
    final completed = await _jsonRequest(
      'PUT',
      '/backups/$backupId/manifest',
      data: {
        'format': 1,
        'patients': [
          for (final item in patients.entries)
            {'id': item.key, 'version': item.value},
        ],
        'diagnoses': [
          for (final item in diagnoses.entries)
            {
              'id': item.key,
              'version': item.value.version,
              if (item.value.checksum != null)
                'image_sha256': item.value.checksum,
            },
        ],
      },
    );
    final result = BackupResult.fromJson(completed);
    if (result.status != 'complete') {
      throw BackupRestoreException(
        'Backup belum lengkap (${result.problemCount} masalah). Sinkronkan lalu coba lagi.',
      );
    }
    return result;
  }

  Future<RestorePlanSummary?> pendingRestore() async {
    final context = await _context();
    final staged = await _readStage();
    await _assertCurrent(context);
    if (staged != null) {
      if (staged['tenant_id'] != context.tenantId ||
          staged['registered_device_id'] != context.registeredDeviceId ||
          staged['local_device_id'] != context.localDeviceId) {
        throw const BackupRestoreException(
          'Restore tertunda terikat ke perangkat atau tenant lain.',
        );
      }
      return RestorePlanSummary(
        restoreId: staged['restore_id'] as String,
        backupName: 'Restore tersimpan - lanjutkan konfirmasi',
        recordsExpected: (staged['records_restored'] as num).toInt(),
        imagesToDownload: (staged['images_verified'] as num).toInt(),
      );
    }
    try {
      final plan = await _jsonRequest('GET', '/restores/pending');
      await _assertCurrent(context);
      return RestorePlanSummary(
        restoreId: plan['restore_id'] as String,
        backupName: plan['backup_name'] as String,
        recordsExpected: (plan['records_expected'] as num).toInt(),
        imagesToDownload: (plan['images_to_download'] as num).toInt(),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<RestoreResult> _restorePending() async {
    final context = await _context();
    Map<String, dynamic>? plan;
    var locallyApplied = false;
    try {
      final staged = await _readStage();
      if (staged != null) return _finishStaged(context, staged);
      await _ensureEmpty(context);
      plan = await _jsonRequest('GET', '/restores/pending');
      await _assertCurrent(context);
      final restoreId = plan['restore_id'] as String;
      final snapshotDescriptor = (plan['snapshot'] as Map)
          .cast<String, dynamic>();
      final snapshotBytes = await _download(
        _trustedRestoreUrl(
          snapshotDescriptor['url'] as String,
          restoreId: restoreId,
          leaf: 'snapshot',
        ),
        expectedSha256: snapshotDescriptor['sha256'] as String?,
        expectedSize: (snapshotDescriptor['size_bytes'] as num?)?.toInt(),
      );
      await _assertCurrent(context);
      final decoded = jsonDecode(utf8.decode(snapshotBytes));
      if (decoded is! Map) {
        throw const BackupRestoreException(
          'Format snapshot backup tidak valid.',
        );
      }
      final snapshot = decoded.cast<String, dynamic>();
      if (snapshot['format'] != 1 ||
          snapshot['tenant_id'] != context.tenantId ||
          snapshot['backup_id'] != plan['backup_id']) {
        throw const BackupRestoreException(
          'Identitas snapshot backup tidak cocok.',
        );
      }

      final patients = _mapList(snapshot['patients'], 'patients');
      final diagnoses = _mapList(snapshot['diagnoses'], 'diagnoses');
      final imageLinks = _mapList(snapshot['images'], 'images');
      final expected = (plan['records_expected'] as num).toInt();
      if (patients.length + diagnoses.length != expected) {
        throw const BackupRestoreException(
          'Jumlah record snapshot tidak cocok.',
        );
      }

      final patientById = {
        for (final patient in patients) patient['id'] as String: patient,
      };
      for (final patient in patients) {
        if (patient['tenant_id'] != context.tenantId) {
          throw const BackupRestoreException(
            'Tenant pasien pada snapshot tidak cocok.',
          );
        }
      }
      for (final diagnosis in diagnoses) {
        if (diagnosis['tenant_id'] != context.tenantId ||
            diagnosis['created_by'] is! String ||
            (diagnosis['created_by'] as String).isEmpty ||
            !patientById.containsKey(diagnosis['patient_id'])) {
          throw const BackupRestoreException(
            'Snapshot tidak memiliki tenant, pemilik dokter, atau pasien yang valid.',
          );
        }
      }
      final restoredPatientIds = diagnoses.map((d) => d['patient_id']).toSet();
      if (patients.any((p) => !restoredPatientIds.contains(p['id']))) {
        throw const BackupRestoreException(
          'Backup memiliki pasien tanpa skrining; pemilik datanya tidak dapat diverifikasi.',
        );
      }
      final autoImages = <String, _DownloadedImage>{};
      final imagePlan = _mapList(plan['images'], 'restore images');
      final imagePlanById = <String, Map<String, dynamic>>{};
      for (final image in imagePlan) {
        final id = image['image_id'] as String;
        if (imagePlanById.containsKey(id)) {
          throw const BackupRestoreException(
            'Rencana restore memiliki gambar duplikat.',
          );
        }
        imagePlanById[id] = image;
        final bytes = await _download(
          _trustedRestoreUrl(
            image['url'] as String,
            restoreId: restoreId,
            leaf: 'images/$id',
          ),
          expectedSha256: image['sha256'] as String?,
          expectedSize: (image['size_bytes'] as num?)?.toInt(),
        );
        await _assertCurrent(context);
        autoImages[id] = _DownloadedImage(
          bytes: bytes,
          checksum: image['sha256'] as String,
          mediaType:
              image['media_type'] as String? ?? 'application/octet-stream',
        );
      }

      final imageByDiagnosis =
          <String, ({String id, String checksum, String mediaType})>{};
      final linkedImageIds = <String>{};
      for (final link in imageLinks) {
        final imageId = link['image_id'] as String;
        final diagnosisId = link['diagnosis_id'] as String;
        final planned = imagePlanById[imageId];
        if (planned == null ||
            !diagnoses.any((item) => item['id'] == diagnosisId) ||
            link['stored_sha256'] != planned['sha256'] ||
            link['size_bytes'] != planned['size_bytes'] ||
            (planned['media_type'] != null &&
                link['media_type'] != planned['media_type'])) {
          throw const BackupRestoreException(
            'Metadata gambar snapshot tidak cocok dengan rencana restore.',
          );
        }
        linkedImageIds.add(imageId);
        final downloaded = autoImages[imageId];
        if (downloaded != null) {
          imageByDiagnosis[diagnosisId] = (
            id: imageId,
            checksum: downloaded.checksum,
            mediaType: downloaded.mediaType,
          );
        }
      }
      if (linkedImageIds.length != imagePlanById.length) {
        throw const BackupRestoreException(
          'Rencana restore memiliki gambar yang tidak terhubung ke skrining.',
        );
      }

      await _assertCurrent(context);
      await _db.transaction(() async {
        for (final diagnosis in diagnoses) {
          await _assertCurrent(context);
          final owner = diagnosis['created_by'] as String;
          final patient = patientById[diagnosis['patient_id']]!;
          final diagnosisId = diagnosis['id'] as String;
          final image = imageByDiagnosis[diagnosisId];
          Map<String, dynamic>? artifact;
          if (image != null) {
            final downloaded = autoImages[image.id]!;
            artifact = await _encryptedArtifact(
              id: diagnosisId,
              ownerId: owner,
              context: context,
              image: _DownloadedImage(
                bytes: downloaded.bytes,
                checksum: downloaded.checksum,
                mediaType: image.mediaType,
              ),
            );
          }
          final localPatient = _localPatient(
            patient,
            owner,
            context.localDeviceId,
          );
          final localDiagnosis = _localDiagnosis(
            diagnosis,
            owner,
            context.localDeviceId,
            patient,
            image?.checksum,
          );
          final now = DateTime.now().toUtc();
          await _assertCurrent(context);
          await _outbox.retainReceived({
            'op': SyncQueueData(
              clientOpId: uuidV4(),
              entityType: 'diagnosis',
              entityId: diagnosisId,
              tenantId: context.tenantId,
              userId: owner,
              deviceId: context.localDeviceId,
              operation: 'update',
              payload: '{}',
              baseVersion: (diagnosis['version'] as num).toInt(),
              baseUpdatedAt: DateTime.tryParse(
                diagnosis['updated_at'] as String? ?? '',
              ),
              status: syncSynced,
              retryCount: 0,
              createdAt: now,
              syncedAt: now,
            ).toJson(),
            'patient': localPatient,
            'diagnosis': localDiagnosis,
            'artifact': ?artifact,
            if (artifact != null) ...{
              'xray_synced': true,
              'image_receipt': {
                'sha256': artifact['checksum'],
                'size_bytes': artifact['sizeBytes'],
              },
            },
            'restored_from_backup': true,
          });
        }
        await _assertCurrent(context);
        await _db.putSetting(
          _restoreStageKey,
          jsonEncode({
            'restore_id': restoreId,
            'tenant_id': context.tenantId,
            'registered_device_id': context.registeredDeviceId,
            'local_device_id': context.localDeviceId,
            'records_restored': expected,
            'images_verified': autoImages.length,
          }),
        );
      });
      locallyApplied = true;
      return _finishStaged(context, (await _readStage())!);
    } catch (error) {
      final id = plan?['restore_id'] as String?;
      if (id != null && !locallyApplied) {
        try {
          await _assertCurrent(context);
          await _jsonRequest(
            'POST',
            '/restores/$id/fail',
            data: {
              'reason': _message(
                error,
              ).substring(0, _message(error).length.clamp(1, 500)),
            },
          );
        } catch (_) {
          // The original verified failure remains the actionable error.
        }
      }
      if (error is BackupRestoreException || error is DioException) rethrow;
      throw BackupRestoreException(_message(error));
    }
  }

  Future<_DeviceContext> _context() async {
    final actor = _actor();
    if (actor == null || actor.role != 'technician') {
      throw const BackupRestoreException(
        'Hanya teknisi yang dapat backup atau restore.',
      );
    }
    final device = await _client.deviceIdentity.read();
    if (device == null || device.tenantId != actor.tenantId) {
      throw const BackupRestoreException(
        'Identitas perangkat atau tenant tidak valid.',
      );
    }
    final localDeviceId = await _localDeviceId();
    if (localDeviceId.isEmpty) {
      throw const BackupRestoreException('ID lokal perangkat tidak tersedia.');
    }
    return _DeviceContext(
      tenantId: actor.tenantId,
      userId: actor.userId,
      registeredDeviceId: device.id,
      localDeviceId: localDeviceId,
      sessionGeneration: _db.sessionGeneration,
    );
  }

  Future<void> _ensureEmpty(_DeviceContext context) async {
    if ((await _db.allPatients()).isNotEmpty ||
        (await _db.allDiagnoses()).isNotEmpty ||
        (await _db.pendingOps()).isNotEmpty ||
        (await _outbox.entries(
          context.tenantId,
          context.localDeviceId,
          includeReceived: true,
        )).isNotEmpty) {
      throw const BackupRestoreException(
        'Restore hanya dapat dilakukan pada perangkat kosong tanpa antrean kerja.',
      );
    }
  }

  Future<void> _assertCurrent(_DeviceContext expected) async {
    final actor = _actor();
    final device = await _client.deviceIdentity.read();
    final local = await _localDeviceId();
    if (_db.sessionGeneration != expected.sessionGeneration ||
        actor?.role != 'technician' ||
        actor?.userId != expected.userId ||
        actor?.tenantId != expected.tenantId ||
        device?.id != expected.registeredDeviceId ||
        device?.tenantId != expected.tenantId ||
        local != expected.localDeviceId) {
      throw const BackupRestoreException(
        'Sesi atau identitas perangkat berubah. Operasi dihentikan.',
      );
    }
  }

  Future<Map<String, dynamic>?> _readStage() async {
    final raw = await _db.getSetting(_restoreStageKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const BackupRestoreException('Status restore lokal rusak.');
    }
    return decoded.cast<String, dynamic>();
  }

  Future<RestoreResult> _finishStaged(
    _DeviceContext context,
    Map<String, dynamic> staged,
  ) async {
    if (staged['tenant_id'] != context.tenantId ||
        staged['registered_device_id'] != context.registeredDeviceId ||
        staged['local_device_id'] != context.localDeviceId) {
      throw const BackupRestoreException(
        'Restore tertunda terikat ke perangkat atau tenant lain.',
      );
    }
    final restoreId = staged['restore_id'] as String;
    final records = (staged['records_restored'] as num).toInt();
    final images = (staged['images_verified'] as num).toInt();
    await _assertCurrent(context);
    final finish = await _jsonRequest(
      'POST',
      '/restores/$restoreId/complete',
      data: {'records_restored': records, 'images_verified': images},
    );
    if (finish['status'] != 'completed') {
      throw const BackupRestoreException('Server belum mengonfirmasi restore.');
    }
    await _assertCurrent(context);
    await _db.deleteSetting(_restoreStageKey);
    return RestoreResult(
      restoreId: restoreId,
      recordsRestored: records,
      imagesVerified: images,
    );
  }

  String _trustedRestoreUrl(
    String raw, {
    required String restoreId,
    required String leaf,
  }) {
    final base = Uri.parse(_client.baseUrl);
    final resolved = base.resolve(raw);
    final apiPrefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final expectedPath = '$apiPrefix/restores/$restoreId/$leaf';
    if (resolved.scheme != base.scheme ||
        resolved.host != base.host ||
        resolved.port != base.port ||
        resolved.userInfo.isNotEmpty ||
        resolved.query.isNotEmpty ||
        resolved.fragment.isNotEmpty ||
        resolved.path != expectedPath ||
        resolved.path.contains('/../')) {
      throw const BackupRestoreException(
        'URL download restore tidak dipercaya.',
      );
    }
    return resolved.toString();
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    Object? data,
  }) async {
    final response = await _client.dio.request<Object?>(
      path,
      data: data,
      options: Options(method: method),
    );
    if (response.data is! Map) {
      throw const BackupRestoreException('Respons server backup tidak valid.');
    }
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Uint8List> _download(
    String path, {
    required String? expectedSha256,
    required int? expectedSize,
  }) async {
    if (expectedSha256 == null || expectedSha256.length != 64) {
      throw const BackupRestoreException(
        'Checksum file restore tidak tersedia.',
      );
    }
    final response = await _client.dio.get<List<int>>(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: false,
      ),
    );
    final bytes = Uint8List.fromList(response.data ?? const []);
    final digest = await Sha256().hash(bytes);
    final actual = digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    if (actual.toLowerCase() != expectedSha256.toLowerCase() ||
        (expectedSize != null && bytes.length != expectedSize)) {
      throw const BackupRestoreException(
        'Integritas file restore gagal diverifikasi.',
      );
    }
    return bytes;
  }

  List<Map<String, dynamic>> _mapList(Object? raw, String label) {
    if (raw is! List || raw.any((item) => item is! Map)) {
      throw BackupRestoreException('Daftar $label pada backup tidak valid.');
    }
    return raw.map((item) => (item as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> _encryptedArtifact({
    required String id,
    required String ownerId,
    required _DeviceContext context,
    required _DownloadedImage image,
  }) async {
    final encodedKey = await _secureStorage.read(_xrayKeyName);
    SecretKey key;
    if (encodedKey == null) {
      key = await AesGcm.with256bits().newSecretKey();
      await _secureStorage.write(
        _xrayKeyName,
        base64Encode(await key.extractBytes()),
      );
    } else {
      final bytes = base64Decode(encodedKey);
      if (bytes.length != 32) {
        throw const BackupRestoreException('Kunci enkripsi X-ray rusak.');
      }
      key = SecretKey(bytes);
    }
    final box = await AesGcm.with256bits().encrypt(image.bytes, secretKey: key);
    return EncryptedXrayArtifact(
      id: id,
      cipherText: Uint8List.fromList(box.cipherText),
      nonce: Uint8List.fromList(box.nonce),
      mac: Uint8List.fromList(box.mac.bytes),
      filename: '$id.${_extension(image.mediaType)}',
      mimeType: image.mediaType,
      source: 'gallery',
      checksum: image.checksum,
      sizeBytes: image.bytes.length,
      createdAt: DateTime.now().toUtc(),
      tenantId: context.tenantId,
      userId: ownerId,
      deviceId: context.localDeviceId,
    ).toJson();
  }

  Map<String, dynamic> _localPatient(
    Map<String, dynamic> patient,
    String owner,
    String deviceId,
  ) {
    final raw = <String, dynamic>{
      'id': patient['id'],
      'code': patient['code'],
      'name': patient['name'],
      'age': patient['age'],
      'gender': patient['gender'],
      'status': patient['status'] ?? 'Normal',
      'confidence': patient['confidence'],
      'lastVisit': patient['last_visit'],
      'history': jsonEncode(patient['history'] ?? const []),
      'tenantId': patient['tenant_id'],
      'userId': owner,
      'deviceId': deviceId,
      'serverVersion': patient['version'],
      'tombstone': patient['deleted_at'] != null,
      'updatedAt': patient['updated_at'],
      'hasConflict': false,
    };
    return LocalPatient.fromJson(raw).toJson();
  }

  Map<String, dynamic> _localDiagnosis(
    Map<String, dynamic> diagnosis,
    String owner,
    String deviceId,
    Map<String, dynamic> patient,
    String? checksum,
  ) {
    final raw = <String, dynamic>{
      'id': diagnosis['id'],
      'patientId': diagnosis['patient_id'],
      'isPositive': diagnosis['is_positive'],
      'confidence': diagnosis['confidence'],
      'modelVersion': diagnosis['model_version'],
      'processingTimeMs': diagnosis['processing_time_ms'],
      'findings': jsonEncode(diagnosis['findings'] ?? const {}),
      'status': diagnosis['status'] ?? 'pending',
      'doctorNote': diagnosis['doctor_note'],
      'lesionRating': diagnosis['lesion_rating'],
      'validationDeletedAt': diagnosis['validation_deleted_at'],
      'validationDeletedBy': diagnosis['validation_deleted_by'],
      'validationScore': diagnosis['validation_score'],
      'validatedBy': diagnosis['validated_by'],
      'validatedAt': diagnosis['validated_at'],
      'diagnosedAt': diagnosis['diagnosed_at'],
      'updatedAt': diagnosis['updated_at'],
      'hasConflict': false,
      'tenantId': diagnosis['tenant_id'],
      'userId': owner,
      'deviceId': deviceId,
      'serverVersion': diagnosis['version'],
      'tombstone': false,
      'imageChecksum': checksum,
      'imageReference': checksum == null
          ? diagnosis['image_path']
          : 'local-encrypted://${diagnosis['id']}',
      'provenance': jsonEncode(diagnosis['provenance'] ?? const {}),
      'isMock':
          diagnosis['is_mock'] == true ||
          (diagnosis['model_version'] as String).startsWith('mock-'),
      'patientSnapshot': jsonEncode({
        'patient_id': patient['id'],
        'patient_code': patient['code'],
        'patient_name': patient['name'],
        'age': patient['age'],
        'gender': patient['gender'],
        'height_cm': (diagnosis['clinical'] as Map?)?['height_cm'],
        'weight_kg': (diagnosis['clinical'] as Map?)?['weight_kg'],
      }),
      'clinicalSnapshot': jsonEncode(diagnosis['clinical'] ?? const {}),
      'saveStatus': 'saved',
    };
    return LocalDiagnose.fromJson(raw).toJson();
  }

  String _extension(String mediaType) => switch (mediaType) {
    'image/png' => 'png',
    'image/jpeg' => 'jpg',
    'application/dicom' => 'dcm',
    _ => 'bin',
  };

  String _message(Object error) => error is BackupRestoreException
      ? error.message
      : error is DioException
      ? 'Server backup tidak dapat dihubungi (${error.response?.statusCode ?? 'network'}).'
      : error.toString();
}

class _DeviceContext {
  const _DeviceContext({
    required this.tenantId,
    required this.userId,
    required this.registeredDeviceId,
    required this.localDeviceId,
    required this.sessionGeneration,
  });
  final String tenantId;
  final String userId;
  final String registeredDeviceId;
  final String localDeviceId;
  final int sessionGeneration;
}

class _DownloadedImage {
  const _DownloadedImage({
    required this.bytes,
    required this.checksum,
    required this.mediaType,
  });
  final Uint8List bytes;
  final String checksum;
  final String mediaType;
}
