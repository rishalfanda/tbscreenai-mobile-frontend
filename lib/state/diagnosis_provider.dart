import 'dart:math' as math;

import 'package:flutter/foundation.dart';

class DiagnosisOutcome {
  const DiagnosisOutcome({
    required this.isPositive,
    required this.confidence,
    required this.processingTime,
    required this.modelVersion,
    required this.createdAt,
    this.consolidation = 0,
    this.cavity = 0,
    this.effusion = 0,
    this.fibrotic = 0,
    this.calcification = 0,
  });

  final bool isPositive;
  final int confidence;
  final String processingTime;
  final String modelVersion;
  final DateTime createdAt;
  final double consolidation;
  final double cavity;
  final double effusion;
  final double fibrotic;
  final double calcification;
}

class DiagnosisProvider extends ChangeNotifier {
  final Set<String> _symptoms = <String>{};
  final math.Random _random = math.Random();

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
  String sunlightExposure = 'Adequate';
  String bta = 'Negative';
  String culture = 'Negative';
  String xpert = 'Negative';
  String igra = 'Negative';
  String tbHistory = 'No';
  String tbStatus = 'Suspected';
  String modelType = 'Standard';
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
    await Future<void>.delayed(const Duration(seconds: 3));

    final confidence = 75 + _random.nextInt(24);
    final isPositive = _random.nextBool();
    final processingMs = 2600 + _random.nextInt(500);

    lastOutcome = DiagnosisOutcome(
      isPositive: isPositive,
      confidence: confidence,
      processingTime: '${(processingMs / 1000).toStringAsFixed(1)}s',
      modelVersion: 'TBScreen v2.1.0',
      createdAt: DateTime.now(),
      consolidation: isPositive ? (20 + _random.nextDouble() * 15) : (1 + _random.nextDouble() * 4),
      cavity: isPositive ? (_random.nextDouble() * 5) : 0.0,
      effusion: isPositive ? (3 + _random.nextDouble() * 8) : (_random.nextDouble() * 2),
      fibrotic: _random.nextDouble() * 2,
      calcification: _random.nextDouble() * 3,
    );

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
