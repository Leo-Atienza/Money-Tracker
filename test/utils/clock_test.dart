import 'package:budget_tracker/utils/clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 7.9 — Clock injection contract.
void main() {
  tearDown(() {
    // Always reset to real wall clock so leakage doesn't cascade
    // through later tests in the run order.
    Clock.instance = const Clock();
  });

  group('Clock', () {
    test('default Clock returns real wall clock', () {
      final before = DateTime.now();
      final now = Clock.instance.now();
      final after = DateTime.now();
      expect(
        now.isAfter(before.subtract(const Duration(milliseconds: 100))),
        isTrue,
      );
      expect(
        now.isBefore(after.add(const Duration(milliseconds: 100))),
        isTrue,
      );
    });
  });

  group('FakeClock.fixed', () {
    test('returns the same DateTime on every call', () {
      final fixed = DateTime(2026, 6, 1, 12, 0, 0);
      Clock.instance = FakeClock.fixed(fixed);
      expect(Clock.instance.now(), fixed);
      expect(Clock.instance.now(), fixed);
      expect(Clock.instance.now(), fixed);
    });

    test('can be swapped out per-test and reset in tearDown', () {
      Clock.instance = FakeClock.fixed(DateTime(2030, 1, 1));
      expect(Clock.instance.now().year, 2030);
    });
  });

  group('FakeClock.sequence', () {
    test('yields each entry in order, then sticks on the last', () {
      Clock.instance = FakeClock.sequence([
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 2),
        DateTime(2026, 6, 3),
      ]);
      expect(Clock.instance.now(), DateTime(2026, 6, 1));
      expect(Clock.instance.now(), DateTime(2026, 6, 2));
      expect(Clock.instance.now(), DateTime(2026, 6, 3));
      // After exhaustion the sequence sticks on the last value — this
      // models "PIN lockout has expired and stays expired" without
      // forcing the test to know exactly how many `now()` calls the
      // code under test will make.
      expect(Clock.instance.now(), DateTime(2026, 6, 3));
      expect(Clock.instance.now(), DateTime(2026, 6, 3));
    });

    test('refuses an empty sequence', () {
      expect(() => FakeClock.sequence([]), throwsA(isA<AssertionError>()));
    });
  });
}
