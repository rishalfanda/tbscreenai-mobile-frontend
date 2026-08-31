import 'package:flutter/foundation.dart';
import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';

class DiagnosisProvider extends ChangeNotifier {
  DiagnosisProvider(this._diagnosisRepository);

  final DiagnosisRepository _diagnosisRepository;

  DiagnosisDraft _draft = const DiagnosisDraft();
  DiagnosisOutcome? lastOutcome;
  bool isRunning = false;
  String? lastError;

  DiagnosisDraft get draft => _draft;
  Set<String> get symptoms => _draft.symptoms;
  String get patientName => _draft.patientName;
  String get gender => _draft.gender ?? 'Not provided';
  int? get age => _draft.age;
  double? get heightCm => _draft.heightCm;
  double? get weightKg => _draft.weightKg;
  String get comorbidity => _draft.comorbidity ?? 'Not provided';
  String get smoking => _draft.smoking ?? 'Not provided';
  String get tbContact => _draft.tbContact ?? 'Not provided';
  int? get pediatricScore => _draft.pediatricScore;
  String get windowsPresence => _draft.windowsPresence ?? 'Not provided';
  String get sunlightExposure => _draft.sunlightExposure ?? 'Not provided';
  String get bta => _draft.bta ?? 'Not provided';
  String get culture => _draft.culture ?? 'Not provided';
  String get xpert => _draft.xpert ?? 'Not provided';
  String get igra => _draft.igra ?? 'Not provided';
  String get tbHistory => _draft.tbHistory ?? 'Not provided';
  String get tbStatus => _draft.tbStatus ?? 'Not provided';
  String get modelType => _draft.modelType ?? 'Not provided';
  String get modelVersion => lastOutcome?.modelVersion ?? 'Not available';
  XrayImage? get image => _draft.image;
  bool get hasImage => image != null && !image!.isEmpty;
  String? get imageLabel => image?.filename;
  bool get requiresPediatricScore => _draft.requiresPediatricScore;
  bool get canAnalyze => _draft.canAnalyze && !isRunning;

  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm == 0) return null;
    final heightM = heightCm! / 100;
    return weightKg! / (heightM * heightM);
  }

  void updatePatientName(String value) =>
      _replace(_draft.copyWith(patientName: value));

  void updateGender(String? value) => _replace(_draft.copyWith(gender: value));

  void updateAge(int? value) {
    _replace(
      _draft.copyWith(
        age: value,
        pediatricScore: value != null && value < 18
            ? _draft.pediatricScore
            : null,
      ),
    );
  }

  void updateHeight(double? value) =>
      _replace(_draft.copyWith(heightCm: value));

  void updateWeight(double? value) =>
      _replace(_draft.copyWith(weightKg: value));

  void updateBasicInfo({
    required String name,
    required String selectedGender,
    required int? selectedAge,
    required double? selectedHeight,
    required double? selectedWeight,
  }) {
    _replace(
      _draft.copyWith(
        patientName: name,
        gender: selectedGender,
        age: selectedAge,
        heightCm: selectedHeight,
        weightKg: selectedWeight,
        pediatricScore: selectedAge != null && selectedAge < 18
            ? _draft.pediatricScore
            : null,
      ),
    );
  }

  void toggleSymptom(String symptom, bool enabled) {
    final updated = Set<String>.of(_draft.symptoms);
    enabled ? updated.add(symptom) : updated.remove(symptom);
    _replace(_draft.copyWith(symptoms: updated));
  }

  void updateComorbidity(String? value) =>
      _replace(_draft.copyWith(comorbidity: value));
  void updateSmoking(String? value) =>
      _replace(_draft.copyWith(smoking: value));
  void updateTbContact(String? value) =>
      _replace(_draft.copyWith(tbContact: value));
  void updatePediatricScore(int? value) =>
      _replace(_draft.copyWith(pediatricScore: value));
  void updateWindowsPresence(String? value) =>
      _replace(_draft.copyWith(windowsPresence: value));
  void updateSunlightExposure(String? value) =>
      _replace(_draft.copyWith(sunlightExposure: value));
  void updateBta(String? value) => _replace(_draft.copyWith(bta: value));
  void updateCulture(String? value) =>
      _replace(_draft.copyWith(culture: value));
  void updateXpert(String? value) => _replace(_draft.copyWith(xpert: value));
  void updateIgra(String? value) => _replace(_draft.copyWith(igra: value));
  void updateTbHistory(String? value) =>
      _replace(_draft.copyWith(tbHistory: value));
  void updateTbStatus(String? value) =>
      _replace(_draft.copyWith(tbStatus: value));
  void updateModelType(String? value) =>
      _replace(_draft.copyWith(modelType: value));

  void updateClinical({
    required String selectedComorbidity,
    required String selectedSmoking,
    required String selectedTbContact,
    required int? selectedPediatricScore,
    required String selectedWindowsPresence,
    required String selectedSunlightExposure,
    required String selectedBta,
    required String selectedCulture,
    required String selectedXpert,
    required String selectedIgra,
    required String selectedTbHistory,
    required String selectedTbStatus,
    required String selectedModelType,
    required String selectedModelVersion,
  }) {
    _replace(
      _draft.copyWith(
        comorbidity: selectedComorbidity,
        smoking: selectedSmoking,
        tbContact: selectedTbContact,
        pediatricScore: selectedPediatricScore,
        windowsPresence: selectedWindowsPresence,
        sunlightExposure: selectedSunlightExposure,
        bta: selectedBta,
        culture: selectedCulture,
        xpert: selectedXpert,
        igra: selectedIgra,
        tbHistory: selectedTbHistory,
        tbStatus: selectedTbStatus,
        modelType: selectedModelType,
      ),
    );
  }

  void attachImage(XrayImage attached) {
    lastError = null;
    _replace(_draft.copyWith(image: attached));
  }

  /// Demo-only helper kept for mock-flow tests. Production UI never calls it.
  void attachPlaceholderImage(String filename) =>
      attachImage(XrayImage.placeholder(filename));

  void clearImage() => _replace(_draft.copyWith(image: null));

  Future<bool> runDiagnosis() async {
    final attached = image;
    if (attached == null || attached.isEmpty) {
      lastError = 'Select or capture a chest X-ray before analysis.';
      notifyListeners();
      return false;
    }

    isRunning = true;
    lastError = null;
    notifyListeners();

    try {
      lastOutcome = await _diagnosisRepository.runInference(image: attached);
      return true;
    } catch (_) {
      lastOutcome = null;
      lastError = 'Analysis failed. Check the server connection and try again.';
      return false;
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  void resetForNewDiagnosis() {
    _draft = const DiagnosisDraft();
    lastOutcome = null;
    lastError = null;
    isRunning = false;
    notifyListeners();
  }

  void _replace(DiagnosisDraft value) {
    _draft = value;
    notifyListeners();
  }
}
