import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:budget_tracker/models/income_model.dart';

void main() {
  group('Income', () {
    late Income income;

    setUp(() {
      income = Income(
        id: 1,
        amount: Decimal.parse('5000.00'),
        category: 'Salary',
        description: 'Monthly salary',
        date: DateTime.utc(2024, 3, 1),
        accountId: 1,
      );
    });

    group('constructor', () {
      test('creates income with all fields', () {
        expect(income.id, 1);
        expect(income.amount, 5000.00);
        expect(income.category, 'Salary');
        expect(income.description, 'Monthly salary');
        expect(income.date, DateTime.utc(2024, 3, 1));
        expect(income.accountId, 1);
      });

      test('id defaults to null when not provided', () {
        final i = Income(
          amount: Decimal.parse('100.00'),
          category: 'Freelance',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        expect(i.id, isNull);
      });

      test('amount getter returns double', () {
        expect(income.amount, isA<double>());
        expect(income.amount, 5000.00);
      });

      test('amountDecimal getter returns Decimal', () {
        expect(income.amountDecimal, isA<Decimal>());
        expect(income.amountDecimal, Decimal.parse('5000.00'));
      });
    });

    group('toMap()', () {
      test('serializes all fields correctly', () {
        final map = income.toMap();
        expect(map['id'], 1);
        expect(map['amount'], 5000.00);
        expect(map['category'], 'Salary');
        expect(map['description'], 'Monthly salary');
        expect(map['date'], '2024-03-01');
        expect(map['account_id'], 1);
      });

      test('serializes null id', () {
        final i = Income(
          amount: Decimal.parse('100.00'),
          category: 'Freelance',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        final map = i.toMap();
        expect(map['id'], isNull);
      });

      test('serializes zero amount', () {
        final i = Income(
          amount: Decimal.zero,
          category: 'Salary',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        final map = i.toMap();
        expect(map['amount'], 0.0);
      });

      test('date is serialized as ISO 8601 date string', () {
        final map = income.toMap();
        expect(map['date'], '2024-03-01');
      });

      test('uses snake_case account_id key', () {
        final map = income.toMap();
        expect(map.containsKey('account_id'), isTrue);
        expect(map.containsKey('accountId'), isFalse);
      });
    });

    group('fromMap()', () {
      test('deserializes all fields correctly', () {
        final map = {
          'id': 2,
          'amount': 3000.50,
          'category': 'Freelance',
          'description': 'Project payment',
          'date': '2024-06-15',
          'account_id': 2,
        };
        final i = Income.fromMap(map);
        expect(i.id, 2);
        expect(i.amount, 3000.50);
        expect(i.category, 'Freelance');
        expect(i.description, 'Project payment');
        expect(i.date, DateTime.utc(2024, 6, 15));
        expect(i.accountId, 2);
      });

      test('handles null id', () {
        final map = {
          'id': null,
          'amount': 100.0,
          'category': 'Salary',
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final i = Income.fromMap(map);
        expect(i.id, isNull);
      });

      test('defaults description to empty string when null', () {
        final map = {
          'amount': 100.0,
          'category': 'Salary',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final i = Income.fromMap(map);
        expect(i.description, '');
      });

      test('defaults amount to 0 when null', () {
        final map = {
          'category': 'Salary',
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final i = Income.fromMap(map);
        expect(i.amount, 0.0);
      });

      test('falls back to today when date is null', () {
        final map = {
          'amount': 100.0,
          'category': 'Salary',
          'description': 'Test',
          'account_id': 1,
        };
        final i = Income.fromMap(map);
        final now = DateTime.now();
        expect(i.date.year, now.year);
        expect(i.date.month, now.month);
        expect(i.date.day, now.day);
      });

      test('falls back to today when date is invalid string', () {
        final map = {
          'amount': 100.0,
          'category': 'Salary',
          'description': 'Test',
          'date': 'invalid-date',
          'account_id': 1,
        };
        final i = Income.fromMap(map);
        final now = DateTime.now();
        expect(i.date.year, now.year);
        expect(i.date.month, now.month);
        expect(i.date.day, now.day);
      });

      test('handles integer amount via num conversion', () {
        final map = {
          'amount': 5000,
          'category': 'Salary',
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final i = Income.fromMap(map);
        expect(i.amount, 5000.0);
      });
    });

    group('fromMap() validation', () {
      test('throws ArgumentError when category is null', () {
        final map = {
          'amount': 100.0,
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        expect(() => Income.fromMap(map), throwsArgumentError);
      });

      test('throws ArgumentError when category is empty string', () {
        final map = {
          'amount': 100.0,
          'category': '',
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        expect(() => Income.fromMap(map), throwsArgumentError);
      });

      test('throws ArgumentError when account_id is null', () {
        final map = {
          'amount': 100.0,
          'category': 'Salary',
          'description': 'Test',
          'date': '2024-01-01',
        };
        expect(() => Income.fromMap(map), throwsArgumentError);
      });

      test('throws ArgumentError with descriptive message for missing category',
          () {
        final map = {
          'amount': 100.0,
          'date': '2024-01-01',
          'account_id': 1,
        };
        expect(
          () => Income.fromMap(map),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Income category is required',
          )),
        );
      });

      test(
          'throws ArgumentError with descriptive message for missing account_id',
          () {
        final map = {
          'amount': 100.0,
          'category': 'Salary',
          'description': 'Test',
          'date': '2024-01-01',
        };
        expect(
          () => Income.fromMap(map),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Income account_id is required',
          )),
        );
      });
    });

    group('copyWith()', () {
      test('copies with new id', () {
        final copy = income.copyWith(id: 99);
        expect(copy.id, 99);
        expect(copy.amount, income.amount);
        expect(copy.category, income.category);
        expect(copy.description, income.description);
        expect(copy.date, income.date);
        expect(copy.accountId, income.accountId);
      });

      test('copies with new amount', () {
        final copy = income.copyWith(amount: 7500.00);
        expect(copy.amount, 7500.00);
        expect(copy.id, income.id);
      });

      test('copies with new category', () {
        final copy = income.copyWith(category: 'Bonus');
        expect(copy.category, 'Bonus');
        expect(copy.id, income.id);
      });

      test('copies with new description', () {
        final copy = income.copyWith(description: 'Year-end bonus');
        expect(copy.description, 'Year-end bonus');
        expect(copy.id, income.id);
      });

      test('copies with new date', () {
        final newDate = DateTime.utc(2025, 6, 1);
        final copy = income.copyWith(date: newDate);
        expect(copy.date, newDate);
        expect(copy.id, income.id);
      });

      test('copies with new accountId', () {
        final copy = income.copyWith(accountId: 3);
        expect(copy.accountId, 3);
        expect(copy.id, income.id);
      });

      test('preserves all fields when no arguments provided', () {
        final copy = income.copyWith();
        expect(copy.id, income.id);
        expect(copy.amount, income.amount);
        expect(copy.category, income.category);
        expect(copy.description, income.description);
        expect(copy.date, income.date);
        expect(copy.accountId, income.accountId);
      });
    });

    group('copyWithDecimal()', () {
      test('copies with Decimal amount', () {
        final copy = income.copyWithDecimal(
          amount: Decimal.parse('10000.00'),
        );
        expect(copy.amountDecimal, Decimal.parse('10000.00'));
        expect(copy.id, income.id);
      });

      test('preserves all fields when no arguments provided', () {
        final copy = income.copyWithDecimal();
        expect(copy.id, income.id);
        expect(copy.amountDecimal, income.amountDecimal);
        expect(copy.category, income.category);
        expect(copy.description, income.description);
        expect(copy.date, income.date);
        expect(copy.accountId, income.accountId);
      });
    });

    group('edge cases', () {
      test('handles empty string description', () {
        final i = Income(
          amount: Decimal.parse('100.00'),
          category: 'Salary',
          description: '',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        expect(i.description, '');
      });

      test('handles large amounts', () {
        final i = Income(
          amount: Decimal.parse('999999999.99'),
          category: 'Salary',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        expect(i.amount, closeTo(999999999.99, 0.01));
      });

      test('roundtrip: toMap then fromMap preserves data', () {
        final map = income.toMap();
        final restored = Income.fromMap(map);
        expect(restored.id, income.id);
        expect(restored.amount, income.amount);
        expect(restored.category, income.category);
        expect(restored.description, income.description);
        expect(restored.date, income.date);
        expect(restored.accountId, income.accountId);
      });
    });
  });
}
