import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/providers/app_state.dart';

/// FIX Phase 3c — Regression tests for Bug #1.
///
/// Bug #1: `_processRecurringExpenses` / `_processRecurringIncomes`
/// previously called `_processMonthlyRecurring` unconditionally, so
/// weekly (frequencyIndex=2) and biweekly (frequencyIndex=1) items
/// were silently ignored — they stayed in the DB but never
/// materialized into expenses/income rows.
///
/// The fix introduced `processRecurringInstances<T>` as a dispatcher
/// keyed on `frequencyIndex`:
/// ```
/// 0 → _processMonthlyRecurring
/// 1 → _processIntervalRecurring (stepDays: 14)
/// 2 → _processIntervalRecurring (stepDays: 7)
/// ```
///
/// `processRecurringInstances` is `@visibleForTesting` + `static`, so
/// these tests drive the real production dispatcher directly without
/// spinning up `AppState`, a DB, or any platform plugins. Each test
/// collects the generated dates via a trivial `createTransaction`
/// callback and inspects the list.
///
/// All DateTimes below are UTC because `DateHelper.normalize` (used
/// internally by the scheduler) returns `DateTime.utc(y, m, d)`.
void main() {
  // Shorthand for a UTC year-month-day. The scheduler normalizes every
  // output through `DateHelper.normalize` which produces UTC dates, so
  // tests compare in the same timezone domain.
  DateTime ymd(int y, int m, int d) => DateTime.utc(y, m, d);

  /// Helper: run the dispatcher and return the generated dates.
  List<DateTime> runFor({
    required int frequencyIndex,
    required int dayOfMonthOrWeek,
    required DateTime now,
    DateTime? lastCreated,
    DateTime? startDate,
  }) {
    return AppState.processRecurringInstances<DateTime>(
      lastCreated: lastCreated,
      startDate: startDate,
      dayOfMonthOrWeek: dayOfMonthOrWeek,
      frequencyIndex: frequencyIndex,
      now: now,
      createTransaction: (date) => date,
    );
  }

  group('processRecurringInstances — monthly (frequencyIndex=0)', () {
    test('generates current month when today.day >= dayOfMonth', () {
      final dates = runFor(
        frequencyIndex: 0,
        dayOfMonthOrWeek: 1,
        now: ymd(2026, 4, 14),
      );
      expect(dates.length, 1);
      expect(dates.first, ymd(2026, 4, 1));
    });

    test('skips current month when today.day < dayOfMonth', () {
      // New recurring, billed on the 20th, today is the 14th → no instance yet.
      final dates = runFor(
        frequencyIndex: 0,
        dayOfMonthOrWeek: 20,
        now: ymd(2026, 4, 14),
      );
      expect(dates, isEmpty);
    });

    test('generates from lastCreated forward, skipping already-created months', () {
      // Last created on 2026-01-01 (Jan processed), today is 2026-04-14.
      // Dispatcher should generate Feb, Mar, Apr.
      final dates = runFor(
        frequencyIndex: 0,
        dayOfMonthOrWeek: 1,
        now: ymd(2026, 4, 14),
        lastCreated: ymd(2026, 1, 1),
      );
      expect(dates.length, 3);
      expect(dates, [
        ymd(2026, 2, 1),
        ymd(2026, 3, 1),
        ymd(2026, 4, 1),
      ]);
    });

    test('clamps dayOfMonth=31 to the last day of a short month during back-fill', () {
      // dayOfMonth=31, lastCreated Jan 15, today April 1 2026.
      // Jan 15 cannot be an instance of a day-31 bill — it is the run day an
      // older build stored — so January's instance (Jan 31) is still owed;
      // the old generator silently skipped it. Back-fill then walks Feb and
      // March: Feb has 28 days so the instance clamps to Feb 28, March
      // generates Mar 31. April's (Apr 30) is not due yet on April 1.
      final dates = runFor(
        frequencyIndex: 0,
        dayOfMonthOrWeek: 31,
        now: ymd(2026, 4, 1),
        lastCreated: ymd(2026, 1, 15),
      );
      expect(dates, [ymd(2026, 1, 31), ymd(2026, 2, 28), ymd(2026, 3, 31)]);
    });

    test('hits Feb 29 in a leap year', () {
      // 2028 is a leap year — dayOfMonth=29 must land on Feb 29.
      final dates = runFor(
        frequencyIndex: 0,
        dayOfMonthOrWeek: 29,
        now: ymd(2028, 2, 29),
      );
      expect(dates.length, 1);
      expect(dates.first, ymd(2028, 2, 29));
    });
  });

  group('processRecurringInstances — biweekly (frequencyIndex=1)', () {
    test('generates instances 14 days apart from lastCreated', () {
      // Last instance 2026-03-17, today 2026-04-14 → 28 days later → 2 instances.
      final dates = runFor(
        frequencyIndex: 1,
        dayOfMonthOrWeek: 1, // unused with a lastCreated anchor
        now: ymd(2026, 4, 14),
        lastCreated: ymd(2026, 3, 17),
      );
      expect(dates.length, 2);
      expect(dates, [ymd(2026, 3, 31), ymd(2026, 4, 14)]);
    });

    test('first instance is the chosen weekday on or after startDate', () {
      // startDate is a Tuesday; the bill is on Mondays (0). The first
      // instance is the following Monday, not the Tuesday it was set up on.
      final dates = runFor(
        frequencyIndex: 1,
        dayOfMonthOrWeek: 0,
        now: ymd(2026, 4, 14),
        startDate: ymd(2026, 4, 7),
      );
      expect(dates, [ymd(2026, 4, 13)]); // next one is 14 days later
    });

    test('returns empty when lastCreated was less than 14 days ago', () {
      // Last 7 days ago → next is in 7 more days.
      final dates = runFor(
        frequencyIndex: 1,
        dayOfMonthOrWeek: 0,
        now: ymd(2026, 4, 14),
        lastCreated: ymd(2026, 4, 7),
      );
      expect(dates, isEmpty);
    });

    test('Bug #1 regression: biweekly is NOT routed to the monthly generator', () {
      // With the old bug, a biweekly recurring with dayOfMonthOrWeek=14
      // (interpreted as dayOfMonth in the buggy monthly path) would
      // have generated a single instance on 2026-04-14. The fixed
      // dispatcher walks the 14-day step from lastCreated instead.
      final dates = runFor(
        frequencyIndex: 1,
        dayOfMonthOrWeek: 14, // a day-of-month that would tempt the monthly path
        now: ymd(2026, 4, 28),
        lastCreated: ymd(2026, 4, 14),
      );
      // Fixed path: 2026-04-14 + 14 days = 2026-04-28 (exactly today).
      expect(dates.length, 1);
      expect(dates.first, ymd(2026, 4, 28));
    });
  });

  group('processRecurringInstances — weekly (frequencyIndex=2)', () {
    test('generates instances 7 days apart from lastCreated', () {
      // Last 2026-03-24, today 2026-04-14 → 21 days → 3 instances.
      final dates = runFor(
        frequencyIndex: 2,
        dayOfMonthOrWeek: 1,
        now: ymd(2026, 4, 14),
        lastCreated: ymd(2026, 3, 24),
      );
      expect(dates.length, 3);
      expect(dates, [
        ymd(2026, 3, 31),
        ymd(2026, 4, 7),
        ymd(2026, 4, 14),
      ]);
    });

    test('first instance is the chosen weekday on or after startDate', () {
      // startDate 2026-04-07 is a Tuesday; the bill is on Mondays (0).
      final dates = runFor(
        frequencyIndex: 2,
        dayOfMonthOrWeek: 0,
        now: ymd(2026, 4, 14),
        startDate: ymd(2026, 4, 7),
      );
      expect(dates, [ymd(2026, 4, 13)]);
    });

    test('a Friday bill set up on a Monday posts on Fridays', () {
      final dates = runFor(
        frequencyIndex: 2,
        dayOfMonthOrWeek: 4, // Friday
        now: ymd(2026, 4, 25), // Saturday
        startDate: ymd(2026, 4, 13), // Monday
      );
      expect(dates, [ymd(2026, 4, 17), ymd(2026, 4, 24)]);
    });

    test('a run-day lastCreated from an older build re-anchors forward', () {
      // Builds before 5.4 stored the day processing ran (a Tuesday here) for
      // a Friday bill. The next instance moves forward to a Friday and is
      // never less than a full week after the stored date.
      final dates = runFor(
        frequencyIndex: 2,
        dayOfMonthOrWeek: 4, // Friday
        now: ymd(2026, 5, 1), // Friday
        lastCreated: ymd(2026, 4, 14), // Tuesday
      );
      expect(dates, [ymd(2026, 4, 24), ymd(2026, 5, 1)]);
    });

    test('with no lastCreated and no startDate, back-fills to matching weekday', () {
      // 2026-04-14 is a Tuesday (DateTime.weekday = 2 → 0-indexed 1).
      // dayOfWeek=0 (Mon) should back-fill to Mon 2026-04-13.
      final dates = runFor(
        frequencyIndex: 2,
        dayOfMonthOrWeek: 0, // Monday in model convention
        now: ymd(2026, 4, 14),
      );
      expect(dates, [ymd(2026, 4, 13)]);
    });

    test('Bug #1 regression: weekly is NOT routed to the monthly generator', () {
      // Old bug: this would have been interpreted as dayOfMonth=7 →
      // monthly generator → 1 instance on 2026-04-07. Fixed dispatcher
      // walks 7-day steps instead.
      final dates = runFor(
        frequencyIndex: 2,
        dayOfMonthOrWeek: 7,
        now: ymd(2026, 4, 28),
        lastCreated: ymd(2026, 4, 7),
      );
      expect(dates.length, 3);
      expect(dates, [
        ymd(2026, 4, 14),
        ymd(2026, 4, 21),
        ymd(2026, 4, 28),
      ]);
    });

    test('safety cap prevents runaway generation for malformed lastCreated', () {
      // lastCreated far in the past (15 years) — cap is 520.
      final dates = runFor(
        frequencyIndex: 2,
        dayOfMonthOrWeek: 0,
        now: ymd(2026, 4, 14),
        lastCreated: ymd(2011, 1, 1),
      );
      expect(dates.length, lessThanOrEqualTo(520));
    });
  });

  group('recurringDueDates — month-boundary regressions (2026-10 review)', () {
    List<DateTime> monthly({
      required int day,
      required DateTime now,
      DateTime? lastCreated,
      DateTime? endDate,
      int? maxCount,
    }) {
      return AppState.recurringDueDates(
        lastCreated: lastCreated,
        startDate: null,
        dayOfMonthOrWeek: day,
        frequencyIndex: 0,
        now: now,
        endDate: endDate,
        maxCount: maxCount,
      );
    }

    test('a bill due on the 1st posts in the month it is due', () {
      // lastCreated is the last INSTANCE (Sep 1). Opening the app on Oct 12
      // creates October's. The old code looked for "Oct 12", found it after
      // Oct 1, and created nothing until November.
      expect(
        monthly(day: 1, lastCreated: ymd(2026, 9, 1), now: ymd(2026, 10, 12)),
        [ymd(2026, 10, 1)],
      );
    });

    test('the following month is not skipped', () {
      expect(
        monthly(day: 1, lastCreated: ymd(2026, 10, 1), now: ymd(2026, 11, 2)),
        [ymd(2026, 11, 1)],
      );
    });

    test('day 31 posts on the 30th of a 30-day month, that month', () {
      expect(monthly(day: 31, now: ymd(2026, 9, 30)), [ymd(2026, 9, 30)]);
    });

    test('a run-day lastCreated before the due day still owes that month', () {
      // Older builds stored the run day (Oct 12) for a bill due the 20th.
      expect(
        monthly(day: 20, lastCreated: ymd(2026, 10, 12), now: ymd(2026, 10, 25)),
        [ymd(2026, 10, 20)],
      );
    });

    test('a run-day lastCreated on or after the due day never duplicates', () {
      // The Oct 5 instance may already exist; only November's is created.
      expect(
        monthly(day: 5, lastCreated: ymd(2026, 10, 12), now: ymd(2026, 11, 6)),
        [ymd(2026, 11, 5)],
      );
    });

    test('catch-up stops at the end date', () {
      // Ended Feb 15: February's instance was owed, March's and April's not.
      expect(
        monthly(
          day: 1,
          lastCreated: ymd(2026, 1, 1),
          now: ymd(2026, 4, 14),
          endDate: ymd(2026, 2, 15),
        ),
        [ymd(2026, 2, 1)],
      );
    });

    test('catch-up stops at the remaining occurrence count', () {
      expect(
        monthly(
          day: 1,
          lastCreated: ymd(2026, 1, 1),
          now: ymd(2026, 4, 14),
          maxCount: 2,
        ),
        [ymd(2026, 2, 1), ymd(2026, 3, 1)],
      );
      expect(
        monthly(
          day: 1,
          lastCreated: ymd(2026, 1, 1),
          now: ymd(2026, 4, 14),
          maxCount: 0,
        ),
        isEmpty,
      );
    });
  });

  group('processRecurringInstances — unknown frequency', () {
    test('returns empty list for invalid frequencyIndex', () {
      final dates = runFor(
        frequencyIndex: 99,
        dayOfMonthOrWeek: 1,
        now: ymd(2026, 4, 14),
      );
      expect(dates, isEmpty);
    });
  });
}
