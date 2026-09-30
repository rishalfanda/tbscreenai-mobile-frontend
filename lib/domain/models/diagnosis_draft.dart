import 'package:myapp/domain/models/xray_image.dart';

/// Immutable snapshot of everything entered on the diagnosis form.
///
/// Keeping one draft prevents the form, camera route and result screen from
/// silently reading different values for the same examination.
class DiagnosisDraft {
  const DiagnosisDraft({
    this.patientId,
    this.patientCode,
    this.patientName = '',
    this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.symptoms = const <String>{},
    this.comorbidity,
    this.smoking,
    this.tbContact,
    this.pediatricScore,
    this.windowsPresence,
    this.sunlightExposure,
    this.bta,
    this.culture,
    this.xpert,
    this.igra,
    this.tbHistory,
    this.tbStatus,
    this.modelType,
    this.image,
  });

  /// Backend UUID selected from the patient cache. A typed clinical save is
  /// blocked when this is absent; a display name is never treated as identity.
  final String? patientId;
  final String? patientCode;
  final String patientName;
  final String? gender;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final Set<String> symptoms;
  final String? comorbidity;
  final String? smoking;
  final String? tbContact;
  final int? pediatricScore;
  final String? windowsPresence;
  final String? sunlightExposure;
  final String? bta;
  final String? culture;
  final String? xpert;
  final String? igra;
  final String? tbHistory;
  final String? tbStatus;
  final String? modelType;
  final XrayImage? image;

  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final meters = heightCm! / 100;
    return weightKg! / (meters * meters);
  }

  bool get requiresPediatricScore => age != null && age! < 18;

  bool get hasRequiredDemographics =>
      patientName.trim().isNotEmpty &&
      gender != null &&
      gender!.trim().isNotEmpty &&
      age != null &&
      age! > 0 &&
      heightCm != null &&
      heightCm!.isFinite &&
      heightCm! > 0 &&
      weightKg != null &&
      weightKg!.isFinite &&
      weightKg! > 0;

  bool get hasPatientReference => patientId?.trim().isNotEmpty == true;

  bool get canAnalyze =>
      hasRequiredDemographics && image != null && !image!.isEmpty;

  DiagnosisDraft copyWith({
    Object? patientId = _unset,
    Object? patientCode = _unset,
    String? patientName,
    Object? gender = _unset,
    Object? age = _unset,
    Object? heightCm = _unset,
    Object? weightKg = _unset,
    Set<String>? symptoms,
    Object? comorbidity = _unset,
    Object? smoking = _unset,
    Object? tbContact = _unset,
    Object? pediatricScore = _unset,
    Object? windowsPresence = _unset,
    Object? sunlightExposure = _unset,
    Object? bta = _unset,
    Object? culture = _unset,
    Object? xpert = _unset,
    Object? igra = _unset,
    Object? tbHistory = _unset,
    Object? tbStatus = _unset,
    Object? modelType = _unset,
    Object? image = _unset,
  }) {
    return DiagnosisDraft(
      patientId: identical(patientId, _unset)
          ? this.patientId
          : patientId as String?,
      patientCode: identical(patientCode, _unset)
          ? this.patientCode
          : patientCode as String?,
      patientName: patientName ?? this.patientName,
      gender: identical(gender, _unset) ? this.gender : gender as String?,
      age: identical(age, _unset) ? this.age : age as int?,
      heightCm: identical(heightCm, _unset)
          ? this.heightCm
          : heightCm as double?,
      weightKg: identical(weightKg, _unset)
          ? this.weightKg
          : weightKg as double?,
      symptoms: Set<String>.unmodifiable(symptoms ?? this.symptoms),
      comorbidity: identical(comorbidity, _unset)
          ? this.comorbidity
          : comorbidity as String?,
      smoking: identical(smoking, _unset) ? this.smoking : smoking as String?,
      tbContact: identical(tbContact, _unset)
          ? this.tbContact
          : tbContact as String?,
      pediatricScore: identical(pediatricScore, _unset)
          ? this.pediatricScore
          : pediatricScore as int?,
      windowsPresence: identical(windowsPresence, _unset)
          ? this.windowsPresence
          : windowsPresence as String?,
      sunlightExposure: identical(sunlightExposure, _unset)
          ? this.sunlightExposure
          : sunlightExposure as String?,
      bta: identical(bta, _unset) ? this.bta : bta as String?,
      culture: identical(culture, _unset) ? this.culture : culture as String?,
      xpert: identical(xpert, _unset) ? this.xpert : xpert as String?,
      igra: identical(igra, _unset) ? this.igra : igra as String?,
      tbHistory: identical(tbHistory, _unset)
          ? this.tbHistory
          : tbHistory as String?,
      tbStatus: identical(tbStatus, _unset)
          ? this.tbStatus
          : tbStatus as String?,
      modelType: identical(modelType, _unset)
          ? this.modelType
          : modelType as String?,
      image: identical(image, _unset) ? this.image : image as XrayImage?,
    );
  }

  Map<String, dynamic> toPatientSnapshot() => {
    'schema_version': 1,
    'patient_id': patientId,
    'patient_code': patientCode,
    'patient_name': patientName,
    'gender': gender,
    'age': age,
    'height_cm': heightCm,
    'weight_kg': weightKg,
  };

  Map<String, dynamic> toClinicalSnapshot({required String deviceId}) => {
    'schema_version': 1,
    'device_id': deviceId,
    'symptoms': symptoms.toList()..sort(),
    'comorbidity': comorbidity,
    'smoking': smoking,
    'tb_contact': tbContact,
    'pediatric_score': pediatricScore,
    'windows_presence': windowsPresence,
    'sunlight_exposure': sunlightExposure,
    'bta': bta,
    'culture': culture,
    'xpert': xpert,
    'igra': igra,
    'tb_history': tbHistory,
    'tb_status': tbStatus,
    'selected_model': modelType,
    'image': image == null
        ? null
        : {
            'filename': image!.filename,
            'mime_type': image!.mimeType,
            'checksum_sha256': image!.checksumSha256,
            'size_bytes': image!.sizeBytes,
            'source': image!.source.name,
          },
  };

  factory DiagnosisDraft.fromSnapshots({
    required Map<String, dynamic> patient,
    required Map<String, dynamic> clinical,
    required XrayImage image,
  }) {
    final rawSymptoms = clinical['symptoms'];
    return DiagnosisDraft(
      patientId: patient['patient_id'] as String?,
      patientCode: patient['patient_code'] as String?,
      patientName: patient['patient_name'] as String? ?? '',
      gender: patient['gender'] as String?,
      age: (patient['age'] as num?)?.toInt(),
      heightCm: (patient['height_cm'] as num?)?.toDouble(),
      weightKg: (patient['weight_kg'] as num?)?.toDouble(),
      symptoms: rawSymptoms is List
          ? rawSymptoms.whereType<String>().toSet()
          : const <String>{},
      comorbidity: clinical['comorbidity'] as String?,
      smoking: clinical['smoking'] as String?,
      tbContact: clinical['tb_contact'] as String?,
      pediatricScore: (clinical['pediatric_score'] as num?)?.toInt(),
      windowsPresence: clinical['windows_presence'] as String?,
      sunlightExposure: clinical['sunlight_exposure'] as String?,
      bta: clinical['bta'] as String?,
      culture: clinical['culture'] as String?,
      xpert: clinical['xpert'] as String?,
      igra: clinical['igra'] as String?,
      tbHistory: clinical['tb_history'] as String?,
      tbStatus: clinical['tb_status'] as String?,
      modelType: clinical['selected_model'] as String?,
      image: image,
    );
  }
}

const Object _unset = Object();
