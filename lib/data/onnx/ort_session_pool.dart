import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'package:myapp/data/onnx/tensor.dart';

/// Manifest `ep_preference` tokens -> `flutter_onnxruntime` provider enum.
const Map<String, OrtProvider> _providerByName = {
  'nnapi': OrtProvider.NNAPI,
  'xnnpack': OrtProvider.XNNPACK,
  'coreml': OrtProvider.CORE_ML,
  'core_ml': OrtProvider.CORE_ML,
  'qnn': OrtProvider.QNN,
  'cuda': OrtProvider.CUDA,
  'cpu': OrtProvider.CPU,
};

typedef OrtSessionFactory =
    Future<OrtSessionHandle> Function(
      String filePath, {
      required List<String> preferredProviders,
      String? label,
    });

/// Thin wrapper around the `flutter_onnxruntime` plugin.
///
/// The plugin routes every native call through a background task queue, so
/// `await`ing session creation / inference never blocks the platform UI thread.
class OrtSessionPool {
  OrtSessionPool({OrtSessionFactory? sessionFactory})
    : _sessionFactory = sessionFactory;

  final OrtSessionFactory? _sessionFactory;
  final OnnxRuntime _ort = OnnxRuntime();
  List<OrtProvider>? _available;

  Future<List<OrtProvider>> availableProviders() async {
    final cached = _available;
    if (cached != null) return cached;
    try {
      return _available = await _ort.getAvailableProviders();
    } catch (_) {
      return _available = const [OrtProvider.CPU];
    }
  }

  /// Loads a model from an absolute file path. [preferredProviders] are tried in
  /// order; CPU is always appended as the final fallback.
  Future<OrtSessionHandle> createSession(
    String filePath, {
    required List<String> preferredProviders,
    String? label,
  }) async {
    if (_sessionFactory != null) {
      return _sessionFactory(
        filePath,
        preferredProviders: preferredProviders,
        label: label,
      );
    }
    final available = await availableProviders();

    final providers = <OrtProvider>[];
    for (final name in preferredProviders) {
      final p = _providerByName[name.toLowerCase()];
      if (p != null && available.contains(p) && !providers.contains(p)) {
        providers.add(p);
      }
    }
    if (!providers.contains(OrtProvider.CPU)) providers.add(OrtProvider.CPU);

    try {
      final session = await _ort.createSession(
        filePath,
        options: OrtSessionOptions(
          providers: providers,
          intraOpNumThreads: 2,
          interOpNumThreads: 1,
        ),
      );
      return _RealOrtSessionHandle(session, providers.first.name.toLowerCase());
    } catch (e) {
      // `.ort`-format models can't be layout-transformed to NHWC at load time
      // (the `com.ms.internal.nhwc` op schemas aren't registered in the
      // ORT-format runtime path), so NNAPI / XNNPACK fail during init. Retry on
      // CPU only, which needs no layout transform.
      final acceleratedOnly = providers.where((p) => p != OrtProvider.CPU);
      if (acceleratedOnly.isNotEmpty) {
        logOrt(
          'accelerated EP init failed for ${label ?? filePath} ($e) '
          '— retrying CPU-only',
        );
        try {
          final session = await _ort.createSession(
            filePath,
            options: OrtSessionOptions(
              providers: const [OrtProvider.CPU],
              intraOpNumThreads: 2,
              interOpNumThreads: 1,
            ),
          );
          return _RealOrtSessionHandle(session, 'cpu (fallback)');
        } catch (e2) {
          throw StateError(
            'could not create ONNX session${label != null ? ' for $label' : ''}'
            ' (CPU fallback also failed): $e2',
          );
        }
      }
      throw StateError(
        'could not create ONNX session${label != null ? ' for $label' : ''}: $e',
      );
    }
  }
}

/// A loaded model. Runs all outputs; the caller maps them positionally
/// (in the graph's declared output order).
abstract class OrtSessionHandle {
  String get activeProvider;
  List<String> get inputNames;
  List<String> get outputNames;

