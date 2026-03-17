import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:budget_tracker/utils/accessibility_helper.dart';

void main() {
  group('AccessibilityHelper', () {
    group('minTouchTargetSize', () {
      test('constant equals 48.0', () {
        expect(AccessibilityHelper.minTouchTargetSize, 48.0);
      });
    });

    group('meetsMinimumTouchTarget', () {
      test('(48, 48) returns true', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(48, 48), isTrue);
      });

      test('(50, 50) returns true', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(50, 50), isTrue);
      });

      test('(47, 48) returns false - width too small', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(47, 48), isFalse);
      });

      test('(48, 47) returns false - height too small', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(48, 47), isFalse);
      });

      test('(0, 0) returns false', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(0, 0), isFalse);
      });

      test('(100, 100) returns true - large target', () {
        expect(AccessibilityHelper.meetsMinimumTouchTarget(100, 100), isTrue);
      });
    });

    group('getBudgetStatusLabel', () {
      test('100% shows Over budget', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(100, 'Food');
        expect(label, contains('Over budget'));
        expect(label, contains('100%'));
      });

      test('110% shows Over budget', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(110, 'Transport');
        expect(label, contains('Over budget'));
        expect(label, contains('110%'));
      });

      test('85% shows Approaching limit', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(85, 'Shopping');
        expect(label, contains('Approaching limit'));
        expect(label, contains('85%'));
      });

      test('90% shows Approaching limit', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(90, 'Bills');
        expect(label, contains('Approaching limit'));
        expect(label, contains('90%'));
      });

      test('50% shows Under budget', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(50, 'Health');
        expect(label, contains('Under budget'));
        expect(label, contains('50%'));
      });

      test('0% shows Under budget', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(0, 'Other');
        expect(label, contains('Under budget'));
        expect(label, contains('0%'));
      });

      test('84.9% shows Under budget (boundary)', () {
        final label = AccessibilityHelper.getBudgetStatusLabel(84.9, 'Food');
        expect(label, contains('Under budget'));
      });
    });

    group('getBudgetStatusIcon', () {
      test('>= 100 returns Icons.cancel', () {
        expect(AccessibilityHelper.getBudgetStatusIcon(100), Icons.cancel);
        expect(AccessibilityHelper.getBudgetStatusIcon(150), Icons.cancel);
      });

      test('>= 85 and < 100 returns Icons.warning', () {
        expect(AccessibilityHelper.getBudgetStatusIcon(85), Icons.warning);
        expect(AccessibilityHelper.getBudgetStatusIcon(99), Icons.warning);
      });

      test('< 85 returns Icons.check_circle', () {
        expect(AccessibilityHelper.getBudgetStatusIcon(0), Icons.check_circle);
        expect(AccessibilityHelper.getBudgetStatusIcon(50), Icons.check_circle);
        expect(AccessibilityHelper.getBudgetStatusIcon(84), Icons.check_circle);
      });
    });

    group('meetsContrastRequirement', () {
      test('black on white meets contrast requirement', () {
        expect(
          AccessibilityHelper.meetsContrastRequirement(Colors.black, Colors.white),
          isTrue,
        );
      });

      test('white on black meets contrast requirement', () {
        expect(
          AccessibilityHelper.meetsContrastRequirement(Colors.white, Colors.black),
          isTrue,
        );
      });

      test('very similar colors fail contrast requirement', () {
        const color1 = Color(0xFF808080);
        const color2 = Color(0xFF909090);
        expect(
          AccessibilityHelper.meetsContrastRequirement(color1, color2),
          isFalse,
        );
      });
    });

    group('getAccessibleTextColor', () {
      test('dark background returns white', () {
        expect(
          AccessibilityHelper.getAccessibleTextColor(Colors.black),
          Colors.white,
        );
      });

      test('light background returns black87', () {
        expect(
          AccessibilityHelper.getAccessibleTextColor(Colors.white),
          Colors.black87,
        );
      });
    });

    group('getPaymentProgressLabel', () {
      test('50 of 100 shows 50%', () {
        final label = AccessibilityHelper.getPaymentProgressLabel(50, 100);
        expect(label, contains('50%'));
      });

      test('0 of 100 shows 0%', () {
        final label = AccessibilityHelper.getPaymentProgressLabel(0, 100);
        expect(label, contains('0%'));
      });

      test('100 of 100 shows 100%', () {
        final label = AccessibilityHelper.getPaymentProgressLabel(100, 100);
        expect(label, contains('100%'));
      });

      test('0 of 0 handles division by zero and shows 0%', () {
        final label = AccessibilityHelper.getPaymentProgressLabel(0, 0);
        expect(label, contains('0%'));
      });
    });
  });
}
