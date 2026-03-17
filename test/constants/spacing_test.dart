import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/constants/spacing.dart';

void main() {
  group('Spacing', () {
    group('base spacing values', () {
      test('base equals 8.0', () {
        expect(Spacing.base, 8.0);
      });

      test('tiny equals 2.0', () {
        expect(Spacing.tiny, 2.0);
      });

      test('xxs equals 4.0', () {
        expect(Spacing.xxs, 4.0);
      });

      test('xs equals 8.0', () {
        expect(Spacing.xs, 8.0);
      });

      test('sm equals 12.0', () {
        expect(Spacing.sm, 12.0);
      });

      test('md equals 16.0', () {
        expect(Spacing.md, 16.0);
      });

      test('lg equals 20.0', () {
        expect(Spacing.lg, 20.0);
      });

      test('xl equals 24.0', () {
        expect(Spacing.xl, 24.0);
      });

      test('xxl equals 32.0', () {
        expect(Spacing.xxl, 32.0);
      });

      test('xxxl equals 40.0', () {
        expect(Spacing.xxxl, 40.0);
      });

      test('huge equals 48.0', () {
        expect(Spacing.huge, 48.0);
      });
    });

    group('screen and card padding', () {
      test('screenPadding equals 24.0', () {
        expect(Spacing.screenPadding, 24.0);
      });

      test('cardPadding equals 20.0', () {
        expect(Spacing.cardPadding, 20.0);
      });
    });

    group('icon sizes', () {
      test('iconSize equals 20.0', () {
        expect(Spacing.iconSize, 20.0);
      });

      test('iconSizeLarge equals 24.0', () {
        expect(Spacing.iconSizeLarge, 24.0);
      });

      test('iconSizeHuge equals 64.0', () {
        expect(Spacing.iconSizeHuge, 64.0);
      });
    });

    group('touch target', () {
      test('minTouchTarget equals 48.0', () {
        expect(Spacing.minTouchTarget, 48.0);
      });
    });

    group('border radius', () {
      test('radiusSmall equals 8.0', () {
        expect(Spacing.radiusSmall, 8.0);
      });

      test('radiusMedium equals 12.0', () {
        expect(Spacing.radiusMedium, 12.0);
      });

      test('radiusLarge equals 16.0', () {
        expect(Spacing.radiusLarge, 16.0);
      });

      test('radiusXLarge equals 20.0', () {
        expect(Spacing.radiusXLarge, 20.0);
      });
    });

    group('other constants', () {
      test('dividerThickness equals 1.0', () {
        expect(Spacing.dividerThickness, 1.0);
      });

      test('progressBarHeight equals 8.0', () {
        expect(Spacing.progressBarHeight, 8.0);
      });

      test('progressBarHeightSmall equals 4.0', () {
        expect(Spacing.progressBarHeightSmall, 4.0);
      });
    });

    group('base unit relationships', () {
      test('xs equals base', () {
        expect(Spacing.xs, Spacing.base);
      });

      test('md equals base * 2', () {
        expect(Spacing.md, Spacing.base * 2);
      });

      test('xxl equals base * 4', () {
        expect(Spacing.xxl, Spacing.base * 4);
      });
    });

    group('WCAG compliance', () {
      test('minTouchTarget meets WCAG AA minimum of 48dp', () {
        expect(Spacing.minTouchTarget, greaterThanOrEqualTo(48.0));
      });
    });
  });
}
