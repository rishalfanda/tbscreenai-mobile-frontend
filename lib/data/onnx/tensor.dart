import 'dart:typed_data';

/// A plain N-D tensor moved between chain steps. Row-major.
///
/// The chain executor only ever *copies* these by name — it never reshapes or
/// does arithmetic on them (all of that is inside the ONNX graphs).
class Tensor {
  Tensor({required this.data, required this.shape});

  /// `Float32List`, `Int64List`, `Int32List` or `Uint8List`.
  final TypedData data;
  final List<int> shape;

  int get elementCount => shape.fold(1, (a, b) => a * b);

  bool get isFloat32 => data is Float32List;
  bool get isInt64 => data is Int64List;
  bool get isUint8 => data is Uint8List;

  Float32List get asFloat32 => data as Float32List;
  Int64List get asInt64 => data as Int64List;
  Uint8List get asUint8 => data as Uint8List;

  /// The scalar / first element as a double (probabilities, flags).
  double get firstAsDouble {
    final d = data;
    if (d is Float32List) return d.first;
    if (d is Float64List) return d.first;
    if (d is Int64List) return d.first.toDouble();
    if (d is Int32List) return d.first.toDouble();
    if (d is Uint8List) return d.first.toDouble();
    throw StateError('unsupported tensor dtype ${d.runtimeType}');
  }

  List<double> toDoubleList() {
    final d = data;
    if (d is Float32List) return List<double>.from(d);
    if (d is Float64List) return List<double>.from(d);
    if (d is Int64List) return [for (final v in d) v.toDouble()];
    if (d is Int32List) return [for (final v in d) v.toDouble()];
    if (d is Uint8List) return [for (final v in d) v.toDouble()];
    throw StateError('unsupported tensor dtype ${d.runtimeType}');
  }

  /// `(H, W)` int grid, dropping any leading size-1 dims (`[1,1,H,W]`/`[1,H,W]`).
  Int32List to2dInt(int height, int width) {
    final flat = toDoubleList();
    final out = Int32List(height * width);
    final offset = flat.length - height * width;
    for (var i = 0; i < out.length; i++) {
      out[i] = flat[offset + i].round();
    }
    return out;
  }

  Float32List to2dFloat(int height, int width) {
    final flat = toDoubleList();
    final out = Float32List(height * width);
    final offset = flat.length - height * width;
    for (var i = 0; i < out.length; i++) {
      out[i] = flat[offset + i];
    }
    return out;
  }
}
