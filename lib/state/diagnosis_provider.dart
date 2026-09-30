import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:myapp/domain/models/diagnosis_draft.dart';
import 'package:myapp/domain/models/diagnosis_inference_request.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/patient.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/models/screening_result.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';
import 'package:myapp/domain/repositories/screening_store.dart';

class DiagnosisProvider extends ChangeNotifier {
  DiagnosisProvider(
    this._diagnosisRepository, {
    ScreeningStore? screeningStore,
    Future<String> Function()? deviceId,
    Listenable? session,
    bool Function()? hasActiveSession,
  }) : _screeningStore = screeningStore,
       _deviceId = deviceId,
       _session = session,
       _hasActiveSession = hasActiveSession {
    _session?.addListener(_onSessionChanged);
  }

  final Listenable? _session;
  final bool Function()? _hasActiveSession;

  final DiagnosisRepository _diagnosisRepository;
  final ScreeningStore? _screeningStore;
  final Future<String> Function()? _deviceId;

  DiagnosisDraft _draft = const DiagnosisDraft();
  ScreeningResult? _lastResult;
  int _generation = 0;
  bool _disposed = false;
  StreamSubscription<ScreeningSaveStatus>? _saveSubscription;

  ScreeningResult? get lastResult => _lastResult;
  DiagnosisOutcome? get lastOutcome => _lastResult?.outcome;
  ScreeningSaveStatus get saveStatus =>
      _lastResult?.saveStatus ?? ScreeningSaveStatus.unsaved;
  String? get persistenceError => _lastResult?.persistenceError;
  bool get requiresLeaveConfirmation =>
      _lastResult?.requiresLeaveConfirmation ?? false;

  @visibleForTesting
  set lastOutcome(DiagnosisOutcome? value) {
    _lastResult = value == null
        ? null
        : ScreeningResult(
            draft: _draft,
            outcome: value,
            saveStatus: value.isMock
                ? ScreeningSaveStatus.demo
                : ScreeningSaveStatus.unsaved,
          );
  }

  bool isRunning = false;
  bool isSaving = false;
  bool isRestoring = false;
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

  void selectPatient(Patient patient) {
    _replace(
      _draft.copyWith(
        patientId: patient.serverId,
        patientCode: patient.id,
        patientName: patient.name,
        age: patient.age,
        gender: patient.gender,
      ),
    );
  }

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
    if (_disposed || isRunning) return false;
    final generation = ++_generation;
    final input = _draft.copyWith();
    isRunning = true;
    lastError = null;
    notifyListeners();
    late final DiagnosisInferenceRequest request;
    try {
      request = DiagnosisInferenceRequest.fromDraft(
        draft: input,
        deviceId: _deviceId == null ? 'local-device' : await _deviceId(),
      );
    } catch (error) {
      if (_disposed || generation != _generation) return false;
      isRunning = false;
      lastError = error is DiagnosisRequestValidationException
          ? error.message
          : 'Device registration failed. Reconnect and try again.';
      notifyListeners();
      return false;
    }
    if (_disposed || generation != _generation) return false;
    _lastResult = null;
    isRunning = true;
    lastError = null;
    notifyListeners();

    try {
      final outcome = _diagnosisRepository is TypedDiagnosisRepository
          ? await (_diagnosisRepository as TypedDiagnosisRepository)
                .runTypedInference(request)
          : await _diagnosisRepository.runInference(image: request.image);
      if (_disposed || generation != _generation) return false;
      _lastResult = ScreeningResult(
        draft: input,
        outcome: outcome,
        saveStatus: outcome.isMock
            ? ScreeningSaveStatus.demo
            : ScreeningSaveStatus.unsaved,
      );
      if (!outcome.isMock && _screeningStore != null) {
        await _persistCurrent(generation);
      }
      return !_disposed && generation == _generation;
    } catch (_) {
      if (_disposed || generation != _generation) return false;
      _lastResult = null;
      lastError = 'Analysis failed. Check the server connection and try again.';
      return false;
    } finally {
      if (!_disposed && generation == _generation) {
        isRunning = false;
        notifyListeners();
      }
    }
  }

  Future<bool> saveCurrentResult() async {
    if (_disposed ||
        isSaving ||
        _lastResult == null ||
        _screeningStore == null) {
      return false;
    }
    if (_lastResult!.outcome.isMock) return false;
    if ({
      ScreeningSaveStatus.pendingSync,
      ScreeningSaveStatus.saved,
    }.contains(_lastResult!.saveStatus)) {
      return true;
    }
    final generation = _generation;
    await _persistCurrent(generation);
    return _lastResult != null &&
        _lastResult!.saveStatus != ScreeningSaveStatus.failed;
  }

  Future<void> _persistCurrent(int generation) async {
    final current = _lastResult;
    final store = _screeningStore;
    if (current == null || store == null) return;
    isSaving = true;
    _lastResult = current.copyWith(
      saveStatus: ScreeningSaveStatus.saving,
      persistenceError: null,
    );
    notifyListeners();
    try {
      final persisted = await store.persist(current);
      if (_disposed || generation != _generation) return;
      _lastResult = persisted;
      _watchSaveStatus(persisted, generation);
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _lastResult = current.copyWith(
        saveStatus: ScreeningSaveStatus.failed,
        persistenceError: error.toString(),
      );
    } finally {
      if (!_disposed && generation == _generation) {
        isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<void> restoreLatest() async {
    final store = _screeningStore;
    if (_disposed || store == null || isRestoring) return;
    final generation = _generation;
    isRestoring = true;
    try {
      final restored = await store.restoreLatest();
      if (_disposed || generation != _generation || restored == null) return;
      _draft = restored.draft.copyWith();
      _lastResult = restored;
      _watchSaveStatus(restored, generation);
      lastError = null;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      lastError = 'Saved screening could not be restored: $error';
    } finally {
      if (!_disposed && generation == _generation) {
        isRestoring = false;
        notifyListeners();
      }
    }
  }

  void _onSessionChanged() {
    resetForNewDiagnosis();
    if (_hasActiveSession?.call() == true) unawaited(restoreLatest());
  }

  void resetForNewDiagnosis() {
    unawaited(_saveSubscription?.cancel());
    _saveSubscription = null;
    _generation++;
    _draft = const DiagnosisDraft();
    _lastResult = null;
    lastError = null;
    isRunning = false;
    isSaving = false;
    isRestoring = false;
    notifyListeners();
  }

  void _replace(DiagnosisDraft value) {
    unawaited(_saveSubscription?.cancel());
    _saveSubscription = null;
    _generation++;
    _lastResult = null;
    isRunning = false;
    lastError = null;
    _draft = value;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_saveSubscription?.cancel());
    _session?.removeListener(_onSessionChanged);
    _disposed = true;
    _generation++;
    _lastResult = null;
    _draft = const DiagnosisDraft();
    super.dispose();
  }

  void _watchSaveStatus(ScreeningResult result, int generation) {
    unawaited(_saveSubscription?.cancel());
    if (result.id == null || _screeningStore == null) return;
    _saveSubscription = _screeningStore.watchSaveStatus(result.id!).listen((
      status,
    ) {
      if (_disposed ||
          generation != _generation ||
          _lastResult?.id != result.id) {
        return;
      }
      _lastResult = _lastResult!.copyWith(saveStatus: status);
      notifyListeners();
    }, onError: (Object _) {});
  }
}
