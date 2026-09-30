import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:myapp/data/http/api_client.dart';
import 'package:myapp/data/mock/mock_seed_data.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/diagnosis_inference_request.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';

/// Live inference against `POST /diagnoses/infer`.
///
/// This is the piece the clinical flow was missing. The endpoint has existed
/// on the backend since the API was built, but nothing on the tablet ever
/// called it — the repository contract could only pass a filename, so the
/// contract between the two sides had never actually been exercised.
///
/// The result is still produced by the backend's mock model. What is real now
/// is the whole path around it: multipart upload, signature validation, the
/// response shape, and the mapping into [DiagnosisOutcome].
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
    FormData buildForm() => FormData.fromMap({
      'image': MultipartFile.fromBytes(
        image.bytes,
        filename: image.filename,
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
      options: Options(extra: {requestBodyFactoryKey: buildForm}),
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
  );
}

double _percent(Object? value) => (value as num?)?.toDouble() ?? 0.0;
