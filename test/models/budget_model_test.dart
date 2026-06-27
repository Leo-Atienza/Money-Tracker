import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:budget_tracker/models/budget_model.dart';

void main() {
  group('Budget', () {
    late Budget budget;

    setUp(() {
      budget = Budget(
        id: 1,
        category: 'Food',
        amount: Decimal.parse('500.00'),
        accountId: 1,
        month: DateTime.utc(2024, 3, 1),
      );
    });

    group('constructor', () {
      test('creates budget with all fields', () {
        expect(budget.id, 1);
        expect(budget.category, 'Food');
        expect(budget.amount, 500.00);
        expect(budget.accountId, 1);
        expect(budget.month, DateTime.utc(2024, 3, 1));
      });

      test('id defaults to null when not provided', () {
        final b = Budget(
          category: 'Food',
          amount: Decimal.parse('100.00'),
          accountId: 1,
          month: DateTime.utc(2024, 1, 1),
        );
        expect(b.id, isNull);
      });

      test('amount getter returns double', () {
        expect(budget.amount, isA<double>());
        expect(budget.amount, 500.00);
      });

      test('amountDecimal getter returns Decimal', () {
        expect(budget.amountDecimal, isA<Decimal>());
        expect(budget.amountDecimal, Decimal.parse('500.00'));
      });
    });

    group('toMap()', () {
      test('serializes all fields correctly', () {
        final map = budget.toMap();
        expect(map['id'], 1);
        expect(map['category'], 'Food');
        expect(map['amount'], 500.00);
        expect(map['account_id'], 1);
        expect(map['month'], '2024-03-01');
      });

      test('serializes null id', () {
        final b = Budget(
          category: 'Food',
          amount: Decimal.parse('100.00'),
          accountId: 1,
          month: DateTime.utc(2024, 1, 1),
        );
        final map = b.toMap();
        expect(map['id'], isNull);
      });

      test('serializes zero amount', () {
        final b = Budget(
          category: 'Food',
          amount: Decimal.zero,
          accountId: 1,
          month: DateTime.utc(2024, 1, 1),
        );
        final map = b.toMap();
        expect(map['amount'], 0.0);
      });

      test('uses snake_case account_id key', () {
        final map = budget.toMap();
        expect(map.containsKey('account_id'), isTrue);
      });

      test('month is serialized as ISO 8601 date string', () {
        final map = budget.toMap();
        expect(map['month'], '2024-03-01');
      });
    });

    group('fromMap()', () {
      test('deserializes all fields correctly with string date', () {
        final map = {
          'id': 2,
          'category': 'Transport',
          'amount': 300.50,
          'account_id': 2,
          'month': '2024-06-01',
        };
        final b = Budget.fromMap(map);
        expect(b.id, 2);
        expect(b.category, 'Transport');
        expect(b.amount, 300.50);
        expect(b.accountId, 2);
        expect(b.month, DateTime.utc(2024, 6, 1));
      });

      test('handles null id', () {
        final map = {
          'id': null,
          'category': 'Food',
          'amount': 100.0,
          'account_id': 1,
          'month': '2024-01-01',
        };
        final b = Budget.fromMap(map);
        expect(b.id, isNull);
      });

      test('defaults category to Uncategorized when null', () {
        final map = {
          'amount': 100.0,
          'account_id': 1,
          'month': '2024-01-01',
        };
        final b = Budget.fromMap(map);
        expect(b.category, 'Uncategorized');
      });

      test('defaults amount to 0 when null', () {
        final map = {
          'category': 'Food',
          'account_id': 1,
          'month': '2024-01-01',
        };
        final b = Budget.fromMap(map);
        expect(b.amount, 0.0);
      });

      test('supports account_id key (snake_case)', () {
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 5,
          'month': '2024-01-01',
        };
        final b = Budget.fromMap(map);
        expect(b.accountId, 5);
      });

      test('rejects camelCase accountId key (Phase 4.11)', () {
        // Pre-Phase-4.11 this fell back to camelCase. The on-disk schema and
        // every live writer use snake_case; accepting camelCase silently
        // imported hand-edited backups with typos as if they were correct.
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'accountId': 7,
          'month': '2024-01-01',
        };
        expect(() => Budget.fromMap(map), throwsArgumentError);
      });

      test('prefers account_id over accountId when both present', () {
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 5,
          'accountId': 7,
          'month': '2024-01-01',
        };
        final b = Budget.fromMap(map);
        expect(b.accountId, 5);
      });

      test('handles integer amount via num conversion', () {
        final map = {
          'category': 'Food',
          'amount': 500,
          'account_id': 1,
          'month': '2024-01-01',
        };
        final b = Budget.fromMap(map);
        expect(b.amount, 500.0);
      });
    });

    group('fromMap() date parsing', () {
      test('parses month from String (ISO 8601)', () {
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 1,
          'month': '2024-06-15',
        };
        final b = Budget.fromMap(map);
        expect(b.month, DateTime.utc(2024, 6, 15));
      });

      test('parses month from int (milliseconds since epoch)', () {
        // Use local DateTime to construct timestamp, since fromMillisecondsSinceEpoch
        // converts to local time before normalize() extracts the date
        final localDate =
            DateTime(2024, 3, 15, 12); // noon to avoid timezone edge
        final timestamp = localDate.millisecondsSinceEpoch;
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 1,
          'month': timestamp,
        };
        final b = Budget.fromMap(map);
        expect(b.month.year, 2024);
        expect(b.month.month, 3);
        expect(b.month.day, 15);
      });

      test('defaults to start of current month when month is null', () {
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 1,
          'month': null,
        };
        final b = Budget.fromMap(map);
        final now = DateTime.now();
        expect(b.month.year, now.year);
        expect(b.month.month, now.month);
        expect(b.month.day, 1);
      });

      test('defaults to start of current month when month key is missing', () {
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 1,
        };
        final b = Budget.fromMap(map);
        final now = DateTime.now();
        expect(b.month.year, now.year);
        expect(b.month.month, now.month);
        expect(b.month.day, 1);
      });

      test('defaults to start of current month when month has unsupported type',
          () {
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 1,
          'month': 3.14, // double - unsupported type
        };
        final b = Budget.fromMap(map);
        final now = DateTime.now();
        expect(b.month.year, now.year);
        expect(b.month.month, now.month);
        expect(b.month.day, 1);
      });

      test('defaults to start of current month when month string is invalid',
          () {
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 1,
          'month': 'not-a-date',
        };
        final b = Budget.fromMap(map);
        final now = DateTime.now();
        expect(b.month.year, now.year);
        expect(b.month.month, now.month);
        expect(b.month.day, 1);
      });

      test('parses full ISO 8601 datetime string', () {
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 1,
          'month': '2024-03-15T14:30:00.000Z',
        };
        final b = Budget.fromMap(map);
        expect(b.month.year, 2024);
        expect(b.month.month, 3);
        expect(b.month.day, 15);
      });

      test('parses epoch 0 (Unix epoch) as int', () {
        final map = {
          'category': 'Food',
          'amount': 100.0,
          'account_id': 1,
          'month': 0,
        };
        final b = Budget.fromMap(map);
        // Unix epoch 0 converts to local time first, then normalize extracts date
        final localEpoch = DateTime.fromMillisecondsSinceEpoch(0);
        expect(b.month.year, localEpoch.year);
        expect(b.month.month, localEpoch.month);
        expect(b.month.day, localEpoch.day);
      });
    });

    group('copyWith()', () {
      test('copies with new id', () {
        final copy = budget.copyWith(id: 99);
        expect(copy.id, 99);
        expect(copy.category, budget.category);
        expect(copy.amount, budget.amount);
        expect(copy.accountId, budget.accountId);
        expect(copy.month, budget.month);
      });

      test('copies with new category', () {
        final copy = budget.copyWith(category: 'Entertainment');
        expect(copy.category, 'Entertainment');
        expect(copy.id, budget.id);
      });

      test('copies with new amount', () {
        final copy = budget.copyWith(amount: 1000.00);
        expect(copy.amount, 1000.00);
        expect(copy.id, budget.id);
      });

      test('copies with new accountId', () {
        final copy = budget.copyWith(accountId: 5);
        expect(copy.accountId, 5);
        expect(copy.id, budget.id);
      });

      test('copies with new month', () {
        final newMonth = DateTime.utc(2025, 1, 1);
        final copy = budget.copyWith(month: newMonth);
        expect(copy.month, newMonth);
        expect(copy.id, budget.id);
      });

      test('preserves all fields when no arguments provided', () {
        final copy = budget.copyWith();
        expect(copy.id, budget.id);
        expect(copy.category, budget.category);
        expect(copy.amount, budget.amount);
        expect(copy.accountId, budget.accountId);
        expect(copy.month, budget.month);
      });
    });

    group('copyWithDecimal()', () {
      test('copies with Decimal amount', () {
        final copy = budget.copyWithDecimal(
          amount: Decimal.parse('2000.00'),
        );
        expect(copy.amountDecimal, Decimal.parse('2000.00'));
        expect(copy.id, budget.id);
      });

      test('preserves all fields when no arguments provided', () {
        final copy = budget.copyWithDecimal();
        expect(copy.id, budget.id);
        expect(copy.amountDecimal, budget.amountDecimal);
        expect(copy.category, budget.category);
        expect(copy.accountId, budget.accountId);
        expect(copy.month, budget.month);
      });
    });

    group('edge cases', () {
      test('handles large amounts', () {
        final b = Budget(
          category: 'Food',
          amount: Decimal.parse('999999999.99'),
          accountId: 1,
          month: DateTime.utc(2024, 1, 1),
        );
        expect(b.amount, closeTo(999999999.99, 0.01));
      });

      test('roundtrip: toMap then fromMap preserves data', () {
        final map = budget.toMap();
        final restored = Budget.fromMap(map);
        expect(restored.id, budget.id);
        expect(restored.category, budget.category);
        expect(restored.amount, budget.amount);
        expect(restored.accountId, budget.accountId);
        expect(restored.month, budget.month);
      });

      test('rejects empty map (Phase 4.11 — account_id required)', () {
        // Pre-Phase-4.11 returned a fabricated Budget with accountId == 0.
        // That tied corrupted backups to the no-such-account id; reject loud.
        expect(() => Budget.fromMap(<String, dynamic>{}), throwsArgumentError);
      });
    });

    group('round-trip precision', () {
      // Closes the 🟡 Partial round-trip gap in the spec: 3-dp amount
      // truncation and a *round-tripped* (not constructor-only) large amount.
      //
      // Mechanics: toMap() stores DecimalHelper.toDouble(_amount) verbatim
      // (no rounding — only finite/clamp guards). fromMap() restores via
      // fromDoubleSafe -> fromDouble -> Decimal.parse(clamped.toStringAsFixed(2)),
      // so the 2-dp truncation happens on deserialization, not construction.

      test('3-dp amount stored exactly in the constructor (no truncation)', () {
        // The constructor keeps the Decimal as-is; truncation is a round-trip
        // artifact, so a freshly built Budget retains all three decimals.
        final b = Budget(
          category: 'Food',
          amount: Decimal.parse('500.123'),
          accountId: 1,
          month: DateTime.utc(2024, 1, 1),
        );
        expect(b.amountDecimal, Decimal.parse('500.123'));
      });

      test('round-trip truncates a 3-dp amount to 2dp (rounds down)', () {
        final b = Budget(
          category: 'Food',
          amount: Decimal.parse('500.123'), // 3rd dp = 3 -> drops
          accountId: 2,
          month: DateTime.utc(2024, 5, 1),
        );
        final restored = Budget.fromMap(b.toMap());
        // (500.123).toStringAsFixed(2) == '500.12'
        expect(restored.amountDecimal, Decimal.parse('500.12'));
        expect(restored.amount, 500.12);
      });

      test('round-trip truncates a 3-dp amount to 2dp (rounds up)', () {
        final b = Budget(
          category: 'Food',
          amount: Decimal.parse('500.128'), // 3rd dp = 8 -> rounds up
          accountId: 3,
          month: DateTime.utc(2024, 5, 1),
        );
        final restored = Budget.fromMap(b.toMap());
        // (500.128).toStringAsFixed(2) == '500.13'
        expect(restored.amountDecimal, Decimal.parse('500.13'));
        expect(restored.amount, 500.13);
      });

      test('round-trip rounds .999 up across the integer boundary', () {
        final b = Budget(
          category: 'Food',
          amount: Decimal.parse('250.999'),
          accountId: 1,
          month: DateTime.utc(2024, 7, 1),
        );
        final restored = Budget.fromMap(b.toMap());
        // (250.999).toStringAsFixed(2) == '251.00'
        expect(restored.amountDecimal, Decimal.parse('251.00'));
        expect(restored.amount, 251.00);
      });

      test('round-trip preserves the max safe amount (999999999.99)', () {
        // The 'edge cases > handles large amounts' test only checks the
        // constructor. This drives the value through toMap -> fromMap so the
        // DecimalHelper clamp ceiling (999999999.99) is exercised on the
        // serialization path, not just at construction.
        final b = Budget(
          category: 'Food',
          amount: Decimal.parse('999999999.99'),
          accountId: 9,
          month: DateTime.utc(2024, 12, 1),
        );
        final restored = Budget.fromMap(b.toMap());
        expect(restored.amountDecimal, Decimal.parse('999999999.99'));
        expect(restored.amount, closeTo(999999999.99, 0.01));
        expect(restored.id, b.id);
        expect(restored.category, b.category);
        expect(restored.accountId, b.accountId);
        expect(restored.month, b.month);
      });

      test('round-trip is idempotent after the first 2-dp truncation', () {
        // First round-trip truncates 500.123 -> 500.12; a second round-trip
        // must be a no-op (the value is already at 2dp).
        final b = Budget(
          category: 'Food',
          amount: Decimal.parse('500.123'),
          accountId: 4,
          month: DateTime.utc(2024, 6, 1),
        );
        final once = Budget.fromMap(b.toMap());
        final twice = Budget.fromMap(once.toMap());
        expect(twice.amountDecimal, once.amountDecimal);
        expect(twice.amountDecimal, Decimal.parse('500.12'));
      });
    });
  });
}
