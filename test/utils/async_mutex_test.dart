import 'dart:async';

import 'package:budget_tracker/utils/async_mutex.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AsyncMutex mutex;

  setUp(() {
    mutex = AsyncMutex();
  });

  group('AsyncMutex', () {
    group('acquire() and release()', () {
      test('starts unlocked', () {
        expect(mutex.isLocked, isFalse);
        expect(mutex.waitingCount, 0);
      });

      test('acquire locks the mutex', () async {
        await mutex.acquire();
        expect(mutex.isLocked, isTrue);
      });

      test('release unlocks the mutex', () async {
        await mutex.acquire();
        mutex.release();
        expect(mutex.isLocked, isFalse);
      });

      test('release on unlocked mutex throws StateError', () {
        expect(() => mutex.release(), throwsStateError);
      });

      test('can acquire again after release', () async {
        await mutex.acquire();
        mutex.release();
        expect(mutex.isLocked, isFalse);

        await mutex.acquire();
        expect(mutex.isLocked, isTrue);
        mutex.release();
      });
    });

    group('isLocked getter', () {
      test('returns false when not acquired', () {
        expect(mutex.isLocked, isFalse);
      });

      test('returns true after acquire', () async {
        await mutex.acquire();
        expect(mutex.isLocked, isTrue);
      });

      test('returns false after acquire then release', () async {
        await mutex.acquire();
        mutex.release();
        expect(mutex.isLocked, isFalse);
      });

      test('stays true when lock is passed to next waiter', () async {
        await mutex.acquire();

        // Start a second acquire that will queue
        final secondAcquire = mutex.acquire();

        expect(mutex.isLocked, isTrue);
        expect(mutex.waitingCount, 1);

        // Release passes lock to the second waiter
        mutex.release();

        // Allow microtasks to run
        await secondAcquire;

        // Lock is still held by the second acquirer
        expect(mutex.isLocked, isTrue);
        expect(mutex.waitingCount, 0);

        mutex.release();
        expect(mutex.isLocked, isFalse);
      });
    });

    group('waitingCount', () {
      test('starts at zero', () {
        expect(mutex.waitingCount, 0);
      });

      test('increments when acquire is called on a locked mutex', () async {
        await mutex.acquire();
        expect(mutex.waitingCount, 0);

        // These will queue
        final f1 = mutex.acquire();
        expect(mutex.waitingCount, 1);

        final f2 = mutex.acquire();
        expect(mutex.waitingCount, 2);

        final f3 = mutex.acquire();
        expect(mutex.waitingCount, 3);

        // Clean up: release all
        mutex.release();
        await f1;
        mutex.release();
        await f2;
        mutex.release();
        await f3;
        mutex.release();
      });

      test('decrements when a waiter acquires the lock', () async {
        await mutex.acquire();

        final f1 = mutex.acquire();
        final f2 = mutex.acquire();
        expect(mutex.waitingCount, 2);

        mutex.release();
        await f1;
        expect(mutex.waitingCount, 1);

        mutex.release();
        await f2;
        expect(mutex.waitingCount, 0);

        mutex.release();
      });
    });

    group('synchronized<T>()', () {
      test('acquires and releases lock around the function', () async {
        expect(mutex.isLocked, isFalse);

        final result = await mutex.synchronized(() async {
          expect(mutex.isLocked, isTrue);
          return 42;
        });

        expect(result, 42);
        expect(mutex.isLocked, isFalse);
      });

      test('returns the value from the function', () async {
        final result = await mutex.synchronized(() async {
          return 'hello';
        });
        expect(result, 'hello');
      });

      test('releases lock even when function throws', () async {
        expect(mutex.isLocked, isFalse);

        try {
          await mutex.synchronized<void>(() async {
            throw Exception('test error');
          });
        } catch (_) {
          // Expected
        }

        expect(mutex.isLocked, isFalse);
      });

      test('propagates the exception from the function', () async {
        expect(
          () => mutex.synchronized<void>(() async {
            throw FormatException('bad format');
          }),
          throwsFormatException,
        );
      });

      test('serializes concurrent synchronized calls', () async {
        final order = <int>[];

        final f1 = mutex.synchronized(() async {
          order.add(1);
          await Future.delayed(const Duration(milliseconds: 10));
          order.add(2);
          return 'first';
        });

        final f2 = mutex.synchronized(() async {
          order.add(3);
          await Future.delayed(const Duration(milliseconds: 10));
          order.add(4);
          return 'second';
        });

        final results = await Future.wait([f1, f2]);

        expect(results, ['first', 'second']);
        // f1 must complete (1, 2) before f2 starts (3, 4)
        expect(order, [1, 2, 3, 4]);
      });
    });

    group('FIFO ordering', () {
      test('multiple acquires are resolved in order', () async {
        final order = <int>[];

        await mutex.acquire();

        final f1 = mutex.acquire().then((_) => order.add(1));
        final f2 = mutex.acquire().then((_) => order.add(2));
        final f3 = mutex.acquire().then((_) => order.add(3));

        // Release the initial lock -> waiter 1 gets it
        mutex.release();
        await f1;

        // Release for waiter 1 -> waiter 2 gets it
        mutex.release();
        await f2;

        // Release for waiter 2 -> waiter 3 gets it
        mutex.release();
        await f3;

        // Final release
        mutex.release();

        expect(order, [1, 2, 3]);
      });

      test('synchronized calls execute in FIFO order', () async {
        final order = <String>[];

        final futures = <Future>[];
        for (int i = 0; i < 5; i++) {
          futures.add(mutex.synchronized(() async {
            order.add('start_$i');
            // Yield to ensure ordering is real
            await Future.delayed(Duration.zero);
            order.add('end_$i');
          }));
        }

        await Future.wait(futures);

        // Each task must fully complete before the next starts
        expect(order, [
          'start_0',
          'end_0',
          'start_1',
          'end_1',
          'start_2',
          'end_2',
          'start_3',
          'end_3',
          'start_4',
          'end_4',
        ]);
      });
    });

    group('reentrance check', () {
      test('second acquire blocks until first is released', () async {
        await mutex.acquire();

        var secondAcquired = false;
        final secondFuture = mutex.acquire().then((_) {
          secondAcquired = true;
        });

        // Give microtasks a chance to run
        await Future.delayed(Duration.zero);

        // Second acquire should still be blocked
        expect(secondAcquired, isFalse);
        expect(mutex.waitingCount, 1);

        // Release first lock
        mutex.release();
        await secondFuture;

        expect(secondAcquired, isTrue);
        expect(mutex.isLocked, isTrue);
        expect(mutex.waitingCount, 0);

        mutex.release();
      });

      test('lock handoff keeps mutex locked throughout', () async {
        await mutex.acquire();

        final f = mutex.acquire();

        // Before release, still locked
        expect(mutex.isLocked, isTrue);

        // After release (handoff), still locked
        mutex.release();
        await f;
        expect(mutex.isLocked, isTrue);

        // After final release, unlocked
        mutex.release();
        expect(mutex.isLocked, isFalse);
      });
    });
  });
}
