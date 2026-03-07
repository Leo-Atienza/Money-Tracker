import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/date_helper.dart';

void main() {
  // ---------------------------------------------------------------------------
  // normalize()
  // ---------------------------------------------------------------------------
  group('normalize()', () {
    test('strips time components and returns UTC midnight', () {
      final date = DateTime(2024, 3, 15, 14, 30, 45, 123);
      final result = DateHelper.normalize(date);

      expect(result.year, 2024);
      expect(result.month, 3);
      expect(result.day, 15);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
      expect(result.isUtc, isTrue);
    });

    test('preserves date components from local DateTime', () {
      final local = DateTime(2023, 12, 25, 23, 59, 59);
      final result = DateHelper.normalize(local);

      expect(result.year, 2023);
      expect(result.month, 12);
      expect(result.day, 25);
      expect(result.isUtc, isTrue);
    });

    test('preserves date components from UTC DateTime', () {
      final utc = DateTime.utc(2024, 1, 1, 12, 0);
      final result = DateHelper.normalize(utc);

      expect(result.year, 2024);
      expect(result.month, 1);
      expect(result.day, 1);
      expect(result.hour, 0);
      expect(result.isUtc, isTrue);
    });

    test('normalizing an already-normalized date returns equal value', () {
      final normalized = DateHelper.normalize(DateTime(2024, 6, 15));
      final again = DateHelper.normalize(normalized);

      expect(again, equals(normalized));
    });

    test('handles leap day', () {
      final leapDay = DateTime(2024, 2, 29, 18, 45);
      final result = DateHelper.normalize(leapDay);

      expect(result.year, 2024);
      expect(result.month, 2);
      expect(result.day, 29);
      expect(result.isUtc, isTrue);
    });

    test('handles midnight exactly', () {
      final midnight = DateTime(2024, 7, 4, 0, 0, 0, 0);
      final result = DateHelper.normalize(midnight);

      expect(result.year, 2024);
      expect(result.month, 7);
      expect(result.day, 4);
      expect(result.hour, 0);
      expect(result.isUtc, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // today()
  // ---------------------------------------------------------------------------
  group('today()', () {
    test('returns UTC midnight for today', () {
      final result = DateHelper.today();
      final now = DateTime.now();

      expect(result.year, now.year);
      expect(result.month, now.month);
      expect(result.day, now.day);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
      expect(result.isUtc, isTrue);
    });

    test('is equal to normalizing DateTime.now()', () {
      final todayResult = DateHelper.today();
      final normalizedNow = DateHelper.normalize(DateTime.now());

      expect(todayResult, equals(normalizedNow));
    });
  });

  // ---------------------------------------------------------------------------
  // startOfMonth()
  // ---------------------------------------------------------------------------
  group('startOfMonth()', () {
    test('returns first day of given month at UTC midnight', () {
      final date = DateTime(2024, 3, 15);
      final result = DateHelper.startOfMonth(date);

      expect(result.year, 2024);
      expect(result.month, 3);
      expect(result.day, 1);
      expect(result.hour, 0);
      expect(result.isUtc, isTrue);
    });

    test('returns same date if already first of month', () {
      final date = DateTime(2024, 1, 1);
      final result = DateHelper.startOfMonth(date);

      expect(result.day, 1);
      expect(result.month, 1);
    });

    test('handles December', () {
      final date = DateTime(2024, 12, 31);
      final result = DateHelper.startOfMonth(date);

      expect(result.year, 2024);
      expect(result.month, 12);
      expect(result.day, 1);
    });

    test('handles leap year February', () {
      final date = DateTime(2024, 2, 29);
      final result = DateHelper.startOfMonth(date);

      expect(result.year, 2024);
      expect(result.month, 2);
      expect(result.day, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // endOfMonth()
  // ---------------------------------------------------------------------------
  group('endOfMonth()', () {
    test('returns first day of next month (exclusive end)', () {
      final date = DateTime(2024, 3, 15);
      final result = DateHelper.endOfMonth(date);

      expect(result.year, 2024);
      expect(result.month, 4);
      expect(result.day, 1);
      expect(result.hour, 0);
      expect(result.isUtc, isTrue);
    });

    test('handles December -> January year boundary', () {
      final date = DateTime(2024, 12, 15);
      final result = DateHelper.endOfMonth(date);

      expect(result.year, 2025);
      expect(result.month, 1);
      expect(result.day, 1);
    });

    test('handles February in leap year', () {
      final date = DateTime(2024, 2, 10);
      final result = DateHelper.endOfMonth(date);

      expect(result.year, 2024);
      expect(result.month, 3);
      expect(result.day, 1);
    });

    test('handles February in non-leap year', () {
      final date = DateTime(2023, 2, 10);
      final result = DateHelper.endOfMonth(date);

      expect(result.year, 2023);
      expect(result.month, 3);
      expect(result.day, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // lastDayOfMonth()
  // ---------------------------------------------------------------------------
  group('lastDayOfMonth()', () {
    test('returns 31 for months with 31 days', () {
      for (final month in [1, 3, 5, 7, 8, 10, 12]) {
        final result = DateHelper.lastDayOfMonth(DateTime(2024, month, 1));
        expect(result.day, 31, reason: 'Month $month should have 31 days');
      }
    });

    test('returns 30 for months with 30 days', () {
      for (final month in [4, 6, 9, 11]) {
        final result = DateHelper.lastDayOfMonth(DateTime(2024, month, 1));
        expect(result.day, 30, reason: 'Month $month should have 30 days');
      }
    });

    test('returns 29 for February in leap year', () {
      final result = DateHelper.lastDayOfMonth(DateTime(2024, 2, 1));
      expect(result.day, 29);
    });

    test('returns 28 for February in non-leap year', () {
      final result = DateHelper.lastDayOfMonth(DateTime(2023, 2, 1));
      expect(result.day, 28);
    });

    test('result is UTC midnight on the last day', () {
      final result = DateHelper.lastDayOfMonth(DateTime(2024, 3, 15));

      expect(result.year, 2024);
      expect(result.month, 3);
      expect(result.day, 31);
      expect(result.hour, 0);
      expect(result.isUtc, isTrue);
    });

    test('handles December correctly', () {
      final result = DateHelper.lastDayOfMonth(DateTime(2024, 12, 5));

      expect(result.year, 2024);
      expect(result.month, 12);
      expect(result.day, 31);
    });

    test('handles century leap year rules', () {
      // 2000 is a leap year (divisible by 400)
      final result2000 = DateHelper.lastDayOfMonth(DateTime(2000, 2, 1));
      expect(result2000.day, 29);

      // 1900 is NOT a leap year (divisible by 100 but not 400)
      final result1900 = DateHelper.lastDayOfMonth(DateTime(1900, 2, 1));
      expect(result1900.day, 28);
    });
  });

  // ---------------------------------------------------------------------------
  // isSameDay()
  // ---------------------------------------------------------------------------
  group('isSameDay()', () {
    test('returns true for same date with different times', () {
      final a = DateTime(2024, 3, 15, 8, 30);
      final b = DateTime(2024, 3, 15, 22, 45);

      expect(DateHelper.isSameDay(a, b), isTrue);
    });

    test('returns false for different days', () {
      final a = DateTime(2024, 3, 15);
      final b = DateTime(2024, 3, 16);

      expect(DateHelper.isSameDay(a, b), isFalse);
    });

    test('returns false for same day in different months', () {
      final a = DateTime(2024, 3, 15);
      final b = DateTime(2024, 4, 15);

      expect(DateHelper.isSameDay(a, b), isFalse);
    });

    test('returns false for same day and month in different years', () {
      final a = DateTime(2024, 3, 15);
      final b = DateTime(2023, 3, 15);

      expect(DateHelper.isSameDay(a, b), isFalse);
    });

    test('works with UTC and local DateTimes', () {
      final utc = DateTime.utc(2024, 3, 15, 12, 0);
      final local = DateTime(2024, 3, 15, 6, 0);

      expect(DateHelper.isSameDay(utc, local), isTrue);
    });

    test('returns true for identical DateTimes', () {
      final date = DateTime(2024, 6, 1, 10, 30);
      expect(DateHelper.isSameDay(date, date), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // isPast()
  // ---------------------------------------------------------------------------
  group('isPast()', () {
    test('returns true for a date in the past', () {
      final pastDate = DateTime(2020, 1, 1);
      expect(DateHelper.isPast(pastDate), isTrue);
    });

    test('returns false for a date in the future', () {
      final futureDate = DateTime(2099, 12, 31);
      expect(DateHelper.isPast(futureDate), isFalse);
    });

    test('returns false for today', () {
      final todayDate = DateTime.now();
      expect(DateHelper.isPast(todayDate), isFalse);
    });

    test('returns true for yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(DateHelper.isPast(yesterday), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // isFuture()
  // ---------------------------------------------------------------------------
  group('isFuture()', () {
    test('returns true for a date in the future', () {
      final futureDate = DateTime(2099, 12, 31);
      expect(DateHelper.isFuture(futureDate), isTrue);
    });

    test('returns false for a date in the past', () {
      final pastDate = DateTime(2020, 1, 1);
      expect(DateHelper.isFuture(pastDate), isFalse);
    });

    test('returns false for today', () {
      final todayDate = DateTime.now();
      expect(DateHelper.isFuture(todayDate), isFalse);
    });

    test('returns true for tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(DateHelper.isFuture(tomorrow), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // isToday()
  // ---------------------------------------------------------------------------
  group('isToday()', () {
    test('returns true for DateTime.now()', () {
      expect(DateHelper.isToday(DateTime.now()), isTrue);
    });

    test('returns true for today with different time', () {
      final now = DateTime.now();
      final todayLater = DateTime(now.year, now.month, now.day, 23, 59, 59);
      expect(DateHelper.isToday(todayLater), isTrue);
    });

    test('returns false for yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(DateHelper.isToday(yesterday), isFalse);
    });

    test('returns false for tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(DateHelper.isToday(tomorrow), isFalse);
    });

    test('returns false for same day last year', () {
      final now = DateTime.now();
      final lastYear = DateTime(now.year - 1, now.month, now.day);
      expect(DateHelper.isToday(lastYear), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // toDateString()
  // ---------------------------------------------------------------------------
  group('toDateString()', () {
    test('returns ISO 8601 YYYY-MM-DD format', () {
      final date = DateTime(2024, 3, 15);
      expect(DateHelper.toDateString(date), '2024-03-15');
    });

    test('pads single-digit month and day with zeros', () {
      final date = DateTime(2024, 1, 5);
      expect(DateHelper.toDateString(date), '2024-01-05');
    });

    test('handles December 31', () {
      final date = DateTime(2024, 12, 31);
      expect(DateHelper.toDateString(date), '2024-12-31');
    });

    test('handles January 1', () {
      final date = DateTime(2024, 1, 1);
      expect(DateHelper.toDateString(date), '2024-01-01');
    });

    test('ignores time components', () {
      final date = DateTime(2024, 6, 15, 14, 30, 45);
      expect(DateHelper.toDateString(date), '2024-06-15');
    });

    test('handles leap day', () {
      final date = DateTime(2024, 2, 29);
      expect(DateHelper.toDateString(date), '2024-02-29');
    });
  });

  // ---------------------------------------------------------------------------
  // parseDate()
  // ---------------------------------------------------------------------------
  group('parseDate()', () {
    test('parses valid ISO 8601 date string', () {
      final result = DateHelper.parseDate('2024-03-15');

      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 3);
      expect(result.day, 15);
      expect(result.isUtc, isTrue);
    });

    test('normalizes parsed date to UTC midnight', () {
      final result = DateHelper.parseDate('2024-03-15T14:30:00');

      expect(result, isNotNull);
      expect(result!.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.isUtc, isTrue);
    });

    test('returns null for null input', () {
      expect(DateHelper.parseDate(null), isNull);
    });

    test('returns null for empty string', () {
      expect(DateHelper.parseDate(''), isNull);
    });

    test('returns null for invalid date string', () {
      expect(DateHelper.parseDate('not-a-date'), isNull);
    });

    test('returns null for malformed date', () {
      expect(DateHelper.parseDate('99/99/99'), isNull);
      expect(DateHelper.parseDate('abcd-ef-gh'), isNull);
      expect(DateHelper.parseDate('2024/03/15'), isNull);
    });

    test('parses date with timezone info and normalizes', () {
      final result = DateHelper.parseDate('2024-03-15T10:00:00Z');

      expect(result, isNotNull);
      expect(result!.year, 2024);
      expect(result.month, 3);
      expect(result.day, 15);
      expect(result.hour, 0);
      expect(result.isUtc, isTrue);
    });

    test('parses leap day', () {
      final result = DateHelper.parseDate('2024-02-29');

      expect(result, isNotNull);
      expect(result!.month, 2);
      expect(result.day, 29);
    });

    test('round-trips with toDateString', () {
      final original = DateTime(2024, 7, 20);
      final dateString = DateHelper.toDateString(original);
      final parsed = DateHelper.parseDate(dateString);

      expect(parsed, isNotNull);
      expect(parsed!.year, original.year);
      expect(parsed.month, original.month);
      expect(parsed.day, original.day);
    });
  });

  // ---------------------------------------------------------------------------
  // toMonthString()
  // ---------------------------------------------------------------------------
  group('toMonthString()', () {
    test('returns YYYY-MM format', () {
      final date = DateTime(2024, 3, 15);
      expect(DateHelper.toMonthString(date), '2024-03');
    });

    test('pads single-digit month with zero', () {
      final date = DateTime(2024, 1, 1);
      expect(DateHelper.toMonthString(date), '2024-01');
    });

    test('handles December', () {
      final date = DateTime(2024, 12, 31);
      expect(DateHelper.toMonthString(date), '2024-12');
    });

    test('handles different years', () {
      expect(DateHelper.toMonthString(DateTime(2000, 6, 1)), '2000-06');
      expect(DateHelper.toMonthString(DateTime(1999, 11, 15)), '1999-11');
    });

    test('ignores day component', () {
      final date1 = DateTime(2024, 5, 1);
      final date2 = DateTime(2024, 5, 31);
      expect(DateHelper.toMonthString(date1), DateHelper.toMonthString(date2));
    });
  });

  // ---------------------------------------------------------------------------
  // addMonths()
  // ---------------------------------------------------------------------------
  group('addMonths()', () {
    test('adds one month to a simple date', () {
      final date = DateTime(2024, 3, 15);
      final result = DateHelper.addMonths(date, 1);

      expect(result.year, 2024);
      expect(result.month, 4);
      expect(result.day, 15);
      expect(result.isUtc, isTrue);
    });

    test('adds multiple months', () {
      final date = DateTime(2024, 1, 10);
      final result = DateHelper.addMonths(date, 5);

      expect(result.year, 2024);
      expect(result.month, 6);
      expect(result.day, 10);
    });

    test('handles day overflow: Jan 31 + 1 month = Feb 28 (non-leap)', () {
      final date = DateTime(2023, 1, 31);
      final result = DateHelper.addMonths(date, 1);

      expect(result.year, 2023);
      expect(result.month, 2);
      expect(result.day, 28);
    });

    test('handles day overflow: Jan 31 + 1 month = Feb 29 (leap year)', () {
      final date = DateTime(2024, 1, 31);
      final result = DateHelper.addMonths(date, 1);

      expect(result.year, 2024);
      expect(result.month, 2);
      expect(result.day, 29);
    });

    test('handles day overflow: Jan 30 + 1 month = Feb 28 (non-leap)', () {
      final date = DateTime(2023, 1, 30);
      final result = DateHelper.addMonths(date, 1);

      expect(result.year, 2023);
      expect(result.month, 2);
      expect(result.day, 28);
    });

    test('handles year boundary: Dec + 1 month = Jan next year', () {
      final date = DateTime(2024, 12, 15);
      final result = DateHelper.addMonths(date, 1);

      expect(result.year, 2025);
      expect(result.month, 1);
      expect(result.day, 15);
    });

    test('handles year boundary: Nov + 3 months = Feb next year', () {
      final date = DateTime(2024, 11, 15);
      final result = DateHelper.addMonths(date, 3);

      expect(result.year, 2025);
      expect(result.month, 2);
      expect(result.day, 15);
    });

    test('adding 12 months advances exactly one year', () {
      final date = DateTime(2024, 6, 15);
      final result = DateHelper.addMonths(date, 12);

      expect(result.year, 2025);
      expect(result.month, 6);
      expect(result.day, 15);
    });

    test('adding 24 months advances exactly two years', () {
      final date = DateTime(2024, 3, 10);
      final result = DateHelper.addMonths(date, 24);

      expect(result.year, 2026);
      expect(result.month, 3);
      expect(result.day, 10);
    });

    test('adding 0 months returns same date normalized', () {
      final date = DateTime(2024, 5, 20, 14, 30);
      final result = DateHelper.addMonths(date, 0);

      expect(result.year, 2024);
      expect(result.month, 5);
      expect(result.day, 20);
      expect(result.hour, 0);
      expect(result.isUtc, isTrue);
    });

    test('handles negative months (subtracts)', () {
      final date = DateTime(2024, 5, 15);
      final result = DateHelper.addMonths(date, -2);

      expect(result.year, 2024);
      expect(result.month, 3);
      expect(result.day, 15);
    });

    test('handles negative months crossing year boundary', () {
      final date = DateTime(2024, 2, 15);
      final result = DateHelper.addMonths(date, -3);

      expect(result.year, 2023);
      expect(result.month, 11);
      expect(result.day, 15);
    });

    test(
        'handles negative months with day overflow: Mar 31 - 1 month = Feb 29 (leap)',
        () {
      final date = DateTime(2024, 3, 31);
      final result = DateHelper.addMonths(date, -1);

      expect(result.year, 2024);
      expect(result.month, 2);
      expect(result.day, 29);
    });

    test(
        'handles negative months with day overflow: Mar 31 - 1 month = Feb 28 (non-leap)',
        () {
      final date = DateTime(2023, 3, 31);
      final result = DateHelper.addMonths(date, -1);

      expect(result.year, 2023);
      expect(result.month, 2);
      expect(result.day, 28);
    });

    test('result is always UTC', () {
      final localDate = DateTime(2024, 5, 15, 10, 30);
      final result = DateHelper.addMonths(localDate, 1);

      expect(result.isUtc, isTrue);
      expect(result.hour, 0);
    });

    test('chaining: Jan 31 + 1 + 1 preserves clamped day', () {
      final jan31 = DateTime(2023, 1, 31);
      final feb28 = DateHelper.addMonths(jan31, 1); // Feb 28
      final mar28 = DateHelper.addMonths(feb28, 1); // Mar 28 (not 31)

      expect(feb28.day, 28);
      expect(mar28.month, 3);
      expect(mar28.day, 28);
    });

    test('handles Aug 31 + 1 month = Sep 30', () {
      final date = DateTime(2024, 8, 31);
      final result = DateHelper.addMonths(date, 1);

      expect(result.month, 9);
      expect(result.day, 30);
    });
  });

  // ---------------------------------------------------------------------------
  // subtractMonths()
  // ---------------------------------------------------------------------------
  group('subtractMonths()', () {
    test('subtracts one month', () {
      final date = DateTime(2024, 5, 15);
      final result = DateHelper.subtractMonths(date, 1);

      expect(result.year, 2024);
      expect(result.month, 4);
      expect(result.day, 15);
    });

    test('subtracts crossing year boundary', () {
      final date = DateTime(2024, 1, 15);
      final result = DateHelper.subtractMonths(date, 1);

      expect(result.year, 2023);
      expect(result.month, 12);
      expect(result.day, 15);
    });

    test('handles day overflow: Mar 31 - 1 = Feb 29 (leap)', () {
      final date = DateTime(2024, 3, 31);
      final result = DateHelper.subtractMonths(date, 1);

      expect(result.month, 2);
      expect(result.day, 29);
    });

    test('handles day overflow: Mar 31 - 1 = Feb 28 (non-leap)', () {
      final date = DateTime(2023, 3, 31);
      final result = DateHelper.subtractMonths(date, 1);

      expect(result.month, 2);
      expect(result.day, 28);
    });

    test('subtracting 12 months goes back exactly one year', () {
      final date = DateTime(2024, 6, 15);
      final result = DateHelper.subtractMonths(date, 12);

      expect(result.year, 2023);
      expect(result.month, 6);
      expect(result.day, 15);
    });

    test('subtracting 0 months returns normalized date', () {
      final date = DateTime(2024, 5, 20, 14, 30);
      final result = DateHelper.subtractMonths(date, 0);

      expect(result, equals(DateHelper.normalize(date)));
    });
  });

  // ---------------------------------------------------------------------------
  // daysBetween()
  // ---------------------------------------------------------------------------
  group('daysBetween()', () {
    test('returns positive difference for forward range', () {
      final start = DateTime(2024, 3, 1);
      final end = DateTime(2024, 3, 10);

      expect(DateHelper.daysBetween(start, end), 9);
    });

    test('returns negative difference for reversed range', () {
      final start = DateTime(2024, 3, 10);
      final end = DateTime(2024, 3, 1);

      expect(DateHelper.daysBetween(start, end), -9);
    });

    test('returns 0 for same date', () {
      final date = DateTime(2024, 3, 15);
      expect(DateHelper.daysBetween(date, date), 0);
    });

    test('returns 0 for same date with different times', () {
      final start = DateTime(2024, 3, 15, 8, 0);
      final end = DateTime(2024, 3, 15, 22, 0);

      expect(DateHelper.daysBetween(start, end), 0);
    });

    test('handles month boundary', () {
      final start = DateTime(2024, 1, 30);
      final end = DateTime(2024, 2, 2);

      expect(DateHelper.daysBetween(start, end), 3);
    });

    test('handles year boundary', () {
      final start = DateTime(2023, 12, 30);
      final end = DateTime(2024, 1, 2);

      expect(DateHelper.daysBetween(start, end), 3);
    });

    test('handles leap year Feb 28 to Mar 1', () {
      // Leap year: Feb has 29 days
      final start = DateTime(2024, 2, 28);
      final end = DateTime(2024, 3, 1);

      expect(
          DateHelper.daysBetween(start, end), 2); // Feb 28 -> Feb 29 -> Mar 1

      // Non-leap year: Feb has 28 days
      final start2 = DateTime(2023, 2, 28);
      final end2 = DateTime(2023, 3, 1);

      expect(DateHelper.daysBetween(start2, end2), 1); // Feb 28 -> Mar 1
    });

    test('one full year is 365 or 366 days', () {
      // Non-leap year
      expect(
        DateHelper.daysBetween(DateTime(2023, 1, 1), DateTime(2024, 1, 1)),
        365,
      );

      // Leap year
      expect(
        DateHelper.daysBetween(DateTime(2024, 1, 1), DateTime(2025, 1, 1)),
        366,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getRelativeTime()
  // ---------------------------------------------------------------------------
  group('getRelativeTime()', () {
    test('returns "Just now" for date less than a minute ago', () {
      final now = DateTime.now();
      final result = DateHelper.getRelativeTime(now);

      expect(result, 'Just now');
    });

    test('returns "Xm ago" for date minutes ago', () {
      final minutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final result = DateHelper.getRelativeTime(minutesAgo);

      expect(result, matches(RegExp(r'^\d+m ago$')));
    });

    test('returns "Xh ago" for date hours ago', () {
      // Use a time that's guaranteed to be today (not crossing midnight)
      final now = DateTime.now();
      // Only test if we're far enough into the day; otherwise "3h ago" is yesterday
      if (now.hour >= 4) {
        final hoursAgo = now.subtract(const Duration(hours: 3));
        final result = DateHelper.getRelativeTime(hoursAgo);
        expect(result, matches(RegExp(r'^\d+h ago$')));
      } else {
        // Early morning: 1 hour ago is still today
        final oneHourAgo = now.subtract(Duration(hours: now.hour));
        if (now.hour > 0) {
          final result = DateHelper.getRelativeTime(oneHourAgo);
          expect(result, matches(RegExp(r'^\d+(h|m) ago$')));
        }
      }
    });

    test('returns "Yesterday" for yesterday', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1, 12, 0);
      final result = DateHelper.getRelativeTime(yesterday);

      expect(result, 'Yesterday');
    });

    test('returns "X days ago" for 2-6 days ago', () {
      final now = DateTime.now();
      for (int i = 2; i <= 6; i++) {
        final daysAgo = DateTime(now.year, now.month, now.day - i, 12, 0);
        final result = DateHelper.getRelativeTime(daysAgo);

        expect(result, '$i days ago',
            reason: '$i days ago should show "$i days ago"');
      }
    });

    test('returns "Mon DD" for dates 7+ days ago in current year', () {
      final now = DateTime.now();
      // Pick a date at least 7 days ago but in the current year
      final oldDate = DateTime(now.year, 1, 1);
      // Only test this if Jan 1 is at least 7 days ago
      final daysSinceJan1 = DateHelper.daysBetween(
        DateHelper.normalize(oldDate),
        DateHelper.today(),
      );

      if (daysSinceJan1 >= 7) {
        final result = DateHelper.getRelativeTime(oldDate);
        expect(result, 'Jan 1');
      }
    });

    test('returns "Mon DD, YYYY" for dates in a different year', () {
      final oldDate = DateTime(2020, 6, 15);
      final result = DateHelper.getRelativeTime(oldDate);

      expect(result, 'Jun 15, 2020');
    });

    test('formats all months correctly for other-year dates', () {
      final expectedMonths = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      for (int i = 0; i < 12; i++) {
        final date = DateTime(2020, i + 1, 10);
        final result = DateHelper.getRelativeTime(date);
        expect(result, '${expectedMonths[i]} 10, 2020');
      }
    });

    test('handles future dates with formatted date', () {
      final futureDate = DateTime(2099, 7, 4);
      final result = DateHelper.getRelativeTime(futureDate);

      // Future dates should show formatted date since daysAgo will be negative
      expect(result, 'Jul 4, 2099');
    });

    test('handles future dates in current year', () {
      final now = DateTime.now();
      // Use December 31 of current year if we are not in December
      if (now.month < 12) {
        final futureThisYear = DateTime(now.year, 12, 31);
        final result = DateHelper.getRelativeTime(futureThisYear);
        expect(result, 'Dec 31');
      }
    });
  });
}
