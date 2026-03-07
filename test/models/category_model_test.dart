import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/category_model.dart';

void main() {
  group('Category', () {
    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    group('constructor', () {
      test('creates category with all fields', () {
        final cat = Category(
          id: 1,
          name: 'Food',
          accountId: 2,
          isDefault: true,
          type: 'expense',
          color: '#FF5733',
          icon: '0xe25a',
        );
        expect(cat.id, 1);
        expect(cat.name, 'Food');
        expect(cat.accountId, 2);
        expect(cat.isDefault, true);
        expect(cat.type, 'expense');
        expect(cat.color, '#FF5733');
        expect(cat.icon, '0xe25a');
      });

      test('id defaults to null', () {
        final cat = Category(name: 'Food', accountId: 1);
        expect(cat.id, isNull);
      });

      test('isDefault defaults to false', () {
        final cat = Category(name: 'Food', accountId: 1);
        expect(cat.isDefault, false);
      });

      test('type defaults to expense', () {
        final cat = Category(name: 'Food', accountId: 1);
        expect(cat.type, 'expense');
      });

      test('color defaults to null', () {
        final cat = Category(name: 'Food', accountId: 1);
        expect(cat.color, isNull);
      });

      test('icon defaults to null', () {
        final cat = Category(name: 'Food', accountId: 1);
        expect(cat.icon, isNull);
      });

      test('accepts income type', () {
        final cat = Category(name: 'Salary', accountId: 1, type: 'income');
        expect(cat.type, 'income');
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------
    group('toMap()', () {
      test('serializes all fields correctly', () {
        final cat = Category(
          id: 5,
          name: 'Transport',
          accountId: 3,
          isDefault: true,
          type: 'expense',
          color: '#00FF00',
          icon: '0xe1d5',
        );
        final map = cat.toMap();

        expect(map['id'], 5);
        expect(map['name'], 'Transport');
        expect(map['account_id'], 3);
        expect(map['isDefault'], 1); // true -> 1
        expect(map['type'], 'expense');
        expect(map['color'], '#00FF00');
        expect(map['icon'], '0xe1d5');
      });

      test('serializes isDefault=false as 0', () {
        final cat = Category(name: 'Food', accountId: 1, isDefault: false);
        expect(cat.toMap()['isDefault'], 0);
      });

      test('serializes isDefault=true as 1', () {
        final cat = Category(name: 'Food', accountId: 1, isDefault: true);
        expect(cat.toMap()['isDefault'], 1);
      });

      test('serializes null id', () {
        final cat = Category(name: 'Food', accountId: 1);
        expect(cat.toMap()['id'], isNull);
      });

      test('serializes null color', () {
        final cat = Category(name: 'Food', accountId: 1);
        expect(cat.toMap()['color'], isNull);
      });

      test('serializes null icon', () {
        final cat = Category(name: 'Food', accountId: 1);
        expect(cat.toMap()['icon'], isNull);
      });

      test('uses account_id key (snake_case)', () {
        final cat = Category(name: 'Food', accountId: 7);
        final map = cat.toMap();
        expect(map.containsKey('account_id'), isTrue);
        expect(map['account_id'], 7);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() - happy path
    // -----------------------------------------------------------------------
    group('fromMap()', () {
      test('deserializes all fields from complete map', () {
        final map = {
          'id': 10,
          'name': 'Groceries',
          'account_id': 2,
          'isDefault': 1,
          'type': 'expense',
          'color': '#AABB00',
          'icon': '0xe123',
        };
        final cat = Category.fromMap(map);

        expect(cat.id, 10);
        expect(cat.name, 'Groceries');
        expect(cat.accountId, 2);
        expect(cat.isDefault, true);
        expect(cat.type, 'expense');
        expect(cat.color, '#AABB00');
        expect(cat.icon, '0xe123');
      });

      test('isDefault=0 maps to false', () {
        final map = {
          'name': 'Food',
          'account_id': 1,
          'isDefault': 0,
        };
        final cat = Category.fromMap(map);
        expect(cat.isDefault, false);
      });

      test('isDefault missing maps to false', () {
        final map = {
          'name': 'Food',
          'account_id': 1,
        };
        final cat = Category.fromMap(map);
        expect(cat.isDefault, false);
      });

      test('type defaults to expense when missing', () {
        final map = {
          'name': 'Food',
          'account_id': 1,
        };
        final cat = Category.fromMap(map);
        expect(cat.type, 'expense');
      });

      test('type defaults to expense when null', () {
        final map = {
          'name': 'Food',
          'account_id': 1,
          'type': null,
        };
        final cat = Category.fromMap(map);
        expect(cat.type, 'expense');
      });

      test('handles income type', () {
        final map = {
          'name': 'Salary',
          'account_id': 1,
          'type': 'income',
        };
        final cat = Category.fromMap(map);
        expect(cat.type, 'income');
      });

      test('handles null id', () {
        final map = {
          'id': null,
          'name': 'Food',
          'account_id': 1,
        };
        final cat = Category.fromMap(map);
        expect(cat.id, isNull);
      });

      test('handles missing id', () {
        final map = {
          'name': 'Food',
          'account_id': 1,
        };
        final cat = Category.fromMap(map);
        expect(cat.id, isNull);
      });

      test('handles null color and icon', () {
        final map = {
          'name': 'Food',
          'account_id': 1,
          'color': null,
          'icon': null,
        };
        final cat = Category.fromMap(map);
        expect(cat.color, isNull);
        expect(cat.icon, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() - validation errors
    // -----------------------------------------------------------------------
    group('fromMap() validation', () {
      test('throws ArgumentError when name is null', () {
        final map = {
          'name': null,
          'account_id': 1,
        };
        expect(
          () => Category.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when name is missing', () {
        final map = {
          'account_id': 1,
        };
        expect(
          () => Category.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when name is empty string', () {
        final map = {
          'name': '',
          'account_id': 1,
        };
        expect(
          () => Category.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when account_id is null', () {
        final map = {
          'name': 'Food',
          'account_id': null,
        };
        expect(
          () => Category.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when account_id is missing', () {
        final map = {
          'name': 'Food',
        };
        expect(
          () => Category.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('error message mentions name for missing name', () {
        try {
          Category.fromMap({'account_id': 1});
          fail('Should have thrown');
        } on ArgumentError catch (e) {
          expect(e.message, contains('name'));
        }
      });

      test('error message mentions account_id for missing account_id', () {
        try {
          Category.fromMap({'name': 'Food'});
          fail('Should have thrown');
        } on ArgumentError catch (e) {
          expect(e.message, contains('account_id'));
        }
      });
    });

    // -----------------------------------------------------------------------
    // copyWith()
    // -----------------------------------------------------------------------
    group('copyWith()', () {
      late Category original;

      setUp(() {
        original = Category(
          id: 1,
          name: 'Food',
          accountId: 2,
          isDefault: false,
          type: 'expense',
          color: '#FF0000',
          icon: '0xe001',
        );
      });

      test('overrides id', () {
        final copy = original.copyWith(id: 99);
        expect(copy.id, 99);
        expect(copy.name, original.name);
      });

      test('overrides name', () {
        final copy = original.copyWith(name: 'Transport');
        expect(copy.name, 'Transport');
        expect(copy.id, original.id);
      });

      test('overrides accountId', () {
        final copy = original.copyWith(accountId: 50);
        expect(copy.accountId, 50);
      });

      test('overrides isDefault', () {
        final copy = original.copyWith(isDefault: true);
        expect(copy.isDefault, true);
      });

      test('overrides type', () {
        final copy = original.copyWith(type: 'income');
        expect(copy.type, 'income');
      });

      test('overrides color', () {
        final copy = original.copyWith(color: '#00FF00');
        expect(copy.color, '#00FF00');
      });

      test('overrides icon', () {
        final copy = original.copyWith(icon: '0xe999');
        expect(copy.icon, '0xe999');
      });

      test('preserves all fields when no arguments provided', () {
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.accountId, original.accountId);
        expect(copy.isDefault, original.isDefault);
        expect(copy.type, original.type);
        expect(copy.color, original.color);
        expect(copy.icon, original.icon);
      });
    });

    // -----------------------------------------------------------------------
    // Round-trip serialization
    // -----------------------------------------------------------------------
    group('round-trip serialization', () {
      test('toMap then fromMap preserves all values', () {
        final original = Category(
          id: 3,
          name: 'Entertainment',
          accountId: 5,
          isDefault: true,
          type: 'expense',
          color: '#123456',
          icon: '0xeabc',
        );
        final map = original.toMap();
        final restored = Category.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.accountId, original.accountId);
        expect(restored.isDefault, original.isDefault);
        expect(restored.type, original.type);
        expect(restored.color, original.color);
        expect(restored.icon, original.icon);
      });

      test('round-trip with null optional fields', () {
        final original = Category(
          id: null,
          name: 'Bills',
          accountId: 1,
          isDefault: false,
          type: 'expense',
          color: null,
          icon: null,
        );
        final map = original.toMap();
        final restored = Category.fromMap(map);

        expect(restored.id, isNull);
        expect(restored.name, 'Bills');
        expect(restored.color, isNull);
        expect(restored.icon, isNull);
      });

      test('round-trip with income type', () {
        final original = Category(
          name: 'Freelance',
          accountId: 2,
          type: 'income',
        );
        final restored = Category.fromMap(original.toMap());
        expect(restored.type, 'income');
      });
    });
  });
}
