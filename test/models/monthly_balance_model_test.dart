import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:budget_tracker/models/monthly_balance_model.dart';
import 'package:budget_tracker/utils/date_helper.dart';

void main() {
  group('MonthlyBalance', () {
    // -----------------------------------------------------------------------
    // Helper: build a fully-populated MonthlyBalance
    // -----------------------------------------------------------------------
    MonthlyBalance _make({
      int? id = 1,
      double carryoverFromPrevious = 500.00,
      double? overallBudget = 2000.00,
      int accountId = 1,
      DateTime? month,
    }) {
      return MonthlyBalance(
        id: id,
        carryoverFromPrevious:
            Decimal.parse(carryoverFromPrevious.toStringAsFixed(2)),
        overallBudget: overallBudget != null
            ? Decimal.parse(overallBudget.toStringAsFixed(2))
            : null,
        accountId: accountId,
        month: month ?? DateTime.utc(2024, 6, 1),
      );
    }

    // -----------------------------------------------------------------------
    // Constructor & getters
    // -----------------------------------------------------------------------
    group('constructor and getters', () {
      test('stores all fields', () {
        final month = DateTime.utc(2024, 6, 1);
        final balance = _make(month: month);

        expect(balance.id, 1);
        expect(balance.carryoverFromPrevious, closeTo(500.00, 0.001));
        expect(
          balance.carryoverFromPreviousDecimal,
          Decimal.parse('500.00'),
        );
        expect(balance.overallBudget, closeTo(2000.00, 0.001));
        expect(balance.overallBudgetDecimal, Decimal.parse('2000.00'));
        expect(balance.accountId, 1);
        expect(balance.month, month);
      });

      test('overallBudget returns null when not set', () {
        final balance = _make(overallBudget: null);
        expect(balance.overallBudget, isNull);
        expect(balance.overallBudgetDecimal, isNull);
      });

      test('handles negative carryover', () {
        final balance = _make(carryoverFromPrevious: -250.50);
        expect(balance.carryoverFromPrevious, closeTo(-250.50, 0.001));
      });

      test('id defaults to null', () {
        final balance = MonthlyBalance(
          carryoverFromPrevious: Decimal.zero,
          accountId: 1,
          month: DateTime.utc(2024, 1, 1),
        );
        expect(balance.id, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // hasOverallBudget computed property
    // -----------------------------------------------------------------------
    group('hasOverallBudget', () {
      test('returns true when budget is positive', () {
        final balance = _make(overallBudget: 1000.00);
        expect(balance.hasOverallBudget, true);
      });

      test('returns false when budget is null', () {
        final balance = _make(overallBudget: null);
        expect(balance.hasOverallBudget, false);
      });

      test('returns false when budget is zero', () {
        final balance = MonthlyBalance(
          carryoverFromPrevious: Decimal.zero,
          overallBudget: Decimal.zero,
          accountId: 1,
          month: DateTime.utc(2024, 1, 1),
        );
        expect(balance.hasOverallBudget, false);
      });

      test('returns true when budget is a small positive value', () {
        final balance = MonthlyBalance(
          carryoverFromPrevious: Decimal.zero,
          overallBudget: Decimal.parse('0.01'),
          accountId: 1,
          month: DateTime.utc(2024, 1, 1),
        );
        expect(balance.hasOverallBudget, true);
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------
    group('toMap()', () {
      test('serializes all fields correctly', () {
        final month = DateTime.utc(2024, 6, 1);
        final balance = _make(month: month);
        final map = balance.toMap();

        expect(map['id'], 1);
        expect(
          map['carryover_from_previous'],
          closeTo(500.00, 0.001),
        );
        expect(map['overall_budget'], closeTo(2000.00, 0.001));
        expect(map['account_id'], 1);
        expect(map['month'], '2024-06-01');
      });

      test('serializes null id', () {
        final balance = _make(id: null);
        expect(balance.toMap()['id'], isNull);
      });

      test('serializes null overall_budget', () {
        final balance = _make(overallBudget: null);
        expect(balance.toMap()['overall_budget'], isNull);
      });

      test('serializes negative carryover', () {
        final balance = _make(carryoverFromPrevious: -100.50);
        expect(
          balance.toMap()['carryover_from_previous'],
          closeTo(-100.50, 0.001),
        );
      });

      test('serializes zero carryover', () {
        final balance = _make(carryoverFromPrevious: 0.00);
        expect(balance.toMap()['carryover_from_previous'], 0.0);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() - happy path
    // -----------------------------------------------------------------------
    group('fromMap() deserialization', () {
      test('deserializes all fields from a complete map', () {
        final map = {
          'id': 5,
          'carryover_from_previous': 750.25,
          'overall_budget': 3000.00,
          'account_id': 2,
          'month': '2024-03-01',
        };

        final balance = MonthlyBalance.fromMap(map);

        expect(balance.id, 5);
        expect(
          balance.carryoverFromPrevious,
          closeTo(750.25, 0.001),
        );
        expect(balance.overallBudget, closeTo(3000.00, 0.001));
        expect(balance.accountId, 2);
        expect(balance.month, DateTime.utc(2024, 3, 1));
      });

      test('handles null overall_budget', () {
        final map = {
          'id': 1,
          'carryover_from_previous': 100.0,
          'overall_budget': null,
          'account_id': 1,
          'month': '2024-01-01',
        };
        final balance = MonthlyBalance.fromMap(map);
        expect(balance.overallBudget, isNull);
        expect(balance.hasOverallBudget, false);
      });

      test('treats zero overall_budget as null (no budget set)', () {
        final map = {
          'id': 1,
          'carryover_from_previous': 100.0,
          'overall_budget': 0.0,
          'account_id': 1,
          'month': '2024-01-01',
        };
        final balance = MonthlyBalance.fromMap(map);
        expect(balance.overallBudget, isNull);
        expect(balance.overallBudgetDecimal, isNull);
        expect(balance.hasOverallBudget, false);
      });

      test('handles null carryover as zero', () {
        final map = {
          'id': 1,
          'carryover_from_previous': null,
          'account_id': 1,
          'month': '2024-01-01',
        };
        final balance = MonthlyBalance.fromMap(map);
        expect(balance.carryoverFromPrevious, 0.0);
      });

      test('handles integer carryover (num conversion)', () {
        final map = {
          'id': 1,
          'carryover_from_previous': 500,
          'account_id': 1,
          'month': '2024-01-01',
        };
        final balance = MonthlyBalance.fromMap(map);
        expect(balance.carryoverFromPrevious, closeTo(500.0, 0.001));
      });

      test('falls back to accountId key when account_id missing', () {
        final map = {
          'id': 1,
          'carryover_from_previous': 100.0,
          'accountId': 3,
          'month': '2024-01-01',
        };
        final balance = MonthlyBalance.fromMap(map);
        expect(balance.accountId, 3);
      });

      test('defaults accountId to 0 when both keys missing', () {
        final map = {
          'id': 1,
          'carryover_from_previous': 100.0,
          'month': '2024-01-01',
        };
        final balance = MonthlyBalance.fromMap(map);
        expect(balance.accountId, 0);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() month parsing
    // -----------------------------------------------------------------------
    group('fromMap() month parsing', () {
      test('parses ISO date string', () {
        final map = {
          'id': 1,
          'carryover_from_previous': 0.0,
          'account_id': 1,
          'month': '2024-09-15',
        };
        final balance = MonthlyBalance.fromMap(map);
        expect(balance.month, DateTime.utc(2024, 9, 15));
      });

      test('parses integer timestamp', () {
        // Use local DateTime with noon to avoid timezone edge cases
        final localDate = DateTime(2024, 1, 15, 12);
        final timestamp = localDate.millisecondsSinceEpoch;
        final map = {
          'id': 1,
          'carryover_from_previous': 0.0,
          'account_id': 1,
          'month': timestamp,
        };
        final balance = MonthlyBalance.fromMap(map);
        expect(balance.month.year, 2024);
        expect(balance.month.month, 1);
        expect(balance.month.day, 15);
      });

      test('defaults to start of current month when month is null', () {
        final map = {
          'id': 1,
          'carryover_from_previous': 0.0,
          'account_id': 1,
          'month': null,
        };
        final balance = MonthlyBalance.fromMap(map);
        final expected = DateHelper.startOfMonth(DateHelper.today());
        expect(balance.month, expected);
      });

      test('defaults to start of current month for unrecognized type', () {
        final map = {
          'id': 1,
          'carryover_from_previous': 0.0,
          'account_id': 1,
          'month': true, // boolean, unrecognized
        };
        final balance = MonthlyBalance.fromMap(map);
        final expected = DateHelper.startOfMonth(DateHelper.today());
        expect(balance.month, expected);
      });

      test('defaults to start of current month when month key missing', () {
        final map = {
          'id': 1,
          'carryover_from_previous': 0.0,
          'account_id': 1,
        };
        final balance = MonthlyBalance.fromMap(map);
        final expected = DateHelper.startOfMonth(DateHelper.today());
        expect(balance.month, expected);
      });
    });

    // -----------------------------------------------------------------------
    // copyWith()
    // -----------------------------------------------------------------------
    group('copyWith()', () {
      test('overrides id', () {
        final original = _make();
        final copy = original.copyWith(id: 99);
        expect(copy.id, 99);
        expect(copy.carryoverFromPrevious, original.carryoverFromPrevious);
      });

      test('overrides carryoverFromPrevious', () {
        final original = _make();
        final copy = original.copyWith(carryoverFromPrevious: 999.99);
        expect(copy.carryoverFromPrevious, closeTo(999.99, 0.001));
      });

      test('overrides overallBudget', () {
        final original = _make();
        final copy = original.copyWith(overallBudget: 5000.00);
        expect(copy.overallBudget, closeTo(5000.00, 0.001));
      });

      test('clears overallBudget with clearOverallBudget flag', () {
        final original = _make(overallBudget: 2000.00);
        final copy = original.copyWith(clearOverallBudget: true);
        expect(copy.overallBudget, isNull);
        expect(copy.hasOverallBudget, false);
      });

      test('overrides accountId', () {
        final original = _make();
        final copy = original.copyWith(accountId: 42);
        expect(copy.accountId, 42);
      });

      test('overrides month', () {
        final newMonth = DateTime.utc(2025, 1, 1);
        final original = _make();
        final copy = original.copyWith(month: newMonth);
        expect(copy.month, newMonth);
      });

      test('preserves all fields when nothing overridden', () {
        final original = _make();
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.carryoverFromPrevious, original.carryoverFromPrevious);
        expect(copy.overallBudget, original.overallBudget);
        expect(copy.accountId, original.accountId);
        expect(copy.month, original.month);
      });
    });

    // -----------------------------------------------------------------------
    // copyWithDecimal()
    // -----------------------------------------------------------------------
    group('copyWithDecimal()', () {
      test('overrides carryoverFromPrevious with Decimal', () {
        final original = _make();
        final copy = original.copyWithDecimal(
          carryoverFromPrevious: Decimal.parse('1234.56'),
        );
        expect(
          copy.carryoverFromPreviousDecimal,
          Decimal.parse('1234.56'),
        );
      });

      test('overrides overallBudget with Decimal', () {
        final original = _make();
        final copy = original.copyWithDecimal(
          overallBudget: Decimal.parse('8000.00'),
        );
        expect(copy.overallBudgetDecimal, Decimal.parse('8000.00'));
      });

      test('clears overallBudget with clearOverallBudget flag', () {
        final original = _make(overallBudget: 2000.00);
        final copy = original.copyWithDecimal(clearOverallBudget: true);
        expect(copy.overallBudgetDecimal, isNull);
        expect(copy.hasOverallBudget, false);
      });

      test('preserves all fields when nothing overridden', () {
        final original = _make();
        final copy = original.copyWithDecimal();

        expect(copy.id, original.id);
        expect(
          copy.carryoverFromPreviousDecimal,
          original.carryoverFromPreviousDecimal,
        );
        expect(copy.overallBudgetDecimal, original.overallBudgetDecimal);
        expect(copy.accountId, original.accountId);
        expect(copy.month, original.month);
      });
    });

    // -----------------------------------------------------------------------
    // Round-trip: toMap -> fromMap
    // -----------------------------------------------------------------------
    group('round-trip serialization', () {
      test('toMap then fromMap preserves all values', () {
        final original = _make(
          carryoverFromPrevious: 1500.75,
          overallBudget: 4000.00,
          accountId: 3,
          month: DateTime.utc(2024, 9, 1),
        );
        final map = original.toMap();
        final restored = MonthlyBalance.fromMap(map);

        expect(restored.id, original.id);
        expect(
          restored.carryoverFromPrevious,
          closeTo(original.carryoverFromPrevious, 0.001),
        );
        expect(
          restored.overallBudget,
          closeTo(original.overallBudget!, 0.001),
        );
        expect(restored.accountId, original.accountId);
        expect(restored.month, original.month);
      });

      test('round-trip with null budget preserved', () {
        final original = _make(overallBudget: null);
        final map = original.toMap();
        final restored = MonthlyBalance.fromMap(map);

        expect(restored.overallBudget, isNull);
        expect(restored.hasOverallBudget, false);
      });

      test('round-trip with negative carryover preserved', () {
        final original = _make(carryoverFromPrevious: -350.25);
        final map = original.toMap();
        final restored = MonthlyBalance.fromMap(map);

        expect(
          restored.carryoverFromPrevious,
          closeTo(-350.25, 0.001),
        );
      });
    });
  });
}
