import 'package:budget_tracker/models/recurring_expense_model.dart';
import 'package:budget_tracker/utils/notification_helper.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-10 review — bill reminders and Home's "Upcoming bills" read a weekly
/// or biweekly bill's weekday (0-6) as a day of the month, so a Monday bill
/// landed on "day 0" (the previous month's last day). They also ignored the
/// end date. Both now go through [RecurringExpense.nextDueDate].
void main() {
  DateTime ymd(int y, int m, int d) => DateTime.utc(y, m, d);

  RecurringExpense bill({
    int day = 1,
    RecurringExpenseFrequency frequency = RecurringExpenseFrequency.monthly,
    DateTime? lastCreated,
    DateTime? startDate,
    DateTime? endDate,
    int? maxOccurrences,
    int occurrenceCount = 0,
    bool isActive = true,
  }) {
    return RecurringExpense(
      id: 1,
      description: 'rent',
      amount: Decimal.parse('100'),
      category: 'Bills',
      dayOfMonth: day,
      accountId: 1,
      frequency: frequency,
      lastCreated: lastCreated,
      startDate: startDate,
      endDate: endDate,
      maxOccurrences: maxOccurrences,
      occurrenceCount: occurrenceCount,
      isActive: isActive,
    );
  }

  group('nextDueDate', () {
    test('monthly: this month when the day is still ahead, else next', () {
      expect(bill(day: 20).nextDueDate(ymd(2026, 10, 12)), ymd(2026, 10, 20));
      expect(bill(day: 5).nextDueDate(ymd(2026, 10, 12)), ymd(2026, 11, 5));
      expect(bill(day: 12).nextDueDate(ymd(2026, 10, 12)), ymd(2026, 10, 12));
    });

    test('monthly: day 31 clamps to the end of a short month', () {
      expect(bill(day: 31).nextDueDate(ymd(2026, 9, 2)), ymd(2026, 9, 30));
      expect(bill(day: 31).nextDueDate(ymd(2027, 2, 1)), ymd(2027, 2, 28));
    });

    test('weekly: the weekday, never "day 0" of the month', () {
      // 2026-10-12 is a Monday (weekday 0).
      final monday = bill(day: 0, frequency: RecurringExpenseFrequency.weekly);
      expect(monday.nextDueDate(ymd(2026, 10, 12)), ymd(2026, 10, 12));
      expect(monday.nextDueDate(ymd(2026, 10, 13)), ymd(2026, 10, 19));
    });

    test('biweekly: every other week from the last instance', () {
      final friday = bill(
        day: 4,
        frequency: RecurringExpenseFrequency.biweekly,
        lastCreated: ymd(2026, 10, 2), // a Friday
      );
      expect(friday.nextDueDate(ymd(2026, 10, 5)), ymd(2026, 10, 16));
      expect(friday.nextDueDate(ymd(2026, 10, 17)), ymd(2026, 10, 30));
    });

    test('null past the end date, out of occurrences, or inactive', () {
      expect(
        bill(day: 20, endDate: ymd(2026, 10, 15)).nextDueDate(ymd(2026, 10, 12)),
        isNull,
      );
      expect(
        bill(day: 20, maxOccurrences: 3, occurrenceCount: 3)
            .nextDueDate(ymd(2026, 10, 12)),
        isNull,
      );
      expect(bill(day: 20, isActive: false).nextDueDate(ymd(2026, 10, 12)),
          isNull);
    });
  });

  group('NotificationHelper.isOneShotReminder', () {
    test('one-shot where no native repeat lands on the right day', () {
      expect(NotificationHelper.isOneShotReminder(bill(day: 1)), isTrue);
      expect(NotificationHelper.isOneShotReminder(bill(day: 29)), isTrue);
      expect(
        NotificationHelper.isOneShotReminder(
          bill(day: 3, frequency: RecurringExpenseFrequency.biweekly),
        ),
        isTrue,
      );
    });

    test('repeating for monthly 2nd-28th and every weekly bill', () {
      expect(NotificationHelper.isOneShotReminder(bill(day: 2)), isFalse);
      expect(NotificationHelper.isOneShotReminder(bill(day: 28)), isFalse);
      expect(
        NotificationHelper.isOneShotReminder(
          bill(day: 0, frequency: RecurringExpenseFrequency.weekly),
        ),
        isFalse,
      );
    });
  });
}
