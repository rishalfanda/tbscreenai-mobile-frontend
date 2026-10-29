import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/data/onnx/async_semaphore.dart';
import 'package:myapp/data/onnx/bundle_manifest.dart';
import 'package:myapp/data/onnx/bundle_store.dart';
import 'package:myapp/data/onnx/ort_chain_executor.dart';
import 'package:myapp/data/onnx/ort_session_pool.dart';
import 'package:myapp/data/onnx/tensor.dart';

const _mockManifestJson = '''
{
  "schema_version": 1,
  "bundle_version": "2026.09.04",
  "created_utc": "2026-09-04T05:21:40+00:00",
  "input": {
    "name": "decoded_image",
    "dtype": "uint8",
    "layout": "NHWC",
    "channels": "RGB"
  },
  "pipeline": [
    {
      "id": "pre",
      "model": "preprocess.onnx",
      "inputs": {
        "image": "@input"
      },
      "outputs": [
        "seg_input_norm",
        "seg_input_raw",
        "cls_input",
        "seg_rgb256"
      ],
      "ep_preference": ["cpu"]
    },
    {
      "id": "lung",
      "model": "seg_lung.onnx",
      "inputs": {
        "lung_input": "pre.seg_input_norm"
      },
      "outputs": [
        "lung_prob"
      ],
      "ep_preference": ["cpu"]
    },
    {
      "id": "lesion",
      "model": "seg_lesion.onnx",
      "inputs": {
        "lesion_input": "pre.seg_input_raw"
      },
      "outputs": [
        "lesion_prob"
      ],
      "ep_preference": ["cpu"]
    },
    {
      "id": "cnn",
      "model": "cnn.onnx",
      "inputs": {
        "cnn_input": "pre.cls_input"
      },
      "outputs": [
        "p_cnn"
      ],
      "ep_preference": ["cpu"]
    },
    {
      "id": "feat",
      "model": "features.onnx",
      "inputs": {
        "seg_rgb256": "pre.seg_rgb256",
        "lung_prob": "lung.lung_prob",
        "lesion_prob": "lesion.lesion_prob"
      },
      "outputs": [
        "feature_vec",
        "lung_mask",
        "label_map",
        "confidence"
      ],
      "ep_preference": ["cpu"]
    },
    {
      "id": "rf",
      "model": "@rf_active",
      "inputs": {
        "features": "feat.feature_vec"
      },
      "outputs": [
        "label_out",
        "p_rf"
      ],
      "ep_preference": ["cpu"]
    },
    {
      "id": "fuse",
      "model": "fuse.onnx",
      "inputs": {
        "p_rf": "rf.p_rf",
        "p_cnn": "cnn.p_cnn"
      },
      "outputs": [
        "p_fused",
        "is_tb"
      ],
      "ep_preference": ["cpu"]
    }
  ],
  "rf": {
    "active": "rf_default.onnx",
    "available": ["rf_default.onnx"]
  },
  "outputs": {
    "decision": "fuse.is_tb",
    "probability": "fuse.p_fused",
    "probability_cnn": "cnn.p_cnn",
    "probability_rf": "rf.p_rf",
    "lung_mask": "feat.lung_mask",
    "lesion_map": "feat.label_map",
    "confidence": "feat.confidence",
    "features": "feat.feature_vec"
  },
  "render": {
    "positive_label": "TB",
    "negative_label": "NON TB",
    "lesion_names": ["consolidation", "cavity"],
    "lesion_palette_rgb": [[255, 0, 0], [0, 255, 0]]
  },
  "baked_constants": {
    "seg_image_size": [256, 256],
    "cls_image_size": [224, 224],
    "lesion_num_classes": 2,
    "decision_threshold": 0.5,
    "fusion_alpha_rf": 0.5,
    "cnn_tb_index": 1,
    "rf_tb_index": 1,
    "lung_threshold": 0.5,
    "lesion_conf_threshold": 0.5
  },
  "feature_order": ["f1", "f2"]
}
''';

Tensor _tensor1d(double val) =>
    Tensor(data: Float32List.fromList([val]), shape: const [1]);

