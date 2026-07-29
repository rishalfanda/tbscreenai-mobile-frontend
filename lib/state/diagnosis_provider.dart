import 'package:flutter/foundation.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/xray_image.dart';
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
  /// The attached X-ray, bytes and all — inference needs the image itself,
  /// not a label describing one.
  XrayImage? image;
  DiagnosisOutcome? lastOutcome;
  bool isRunning = false;

  /// Set when the last inference attempt failed, so the UI can say what went
  /// wrong instead of silently showing an empty Result screen.
  String? lastError;

  Set<String> get symptoms => _symptoms;
  bool get hasImage => image != null && !image!.isEmpty;

  /// Filename of the attached image, for display.
  String? get imageLabel => image?.filename;
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

  void attachImage(XrayImage attached) {
    image = attached;
    lastError = null;
    notifyListeners();
  }

  /// Attaches a stand-in image so the flow is exercisable before a capture
  /// plugin exists. The bytes are a real PNG, so the request the server sees
  /// is the same shape a genuine capture will produce.
  void attachPlaceholderImage(String filename) =>
      attachImage(XrayImage.placeholder(filename));

  void clearImage() {
    image = null;
    notifyListeners();
  }

  Future<void> runDiagnosis() async {
    final attached = image;
    if (attached == null || attached.isEmpty) {
      return;
    }

    isRunning = true;
    lastError = null;
    notifyListeners();

    try {
      lastOutcome = await _diagnosisRepository.runInference(image: attached);
    } catch (error) {
      // A failed inference must not leave the previous patient's result on
      // screen — that is a misread waiting to happen.
      lastOutcome = null;
      lastError = 'Analisis gagal: periksa koneksi ke server dan coba lagi.';
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  void resetForNewDiagnosis() {
    image = null;
    lastOutcome = null;
    lastError = null;
    isRunning = false;
    notifyListeners();
  }
}
