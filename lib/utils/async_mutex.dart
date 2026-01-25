import 'dart:async';
import 'dart:collection';

/// A robust async mutex to prevent concurrent write operations to the database.
/// This ensures that complex transactions don't interleave and cause deadlocks.
///
/// FIX: Uses a queue-based approach to prevent race conditions and ensure FIFO ordering.
/// The previous while-loop approach could miss wake-ups if a completer completed
/// between the null check and the await.
class AsyncMutex {
  /// Queue of waiting completers for FIFO lock acquisition
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  /// Whether the lock is currently held
  bool _isLocked = false;

  /// Acquire the lock - waits until the lock is available.
  /// Uses a queue to ensure fair ordering of lock requests.
  Future<void> acquire() async {
    if (!_isLocked) {
      // Lock is free, acquire immediately
      _isLocked = true;
      return;
    }

    // Lock is held, add ourselves to the wait queue
    final completer = Completer<void>();
    _waitQueue.add(completer);

    // Wait for our turn
    await completer.future;
  }

  /// Release the lock.
  /// If there are waiters, wakes up the next one in FIFO order.
  void release() {
    if (!_isLocked) {
      throw StateError('Cannot release mutex that is not locked');
    }

    if (_waitQueue.isNotEmpty) {
      // Wake up the next waiter (they now hold the lock)
      final nextWaiter = _waitQueue.removeFirst();
      // Note: _isLocked stays true because we're passing the lock to the next waiter
      nextWaiter.complete();
    } else {
      // No waiters, release the lock
      _isLocked = false;
    }
  }

  /// Execute a function while holding the lock.
  /// Automatically releases the lock when done, even if the function throws.
  Future<T> synchronized<T>(Future<T> Function() fn) async {
    await acquire();
    try {
      return await fn();
    } finally {
      release();
    }
  }

  /// Check if the mutex is currently locked.
  /// Useful for debugging and assertions.
  bool get isLocked => _isLocked;

  /// Get the number of waiters in the queue.
  /// Useful for debugging and monitoring.
  int get waitingCount => _waitQueue.length;
}