void main() {
  group('AsyncSemaphore', () {
    test('rejects non-positive permits', () {
      expect(() => AsyncSemaphore(0), throwsArgumentError);
      expect(() => AsyncSemaphore(-1), throwsArgumentError);
    });

    test('allows up to maxPermits immediately', () async {
      final sem = AsyncSemaphore(2);
      expect(sem.availablePermits, 2);

      await sem.acquire();
      expect(sem.availablePermits, 1);

      await sem.acquire();
      expect(sem.availablePermits, 0);

      sem.release();
      expect(sem.availablePermits, 1);

      sem.release();
      expect(sem.availablePermits, 2);
    });

    test('queues callers when permits are exhausted', () async {
      final sem = AsyncSemaphore(1);
      await sem.acquire();

      var secondAcquired = false;
      final second = sem.acquire().then((_) => secondAcquired = true);

      expect(sem.queueLength, 1);
      expect(secondAcquired, isFalse);

      sem.release();
      await second;
      expect(secondAcquired, isTrue);
      expect(sem.queueLength, 0);
    });

    test('withPermit executes action and releases permit on success', () async {
      final sem = AsyncSemaphore(1);
      final result = await sem.withPermit(() async => 42);
      expect(result, 42);
      expect(sem.availablePermits, 1);
    });

    test('withPermit releases permit even when action throws', () async {
      final sem = AsyncSemaphore(1);
      await expectLater(
        () => sem.withPermit(() async => throw StateError('boom')),
        throwsStateError,
      );
      expect(sem.availablePermits, 1);
    });
  });

  group('OrtChainExecutor (Dynamic DAG)', () {
    late BundleManifest manifest;
    late BundleStore store;

    setUp(() {
      manifest = BundleManifest.parse(_mockManifestJson);
      store = BundleStore.test(manifest: manifest);
    });

    test('executes all steps in DAG and yields declared outputs', () async {
      final executedSteps = <String>[];
      final closedSessions = <String>[];

      final pool = OrtSessionPool(
        sessionFactory: (filePath, {label, required preferredProviders}) async {
          return OrtSessionHandle.mock(
            activeProvider: 'cpu',
            onRun: (feeds) async {
              executedSteps.add(label ?? filePath);
              // Return dummy tensors for declared step outputs
              switch (label) {
                case 'preprocess.onnx':
                  return [
                    _tensor1d(1),
                    _tensor1d(2),
                    _tensor1d(3),
                    _tensor1d(4),
                  ];
                case 'seg_lung.onnx':
                  return [_tensor1d(0.9)];
                case 'seg_lesion.onnx':
                  return [_tensor1d(0.8)];
                case 'cnn.onnx':
                  return [_tensor1d(0.7)];
                case 'features.onnx':
                  return [
                    _tensor1d(0.5),
                    _tensor1d(1.0),
                    _tensor1d(0.0),
                    _tensor1d(0.85),
                  ];
                case 'rf_default.onnx':
                  return [_tensor1d(1), _tensor1d(0.75)];
                case 'fuse.onnx':
                  return [_tensor1d(0.8), _tensor1d(1)];
                default:
                  return [_tensor1d(0)];
              }
            },
            onClose: () async {
              closedSessions.add(label ?? filePath);
            },
          );
        },
      );

      final executor = OrtChainExecutor(
        store: store,
        pool: pool,
        concurrencyLimit: 2,
      );

      final input = Tensor(
        data: Uint8List.fromList([1, 2, 3]),
        shape: const [1, 1, 1, 3],
      );

      final stepsNotified = <String>[];
      final outputs = await executor.run(
        input,
        onStep: (stepId) => stepsNotified.add(stepId),
      );

      // Verify all terminal outputs declared in manifest are present
      expect(outputs.containsKey('decision'), isTrue);
      expect(outputs.containsKey('probability'), isTrue);
      expect(outputs.containsKey('probability_cnn'), isTrue);
      expect(outputs.containsKey('probability_rf'), isTrue);
      expect(outputs.containsKey('lung_mask'), isTrue);
      expect(outputs.containsKey('lesion_map'), isTrue);
      expect(outputs.containsKey('confidence'), isTrue);
      expect(outputs.containsKey('features'), isTrue);

      expect(outputs['decision']!.firstAsDouble, 1.0);
      expect(outputs['probability']!.firstAsDouble, closeTo(0.8, 1e-4));
      expect(outputs['probability_cnn']!.firstAsDouble, closeTo(0.7, 1e-4));

      // Verify all steps were executed and notified
      expect(stepsNotified, containsAll(['pre', 'lung', 'lesion', 'cnn', 'feat', 'rf', 'fuse']));

      // Verify timings were captured
      expect(executor.stepTimings.length, 7);
      expect(executor.sessionLoadTimings.length, 7);

      // Verify memory cleanup: seg_lung and seg_lesion sessions closed immediately
      expect(closedSessions, contains('seg_lung.onnx'));
      expect(closedSessions, contains('seg_lesion.onnx'));
    });

    test('enforces concurrency limit and allows parallel execution of independent nodes', () async {
      var currentConcurrent = 0;
      var maxObservedConcurrent = 0;

      final pool = OrtSessionPool(
        sessionFactory: (filePath, {label, required preferredProviders}) async {
          return OrtSessionHandle.mock(
            activeProvider: 'cpu',
            onRun: (feeds) async {
              currentConcurrent++;
              if (currentConcurrent > maxObservedConcurrent) {
                maxObservedConcurrent = currentConcurrent;
              }

              // Simulate brief async work
              await Future<void>.delayed(const Duration(milliseconds: 20));

              currentConcurrent--;

              switch (label) {
                case 'preprocess.onnx':
                  return [_tensor1d(1), _tensor1d(2), _tensor1d(3), _tensor1d(4)];
                case 'seg_lung.onnx':
                  return [_tensor1d(0.9)];
                case 'seg_lesion.onnx':
                  return [_tensor1d(0.8)];
                case 'cnn.onnx':
                  return [_tensor1d(0.7)];
                case 'features.onnx':
                  return [_tensor1d(0.5), _tensor1d(1.0), _tensor1d(0.0), _tensor1d(0.85)];
                case 'rf_default.onnx':
                  return [_tensor1d(1), _tensor1d(0.75)];
                case 'fuse.onnx':
                  return [_tensor1d(0.8), _tensor1d(1)];
                default:
                  return [_tensor1d(0)];
              }
            },
          );
        },
      );

      final executor = OrtChainExecutor(
        store: store,
        pool: pool,
        concurrencyLimit: 2,
      );

      final input = Tensor(
        data: Uint8List.fromList([1, 2, 3]),
        shape: const [1, 1, 1, 3],
      );

      await executor.run(input);

      // Because pre forks to [lung, lesion, cnn], with concurrencyLimit = 2,
      // exactly 2 tasks should have run concurrently, never 3.
      expect(maxObservedConcurrent, 2);
    });

    test('propagates step error cleanly and aborts pipeline without hang', () async {
      final pool = OrtSessionPool(
        sessionFactory: (filePath, {label, required preferredProviders}) async {
          return OrtSessionHandle.mock(
            activeProvider: 'cpu',
            onRun: (feeds) async {
              if (label == 'cnn.onnx') {
                throw StateError('Simulated CNN execution failure');
              }
              switch (label) {
                case 'preprocess.onnx':
                  return [_tensor1d(1), _tensor1d(2), _tensor1d(3), _tensor1d(4)];
                case 'seg_lung.onnx':
                  return [_tensor1d(0.9)];
                case 'seg_lesion.onnx':
                  return [_tensor1d(0.8)];
                case 'features.onnx':
                  return [_tensor1d(0.5), _tensor1d(1.0), _tensor1d(0.0), _tensor1d(0.85)];
                case 'rf_default.onnx':
                  return [_tensor1d(1), _tensor1d(0.75)];
                case 'fuse.onnx':
                  return [_tensor1d(0.8), _tensor1d(1)];
                default:
                  return [_tensor1d(0)];
              }
            },
          );
        },
      );

      final executor = OrtChainExecutor(
        store: store,
        pool: pool,
        concurrencyLimit: 2,
      );

      final input = Tensor(
        data: Uint8List.fromList([1, 2, 3]),
        shape: const [1, 1, 1, 3],
      );

      expect(
        () => executor.run(input),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Simulated CNN execution failure'))),
      );
    });
    test('keepSessionsStandby preloads and retains all sessions across execution', () async {
      final loadedSessions = <String>[];
      final closedSessions = <String>[];

      final pool = OrtSessionPool(
        sessionFactory: (filePath, {label, required preferredProviders}) async {
          loadedSessions.add(label ?? filePath);
          return OrtSessionHandle.mock(
            activeProvider: 'cpu',
            onRun: (feeds) async {
              switch (label) {
                case 'preprocess.onnx':
                  return [_tensor1d(1), _tensor1d(2), _tensor1d(3), _tensor1d(4)];
                case 'seg_lung.onnx':
                  return [_tensor1d(0.9)];
                case 'seg_lesion.onnx':
                  return [_tensor1d(0.8)];
                case 'cnn.onnx':
                  return [_tensor1d(0.7)];
                case 'features.onnx':
                  return [_tensor1d(0.5), _tensor1d(1.0), _tensor1d(0.0), _tensor1d(0.85)];
                case 'rf_default.onnx':
                  return [_tensor1d(1), _tensor1d(0.75)];
                case 'fuse.onnx':
                  return [_tensor1d(0.8), _tensor1d(1)];
                default:
                  return [_tensor1d(0)];
              }
            },
            onClose: () async {
              closedSessions.add(label ?? filePath);
            },
          );
        },
      );

      final executor = OrtChainExecutor(
        store: store,
        pool: pool,
        keepSessionsStandby: true,
      );

      await executor.preloadSessions();
      expect(loadedSessions, containsAll(['preprocess.onnx', 'seg_lung.onnx', 'seg_lesion.onnx', 'cnn.onnx', 'features.onnx', 'rf_default.onnx', 'fuse.onnx']));

      final input = Tensor(
        data: Uint8List.fromList([1, 2, 3]),
        shape: const [1, 1, 1, 3],
      );

      await executor.run(input);

      expect(closedSessions, isEmpty);
    });
  });
}

