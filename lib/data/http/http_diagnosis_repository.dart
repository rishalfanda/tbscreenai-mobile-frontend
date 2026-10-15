import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/diagnosis_inference_request.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';

/// Live inference against `POST /diagnoses/infer`.
///
class HttpDiagnosisRepository
    implements DiagnosisRepository, TypedDiagnosisRepository {
  HttpDiagnosisRepository(this._client);

  final ApiClient _client;

  /// Served from seed data: the backend exposes no symptom endpoint yet, and
  /// inventing one here would be guessing at an API that does not exist.
  @override
  Future<List<String>> getSymptomOptions() =>
      SynchronousFuture(List.unmodifiable(MockSeedData.symptomOptions));

  @override
  Future<DiagnosisOutcome> runInference({required XrayImage image}) =>
      _postInference(image: image);

  @override
  Future<DiagnosisOutcome> runTypedInference(
    DiagnosisInferenceRequest request,
  ) => _postInference(image: request.image, request: request);

  Future<DiagnosisOutcome> _postInference({
    required XrayImage image,
    DiagnosisInferenceRequest? request,
  }) async {
    if (image.sizeBytes > 25 * 1024 * 1024) {
      throw const DiagnosisRequestValidationException('Gambar maksimal 25 MB.');
    }
    if (image.format == XrayImageFormat.dicom) {
      throw const DiagnosisRequestValidationException(
        'Ekspor DICOM menjadi PNG/JPEG sebelum uji model backend.',
      );
    }
    final decoder = img.findDecoderForData(image.bytes);
    final info = decoder?.startDecode(image.bytes);
    if (info == null || info.width <= 0 || info.height <= 0) {
      throw const DiagnosisRequestValidationException(
        'Gambar tidak didukung. Pilih PNG/JPEG X-ray yang valid.',
      );
    }
    if (info.width * info.height > 20000000) {
      throw const DiagnosisRequestValidationException(
        'Gambar maksimal 20 juta pixel. Ekspor ulang dengan resolusi lebih kecil.',
      );
    }
    FormData buildForm() => FormData.fromMap({
      'image': MultipartFile.fromBytes(
        image.bytes,
        filename: image.format == XrayImageFormat.png ? 'xray.png' : 'xray.jpg',
        contentType: DioMediaType.parse(image.mimeType),
      ),
      if (request != null) ...{
        // Backend main@7ede475 currently ignores these extra form fields; they
        // are still sent and versioned so the frontend no longer loses the
        // reviewed snapshot while BE-08 formalizes them in OpenAPI.
        'contract_version': '1',
        'clinical_metadata': jsonEncode(request.toJson()),
      },
    });

    final response = await _client.dio.post<Map<String, dynamic>>(
      '/diagnoses/infer',
      data: buildForm(),
      options: Options(
        receiveTimeout: const Duration(minutes: 5),
        extra: {requestBodyFactoryKey: buildForm},
      ),
    );

    return _outcomeFromJson(response.data!);
  }
}

/// Maps the backend's InferenceResult onto the app's outcome model.
///
/// `processing_time_ms` becomes the display string the Result screen already
/// expects, so the rendering path is unchanged whether the outcome came from
/// the mock repository or the server.
DiagnosisOutcome _outcomeFromJson(Map<String, dynamic> json) {
  final isPositive = json['is_positive'];
  final confidence = json['confidence'];
  final modelVersion = json['model_version'];
  final isMock = json['is_mock'];
  if (isPositive is! bool ||
      confidence is! num ||
      !confidence.isFinite ||
      confidence < 0 ||
      confidence > 100 ||
      modelVersion is! String ||
      modelVersion.trim().isEmpty ||
      isMock is! bool) {
    throw const FormatException(
      'Inference response is missing required provenance fields.',
    );
  }
  final findings =
      (json['findings'] as Map?)?.cast<String, dynamic>() ?? const {};
  final processingValue = json['processing_time_ms'];
  if (processingValue is! num ||
      !processingValue.isFinite ||
      processingValue < 0) {
    throw const FormatException('Inference processing time is invalid.');
  }
  final processingMs = processingValue.toInt();

  return DiagnosisOutcome(
    isPositive: isPositive,
    confidence: confidence.toInt(),
    processingTime: '${(processingMs / 1000).toStringAsFixed(1)}s',
    processingTimeMs: processingMs,
    modelVersion: modelVersion,
    createdAt: DateTime.now(),
    isMock: isMock,
    consolidation: _percent(findings['consolidation']),
    cavity: _percent(findings['cavity']),
    effusion: _percent(findings['effusion']),
    fibrotic: _percent(findings['fibrotic']),
    calcification: _percent(findings['calcification']),
    infiltrate: _percent(findings['infiltrate']),
    imageId: _imageId(json['image_id']),
    provenance: _provenance(json['provenance']),
  );
}

double _percent(Object? value) {
  if (value == null) return 0;
  if (value is! num || !value.isFinite || value < 0 || value > 100) {
    throw const FormatException('Invalid finding percentage.');
  }
  return value.toDouble();
}

String? _imageId(Object? value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid image reference.');
  }
  return value;
}

Map<String, dynamic>? _provenance(Object? value) {
  if (value == null) return null;
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid model provenance.');
  }
  return Map.unmodifiable(value);
}
