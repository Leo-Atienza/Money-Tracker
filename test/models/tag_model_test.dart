import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/models/tag_model.dart';

void main() {
  group('Tag', () {
    // -----------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------
    group('constructor', () {
      test('creates tag with all fields', () {
        final tag = Tag(
          id: 1,
          name: 'Groceries',
          color: '#FF5733',
          accountId: 2,
        );
        expect(tag.id, 1);
        expect(tag.name, 'Groceries');
        expect(tag.color, '#FF5733');
        expect(tag.accountId, 2);
      });

      test('id defaults to null', () {
        final tag = Tag(name: 'Test', accountId: 1);
        expect(tag.id, isNull);
      });

      test('color defaults to null', () {
        final tag = Tag(name: 'Test', accountId: 1);
        expect(tag.color, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // toMap()
    // -----------------------------------------------------------------------
    group('toMap()', () {
      test('serializes all fields correctly', () {
        final tag = Tag(
          id: 5,
          name: 'Vacation',
          color: '#00AAFF',
          accountId: 3,
        );
        final map = tag.toMap();

        expect(map['id'], 5);
        expect(map['name'], 'Vacation');
        expect(map['color'], '#00AAFF');
        expect(map['account_id'], 3);
      });

      test('serializes null id', () {
        final tag = Tag(name: 'Test', accountId: 1);
        expect(tag.toMap()['id'], isNull);
      });

      test('serializes null color', () {
        final tag = Tag(name: 'Test', accountId: 1);
        expect(tag.toMap()['color'], isNull);
      });

      test('uses account_id key (snake_case)', () {
        final tag = Tag(name: 'Test', accountId: 7);
        final map = tag.toMap();
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
          'name': 'Bills',
          'color': '#AABB00',
          'account_id': 2,
        };
        final tag = Tag.fromMap(map);

        expect(tag.id, 10);
        expect(tag.name, 'Bills');
        expect(tag.color, '#AABB00');
        expect(tag.accountId, 2);
      });

      test('handles null id', () {
        final map = {
          'id': null,
          'name': 'Test',
          'account_id': 1,
        };
        final tag = Tag.fromMap(map);
        expect(tag.id, isNull);
      });

      test('handles missing id', () {
        final map = {
          'name': 'Test',
          'account_id': 1,
        };
        final tag = Tag.fromMap(map);
        expect(tag.id, isNull);
      });

      test('handles null color', () {
        final map = {
          'name': 'Test',
          'color': null,
          'account_id': 1,
        };
        final tag = Tag.fromMap(map);
        expect(tag.color, isNull);
      });

      test('handles missing color', () {
        final map = {
          'name': 'Test',
          'account_id': 1,
        };
        final tag = Tag.fromMap(map);
        expect(tag.color, isNull);
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
          () => Tag.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when name is missing', () {
        final map = {
          'account_id': 1,
        };
        expect(
          () => Tag.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when name is empty string', () {
        final map = {
          'name': '',
          'account_id': 1,
        };
        expect(
          () => Tag.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when account_id is null', () {
        final map = {
          'name': 'Test',
          'account_id': null,
        };
        expect(
          () => Tag.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws ArgumentError when account_id is missing', () {
        final map = {
          'name': 'Test',
        };
        expect(
          () => Tag.fromMap(map),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('error message mentions name for missing name', () {
        try {
          Tag.fromMap({'account_id': 1});
          fail('Should have thrown');
        } on ArgumentError catch (e) {
          expect(e.message, contains('name'));
        }
      });

      test('error message mentions account_id for missing account_id', () {
        try {
          Tag.fromMap({'name': 'Test'});
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
      late Tag original;

      setUp(() {
        original = Tag(
          id: 1,
          name: 'Shopping',
          color: '#FF0000',
          accountId: 2,
        );
      });

      test('overrides id', () {
        final copy = original.copyWith(id: 99);
        expect(copy.id, 99);
        expect(copy.name, original.name);
      });

      test('overrides name', () {
        final copy = original.copyWith(name: 'Travel');
        expect(copy.name, 'Travel');
        expect(copy.id, original.id);
      });

      test('overrides color', () {
        final copy = original.copyWith(color: '#00FF00');
        expect(copy.color, '#00FF00');
      });

      test('overrides accountId', () {
        final copy = original.copyWith(accountId: 50);
        expect(copy.accountId, 50);
      });

      test('preserves all fields when no arguments provided', () {
        final copy = original.copyWith();
        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.color, original.color);
        expect(copy.accountId, original.accountId);
      });
    });

    // -----------------------------------------------------------------------
    // Round-trip serialization
    // -----------------------------------------------------------------------
    group('round-trip serialization', () {
      test('toMap then fromMap preserves all values', () {
        final original = Tag(
          id: 3,
          name: 'Emergency',
          color: '#123456',
          accountId: 5,
        );
        final map = original.toMap();
        final restored = Tag.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.color, original.color);
        expect(restored.accountId, original.accountId);
      });

      test('round-trip with null optional fields', () {
        final original = Tag(
          name: 'Simple',
          accountId: 1,
        );
        final map = original.toMap();
        final restored = Tag.fromMap(map);

        expect(restored.id, isNull);
        expect(restored.name, 'Simple');
        expect(restored.color, isNull);
        expect(restored.accountId, 1);
      });
    });
  });
}
