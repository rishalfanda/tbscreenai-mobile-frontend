import 'package:myapp/domain/models/xray_image.dart';

/// Immutable snapshot of everything entered on the diagnosis form.
///
/// Keeping one draft prevents the form, camera route and result screen from
/// silently reading different values for the same examination.
class DiagnosisDraft {
  const DiagnosisDraft({
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

  bool get requiresPediatricScore => age != null && age! < 18;

  bool get hasRequiredDemographics =>
      patientName.trim().isNotEmpty &&
      gender != null &&
      age != null &&
      age! > 0 &&
      heightCm != null &&
      heightCm! > 0 &&
      weightKg != null &&
      weightKg! > 0;

  bool get canAnalyze =>
      hasRequiredDemographics && image != null && !image!.isEmpty;

  DiagnosisDraft copyWith({
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
}

const Object _unset = Object();
