import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:budget_tracker/utils/category_icons.dart';

void main() {
  group('CategoryIcons', () {
    group('defaultExpenseIcons', () {
      test('has entries for all expected expense categories', () {
        const expected = [
          'Food',
          'Transport',
          'Shopping',
          'Entertainment',
          'Health',
          'Education',
          'Bills',
          'Other',
        ];
        for (final category in expected) {
          expect(
            CategoryIcons.defaultExpenseIcons.containsKey(category),
            isTrue,
            reason: 'Missing expense category: $category',
          );
        }
      });
    });

    group('defaultIncomeIcons', () {
      test('has entries for all expected income categories', () {
        const expected = ['Salary', 'Freelance', 'Investment', 'Gift', 'Other'];
        for (final category in expected) {
          expect(
            CategoryIcons.defaultIncomeIcons.containsKey(category),
            isTrue,
            reason: 'Missing income category: $category',
          );
        }
      });
    });

    group('availableIcons', () {
      test('is non-empty', () {
        expect(CategoryIcons.availableIcons, isNotEmpty);
      });

      test('contains all default expense icons', () {
        for (final icon in CategoryIcons.defaultExpenseIcons.values) {
          expect(
            CategoryIcons.availableIcons.contains(icon),
            isTrue,
            reason: 'availableIcons missing expense icon: ${icon.codePoint}',
          );
        }
      });

      test('contains all default income icons', () {
        for (final icon in CategoryIcons.defaultIncomeIcons.values) {
          expect(
            CategoryIcons.availableIcons.contains(icon),
            isTrue,
            reason: 'availableIcons missing income icon: ${icon.codePoint}',
          );
        }
      });
    });

    group('iconToString', () {
      test('returns the codePoint as a string', () {
        const icon = Icons.restaurant_rounded;
        final result = CategoryIcons.iconToString(icon);
        expect(result, icon.codePoint.toString());
      });
    });

    group('iconFromString', () {
      test('null returns fallback Icons.category_rounded', () {
        expect(CategoryIcons.iconFromString(null), Icons.category_rounded);
      });

      test('empty string returns fallback Icons.category_rounded', () {
        expect(CategoryIcons.iconFromString(''), Icons.category_rounded);
      });

      test('invalid string returns fallback Icons.category_rounded', () {
        expect(CategoryIcons.iconFromString('invalid'), Icons.category_rounded);
      });

      test('valid codePoint roundtrips correctly', () {
        const original = Icons.restaurant_rounded;
        final asString = CategoryIcons.iconToString(original);
        final restored = CategoryIcons.iconFromString(asString);
        expect(restored, original);
      });
    });

    group('getDefaultIcon', () {
      test('Food expense returns Icons.restaurant_rounded', () {
        expect(
          CategoryIcons.getDefaultIcon('Food', 'expense'),
          Icons.restaurant_rounded,
        );
      });

      test('Salary income returns Icons.account_balance_wallet_rounded', () {
        expect(
          CategoryIcons.getDefaultIcon('Salary', 'income'),
          Icons.account_balance_wallet_rounded,
        );
      });

      test('Unknown expense returns fallback Icons.category_rounded', () {
        expect(
          CategoryIcons.getDefaultIcon('Unknown', 'expense'),
          Icons.category_rounded,
        );
      });
    });

    group('getIcon', () {
      test('null iconStr falls back to default for category', () {
        final icon = CategoryIcons.getIcon(null, 'Food', 'expense');
        expect(icon, Icons.restaurant_rounded);
      });

      test('empty iconStr falls back to default for category', () {
        final icon = CategoryIcons.getIcon('', 'Food', 'expense');
        expect(icon, Icons.restaurant_rounded);
      });

      test('valid iconStr returns the custom icon', () {
        final customIconStr =
            CategoryIcons.iconToString(Icons.savings_rounded);
        final icon = CategoryIcons.getIcon(customIconStr, 'Food', 'expense');
        expect(icon, Icons.savings_rounded);
      });
    });
  });
}
