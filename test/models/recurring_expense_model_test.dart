import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:budget_tracker/models/recurring_expense_model.dart';
import 'package:budget_tracker/utils/date_helper.dart';

void main() {
  group('RecurringExpense', () {
    // -----------------------------------------------------------------------
    // Helper: build a fully-populated RecurringExpense
    // -----------------------------------------------------------------------
    RecurringExpense _make({
      int? id = 1,
      String description = 'Netflix',
      double amount = 15.99,
      String category = 'Entertainment',
      int dayOfMonth = 15,
      bool isActive = true,
      DateTime? lastCreated,
      int accountId = 1,
      String paymentMethod = 'Credit Card',
      DateTime? endDate,
      int? maxOccurrences,
      int occurrenceCount = 0,
      RecurringExpenseFrequency frequency = RecurringExpenseFrequency.monthly,
      DateTime? startDate,
    }) {
      return RecurringExpense(
        id: id,
        description: description,
        amount: Decimal.parse(amount.toStringAsFixed(2)),
        category: category,
        dayOfMonth: dayOfMonth,
        isActive: isActive,
        lastCreated: lastCreated,
        accountId: accountId,
        paymentMethod: paymentMethod,
        endDate: endDate,
        maxOccurrences: maxOccurrences,
        occurrenceCount: occurrenceCount,
        frequency: frequency,
        startDate: startDate,
      );
    }

    // -----------------------------------------------------------------------
    // Constructor & getters
    // -----------------------------------------------------------------------
    group('constructor and getters', () {
      test('stores all required and optional fields', () {
        final startDate = DateTime.utc(2024, 1, 1);
        final endDate = DateTime.utc(2025, 12, 31);
        final lastCreated = DateTime.utc(2024, 6, 15);

        final e = _make(
          startDate: startDate,
          endDate: endDate,
          lastCreated: lastCreated,
          maxOccurrences: 24,
          occurrenceCount: 6,
        );

        expect(e.id, 1);
        expect(e.description, 'Netflix');
        expect(e.amount, closeTo(15.99, 0.001));
        expect(e.amountDecimal, Decimal.parse('15.99'));
        expect(e.category, 'Entertainment');
        expect(e.dayOfMonth, 15);
        expect(e.isActive, true);
        expect(e.lastCreated, lastCreated);
        expect(e.accountId, 1);
        expect(e.paymentMethod, 'Credit Card');
        expect(e.endDate, endDate);
        expect(e.maxOccurrences, 24);
        expect(e.occurrenceCount, 6);
        expect(e.frequency, RecurringExpenseFrequency.monthly);
        expect(e.startDate, startDate);
      });

      test('defaults isActive to true', () {
        final e = RecurringExpense(
          description: 'Test',
          amount: Decimal.parse('10.00'),
          category: 'Other',
          dayOfMonth: 1,
          accountId: 1,
        );
        expect(e.isActive, true);
      });

      test('defaults paymentMethod to Cash', () {
        final e = RecurringExpense(
          description: 'Test',
          amount: Decimal.parse('10.00'),
          category: 'Other',
          dayOfMonth: 1,
          accountId: 1,
        );
        expect(e.paymentMethod, 'Cash');
      });

      test('defaults occurrenceCount to 0', () {
        final e = RecurringExpense(
          description: 'Test',
          amount: Decimal.parse('10.00'),
          category: 'Other',
          dayOfMonth: 1,
          accountId: 1,
        );
        expect(e.occurrenceCount, 0);
      });

      test('defaults frequency to monthly', () {
        final e = RecurringExpense(
          description: 'Test',
          amount: Decimal.parse('10.00'),
          category: 'Other',
          dayOfMonth: 1,
          accountId: 1,
        );
        expect(e.frequency, RecurringExpenseFrequency.monthly);
      });
    });

    // -----------------------------------------------------------------------
    // dayName computed property
    // -----------------------------------------------------------------------
    group('dayName', () {
      test('returns "Day N" for monthly frequency', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.monthly,
          dayOfMonth: 15,
        );
        expect(e.dayName, 'Day 15');
      });

      test('returns weekday name for weekly frequency (index 0 = Monday)', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.weekly,
          dayOfMonth: 0,
        );
        expect(e.dayName, 'Monday');
      });

      test('returns weekday name for weekly frequency (index 4 = Friday)', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.weekly,
          dayOfMonth: 4,
        );
        expect(e.dayName, 'Friday');
      });

      test('returns weekday name for weekly frequency (index 6 = Sunday)', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.weekly,
          dayOfMonth: 6,
        );
        expect(e.dayName, 'Sunday');
      });

      test('returns weekday name for biweekly frequency', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.biweekly,
          dayOfMonth: 2,
        );
        expect(e.dayName, 'Wednesday');
      });

      test('clamps negative dayOfMonth to Monday for weekly', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.weekly,
          dayOfMonth: -5,
        );
        expect(e.dayName, 'Monday');
      });

      test('clamps dayOfMonth > 6 to Sunday for weekly', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.weekly,
          dayOfMonth: 99,
        );
        expect(e.dayName, 'Sunday');
      });
    });

    // -----------------------------------------------------------------------
    // frequencyDescription
    // -----------------------------------------------------------------------
    group('frequencyDescription', () {
      test('monthly description', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.monthly,
          dayOfMonth: 15,
        );
        expect(e.frequencyDescription, 'Monthly on day 15');
      });

      test('weekly description', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.weekly,
          dayOfMonth: 0,
        );
        expect(e.frequencyDescription, 'Weekly on Monday');
      });

      test('biweekly description', () {
        final e = _make(
          frequency: RecurringExpenseFrequency.biweekly,
          dayOfMonth: 4,
        );
        expect(e.frequencyDescription, 'Every 2 weeks on Friday');
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------
    group('toMap()', () {
      test('serializes all fields correctly', () {
        final startDate = DateTime.utc(2024, 1, 1);
        final endDate = DateTime.utc(2025, 12, 31);
        final lastCreated = DateTime.utc(2024, 6, 15);

        final e = _make(
          startDate: startDate,
          endDate: endDate,
          lastCreated: lastCreated,
          maxOccurrences: 12,
          occurrenceCount: 3,
          frequency: RecurringExpenseFrequency.biweekly,
        );

        final map = e.toMap();

        expect(map['id'], 1);
        expect(map['description'], 'Netflix');
        expect(map['amount'], closeTo(15.99, 0.001));
        expect(map['category'], 'Entertainment');
        expect(map['dayOfMonth'], 15);
        expect(map['isActive'], 1);
        expect(map['lastCreated'], '2024-06-15');
        expect(map['account_id'], 1);
        expect(map['paymentMethod'], 'Credit Card');
        expect(map['endDate'], '2025-12-31');
        expect(map['maxOccurrences'], 12);
        expect(map['occurrenceCount'], 3);
        expect(map['frequency'], 1); // biweekly index
        expect(map['startDate'], '2024-01-01');
      });

      test('serializes isActive=false as 0', () {
        final e = _make(isActive: false);
        expect(e.toMap()['isActive'], 0);
      });

      test('serializes null optional dates as null', () {
        final e = _make(
          lastCreated: null,
          endDate: null,
          startDate: null,
        );
        final map = e.toMap();
        expect(map['lastCreated'], isNull);
        expect(map['endDate'], isNull);
        expect(map['startDate'], isNull);
      });

      test('serializes null maxOccurrences', () {
        final e = _make(maxOccurrences: null);
        expect(e.toMap()['maxOccurrences'], isNull);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() - happy path
    // -----------------------------------------------------------------------
    group('fromMap() deserialization', () {
      test('deserializes all fields from a complete map', () {
        final map = {
          'id': 5,
          'description': 'Spotify',
          'amount': 9.99,
          'category': 'Music',
          'dayOfMonth': 1,
          'isActive': 1,
          'lastCreated': '2024-06-01',
          'account_id': 2,
          'paymentMethod': 'Debit Card',
          'endDate': '2025-06-01',
          'maxOccurrences': 24,
          'occurrenceCount': 12,
          'frequency': 0, // monthly
          'startDate': '2024-01-01',
        };

        final e = RecurringExpense.fromMap(map);

        expect(e.id, 5);
        expect(e.description, 'Spotify');
        expect(e.amount, closeTo(9.99, 0.001));
        expect(e.category, 'Music');
        expect(e.dayOfMonth, 1);
        expect(e.isActive, true);
        expect(e.lastCreated, DateTime.utc(2024, 6, 1));
        expect(e.accountId, 2);
        expect(e.paymentMethod, 'Debit Card');
        expect(e.endDate, DateTime.utc(2025, 6, 1));
        expect(e.maxOccurrences, 24);
        expect(e.occurrenceCount, 12);
        expect(e.frequency, RecurringExpenseFrequency.monthly);
        expect(e.startDate, DateTime.utc(2024, 1, 1));
      });

      test('isActive false when value is 0', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 0,
          'account_id': 1,
        };
        final e = RecurringExpense.fromMap(map);
        expect(e.isActive, false);
      });

      test('defaults paymentMethod to Cash when missing', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
        };
        final e = RecurringExpense.fromMap(map);
        expect(e.paymentMethod, 'Cash');
      });

      test('defaults occurrenceCount to 0 when missing', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
        };
        final e = RecurringExpense.fromMap(map);
        expect(e.occurrenceCount, 0);
      });

      test('handles null date strings', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'lastCreated': null,
          'endDate': null,
          'startDate': null,
        };
        final e = RecurringExpense.fromMap(map);
        expect(e.lastCreated, isNull);
        expect(e.endDate, isNull);
        expect(e.startDate, isNull);
      });

      test('handles invalid date strings gracefully', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'lastCreated': 'not-a-date',
          'endDate': 'garbage',
          'startDate': '???',
        };
        final e = RecurringExpense.fromMap(map);
        expect(e.lastCreated, isNull);
        expect(e.endDate, isNull);
        expect(e.startDate, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() frequency clamping
    // -----------------------------------------------------------------------
    group('fromMap() frequency enum clamping', () {
      test('valid frequency index 0 maps to monthly', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': 0,
        };
        expect(
          RecurringExpense.fromMap(map).frequency,
          RecurringExpenseFrequency.monthly,
        );
      });

      test('valid frequency index 1 maps to biweekly', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': 1,
        };
        expect(
          RecurringExpense.fromMap(map).frequency,
          RecurringExpenseFrequency.biweekly,
        );
      });

      test('valid frequency index 2 maps to weekly', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': 2,
        };
        expect(
          RecurringExpense.fromMap(map).frequency,
          RecurringExpenseFrequency.weekly,
        );
      });

      test('negative frequency index clamped to 0 (monthly)', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': -1,
        };
        expect(
          RecurringExpense.fromMap(map).frequency,
          RecurringExpenseFrequency.monthly,
        );
      });

      test('out-of-range frequency index clamped to max (weekly)', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': 99,
        };
        expect(
          RecurringExpense.fromMap(map).frequency,
          RecurringExpenseFrequency.weekly,
        );
      });

      test('null frequency defaults to 0 (monthly)', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': null,
        };
        expect(
          RecurringExpense.fromMap(map).frequency,
          RecurringExpenseFrequency.monthly,
        );
      });

      test('missing frequency key defaults to monthly', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
        };
        expect(
          RecurringExpense.fromMap(map).frequency,
          RecurringExpenseFrequency.monthly,
        );
      });
    });

    // -----------------------------------------------------------------------
    // shouldBeActive
    // -----------------------------------------------------------------------
    group('shouldBeActive', () {
      test('returns true when active with no constraints', () {
        final e = _make(isActive: true);
        expect(e.shouldBeActive, true);
      });

      test('returns false when isActive is false', () {
        final e = _make(isActive: false);
        expect(e.shouldBeActive, false);
      });

      test('returns false when endDate is in the past', () {
        final pastDate = DateHelper.today().subtract(const Duration(days: 1));
        final e = _make(isActive: true, endDate: pastDate);
        expect(e.shouldBeActive, false);
      });

      test('returns true when endDate is in the future', () {
        final futureDate = DateHelper.today().add(const Duration(days: 30));
        final e = _make(isActive: true, endDate: futureDate);
        expect(e.shouldBeActive, true);
      });

      test('returns true when endDate is today', () {
        // endDate == today => isPast(today) is false, so it should still be active
        final today = DateHelper.today();
        final e = _make(isActive: true, endDate: today);
        expect(e.shouldBeActive, true);
      });

      test('returns false when maxOccurrences reached', () {
        final e = _make(
          isActive: true,
          maxOccurrences: 5,
          occurrenceCount: 5,
        );
        expect(e.shouldBeActive, false);
      });

      test('returns false when occurrenceCount exceeds maxOccurrences', () {
        final e = _make(
          isActive: true,
          maxOccurrences: 3,
          occurrenceCount: 10,
        );
        expect(e.shouldBeActive, false);
      });

      test('returns true when occurrenceCount < maxOccurrences', () {
        final e = _make(
          isActive: true,
          maxOccurrences: 10,
          occurrenceCount: 5,
        );
        expect(e.shouldBeActive, true);
      });

      test('returns true when maxOccurrences is null (unlimited)', () {
        final e = _make(isActive: true, maxOccurrences: null);
        expect(e.shouldBeActive, true);
      });

      test('returns false when inactive even with future endDate', () {
        final futureDate = DateHelper.today().add(const Duration(days: 30));
        final e = _make(isActive: false, endDate: futureDate);
        expect(e.shouldBeActive, false);
      });
    });

    // -----------------------------------------------------------------------
    // copyWith()
    // -----------------------------------------------------------------------
    group('copyWith()', () {
      test('overrides description', () {
        final original = _make();
        final copy = original.copyWith(description: 'Hulu');
        expect(copy.description, 'Hulu');
        expect(copy.id, original.id);
      });

      test('overrides amount', () {
        final original = _make();
        final copy = original.copyWith(amount: 29.99);
        expect(copy.amount, closeTo(29.99, 0.001));
      });

      test('overrides isActive', () {
        final original = _make(isActive: true);
        final copy = original.copyWith(isActive: false);
        expect(copy.isActive, false);
      });

      test('overrides frequency', () {
        final original = _make();
        final copy = original.copyWith(
          frequency: RecurringExpenseFrequency.weekly,
        );
        expect(copy.frequency, RecurringExpenseFrequency.weekly);
      });

      test('overrides endDate', () {
        final newEnd = DateTime.utc(2030, 1, 1);
        final original = _make();
        final copy = original.copyWith(endDate: newEnd);
        expect(copy.endDate, newEnd);
      });

      test('clears endDate with clearEndDate flag', () {
        final original = _make(endDate: DateTime.utc(2025, 12, 31));
        final copy = original.copyWith(clearEndDate: true);
        expect(copy.endDate, isNull);
      });

      test('clears lastCreated with clearLastCreated flag', () {
        final original = _make(lastCreated: DateTime.utc(2024, 1, 1));
        final copy = original.copyWith(clearLastCreated: true);
        expect(copy.lastCreated, isNull);
      });

      test('clears maxOccurrences with clearMaxOccurrences flag', () {
        final original = _make(maxOccurrences: 12);
        final copy = original.copyWith(clearMaxOccurrences: true);
        expect(copy.maxOccurrences, isNull);
      });

      test('clears startDate with clearStartDate flag', () {
        final original = _make(startDate: DateTime.utc(2024, 1, 1));
        final copy = original.copyWith(clearStartDate: true);
        expect(copy.startDate, isNull);
      });

      test('preserves all fields when nothing overridden', () {
        final startDate = DateTime.utc(2024, 1, 1);
        final endDate = DateTime.utc(2025, 12, 31);
        final lastCreated = DateTime.utc(2024, 6, 15);

        final original = _make(
          startDate: startDate,
          endDate: endDate,
          lastCreated: lastCreated,
          maxOccurrences: 12,
          occurrenceCount: 3,
        );
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.description, original.description);
        expect(copy.amount, original.amount);
        expect(copy.category, original.category);
        expect(copy.dayOfMonth, original.dayOfMonth);
        expect(copy.isActive, original.isActive);
        expect(copy.lastCreated, original.lastCreated);
        expect(copy.accountId, original.accountId);
        expect(copy.paymentMethod, original.paymentMethod);
        expect(copy.endDate, original.endDate);
        expect(copy.maxOccurrences, original.maxOccurrences);
        expect(copy.occurrenceCount, original.occurrenceCount);
        expect(copy.frequency, original.frequency);
        expect(copy.startDate, original.startDate);
      });
    });

    // -----------------------------------------------------------------------
    // copyWithDecimal()
    // -----------------------------------------------------------------------
    group('copyWithDecimal()', () {
      test('overrides amount with Decimal value', () {
        final original = _make();
        final copy = original.copyWithDecimal(
          amount: Decimal.parse('29.99'),
        );
        expect(copy.amountDecimal, Decimal.parse('29.99'));
      });

      test('clear flags work with Decimal variant', () {
        final original = _make(
          endDate: DateTime.utc(2025, 12, 31),
          maxOccurrences: 5,
          startDate: DateTime.utc(2024, 1, 1),
          lastCreated: DateTime.utc(2024, 6, 1),
        );
        final copy = original.copyWithDecimal(
          clearEndDate: true,
          clearMaxOccurrences: true,
          clearStartDate: true,
          clearLastCreated: true,
        );
        expect(copy.endDate, isNull);
        expect(copy.maxOccurrences, isNull);
        expect(copy.startDate, isNull);
        expect(copy.lastCreated, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // Round-trip: toMap -> fromMap
    // -----------------------------------------------------------------------
    group('round-trip serialization', () {
      test('toMap then fromMap preserves all values', () {
        final original = _make(
          startDate: DateTime.utc(2024, 1, 1),
          endDate: DateTime.utc(2025, 12, 31),
          lastCreated: DateTime.utc(2024, 6, 15),
          maxOccurrences: 24,
          occurrenceCount: 6,
          frequency: RecurringExpenseFrequency.biweekly,
        );
        final map = original.toMap();
        final restored = RecurringExpense.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.description, original.description);
        expect(restored.amount, closeTo(original.amount, 0.001));
        expect(restored.category, original.category);
        expect(restored.dayOfMonth, original.dayOfMonth);
        expect(restored.isActive, original.isActive);
        expect(restored.lastCreated, original.lastCreated);
        expect(restored.accountId, original.accountId);
        expect(restored.paymentMethod, original.paymentMethod);
        expect(restored.endDate, original.endDate);
        expect(restored.maxOccurrences, original.maxOccurrences);
        expect(restored.occurrenceCount, original.occurrenceCount);
        expect(restored.frequency, original.frequency);
        expect(restored.startDate, original.startDate);
      });

      test('round-trip with nulls preserved', () {
        final original = _make(
          id: null,
          lastCreated: null,
          endDate: null,
          startDate: null,
          maxOccurrences: null,
        );
        final map = original.toMap();
        final restored = RecurringExpense.fromMap(map);

        expect(restored.id, isNull);
        expect(restored.lastCreated, isNull);
        expect(restored.endDate, isNull);
        expect(restored.startDate, isNull);
        expect(restored.maxOccurrences, isNull);
      });
    });
  });
}
