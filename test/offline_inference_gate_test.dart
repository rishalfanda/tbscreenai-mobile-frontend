import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/onnx/inference_result.dart';
import 'package:myapp/data/onnx/on_device_diagnosis_repository.dart';
import 'package:myapp/data/onnx/onnx_inference_engine.dart';
import 'package:myapp/domain/models/xray_image.dart';
import 'package:myapp/domain/repositories/diagnosis_repository.dart';

class _MissingModel extends OnnxInferenceEngine {
  bool ran = false;
  @override
  Future<bool> get ready async => false;
  @override
  bool get hasBundle => false;
  @override
  Future<InferenceResult> run(Uint8List bytes) async {
    ran = true;
    throw StateError('Must not run without installed model');
  }
}

void main() {
  test(
    'missing local model rejects inference without network or mock fallback',
    () async {
      final engine = _MissingModel();
      await expectLater(
        OnDeviceDiagnosisRepository(
          engine,
        ).runInference(image: XrayImage.placeholder()),
        throwsA(isA<LocalModelUnavailable>()),
      );
      expect(engine.ran, isFalse);
    },
  );
}
