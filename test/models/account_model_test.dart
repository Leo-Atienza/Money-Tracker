import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/account_model.dart';

void main() {
  group('Account', () {
    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    group('constructor', () {
      test('creates account with all fields', () {
        final account = Account(
          id: 1,
          name: 'Main',
          icon: '0xe001',
          color: '#FF0000',
          isDefault: true,
          currencyCode: 'EUR',
        );
        expect(account.id, 1);
        expect(account.name, 'Main');
        expect(account.icon, '0xe001');
        expect(account.color, '#FF0000');
        expect(account.isDefault, true);
        expect(account.currencyCode, 'EUR');
      });

      test('id defaults to null', () {
        final account = Account(name: 'Test');
        expect(account.id, isNull);
      });

      test('icon defaults to null', () {
        final account = Account(name: 'Test');
        expect(account.icon, isNull);
      });

      test('color defaults to null', () {
        final account = Account(name: 'Test');
        expect(account.color, isNull);
      });

      test('isDefault defaults to false', () {
        final account = Account(name: 'Test');
        expect(account.isDefault, false);
      });

      test('currencyCode defaults to USD', () {
        final account = Account(name: 'Test');
        expect(account.currencyCode, 'USD');
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------
    group('toMap()', () {
      test('serializes all fields correctly', () {
        final account = Account(
          id: 5,
          name: 'Savings',
          icon: '0xe555',
          color: '#00AAFF',
          isDefault: true,
          currencyCode: 'GBP',
        );
        final map = account.toMap();

        expect(map['id'], 5);
        expect(map['name'], 'Savings');
        expect(map['icon'], '0xe555');
        expect(map['color'], '#00AAFF');
        expect(map['isDefault'], 1);
        expect(map['currencyCode'], 'GBP');
      });

      test('serializes isDefault=false as 0', () {
        final account = Account(name: 'Test', isDefault: false);
        expect(account.toMap()['isDefault'], 0);
      });

      test('serializes isDefault=true as 1', () {
        final account = Account(name: 'Test', isDefault: true);
        expect(account.toMap()['isDefault'], 1);
      });

      test('serializes null id', () {
        final account = Account(name: 'Test');
        expect(account.toMap()['id'], isNull);
      });

      test('serializes null icon', () {
        final account = Account(name: 'Test');
        expect(account.toMap()['icon'], isNull);
      });

      test('serializes null color', () {
        final account = Account(name: 'Test');
        expect(account.toMap()['color'], isNull);
      });

      test('serializes default currencyCode', () {
        final account = Account(name: 'Test');
        expect(account.toMap()['currencyCode'], 'USD');
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() - happy path
    // -----------------------------------------------------------------------
    group('fromMap()', () {
      test('deserializes all fields from complete map', () {
        final map = {
          'id': 3,
          'name': 'Business',
          'icon': '0xe333',
          'color': '#AABBCC',
          'isDefault': 1,
          'currencyCode': 'JPY',
        };
        final account = Account.fromMap(map);

        expect(account.id, 3);
        expect(account.name, 'Business');
        expect(account.icon, '0xe333');
        expect(account.color, '#AABBCC');
        expect(account.isDefault, true);
        expect(account.currencyCode, 'JPY');
      });

      test('isDefault=0 maps to false', () {
        final map = {
          'name': 'Test',
          'isDefault': 0,
        };
        final account = Account.fromMap(map);
        expect(account.isDefault, false);
      });

      test('isDefault missing maps to false', () {
        final map = {'name': 'Test'};
        final account = Account.fromMap(map);
        expect(account.isDefault, false);
      });

      test('currencyCode defaults to USD when missing', () {
        final map = {'name': 'Test'};
        final account = Account.fromMap(map);
        expect(account.currencyCode, 'USD');
      });

      test('currencyCode defaults to USD when null', () {
        final map = {
          'name': 'Test',
          'currencyCode': null,
        };
        final account = Account.fromMap(map);
        expect(account.currencyCode, 'USD');
      });

      test('handles null id', () {
        final map = {
          'id': null,
          'name': 'Test',
        };
        final account = Account.fromMap(map);
        expect(account.id, isNull);
      });

      test('handles missing id', () {
        final map = {'name': 'Test'};
        final account = Account.fromMap(map);
        expect(account.id, isNull);
      });

      test('handles null icon and color', () {
        final map = {
          'name': 'Test',
          'icon': null,
          'color': null,
        };
        final account = Account.fromMap(map);
        expect(account.icon, isNull);
        expect(account.color, isNull);
      });

      test('accepts various currency codes', () {
        for (final code in ['USD', 'EUR', 'GBP', 'JPY', 'INR', 'BRL']) {
          final account = Account.fromMap({
            'name': 'Test',
            'currencyCode': code,
          });
          expect(account.currencyCode, code);
        }
      });
    });

    // -----------------------------------------------------------------------
    // fromMap() - validation errors
    // -----------------------------------------------------------------------
    group('fromMap() validation', () {
      test('throws ArgumentError when name is null', () {
        final map = {'name': null};
        expect(
          () => Account.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when name is missing', () {
        final map = <String, dynamic>{};
        expect(
          () => Account.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when name is empty string', () {
        final map = {'name': ''};
        expect(
          () => Account.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('error message mentions name', () {
        try {
          Account.fromMap(<String, dynamic>{});
          fail('Should have thrown');
        } on ArgumentError catch (e) {
          expect(e.message, contains('name'));
        }
      });
    });

    // -----------------------------------------------------------------------
    // copyWith()
    // -----------------------------------------------------------------------
    group('copyWith()', () {
      late Account original;

      setUp(() {
        original = Account(
          id: 1,
          name: 'Main',
          icon: '0xe001',
          color: '#FF0000',
          isDefault: true,
          currencyCode: 'EUR',
        );
      });

      test('overrides id', () {
        final copy = original.copyWith(id: 99);
        expect(copy.id, 99);
        expect(copy.name, original.name);
      });

      test('overrides name', () {
        final copy = original.copyWith(name: 'Savings');
        expect(copy.name, 'Savings');
        expect(copy.id, original.id);
      });

      test('overrides icon', () {
        final copy = original.copyWith(icon: '0xe999');
        expect(copy.icon, '0xe999');
      });

      test('overrides color', () {
        final copy = original.copyWith(color: '#00FF00');
        expect(copy.color, '#00FF00');
      });

      test('overrides isDefault', () {
        final copy = original.copyWith(isDefault: false);
        expect(copy.isDefault, false);
      });

      test('overrides currencyCode', () {
        final copy = original.copyWith(currencyCode: 'JPY');
        expect(copy.currencyCode, 'JPY');
      });

      test('preserves all fields when no arguments provided', () {
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.icon, original.icon);
        expect(copy.color, original.color);
        expect(copy.isDefault, original.isDefault);
        expect(copy.currencyCode, original.currencyCode);
      });
    });

    // -----------------------------------------------------------------------
    // Round-trip serialization
    // -----------------------------------------------------------------------
    group('round-trip serialization', () {
      test('toMap then fromMap preserves all values', () {
        final original = Account(
          id: 7,
          name: 'Investment',
          icon: '0xeaaa',
          color: '#112233',
          isDefault: true,
          currencyCode: 'CHF',
        );
        final map = original.toMap();
        final restored = Account.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.icon, original.icon);
        expect(restored.color, original.color);
        expect(restored.isDefault, original.isDefault);
        expect(restored.currencyCode, original.currencyCode);
      });

      test('round-trip with null optional fields', () {
        final original = Account(
          name: 'Simple',
          isDefault: false,
        );
        final map = original.toMap();
        final restored = Account.fromMap(map);

        expect(restored.id, isNull);
        expect(restored.name, 'Simple');
        expect(restored.icon, isNull);
        expect(restored.color, isNull);
        expect(restored.isDefault, false);
        expect(restored.currencyCode, 'USD');
      });

      test('round-trip with non-USD currency', () {
        final original = Account(
          name: 'Euro Account',
          currencyCode: 'EUR',
        );
        final restored = Account.fromMap(original.toMap());
        expect(restored.currencyCode, 'EUR');
      });
    });
  });
}
