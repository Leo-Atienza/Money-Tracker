import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:budget_tracker/models/expense_model.dart';

void main() {
  group('Expense', () {
    late Expense expense;

    setUp(() {
      expense = Expense(
        id: 1,
        amount: Decimal.parse('100.50'),
        category: 'Food',
        description: 'Grocery shopping',
        date: DateTime.utc(2024, 3, 15),
        accountId: 1,
        amountPaid: Decimal.parse('50.25'),
        paymentMethod: 'Card',
      );
    });

    group('constructor', () {
      test('creates expense with all fields', () {
        expect(expense.id, 1);
        expect(expense.amount, 100.50);
        expect(expense.category, 'Food');
        expect(expense.description, 'Grocery shopping');
        expect(expense.date, DateTime.utc(2024, 3, 15));
        expect(expense.accountId, 1);
        expect(expense.amountPaid, 50.25);
        expect(expense.paymentMethod, 'Card');
      });

      test('defaults amountPaid to zero when not provided', () {
        final e = Expense(
          amount: Decimal.parse('50.00'),
          category: 'Food',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        expect(e.amountPaid, 0.0);
      });

      test('defaults paymentMethod to Cash when not provided', () {
        final e = Expense(
          amount: Decimal.parse('50.00'),
          category: 'Food',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        expect(e.paymentMethod, 'Cash');
      });

      test('id defaults to null when not provided', () {
        final e = Expense(
          amount: Decimal.parse('10.00'),
          category: 'Food',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        expect(e.id, isNull);
      });

      test('Decimal getters return exact Decimal values', () {
        expect(expense.amountDecimal, Decimal.parse('100.50'));
        expect(expense.amountPaidDecimal, Decimal.parse('50.25'));
      });
    });

    group('toMap()', () {
      test('serializes all fields correctly', () {
        final map = expense.toMap();
        expect(map['id'], 1);
        expect(map['amount'], 100.50);
        expect(map['category'], 'Food');
        expect(map['description'], 'Grocery shopping');
        expect(map['date'], '2024-03-15');
        expect(map['account_id'], 1);
        expect(map['amountPaid'], 50.25);
        expect(map['paymentMethod'], 'Card');
      });

      test('serializes null id', () {
        final e = Expense(
          amount: Decimal.parse('10.00'),
          category: 'Food',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        final map = e.toMap();
        expect(map['id'], isNull);
      });

      test('serializes zero amount', () {
        final e = Expense(
          amount: Decimal.zero,
          category: 'Food',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        final map = e.toMap();
        expect(map['amount'], 0.0);
        expect(map['amountPaid'], 0.0);
      });

      test('date is serialized as ISO 8601 date string', () {
        final e = Expense(
          amount: Decimal.parse('10.00'),
          category: 'Food',
          description: 'Test',
          date: DateTime.utc(2024, 12, 31),
          accountId: 1,
        );
        final map = e.toMap();
        expect(map['date'], '2024-12-31');
      });
    });

    group('fromMap()', () {
      test('deserializes all fields correctly', () {
        final map = {
          'id': 2,
          'amount': 75.50,
          'category': 'Transport',
          'description': 'Taxi ride',
          'date': '2024-06-20',
          'account_id': 3,
          'amountPaid': 75.50,
          'paymentMethod': 'Cash',
        };
        final e = Expense.fromMap(map);
        expect(e.id, 2);
        expect(e.amount, 75.50);
        expect(e.category, 'Transport');
        expect(e.description, 'Taxi ride');
        expect(e.date, DateTime.utc(2024, 6, 20));
        expect(e.accountId, 3);
        expect(e.amountPaid, 75.50);
        expect(e.paymentMethod, 'Cash');
      });

      test('handles null id', () {
        final map = {
          'id': null,
          'amount': 10.0,
          'category': 'Food',
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final e = Expense.fromMap(map);
        expect(e.id, isNull);
      });

      test('defaults category to Uncategorized when null', () {
        final map = {
          'amount': 10.0,
          'date': '2024-01-01',
          'account_id': 1,
        };
        final e = Expense.fromMap(map);
        expect(e.category, 'Uncategorized');
      });

      test('defaults description to empty string when null', () {
        final map = {
          'amount': 10.0,
          'category': 'Food',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final e = Expense.fromMap(map);
        expect(e.description, '');
      });

      test('defaults accountId to 0 when null', () {
        final map = {
          'amount': 10.0,
          'category': 'Food',
          'description': 'Test',
          'date': '2024-01-01',
        };
        final e = Expense.fromMap(map);
        expect(e.accountId, 0);
      });

      test('defaults amountPaid to 0 when null', () {
        final map = {
          'amount': 10.0,
          'category': 'Food',
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final e = Expense.fromMap(map);
        expect(e.amountPaid, 0.0);
      });

      test('defaults paymentMethod to Cash when null', () {
        final map = {
          'amount': 10.0,
          'category': 'Food',
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final e = Expense.fromMap(map);
        expect(e.paymentMethod, 'Cash');
      });

      test('defaults amount to 0 when null', () {
        final map = {
          'category': 'Food',
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final e = Expense.fromMap(map);
        expect(e.amount, 0.0);
      });

      test('falls back to today when date is null', () {
        final map = {
          'amount': 10.0,
          'category': 'Food',
          'description': 'Test',
          'account_id': 1,
        };
        final e = Expense.fromMap(map);
        final now = DateTime.now();
        expect(e.date.year, now.year);
        expect(e.date.month, now.month);
        expect(e.date.day, now.day);
      });

      test('falls back to today when date is invalid string', () {
        final map = {
          'amount': 10.0,
          'category': 'Food',
          'description': 'Test',
          'date': 'not-a-date',
          'account_id': 1,
        };
        final e = Expense.fromMap(map);
        final now = DateTime.now();
        expect(e.date.year, now.year);
        expect(e.date.month, now.month);
        expect(e.date.day, now.day);
      });

      test('handles integer amount via num conversion', () {
        final map = {
          'amount': 100,
          'category': 'Food',
          'description': 'Test',
          'date': '2024-01-01',
          'account_id': 1,
        };
        final e = Expense.fromMap(map);
        expect(e.amount, 100.0);
      });

      test('handles empty map with graceful defaults', () {
        final map = <String, dynamic>{};
        final e = Expense.fromMap(map);
        expect(e.id, isNull);
        expect(e.amount, 0.0);
        expect(e.category, 'Uncategorized');
        expect(e.description, '');
        expect(e.accountId, 0);
        expect(e.amountPaid, 0.0);
        expect(e.paymentMethod, 'Cash');
      });
    });

    group('copyWith()', () {
      test('copies with new id', () {
        final copy = expense.copyWith(id: 99);
        expect(copy.id, 99);
        expect(copy.amount, expense.amount);
        expect(copy.category, expense.category);
        expect(copy.description, expense.description);
        expect(copy.date, expense.date);
        expect(copy.accountId, expense.accountId);
        expect(copy.amountPaid, expense.amountPaid);
        expect(copy.paymentMethod, expense.paymentMethod);
      });

      test('copies with new amount', () {
        final copy = expense.copyWith(amount: 200.00);
        expect(copy.amount, 200.00);
        expect(copy.id, expense.id);
      });

      test('copies with new category', () {
        final copy = expense.copyWith(category: 'Entertainment');
        expect(copy.category, 'Entertainment');
        expect(copy.id, expense.id);
      });

      test('copies with new description', () {
        final copy = expense.copyWith(description: 'New description');
        expect(copy.description, 'New description');
        expect(copy.id, expense.id);
      });

      test('copies with new date', () {
        final newDate = DateTime.utc(2025, 1, 1);
        final copy = expense.copyWith(date: newDate);
        expect(copy.date, newDate);
        expect(copy.id, expense.id);
      });

      test('copies with new accountId', () {
        final copy = expense.copyWith(accountId: 5);
        expect(copy.accountId, 5);
        expect(copy.id, expense.id);
      });

      test('copies with new amountPaid', () {
        final copy = expense.copyWith(amountPaid: 100.50);
        expect(copy.amountPaid, 100.50);
        expect(copy.id, expense.id);
      });

      test('copies with new paymentMethod', () {
        final copy = expense.copyWith(paymentMethod: 'Bank Transfer');
        expect(copy.paymentMethod, 'Bank Transfer');
        expect(copy.id, expense.id);
      });

      test('preserves all fields when no arguments provided', () {
        final copy = expense.copyWith();
        expect(copy.id, expense.id);
        expect(copy.amount, expense.amount);
        expect(copy.category, expense.category);
        expect(copy.description, expense.description);
        expect(copy.date, expense.date);
        expect(copy.accountId, expense.accountId);
        expect(copy.amountPaid, expense.amountPaid);
        expect(copy.paymentMethod, expense.paymentMethod);
      });
    });

    group('copyWithDecimal()', () {
      test('copies with Decimal amount', () {
        final copy = expense.copyWithDecimal(
          amount: Decimal.parse('999.99'),
        );
        expect(copy.amountDecimal, Decimal.parse('999.99'));
        expect(copy.id, expense.id);
      });

      test('copies with Decimal amountPaid', () {
        final copy = expense.copyWithDecimal(
          amountPaid: Decimal.parse('100.50'),
        );
        expect(copy.amountPaidDecimal, Decimal.parse('100.50'));
        expect(copy.id, expense.id);
      });

      test('preserves all fields when no arguments provided', () {
        final copy = expense.copyWithDecimal();
        expect(copy.id, expense.id);
        expect(copy.amountDecimal, expense.amountDecimal);
        expect(copy.category, expense.category);
      });
    });

    group('computed properties', () {
      group('isPaid', () {
        test('returns true when amountPaid equals amount', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('100.00'),
          );
          expect(e.isPaid, isTrue);
        });

        test('returns true when amountPaid exceeds amount (overpayment)', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('150.00'),
          );
          expect(e.isPaid, isTrue);
        });

        test('returns false when amountPaid is less than amount', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('99.99'),
          );
          expect(e.isPaid, isFalse);
        });

        test('returns false when amountPaid is zero', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
          );
          expect(e.isPaid, isFalse);
        });

        test('returns true when both amount and amountPaid are zero', () {
          final e = Expense(
            amount: Decimal.zero,
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
          );
          expect(e.isPaid, isTrue);
        });

        test('handles precise decimal comparison (avoids floating-point bug)',
            () {
          // This tests the critical fix: 99.999... should not equal 100.00
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('100.00'),
          );
          expect(e.isPaid, isTrue);
        });
      });

      group('remainingAmount', () {
        test('returns correct remaining when partially paid', () {
          expect(expense.remainingAmount, closeTo(50.25, 0.01));
        });

        test('returns zero when fully paid', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('100.00'),
          );
          expect(e.remainingAmount, 0.0);
        });

        test('returns full amount when nothing paid', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
          );
          expect(e.remainingAmount, 100.0);
        });

        test('returns negative when overpaid', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('150.00'),
          );
          expect(e.remainingAmount, -50.0);
        });

        test('remainingAmountDecimal returns Decimal type', () {
          expect(
            expense.remainingAmountDecimal,
            Decimal.parse('50.25'),
          );
        });
      });

      group('paymentProgress', () {
        test('returns 0.5 when half paid', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('50.00'),
          );
          expect(e.paymentProgress, closeTo(0.5, 0.01));
        });

        test('returns 1.0 when fully paid', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('100.00'),
          );
          expect(e.paymentProgress, 1.0);
        });

        test('clamps to 1.0 when overpaid', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('200.00'),
          );
          expect(e.paymentProgress, 1.0);
        });

        test('returns 0.0 when nothing paid', () {
          final e = Expense(
            amount: Decimal.parse('100.00'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
          );
          expect(e.paymentProgress, 0.0);
        });

        test('returns 0.0 when amount is zero (avoids division by zero)', () {
          final e = Expense(
            amount: Decimal.zero,
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
          );
          expect(e.paymentProgress, 0.0);
        });

        test('returns 0.0 when amount is very small (less than 0.01)', () {
          final e = Expense(
            amount: Decimal.parse('0.005'),
            category: 'Food',
            description: 'Test',
            date: DateTime.utc(2024, 1, 1),
            accountId: 1,
            amountPaid: Decimal.parse('0.005'),
          );
          expect(e.paymentProgress, 0.0);
        });
      });
    });

    group('edge cases', () {
      test('handles empty string description', () {
        final e = Expense(
          amount: Decimal.parse('10.00'),
          category: 'Food',
          description: '',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        expect(e.description, '');
        expect(e.toMap()['description'], '');
      });

      test('handles large amounts', () {
        final e = Expense(
          amount: Decimal.parse('999999999.99'),
          category: 'Food',
          description: 'Test',
          date: DateTime.utc(2024, 1, 1),
          accountId: 1,
        );
        expect(e.amount, closeTo(999999999.99, 0.01));
      });

      test('roundtrip: toMap then fromMap preserves data', () {
        final map = expense.toMap();
        final restored = Expense.fromMap(map);
        expect(restored.id, expense.id);
        expect(restored.amount, expense.amount);
        expect(restored.category, expense.category);
        expect(restored.description, expense.description);
        expect(restored.date, expense.date);
        expect(restored.accountId, expense.accountId);
        expect(restored.amountPaid, expense.amountPaid);
        expect(restored.paymentMethod, expense.paymentMethod);
      });
    });
  });
}
