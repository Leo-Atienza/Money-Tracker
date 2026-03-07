import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:budget_tracker/models/quick_template_model.dart';

void main() {
  group('QuickTemplate', () {
    // -----------------------------------------------------------------------
    // Helper: build a fully-populated QuickTemplate
    // -----------------------------------------------------------------------
    QuickTemplate _makeTemplate({
      int? id = 1,
      String name = 'Coffee',
      double amount = 4.50,
      String category = 'Food',
      String paymentMethod = 'Credit Card',
      String type = 'expense',
      int accountId = 1,
      int sortOrder = 3,
    }) {
      return QuickTemplate(
        id: id,
        name: name,
        amount: Decimal.parse(amount.toStringAsFixed(2)),
        category: category,
        paymentMethod: paymentMethod,
        type: type,
        accountId: accountId,
        sortOrder: sortOrder,
      );
    }

    // -----------------------------------------------------------------------
    // Constructor & getters
    // -----------------------------------------------------------------------
    group('constructor and getters', () {
      test('stores all required and optional fields', () {
        final t = _makeTemplate();

        expect(t.id, 1);
        expect(t.name, 'Coffee');
        expect(t.amount, 4.50);
        expect(t.amountDecimal, Decimal.parse('4.50'));
        expect(t.category, 'Food');
        expect(t.paymentMethod, 'Credit Card');
        expect(t.type, 'expense');
        expect(t.accountId, 1);
        expect(t.sortOrder, 3);
      });

      test('defaults paymentMethod to Cash', () {
        final t = QuickTemplate(
          name: 'Test',
          amount: Decimal.parse('10.00'),
          category: 'Other',
          accountId: 1,
        );
        expect(t.paymentMethod, 'Cash');
      });

      test('defaults type to expense', () {
        final t = QuickTemplate(
          name: 'Test',
          amount: Decimal.parse('10.00'),
          category: 'Other',
          accountId: 1,
        );
        expect(t.type, 'expense');
      });

      test('defaults sortOrder to 0', () {
        final t = QuickTemplate(
          name: 'Test',
          amount: Decimal.parse('10.00'),
          category: 'Other',
          accountId: 1,
        );
        expect(t.sortOrder, 0);
      });

      test('id defaults to null', () {
        final t = QuickTemplate(
          name: 'Test',
          amount: Decimal.parse('10.00'),
          category: 'Other',
          accountId: 1,
        );
        expect(t.id, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------
    group('toMap()', () {
      test('serializes all fields correctly', () {
        final t = _makeTemplate();
        final map = t.toMap();

        expect(map['id'], 1);
        expect(map['name'], 'Coffee');
        expect(map['amount'], closeTo(4.50, 0.001));
        expect(map['category'], 'Food');
        expect(map['paymentMethod'], 'Credit Card');
        expect(map['type'], 'expense');
        expect(map['account_id'], 1);
        expect(map['sortOrder'], 3);
      });

      test('serializes null id', () {
        final t = _makeTemplate(id: null);
        expect(t.toMap()['id'], isNull);
      });

      test('serializes income type', () {
        final t = _makeTemplate(type: 'income');
        expect(t.toMap()['type'], 'income');
      });

      test('serializes zero amount', () {
        final t = _makeTemplate(amount: 0.0);
        expect(t.toMap()['amount'], 0.0);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() - happy path
    // -----------------------------------------------------------------------
    group('fromMap() deserialization', () {
      test('deserializes all fields from a complete map', () {
        final map = {
          'id': 5,
          'name': 'Lunch',
          'amount': 12.99,
          'category': 'Food',
          'paymentMethod': 'Debit Card',
          'type': 'expense',
          'account_id': 2,
          'sortOrder': 7,
        };

        final t = QuickTemplate.fromMap(map);

        expect(t.id, 5);
        expect(t.name, 'Lunch');
        expect(t.amount, closeTo(12.99, 0.001));
        expect(t.category, 'Food');
        expect(t.paymentMethod, 'Debit Card');
        expect(t.type, 'expense');
        expect(t.accountId, 2);
        expect(t.sortOrder, 7);
      });

      test('defaults paymentMethod to Cash when missing', () {
        final map = {
          'name': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'account_id': 1,
        };
        final t = QuickTemplate.fromMap(map);
        expect(t.paymentMethod, 'Cash');
      });

      test('defaults type to expense when missing', () {
        final map = {
          'name': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'account_id': 1,
        };
        final t = QuickTemplate.fromMap(map);
        expect(t.type, 'expense');
      });

      test('defaults sortOrder to 0 when missing', () {
        final map = {
          'name': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'account_id': 1,
        };
        final t = QuickTemplate.fromMap(map);
        expect(t.sortOrder, 0);
      });

      test('handles null amount as zero', () {
        final map = {
          'name': 'Test',
          'amount': null,
          'category': 'Other',
          'account_id': 1,
        };
        final t = QuickTemplate.fromMap(map);
        expect(t.amount, 0.0);
      });

      test('handles integer amount (num conversion)', () {
        final map = {
          'name': 'Test',
          'amount': 25,
          'category': 'Other',
          'account_id': 1,
        };
        final t = QuickTemplate.fromMap(map);
        expect(t.amount, closeTo(25.0, 0.001));
      });

      test('id can be null in map', () {
        final map = {
          'id': null,
          'name': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'account_id': 1,
        };
        final t = QuickTemplate.fromMap(map);
        expect(t.id, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() validation - ArgumentError
    // -----------------------------------------------------------------------
    group('fromMap() validation', () {
      test('throws ArgumentError when name is null', () {
        final map = {
          'name': null,
          'amount': 10.0,
          'category': 'Other',
          'account_id': 1,
        };
        expect(
          () => QuickTemplate.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when name is empty string', () {
        final map = {
          'name': '',
          'amount': 10.0,
          'category': 'Other',
          'account_id': 1,
        };
        expect(
          () => QuickTemplate.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when name key is missing', () {
        final map = {
          'amount': 10.0,
          'category': 'Other',
          'account_id': 1,
        };
        expect(
          () => QuickTemplate.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when category is null', () {
        final map = {
          'name': 'Test',
          'amount': 10.0,
          'category': null,
          'account_id': 1,
        };
        expect(
          () => QuickTemplate.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when category is empty string', () {
        final map = {
          'name': 'Test',
          'amount': 10.0,
          'category': '',
          'account_id': 1,
        };
        expect(
          () => QuickTemplate.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when category key is missing', () {
        final map = {
          'name': 'Test',
          'amount': 10.0,
          'account_id': 1,
        };
        expect(
          () => QuickTemplate.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when account_id is null', () {
        final map = {
          'name': 'Test',
          'amount': 10.0,
          'category': 'Other',
          'account_id': null,
        };
        expect(
          () => QuickTemplate.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when account_id key is missing', () {
        final map = {
          'name': 'Test',
          'amount': 10.0,
          'category': 'Other',
        };
        expect(
          () => QuickTemplate.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // -----------------------------------------------------------------------
    // copyWith()
    // -----------------------------------------------------------------------
    group('copyWith()', () {
      test('overrides id', () {
        final original = _makeTemplate();
        final copy = original.copyWith(id: 99);
        expect(copy.id, 99);
        expect(copy.name, original.name);
      });

      test('overrides name', () {
        final original = _makeTemplate();
        final copy = original.copyWith(name: 'Tea');
        expect(copy.name, 'Tea');
        expect(copy.id, original.id);
      });

      test('overrides amount', () {
        final original = _makeTemplate();
        final copy = original.copyWith(amount: 9.99);
        expect(copy.amount, closeTo(9.99, 0.001));
        expect(copy.name, original.name);
      });

      test('overrides category', () {
        final original = _makeTemplate();
        final copy = original.copyWith(category: 'Drinks');
        expect(copy.category, 'Drinks');
      });

      test('overrides paymentMethod', () {
        final original = _makeTemplate();
        final copy = original.copyWith(paymentMethod: 'Cash');
        expect(copy.paymentMethod, 'Cash');
      });

      test('overrides type', () {
        final original = _makeTemplate();
        final copy = original.copyWith(type: 'income');
        expect(copy.type, 'income');
      });

      test('overrides accountId', () {
        final original = _makeTemplate();
        final copy = original.copyWith(accountId: 42);
        expect(copy.accountId, 42);
      });

      test('overrides sortOrder', () {
        final original = _makeTemplate();
        final copy = original.copyWith(sortOrder: 10);
        expect(copy.sortOrder, 10);
      });

      test('preserves all fields when nothing overridden', () {
        final original = _makeTemplate();
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.amount, original.amount);
        expect(copy.category, original.category);
        expect(copy.paymentMethod, original.paymentMethod);
        expect(copy.type, original.type);
        expect(copy.accountId, original.accountId);
        expect(copy.sortOrder, original.sortOrder);
      });
    });

    // -----------------------------------------------------------------------
    // copyWithDecimal()
    // -----------------------------------------------------------------------
    group('copyWithDecimal()', () {
      test('overrides amount with Decimal value', () {
        final original = _makeTemplate();
        final copy = original.copyWithDecimal(
          amount: Decimal.parse('19.99'),
        );
        expect(copy.amount, closeTo(19.99, 0.001));
        expect(copy.amountDecimal, Decimal.parse('19.99'));
      });

      test('preserves all fields when nothing overridden', () {
        final original = _makeTemplate();
        final copy = original.copyWithDecimal();

        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.amountDecimal, original.amountDecimal);
        expect(copy.category, original.category);
        expect(copy.paymentMethod, original.paymentMethod);
        expect(copy.type, original.type);
        expect(copy.accountId, original.accountId);
        expect(copy.sortOrder, original.sortOrder);
      });
    });

    // -----------------------------------------------------------------------
    // Round-trip: toMap -> fromMap
    // -----------------------------------------------------------------------
    group('round-trip serialization', () {
      test('toMap then fromMap preserves all values', () {
        final original = _makeTemplate();
        final map = original.toMap();
        final restored = QuickTemplate.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.amount, closeTo(original.amount, 0.001));
        expect(restored.category, original.category);
        expect(restored.paymentMethod, original.paymentMethod);
        expect(restored.type, original.type);
        expect(restored.accountId, original.accountId);
        expect(restored.sortOrder, original.sortOrder);
      });
    });
  });
}
