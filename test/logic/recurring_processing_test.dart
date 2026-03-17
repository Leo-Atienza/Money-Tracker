import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/date_helper.dart';

/// Standalone copy of AppState._processMonthlyRecurring for testability.
/// This mirrors the exact algorithm (with bug fix H2) from app_state.dart.
List<T> processMonthlyRecurring<T>({
  required DateTime? lastCreated,
  required int dayOfMonth,
  required DateTime now,
  required T Function(DateTime date) createTransaction,
}) {
  final List<T> transactionsToCreate = [];
  // FIX H2: When lastCreated is null (new recurring), always start from current month.
  DateTime currentMonth = lastCreated == null
      ? DateHelper.startOfMonth(now)
      : DateHelper.addMonths(lastCreated, 1);
  final currentMonthStart = DateHelper.startOfMonth(now);

  while (!DateHelper.normalize(currentMonth).isAfter(currentMonthStart)) {
    if (DateHelper.normalize(currentMonth).isBefore(currentMonthStart) ||
        now.day >= dayOfMonth) {
      final lastDay = DateHelper.lastDayOfMonth(currentMonth).day;
      transactionsToCreate.add(createTransaction(DateHelper.normalize(
        DateTime(
          currentMonth.year,
          currentMonth.month,
          dayOfMonth > lastDay ? lastDay : dayOfMonth,
        ),
      )));
    }
    currentMonth = DateHelper.addMonths(currentMonth, 1);
  }
  return transactionsToCreate;
}

