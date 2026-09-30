import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'package:myapp/domain/models/xray_image.dart';

class DiagnosisRequestValidationException implements Exception {
  const DiagnosisRequestValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Immutable, versioned request built at the provider/repository boundary.
///
/// The current backend consumes [image] and ignores the additional multipart
/// metadata until BE-08 lands. Keeping the typed snapshot in the same request
/// prevents Result and persistence from reading mutable form state later.
class DiagnosisInferenceRequest {
  DiagnosisInferenceRequest._({
    required DiagnosisDraft draft,
    required this.deviceId,
  }) : draft = draft.copyWith(),
       image = draft.image!;

  factory DiagnosisInferenceRequest.fromDraft({
    required DiagnosisDraft draft,
    required String deviceId,
  }) {
    if (!draft.hasRequiredDemographics) {
      throw const DiagnosisRequestValidationException(
        'Complete the required patient information before analysis.',
      );
    }
    if (draft.image == null || draft.image!.isEmpty) {
      throw const DiagnosisRequestValidationException(
        'Select or capture a chest X-ray before analysis.',
      );
    }
    if (deviceId.trim().isEmpty) {
      throw const DiagnosisRequestValidationException(
        'This device is not registered for clinical inference.',
      );
    }
    return DiagnosisInferenceRequest._(draft: draft, deviceId: deviceId);
  }

  final DiagnosisDraft draft;
  final XrayImage image;
  final String deviceId;

  Map<String, dynamic> toJson() => {
    'contract_version': 1,
    'patient': draft.toPatientSnapshot(),
    'clinical': draft.toClinicalSnapshot(deviceId: deviceId),
  };
}
