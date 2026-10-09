import 'dart:async';

/// An asynchronous counting semaphore to limit concurrent operations.
///
/// Useful for bounding concurrent ONNX inference sessions to prevent
/// memory spikes and CPU thrashing on resource-constrained devices.
class AsyncSemaphore {
  AsyncSemaphore(this.maxPermits) : _availablePermits = maxPermits {
    if (maxPermits <= 0) {
      throw ArgumentError.value(
        maxPermits,
        'maxPermits',
        'must be greater than 0',
      );
    }
  }

  final int maxPermits;
  int _availablePermits;
  final List<Completer<void>> _waitQueue = [];

  int get availablePermits => _availablePermits;
  int get queueLength => _waitQueue.length;

  /// Acquires a single permit, waiting asynchronously if none are available.
  Future<void> acquire() {
    if (_availablePermits > 0) {
      _availablePermits--;
      return Future.value();
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  /// Releases a permit, unblocking the next waiting task if any.
  void release() {
    if (_waitQueue.isNotEmpty) {
      final next = _waitQueue.removeAt(0);
      next.complete();
    } else {
      _availablePermits++;
    }
  }

  /// Executes [action] with a permit, ensuring the permit is released even
  /// if [action] throws.
  Future<T> withPermit<T>(Future<T> Function() action) async {
    await acquire();
    try {
      return await action();
    } finally {
      release();
    }
  }
}