  Future<List<Tensor>> run(Map<String, Tensor> feeds);
  Future<void> close();

  @visibleForTesting
  factory OrtSessionHandle.mock({
    required String activeProvider,
    required Future<List<Tensor>> Function(Map<String, Tensor> feeds) onRun,
    Future<void> Function()? onClose,
    List<String> inputNames,
    List<String> outputNames,
  }) = _MockOrtSessionHandle;
}

class _RealOrtSessionHandle implements OrtSessionHandle {
  _RealOrtSessionHandle(this._session, this.activeProvider);

  final OrtSession _session;

  @override
  final String activeProvider;

  @override
  List<String> get inputNames => _session.inputNames;

  @override
  List<String> get outputNames => _session.outputNames;

  @override
  Future<List<Tensor>> run(Map<String, Tensor> feeds) async {
    final inputs = <String, OrtValue>{};
    try {
      for (final entry in feeds.entries) {
        inputs[entry.key] = await _toOrtValue(entry.value);
      }

      final out = await _session.run(inputs);
      try {
        final result = <Tensor>[];
        for (final name in _session.outputNames) {
          final v = out[name];
          if (v != null) result.add(await _fromOrtValue(v));
        }
        return result;
      } finally {
        for (final v in out.values) {
          await v.dispose();
        }
      }
    } finally {
      for (final v in inputs.values) {
        await v.dispose();
      }
    }
  }

  Future<OrtValue> _toOrtValue(Tensor t) {
    final data = t.data;
    if (data is Float32List) return OrtValue.fromList(data, t.shape);
    if (data is Uint8List) return OrtValue.fromList(data, t.shape);
    if (data is Int32List) return OrtValue.fromList(data, t.shape);
    if (data is Int64List) return OrtValue.fromList(data, t.shape);
    throw StateError('unsupported feed dtype ${data.runtimeType}');
  }

  Future<Tensor> _fromOrtValue(OrtValue value) async {
    final shape = value.shape.isEmpty ? <int>[] : List<int>.from(value.shape);
    final flat = await value.asFlattenedList();

    List<int> outShape() => shape.isEmpty ? [flat.length] : shape;

    switch (value.dataType) {
      case OrtDataType.float32:
      case OrtDataType.float16:
      case OrtDataType.bfloat16:
        final f = Float32List(flat.length);
        for (var i = 0; i < flat.length; i++) {
          f[i] = (flat[i] as num).toDouble();
        }
        return Tensor(data: f, shape: outShape());
      case OrtDataType.string:
        return Tensor(data: Float32List(0), shape: const [0]);
      case OrtDataType.bool:
        final b = Int64List(flat.length);
        for (var i = 0; i < flat.length; i++) {
          final e = flat[i];
          b[i] = e is bool ? (e ? 1 : 0) : (e as num).toInt();
        }
        return Tensor(data: b, shape: outShape());
      default:
        final n = Int64List(flat.length);
        for (var i = 0; i < flat.length; i++) {
          n[i] = (flat[i] as num).toInt();
        }
        return Tensor(data: n, shape: outShape());
    }
  }

  @override
  Future<void> close() => _session.close();
}

class _MockOrtSessionHandle implements OrtSessionHandle {
  _MockOrtSessionHandle({
    required this.activeProvider,
    required Future<List<Tensor>> Function(Map<String, Tensor> feeds) onRun,
    Future<void> Function()? onClose,
    this.inputNames = const [],
    this.outputNames = const [],
  }) : _onRun = onRun,
       _onClose = onClose;

  @override
  final String activeProvider;
  @override
  final List<String> inputNames;
  @override
  final List<String> outputNames;

  final Future<List<Tensor>> Function(Map<String, Tensor> feeds) _onRun;
  final Future<void> Function()? _onClose;

  @override
  Future<List<Tensor>> run(Map<String, Tensor> feeds) => _onRun(feeds);

  @override
  Future<void> close() async => await _onClose?.call();
}

/// Reason a session failed to load, for surfacing in the UI.
void logOrt(String message) {
  if (kDebugMode) debugPrint('[onnx] $message');
}