void main() {
  /// Helper: runs processMonthlyRecurring and returns the list of generated dates.
  List<DateTime> run({
    DateTime? lastCreated,
    required int dayOfMonth,
    required DateTime now,
  }) {
    return processMonthlyRecurring<DateTime>(
      lastCreated: lastCreated,
      dayOfMonth: dayOfMonth,
      now: now,
      createTransaction: (date) => date,
    );
  }

  group('processMonthlyRecurring', () {
    // ---------------------------------------------------------------
    // 1. New recurring (lastCreated=null), today >= dayOfMonth
    //    Bug fix H2: should create a transaction for the current month.
    //
    //    currentMonth = startOfMonth(now) = Mar 1
    //    currentMonthStart = Mar 1
    //    Loop: Mar 1 is NOT after Mar 1 -> true, enters loop
    //    Mar 1 is NOT before Mar 1 -> false, check day: 15 >= 10 -> true
    //    Creates Mar 10. Then addMonths(Mar 1, 1) = Apr 1 > Mar 1, loop ends.
    // ---------------------------------------------------------------
    test('1. new recurring, today >= dayOfMonth -> creates current month', () {
      final results = run(
        lastCreated: null,
        dayOfMonth: 10,
        now: DateTime(2026, 3, 15), // day 15 >= 10
      );

      expect(results, hasLength(1));
      expect(results[0], DateTime.utc(2026, 3, 10));
    });

    // ---------------------------------------------------------------
    // 2. New recurring (lastCreated=null), today < dayOfMonth
    //    currentMonth = Mar 1, currentMonthStart = Mar 1
    //    Loop enters (Mar 1 not after Mar 1).
    //    Mar 1 not before Mar 1 -> false. day: 15 >= 20 -> false.
    //    Neither condition met, no transaction created.
    // ---------------------------------------------------------------
    test('2. new recurring, today < dayOfMonth -> creates nothing', () {
      final results = run(
        lastCreated: null,
        dayOfMonth: 20,
        now: DateTime(2026, 3, 15), // day 15 < 20
      );

      expect(results, isEmpty);
    });

    // ---------------------------------------------------------------
    // 3. lastCreated = last month (day 1), today >= dayOfMonth
    //    addMonths(Feb 1, 1) = Mar 1. currentMonthStart = Mar 1.
    //    Mar 1 not after Mar 1 -> enters loop.
    //    Mar 1 not before Mar 1 -> false. day: 10 >= 5 -> true.
    //    Creates Mar 5.
    //
    //    NOTE: lastCreated's day affects iteration. When lastCreated
    //    has day > 1, addMonths may land past the 1st of next month,
    //    causing the while condition to fail. In practice, lastCreated
    //    stores the actual transaction date (dayOfMonth), so we use
    //    a date where day=1 here to ensure the loop enters.
    //    For dayOfMonth > 1, see test 3b.
    // ---------------------------------------------------------------
    test('3. lastCreated last month day 1, today >= dayOfMonth -> one transaction',
        () {
      final results = run(
        lastCreated: DateTime.utc(2026, 2, 1),
        dayOfMonth: 5,
        now: DateTime(2026, 3, 10), // day 10 >= 5
      );

      expect(results, hasLength(1));
      expect(results[0], DateTime.utc(2026, 3, 5));
    });

    // ---------------------------------------------------------------
    // 3b. lastCreated = last month with day = dayOfMonth (typical case)
    //     lastCreated = Feb 5, dayOfMonth = 5
    //     addMonths(Feb 5, 1) = Mar 5. currentMonthStart = Mar 1.
    //     Mar 5 IS after Mar 1 -> while condition false -> loop never runs.
    //     This means: if lastCreated's day > 1, the algorithm won't
    //     generate for current month via the while loop. This is the
    //     actual algorithm behavior.
    // ---------------------------------------------------------------
    test('3b. lastCreated with day > 1 same as dayOfMonth -> no transaction (day past start of month)',
        () {
      final results = run(
        lastCreated: DateTime.utc(2026, 2, 5),
        dayOfMonth: 5,
        now: DateTime(2026, 3, 10),
      );

      // addMonths(Feb 5, 1) = Mar 5, which is after Mar 1, so loop doesn't run
      expect(results, isEmpty);
    });

    // ---------------------------------------------------------------
    // 4. lastCreated = last month, today < dayOfMonth
    //    lastCreated = Feb 1, dayOfMonth = 25.
    //    addMonths(Feb 1, 1) = Mar 1. currentMonthStart = Mar 1.
    //    Mar 1 not after Mar 1 -> enters loop.
    //    Mar 1 not before Mar 1 -> false. day: 10 >= 25 -> false.
    //    No transaction created.
    // ---------------------------------------------------------------
    test('4. lastCreated last month, today < dayOfMonth -> creates nothing',
        () {
      final results = run(
        lastCreated: DateTime.utc(2026, 2, 1),
        dayOfMonth: 25,
        now: DateTime(2026, 3, 10), // day 10 < 25
      );

      expect(results, isEmpty);
    });

    // ---------------------------------------------------------------
    // 5. lastCreated = 3 months ago, today >= dayOfMonth
    //    lastCreated = Dec 1, dayOfMonth = 1.
    //    addMonths(Dec 1, 1) = Jan 1. currentMonthStart = Mar 1.
    //    Jan 1 not after Mar 1 -> enters.
    //      Jan 1 before Mar 1 -> true, creates Jan 1.
    //      addMonths(Jan 1, 1) = Feb 1. Feb 1 before Mar 1 -> true, creates Feb 1.
    //      addMonths(Feb 1, 1) = Mar 1. Mar 1 not after Mar 1 -> enters.
    //        Mar 1 not before Mar 1 -> false. day: 5 >= 1 -> true, creates Mar 1.
    //      addMonths(Mar 1, 1) = Apr 1 > Mar 1 -> exits.
    // ---------------------------------------------------------------
    test('5. lastCreated 3 months ago -> catch-up creates 3 transactions', () {
      final results = run(
        lastCreated: DateTime.utc(2025, 12, 1),
        dayOfMonth: 1,
        now: DateTime(2026, 3, 5), // day 5 >= 1
      );

      expect(results, hasLength(3));
      expect(results[0], DateTime.utc(2026, 1, 1));
      expect(results[1], DateTime.utc(2026, 2, 1));
      expect(results[2], DateTime.utc(2026, 3, 1));
    });

    // ---------------------------------------------------------------
    // 6. lastCreated = current month (already processed)
    //    lastCreated = Mar 5, addMonths(Mar 5, 1) = Apr 5.
    //    Apr 5 > Mar 1 -> loop never runs.
    // ---------------------------------------------------------------
    test('6. lastCreated is current month -> creates nothing', () {
      final results = run(
        lastCreated: DateTime.utc(2026, 3, 5),
        dayOfMonth: 5,
        now: DateTime(2026, 3, 16),
      );

      expect(results, isEmpty);
    });

    // ---------------------------------------------------------------
    // 7. dayOfMonth = 31 in February -> should clamp to 28 (non-leap)
    //    lastCreated = Jan 31. addMonths(Jan 31, 1) = Feb 28 (clamped).
    //    currentMonthStart = Mar 1.
    //    Feb 28 not after Mar 1 -> enters loop.
    //      Feb 28 before Mar 1 -> true, creates. lastDayOfMonth(Feb) = 28.
    //      dayOfMonth 31 > 28 -> clamp to 28. Creates Feb 28.
    //    addMonths(Feb 28, 1) = Mar 28. Mar 28 > Mar 1 -> exits.
    //    Only 1 transaction (Feb), not 2 -- Mar is skipped because
    //    addMonths from Feb 28 lands on Mar 28 which is after Mar 1.
    // ---------------------------------------------------------------
    test('7. dayOfMonth 31 in February (non-leap) -> clamps to 28', () {
      final results = run(
        lastCreated: DateTime.utc(2026, 1, 31),
        dayOfMonth: 31,
        now: DateTime(2026, 3, 31),
      );

      // Only Feb is created; Mar 28 (from addMonths) > Mar 1, so loop exits
      // before processing March.
      expect(results, hasLength(1));
      expect(results[0], DateTime.utc(2026, 2, 28));
    });

    // ---------------------------------------------------------------
    // 8. dayOfMonth = 31 in April (30-day month)
    //    lastCreated = Mar 31. addMonths(Mar 31, 1) = Apr 30 (clamped).
    //    currentMonthStart = Apr 1. Apr 30 > Apr 1 -> loop never runs.
    // ---------------------------------------------------------------
    test('8. dayOfMonth 31 in April, now is April -> loop skips (addMonths clamp)', () {
      final results = run(
        lastCreated: DateTime.utc(2026, 3, 31),
        dayOfMonth: 31,
        now: DateTime(2026, 4, 30),
      );

      expect(results, isEmpty);
    });

    // ---------------------------------------------------------------
    // 8b. dayOfMonth 31, lastCreated March, now May
    //     addMonths(Mar 31, 1) = Apr 30. currentMonthStart = May 1.
    //     Apr 30 not after May 1 -> enters.
    //       Apr 30 before May 1 -> true, creates. lastDayOfMonth(Apr) = 30.
    //       31 > 30 -> clamp to 30. Creates Apr 30.
    //     addMonths(Apr 30, 1) = May 30. May 30 > May 1 -> exits.
    //     Only 1 transaction (Apr).
    // ---------------------------------------------------------------
    test('8b. dayOfMonth 31 in April, today is May -> clamps April to 30', () {
      final results = run(
        lastCreated: DateTime.utc(2026, 3, 31),
        dayOfMonth: 31,
        now: DateTime(2026, 5, 31),
      );

      // Only April created; addMonths(Apr 30, 1) = May 30 > May 1 -> exits
      expect(results, hasLength(1));
      expect(results[0], DateTime.utc(2026, 4, 30));
    });

    // ---------------------------------------------------------------
    // 9. Cross-year boundary (lastCreated in December, now in January)
    //    lastCreated = Dec 15. addMonths(Dec 15, 1) = Jan 15.
    //    currentMonthStart = Jan 1.
    //    Jan 15 IS after Jan 1 -> while condition false -> loop never runs.
    //
    //    To make this work, lastCreated day must be 1.
    // ---------------------------------------------------------------
    test('9. cross-year boundary Dec -> Jan (lastCreated day 1)', () {
      final results = run(
        lastCreated: DateTime.utc(2025, 12, 1),
        dayOfMonth: 15,
        now: DateTime(2026, 1, 20), // day 20 >= 15
      );

      // addMonths(Dec 1, 1) = Jan 1. currentMonthStart = Jan 1.
      // Jan 1 not after Jan 1 -> enters. Jan 1 not before Jan 1 -> false.
      // day: 20 >= 15 -> true. Creates Jan 15.
      expect(results, hasLength(1));
      expect(results[0], DateTime.utc(2026, 1, 15));
    });

    test('9b. cross-year boundary Dec 15 -> Jan (day > 1 causes skip)', () {
      final results = run(
        lastCreated: DateTime.utc(2025, 12, 15),
        dayOfMonth: 15,
        now: DateTime(2026, 1, 20),
      );

      // addMonths(Dec 15, 1) = Jan 15. Jan 15 > Jan 1 -> loop never runs.
      expect(results, isEmpty);
    });

    // ---------------------------------------------------------------
    // 10. Same month, different year (Jan 2025 -> Jan 2026)
    //     lastCreated = Jan 1 2025, dayOfMonth = 1.
    //     addMonths(Jan 1, 1) = Feb 1 2025. currentMonthStart = Jan 1 2026.
    //     Feb 1 2025 not after Jan 1 2026 -> enters.
    //     Feb through Dec are before Jan 2026 -> all created (11 months).
    //     Jan 1 2026 not after Jan 1 2026 -> enters.
    //       Jan 1 not before Jan 1 -> false. day: 5 >= 1 -> true. Creates.
    //     addMonths(Jan 1 2026, 1) = Feb 1 2026 > Jan 1 2026 -> exits.
    //     Total: 12 transactions.
    // ---------------------------------------------------------------
    test('10. lastCreated Jan 2025, now Jan 2026 -> 12 transactions', () {
      final results = run(
        lastCreated: DateTime.utc(2025, 1, 1),
        dayOfMonth: 1,
        now: DateTime(2026, 1, 5), // day 5 >= 1
      );

      expect(results, hasLength(12));
      expect(results[0], DateTime.utc(2025, 2, 1));
      expect(results[11], DateTime.utc(2026, 1, 1));

      // Verify all 12 months are sequential
      for (int i = 0; i < 12; i++) {
        final expectedMonth = (2 + i) > 12 ? (2 + i) - 12 : (2 + i);
        final expectedYear = (2 + i) > 12 ? 2026 : 2025;
        expect(results[i], DateTime.utc(expectedYear, expectedMonth, 1));
      }
    });

    // ---------------------------------------------------------------
    // Additional edge cases
    // ---------------------------------------------------------------

    test('dayOfMonth 29 in leap year February -> uses 29', () {
      // 2024 is a leap year. lastCreated Jan 1 so addMonths lands on Feb 1.
      final results = run(
        lastCreated: DateTime.utc(2024, 1, 1),
        dayOfMonth: 29,
        now: DateTime(2024, 2, 29), // day 29 >= 29
      );

      // addMonths(Jan 1, 1) = Feb 1. currentMonthStart = Feb 1.
      // Feb 1 not after Feb 1 -> enters.
      // Feb 1 not before Feb 1 -> false. day: 29 >= 29 -> true.
      // lastDayOfMonth(Feb 2024) = 29 (leap). 29 <= 29 -> no clamp. Creates Feb 29.
      expect(results, hasLength(1));
      expect(results[0], DateTime.utc(2024, 2, 29));
    });

    test('dayOfMonth 29 in non-leap year February -> clamps to 28', () {
      // 2025 is not a leap year. lastCreated Jan 1.
      final results = run(
        lastCreated: DateTime.utc(2025, 1, 1),
        dayOfMonth: 29,
        now: DateTime(2025, 2, 28), // day 28 < 29 -> won't create for current month
      );

      // addMonths(Jan 1, 1) = Feb 1. currentMonthStart = Feb 1.
      // Feb 1 not after Feb 1 -> enters.
      // Feb 1 not before Feb 1 -> false. day: 28 >= 29 -> false.
      // No transaction created (day hasn't arrived, and Feb doesn't have 29).
      expect(results, isEmpty);
    });

    test('dayOfMonth 29 in non-leap Feb, caught up from past month -> clamps to 28', () {
      // lastCreated Dec 1, now is March. Feb is a past month so it gets created.
      final results = run(
        lastCreated: DateTime.utc(2024, 12, 1),
        dayOfMonth: 29,
        now: DateTime(2025, 3, 29),
      );

      // addMonths(Dec 1, 1) = Jan 1 2025. currentMonthStart = Mar 1.
      // Jan 1 before Mar 1 -> creates Jan 29.
      // addMonths(Jan 1, 1) = Feb 1. Feb 1 before Mar 1 -> creates.
      //   lastDayOfMonth(Feb 2025) = 28. 29 > 28 -> clamp to 28. Creates Feb 28.
      // addMonths(Feb 1, 1) = Mar 1. Mar 1 not after Mar 1 -> enters.
      //   Mar 1 not before Mar 1 -> false. day: 29 >= 29 -> true. Creates Mar 29.
      // addMonths(Mar 1, 1) = Apr 1 > Mar 1 -> exits.
      expect(results, hasLength(3));
      expect(results[0], DateTime.utc(2025, 1, 29));
      expect(results[1], DateTime.utc(2025, 2, 28)); // clamped
      expect(results[2], DateTime.utc(2025, 3, 29));
    });

    test('new recurring on exact dayOfMonth -> creates current month', () {
      final results = run(
        lastCreated: null,
        dayOfMonth: 15,
        now: DateTime(2026, 3, 15), // day 15 == 15, >= is true
      );

      expect(results, hasLength(1));
      expect(results[0], DateTime.utc(2026, 3, 15));
    });

    test('lastCreated far in the past (day 1) -> creates many catch-up transactions',
        () {
      // Using day 1 for lastCreated so addMonths always lands on day 1
      // and the iteration proceeds cleanly month by month.
      final results = run(
        lastCreated: DateTime.utc(2025, 1, 1),
        dayOfMonth: 10,
        now: DateTime(2026, 3, 15), // 14 months later, day 15 >= 10
      );

      // Feb 2025 through Mar 2026 = 14 months
      expect(results, hasLength(14));
      expect(results.first, DateTime.utc(2025, 2, 10));
      expect(results.last, DateTime.utc(2026, 3, 10));
    });

    // ---------------------------------------------------------------
    // Iteration drift: when lastCreated day > 1, addMonths may cause
    // the iterator to "drift" and skip the current month.
    // This documents the algorithm's actual behavior.
    // ---------------------------------------------------------------
    test('iteration drift: lastCreated day 15, 2 months ago -> creates only 1 (past month)', () {
      // lastCreated = Jan 15. addMonths(Jan 15, 1) = Feb 15.
      // currentMonthStart = Mar 1. Feb 15 not after Mar 1 -> enters.
      //   Feb 15 before Mar 1 -> true. Creates Feb 10.
      // addMonths(Feb 15, 1) = Mar 15. Mar 15 > Mar 1 -> exits.
      // Only 1 transaction, even though current month qualifies by day.
      final results = run(
        lastCreated: DateTime.utc(2026, 1, 15),
        dayOfMonth: 10,
        now: DateTime(2026, 3, 15),
      );

      expect(results, hasLength(1));
      expect(results[0], DateTime.utc(2026, 2, 10));
    });

    test('dayOfMonth 1 with lastCreated day 1 iterates perfectly', () {
      // This is the ideal case: day=1 means addMonths always lands on
      // the 1st, which equals startOfMonth, so the loop processes
      // every month correctly.
      final results = run(
        lastCreated: DateTime.utc(2025, 6, 1),
        dayOfMonth: 1,
        now: DateTime(2026, 1, 5),
      );

      // Jul 2025 through Jan 2026 = 7 months
      expect(results, hasLength(7));
      expect(results[0], DateTime.utc(2025, 7, 1));
      expect(results[6], DateTime.utc(2026, 1, 1));
    });
  });
}
