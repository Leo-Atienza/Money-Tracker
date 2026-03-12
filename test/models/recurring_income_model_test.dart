import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:budget_tracker/models/recurring_income_model.dart';
import 'package:budget_tracker/utils/date_helper.dart';

void main() {
  group('RecurringIncome', () {
    // -----------------------------------------------------------------------
    // Helper: build a fully-populated RecurringIncome
    // -----------------------------------------------------------------------
    RecurringIncome make({
      int? id = 1,
      String description = 'Salary',
      double amount = 3000.00,
      String category = 'Employment',
      int dayOfMonth = 1,
      bool isActive = true,
      DateTime? lastCreated,
      int accountId = 1,
      RecurringFrequency frequency = RecurringFrequency.monthly,
      DateTime? startDate,
      DateTime? endDate,
      int? maxOccurrences,
      int occurrenceCount = 0,
    }) {
      return RecurringIncome(
        id: id,
        description: description,
        amount: Decimal.parse(amount.toStringAsFixed(2)),
        category: category,
        dayOfMonth: dayOfMonth,
        isActive: isActive,
        lastCreated: lastCreated,
        accountId: accountId,
        frequency: frequency,
        startDate: startDate,
        endDate: endDate,
        maxOccurrences: maxOccurrences,
        occurrenceCount: occurrenceCount,
      );
    }

    // -----------------------------------------------------------------------
    // Constructor & getters
    // -----------------------------------------------------------------------
    group('constructor and getters', () {
      test('stores all required and optional fields', () {
        final startDate = DateTime.utc(2024, 1, 1);
        final endDate = DateTime.utc(2025, 12, 31);
        final lastCreated = DateTime.utc(2024, 6, 1);

        final income = make(
          startDate: startDate,
          endDate: endDate,
          lastCreated: lastCreated,
          maxOccurrences: 24,
          occurrenceCount: 6,
        );

        expect(income.id, 1);
        expect(income.description, 'Salary');
        expect(income.amount, closeTo(3000.00, 0.001));
        expect(income.amountDecimal, Decimal.parse('3000.00'));
        expect(income.category, 'Employment');
        expect(income.dayOfMonth, 1);
        expect(income.isActive, true);
        expect(income.lastCreated, lastCreated);
        expect(income.accountId, 1);
        expect(income.frequency, RecurringFrequency.monthly);
        expect(income.startDate, startDate);
        expect(income.endDate, endDate);
        expect(income.maxOccurrences, 24);
        expect(income.occurrenceCount, 6);
      });

      test('defaults isActive to true', () {
        final income = RecurringIncome(
          description: 'Test',
          amount: Decimal.parse('100.00'),
          category: 'Other',
          dayOfMonth: 1,
          accountId: 1,
        );
        expect(income.isActive, true);
      });

      test('defaults frequency to monthly', () {
        final income = RecurringIncome(
          description: 'Test',
          amount: Decimal.parse('100.00'),
          category: 'Other',
          dayOfMonth: 1,
          accountId: 1,
        );
        expect(income.frequency, RecurringFrequency.monthly);
      });

      test('defaults occurrenceCount to 0', () {
        final income = RecurringIncome(
          description: 'Test',
          amount: Decimal.parse('100.00'),
          category: 'Other',
          dayOfMonth: 1,
          accountId: 1,
        );
        expect(income.occurrenceCount, 0);
      });
    });

    // -----------------------------------------------------------------------
    // dayName computed property
    // -----------------------------------------------------------------------
    group('dayName', () {
      test('returns "Day N" for monthly frequency', () {
        final income = make(
          frequency: RecurringFrequency.monthly,
          dayOfMonth: 25,
        );
        expect(income.dayName, 'Day 25');
      });

      test('returns weekday name for weekly frequency (0 = Monday)', () {
        final income = make(
          frequency: RecurringFrequency.weekly,
          dayOfMonth: 0,
        );
        expect(income.dayName, 'Monday');
      });

      test('returns weekday name for weekly frequency (4 = Friday)', () {
        final income = make(
          frequency: RecurringFrequency.weekly,
          dayOfMonth: 4,
        );
        expect(income.dayName, 'Friday');
      });

      test('returns weekday name for weekly frequency (6 = Sunday)', () {
        final income = make(
          frequency: RecurringFrequency.weekly,
          dayOfMonth: 6,
        );
        expect(income.dayName, 'Sunday');
      });

      test('returns weekday name for biweekly frequency', () {
        final income = make(
          frequency: RecurringFrequency.biweekly,
          dayOfMonth: 3,
        );
        expect(income.dayName, 'Thursday');
      });

      test('clamps negative dayOfMonth to Monday for weekly', () {
        final income = make(
          frequency: RecurringFrequency.weekly,
          dayOfMonth: -3,
        );
        expect(income.dayName, 'Monday');
      });

      test('clamps dayOfMonth > 6 to Sunday for weekly', () {
        final income = make(
          frequency: RecurringFrequency.weekly,
          dayOfMonth: 100,
        );
        expect(income.dayName, 'Sunday');
      });
    });

    // -----------------------------------------------------------------------
    // frequencyDescription
    // -----------------------------------------------------------------------
    group('frequencyDescription', () {
      test('monthly description', () {
        final income = make(
          frequency: RecurringFrequency.monthly,
          dayOfMonth: 1,
        );
        expect(income.frequencyDescription, 'Monthly on day 1');
      });

      test('weekly description', () {
        final income = make(
          frequency: RecurringFrequency.weekly,
          dayOfMonth: 2,
        );
        expect(income.frequencyDescription, 'Weekly on Wednesday');
      });

      test('biweekly description', () {
        final income = make(
          frequency: RecurringFrequency.biweekly,
          dayOfMonth: 4,
        );
        expect(income.frequencyDescription, 'Every 2 weeks on Friday');
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------
    group('toMap()', () {
      test('serializes all fields correctly', () {
        final startDate = DateTime.utc(2024, 1, 1);
        final endDate = DateTime.utc(2025, 12, 31);
        final lastCreated = DateTime.utc(2024, 6, 1);

        final income = make(
          startDate: startDate,
          endDate: endDate,
          lastCreated: lastCreated,
          maxOccurrences: 24,
          occurrenceCount: 12,
          frequency: RecurringFrequency.biweekly,
        );

        final map = income.toMap();

        expect(map['id'], 1);
        expect(map['description'], 'Salary');
        expect(map['amount'], closeTo(3000.00, 0.001));
        expect(map['category'], 'Employment');
        expect(map['dayOfMonth'], 1);
        expect(map['isActive'], 1);
        expect(map['lastCreated'], '2024-06-01');
        expect(map['account_id'], 1);
        expect(map['frequency'], 1); // biweekly index
        expect(map['startDate'], '2024-01-01');
        expect(map['endDate'], '2025-12-31');
        expect(map['maxOccurrences'], 24);
        expect(map['occurrenceCount'], 12);
      });

      test('serializes isActive=false as 0', () {
        final income = make(isActive: false);
        expect(income.toMap()['isActive'], 0);
      });

      test('serializes null optional dates as null', () {
        final income = make(
          lastCreated: null,
          endDate: null,
          startDate: null,
        );
        final map = income.toMap();
        expect(map['lastCreated'], isNull);
        expect(map['endDate'], isNull);
        expect(map['startDate'], isNull);
      });

      test('serializes null maxOccurrences', () {
        final income = make(maxOccurrences: null);
        expect(income.toMap()['maxOccurrences'], isNull);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() - happy path
    // -----------------------------------------------------------------------
    group('fromMap() deserialization', () {
      test('deserializes all fields from a complete map', () {
        final map = {
          'id': 10,
          'description': 'Freelance',
          'amount': 1500.00,
          'category': 'Side Income',
          'dayOfMonth': 15,
          'isActive': 1,
          'lastCreated': '2024-05-15',
          'account_id': 3,
          'frequency': 2, // weekly
          'startDate': '2024-01-01',
          'endDate': '2025-12-31',
          'maxOccurrences': 52,
          'occurrenceCount': 20,
        };

        final income = RecurringIncome.fromMap(map);

        expect(income.id, 10);
        expect(income.description, 'Freelance');
        expect(income.amount, closeTo(1500.00, 0.001));
        expect(income.category, 'Side Income');
        expect(income.dayOfMonth, 15);
        expect(income.isActive, true);
        expect(income.lastCreated, DateTime.utc(2024, 5, 15));
        expect(income.accountId, 3);
        expect(income.frequency, RecurringFrequency.weekly);
        expect(income.startDate, DateTime.utc(2024, 1, 1));
        expect(income.endDate, DateTime.utc(2025, 12, 31));
        expect(income.maxOccurrences, 52);
        expect(income.occurrenceCount, 20);
      });

      test('isActive false when value is 0', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 0,
          'account_id': 1,
        };
        final income = RecurringIncome.fromMap(map);
        expect(income.isActive, false);
      });

      test('defaults occurrenceCount to 0 when missing', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
        };
        final income = RecurringIncome.fromMap(map);
        expect(income.occurrenceCount, 0);
      });

      test('handles null date strings', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'lastCreated': null,
          'startDate': null,
          'endDate': null,
        };
        final income = RecurringIncome.fromMap(map);
        expect(income.lastCreated, isNull);
        expect(income.startDate, isNull);
        expect(income.endDate, isNull);
      });

      test('handles invalid date strings gracefully', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'lastCreated': 'invalid',
          'startDate': 'garbage',
          'endDate': 'nope',
        };
        final income = RecurringIncome.fromMap(map);
        expect(income.lastCreated, isNull);
        expect(income.startDate, isNull);
        expect(income.endDate, isNull);
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
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': 0,
        };
        expect(
          RecurringIncome.fromMap(map).frequency,
          RecurringFrequency.monthly,
        );
      });

      test('valid frequency index 1 maps to biweekly', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': 1,
        };
        expect(
          RecurringIncome.fromMap(map).frequency,
          RecurringFrequency.biweekly,
        );
      });

      test('valid frequency index 2 maps to weekly', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': 2,
        };
        expect(
          RecurringIncome.fromMap(map).frequency,
          RecurringFrequency.weekly,
        );
      });

      test('negative frequency index clamped to 0 (monthly)', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': -5,
        };
        expect(
          RecurringIncome.fromMap(map).frequency,
          RecurringFrequency.monthly,
        );
      });

      test('out-of-range frequency index clamped to max (weekly)', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': 50,
        };
        expect(
          RecurringIncome.fromMap(map).frequency,
          RecurringFrequency.weekly,
        );
      });

      test('null frequency defaults to monthly', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
          'frequency': null,
        };
        expect(
          RecurringIncome.fromMap(map).frequency,
          RecurringFrequency.monthly,
        );
      });

      test('missing frequency key defaults to monthly', () {
        final map = {
          'id': 1,
          'description': 'Test',
          'amount': 100.0,
          'category': 'Other',
          'dayOfMonth': 1,
          'isActive': 1,
          'account_id': 1,
        };
        expect(
          RecurringIncome.fromMap(map).frequency,
          RecurringFrequency.monthly,
        );
      });
    });

    // -----------------------------------------------------------------------
    // shouldBeActive
    // -----------------------------------------------------------------------
    group('shouldBeActive', () {
      test('returns true when active with no constraints', () {
        final income = make(isActive: true);
        expect(income.shouldBeActive, true);
      });

      test('returns false when isActive is false', () {
        final income = make(isActive: false);
        expect(income.shouldBeActive, false);
      });

      test('returns false when endDate is in the past', () {
        final pastDate = DateHelper.today().subtract(const Duration(days: 1));
        final income = make(isActive: true, endDate: pastDate);
        expect(income.shouldBeActive, false);
      });

      test('returns true when endDate is in the future', () {
        final futureDate = DateHelper.today().add(const Duration(days: 30));
        final income = make(isActive: true, endDate: futureDate);
        expect(income.shouldBeActive, true);
      });

      test('returns true when endDate is today', () {
        final today = DateHelper.today();
        final income = make(isActive: true, endDate: today);
        expect(income.shouldBeActive, true);
      });

      test('returns false when maxOccurrences reached', () {
        final income = make(
          isActive: true,
          maxOccurrences: 10,
          occurrenceCount: 10,
        );
        expect(income.shouldBeActive, false);
      });

      test('returns false when occurrenceCount exceeds maxOccurrences', () {
        final income = make(
          isActive: true,
          maxOccurrences: 5,
          occurrenceCount: 8,
        );
        expect(income.shouldBeActive, false);
      });

      test('returns true when occurrenceCount < maxOccurrences', () {
        final income = make(
          isActive: true,
          maxOccurrences: 12,
          occurrenceCount: 7,
        );
        expect(income.shouldBeActive, true);
      });

      test('returns true when maxOccurrences is null (unlimited)', () {
        final income = make(
          isActive: true,
          maxOccurrences: null,
          occurrenceCount: 1000,
        );
        expect(income.shouldBeActive, true);
      });

      test('returns false when inactive even with future endDate', () {
        final futureDate = DateHelper.today().add(const Duration(days: 365));
        final income = make(isActive: false, endDate: futureDate);
        expect(income.shouldBeActive, false);
      });
    });

    // -----------------------------------------------------------------------
    // copyWith()
    // -----------------------------------------------------------------------
    group('copyWith()', () {
      test('overrides description', () {
        final original = make();
        final copy = original.copyWith(description: 'Bonus');
        expect(copy.description, 'Bonus');
        expect(copy.id, original.id);
      });

      test('overrides amount', () {
        final original = make();
        final copy = original.copyWith(amount: 5000.00);
        expect(copy.amount, closeTo(5000.00, 0.001));
      });

      test('overrides isActive', () {
        final original = make(isActive: true);
        final copy = original.copyWith(isActive: false);
        expect(copy.isActive, false);
      });

      test('overrides frequency', () {
        final original = make();
        final copy = original.copyWith(frequency: RecurringFrequency.weekly);
        expect(copy.frequency, RecurringFrequency.weekly);
      });

      test('overrides endDate', () {
        final newEnd = DateTime.utc(2030, 6, 15);
        final original = make();
        final copy = original.copyWith(endDate: newEnd);
        expect(copy.endDate, newEnd);
      });

      test('clears endDate with clearEndDate flag', () {
        final original = make(endDate: DateTime.utc(2025, 12, 31));
        final copy = original.copyWith(clearEndDate: true);
        expect(copy.endDate, isNull);
      });

      test('clears lastCreated with clearLastCreated flag', () {
        final original = make(lastCreated: DateTime.utc(2024, 1, 1));
        final copy = original.copyWith(clearLastCreated: true);
        expect(copy.lastCreated, isNull);
      });

      test('clears maxOccurrences with clearMaxOccurrences flag', () {
        final original = make(maxOccurrences: 12);
        final copy = original.copyWith(clearMaxOccurrences: true);
        expect(copy.maxOccurrences, isNull);
      });

      test('clears startDate with clearStartDate flag', () {
        final original = make(startDate: DateTime.utc(2024, 1, 1));
        final copy = original.copyWith(clearStartDate: true);
        expect(copy.startDate, isNull);
      });

      test('preserves all fields when nothing overridden', () {
        final startDate = DateTime.utc(2024, 1, 1);
        final endDate = DateTime.utc(2025, 12, 31);
        final lastCreated = DateTime.utc(2024, 6, 1);

        final original = make(
          startDate: startDate,
          endDate: endDate,
          lastCreated: lastCreated,
          maxOccurrences: 24,
          occurrenceCount: 6,
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
        expect(copy.frequency, original.frequency);
        expect(copy.startDate, original.startDate);
        expect(copy.endDate, original.endDate);
        expect(copy.maxOccurrences, original.maxOccurrences);
        expect(copy.occurrenceCount, original.occurrenceCount);
      });
    });

    // -----------------------------------------------------------------------
    // copyWithDecimal()
    // -----------------------------------------------------------------------
    group('copyWithDecimal()', () {
      test('overrides amount with Decimal value', () {
        final original = make();
        final copy = original.copyWithDecimal(
          amount: Decimal.parse('7500.00'),
        );
        expect(copy.amountDecimal, Decimal.parse('7500.00'));
      });

      test('clear flags work with Decimal variant', () {
        final original = make(
          endDate: DateTime.utc(2025, 12, 31),
          maxOccurrences: 10,
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
        final original = make(
          startDate: DateTime.utc(2024, 1, 1),
          endDate: DateTime.utc(2025, 12, 31),
          lastCreated: DateTime.utc(2024, 6, 1),
          maxOccurrences: 24,
          occurrenceCount: 12,
          frequency: RecurringFrequency.weekly,
        );
        final map = original.toMap();
        final restored = RecurringIncome.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.description, original.description);
        expect(restored.amount, closeTo(original.amount, 0.001));
        expect(restored.category, original.category);
        expect(restored.dayOfMonth, original.dayOfMonth);
        expect(restored.isActive, original.isActive);
        expect(restored.lastCreated, original.lastCreated);
        expect(restored.accountId, original.accountId);
        expect(restored.frequency, original.frequency);
        expect(restored.startDate, original.startDate);
        expect(restored.endDate, original.endDate);
        expect(restored.maxOccurrences, original.maxOccurrences);
        expect(restored.occurrenceCount, original.occurrenceCount);
      });

      test('round-trip with nulls preserved', () {
        final original = make(
          id: null,
          lastCreated: null,
          startDate: null,
          endDate: null,
          maxOccurrences: null,
        );
        final map = original.toMap();
        final restored = RecurringIncome.fromMap(map);

        expect(restored.id, isNull);
        expect(restored.lastCreated, isNull);
        expect(restored.startDate, isNull);
        expect(restored.endDate, isNull);
        expect(restored.maxOccurrences, isNull);
      });
    });
  });
}
