import 'package:flutter/foundation.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';

class DiagnosisProvider extends ChangeNotifier {
  DiagnosisProvider(this._diagnosisRepository);

  final DiagnosisRepository _diagnosisRepository;

  final Set<String> _symptoms = <String>{};

  String patientName = '';
  String gender = 'Female';
  int? age;
  double? heightCm;
  double? weightKg;
  String comorbidity = 'None';
  String smoking = 'No';
  String tbContact = 'Unknown';
  int? pediatricScore;
  String windowsPresence = 'Yes';
  String sunlightExposure = 'Yes';
  String bta = 'Negative';
  String culture = 'Negative';
  String xpert = 'Negative';
  String igra = 'Negative';
  String tbHistory = 'No';
  String tbStatus = 'Suspected';
  String modelType = 'Non Disability';
  String modelVersion = 'Version 1';
  String? imageLabel;
  DiagnosisOutcome? lastOutcome;
  bool isRunning = false;

  Set<String> get symptoms => _symptoms;
  bool get hasImage => imageLabel != null && imageLabel!.isNotEmpty;
  bool get requiresPediatricScore => age != null && age! < 18;

  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm == 0) {
      return null;
    }

    final heightM = heightCm! / 100;
    return weightKg! / (heightM * heightM);
  }

  void updateBasicInfo({
    required String name,
    required String selectedGender,
    required int? selectedAge,
    required double? selectedHeight,
    required double? selectedWeight,
  }) {
    patientName = name;
    gender = selectedGender;
    age = selectedAge;
    heightCm = selectedHeight;
    weightKg = selectedWeight;
    notifyListeners();
  }

  void toggleSymptom(String symptom, bool enabled) {
    if (enabled) {
      _symptoms.add(symptom);
    } else {
      _symptoms.remove(symptom);
    }
    notifyListeners();
  }

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
    comorbidity = selectedComorbidity;
    smoking = selectedSmoking;
    tbContact = selectedTbContact;
    pediatricScore = selectedPediatricScore;
    windowsPresence = selectedWindowsPresence;
    sunlightExposure = selectedSunlightExposure;
    bta = selectedBta;
    culture = selectedCulture;
    xpert = selectedXpert;
    igra = selectedIgra;
    tbHistory = selectedTbHistory;
    tbStatus = selectedTbStatus;
    modelType = selectedModelType;
    modelVersion = selectedModelVersion;
    notifyListeners();
  }

  void attachMockImage(String label) {
    imageLabel = label;
    notifyListeners();
  }

  void clearImage() {
    imageLabel = null;
    notifyListeners();
  }

  Future<void> runDiagnosis() async {
    if (!hasImage) {
      return;
    }

    isRunning = true;
    notifyListeners();

    // Inference simulation (3s delay + randomized outcome) lives in the
    // repository now — the provider only orchestrates state.
    lastOutcome = await _diagnosisRepository.runInference(imageLabel: imageLabel!);

    isRunning = false;
    notifyListeners();
  }

  void resetForNewDiagnosis() {
    imageLabel = null;
    lastOutcome = null;
    isRunning = false;
    notifyListeners();
  }
}
