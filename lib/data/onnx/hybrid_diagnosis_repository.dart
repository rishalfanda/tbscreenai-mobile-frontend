import 'package:myapp/data/onnx/on_device_diagnosis_repository.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/diagnosis_outcome.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';

/// Runs inference on-device when a verified model bundle is currently
/// active, otherwise delegates to [fallback] (the existing Mock/Http choice)
/// unchanged.
///
/// This is what actually gets wired into `Provider<DiagnosisRepository>` in
/// `app.dart` — enabling on-device inference needs no new build flag: it
/// activates automatically the moment a doctor installs a verified bundle via
/// Sync Center.
class HybridDiagnosisRepository implements DiagnosisRepository {
  HybridDiagnosisRepository({
    required OnnxInferenceEngine engine,
    required DiagnosisRepository fallback,
  }) : _engine = engine,
       _onDevice = OnDeviceDiagnosisRepository(engine),
       _fallback = fallback;

  final OnnxInferenceEngine _engine;
  final OnDeviceDiagnosisRepository _onDevice;
  final DiagnosisRepository _fallback;

  @override
  Future<List<String>> getSymptomOptions() => _fallback.getSymptomOptions();

  @override
  Future<DiagnosisOutcome> runInference({required XrayImage image}) {
    return _engine.hasBundle
        ? _onDevice.runInference(image: image)
        : _fallback.runInference(image: image);
  }
}
