import 'package:budget_tracker/utils/color_contrast_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ColorContrastHelper', () {
    group('contrastRatio()', () {
      test('black and white have maximum contrast ratio of 21:1', () {
        final ratio = ColorContrastHelper.contrastRatio(
          Colors.black,
          Colors.white,
        );
        // WCAG spec: pure black/white = 21:1
        expect(ratio, closeTo(21.0, 0.1));
      });

      test('white and black have the same ratio (order independent)', () {
        final ratio1 = ColorContrastHelper.contrastRatio(
          Colors.black,
          Colors.white,
        );
        final ratio2 = ColorContrastHelper.contrastRatio(
          Colors.white,
          Colors.black,
        );
        expect(ratio1, ratio2);
      });

      test('same color has contrast ratio of 1:1', () {
        final ratio = ColorContrastHelper.contrastRatio(
          Colors.red,
          Colors.red,
        );
        expect(ratio, closeTo(1.0, 0.01));
      });

      test('black against black is 1:1', () {
        final ratio = ColorContrastHelper.contrastRatio(
          Colors.black,
          Colors.black,
        );
        expect(ratio, closeTo(1.0, 0.01));
      });

      test('white against white is 1:1', () {
        final ratio = ColorContrastHelper.contrastRatio(
          Colors.white,
          Colors.white,
        );
        expect(ratio, closeTo(1.0, 0.01));
      });

      test('returns ratio >= 1 for any color pair', () {
        final colors = [
          Colors.red,
          Colors.blue,
          Colors.green,
          Colors.yellow,
          Colors.purple,
          Colors.orange,
          Colors.grey,
        ];

        for (final c1 in colors) {
          for (final c2 in colors) {
            final ratio = ColorContrastHelper.contrastRatio(c1, c2);
            expect(ratio, greaterThanOrEqualTo(1.0),
                reason: 'Contrast ratio must be >= 1');
          }
        }
      });

      test('known color pair: white on blue', () {
        // White (#FFFFFF) on blue (#0000FF) should have significant contrast
        final ratio = ColorContrastHelper.contrastRatio(
          Colors.white,
          const Color(0xFF0000FF),
        );
        // Blue is quite dark in luminance terms
        expect(ratio, greaterThan(4.0));
      });
    });

    group('meetsAA()', () {
      test('black on white meets AA (4.5:1 threshold)', () {
        expect(
          ColorContrastHelper.meetsAA(Colors.black, Colors.white),
          isTrue,
        );
      });

      test('white on black meets AA', () {
        expect(
          ColorContrastHelper.meetsAA(Colors.white, Colors.black),
          isTrue,
        );
      });

      test('same color does not meet AA', () {
        expect(
          ColorContrastHelper.meetsAA(Colors.grey, Colors.grey),
          isFalse,
        );
      });

      test('low contrast pair fails AA', () {
        // Light gray on white should fail
        expect(
          ColorContrastHelper.meetsAA(
            const Color(0xFFCCCCCC),
            Colors.white,
          ),
          isFalse,
        );
      });

      test('threshold is exactly 4.5', () {
        // Verify using the class constant
        expect(ColorContrastHelper.minContrastNormalText, 4.5);
      });
    });

    group('meetsAALarge()', () {
      test('black on white meets AA large (3:1 threshold)', () {
        expect(
          ColorContrastHelper.meetsAALarge(Colors.black, Colors.white),
          isTrue,
        );
      });

      test('threshold is exactly 3.0', () {
        expect(ColorContrastHelper.minContrastLargeText, 3.0);
      });

      test('pair that fails AA can still pass AA large', () {
        // Find a pair with contrast between 3.0 and 4.5
        // A medium-gray on white tends to have moderate contrast
        const mediumGray = Color(0xFF767676); // ~4.54:1 on white (borderline)
        const lightishGray = Color(0xFF949494); // lower contrast

        final ratio = ColorContrastHelper.contrastRatio(
          lightishGray,
          Colors.white,
        );

        if (ratio >= 3.0 && ratio < 4.5) {
          expect(
            ColorContrastHelper.meetsAALarge(lightishGray, Colors.white),
            isTrue,
          );
          expect(
            ColorContrastHelper.meetsAA(lightishGray, Colors.white),
            isFalse,
          );
        }
      });

      test('same color does not meet AA large', () {
        expect(
          ColorContrastHelper.meetsAALarge(Colors.red, Colors.red),
          isFalse,
        );
      });
    });

    group('getContrastingTextColor()', () {
      test('returns white for dark backgrounds', () {
        expect(
          ColorContrastHelper.getContrastingTextColor(Colors.black),
          Colors.white,
        );
      });

      test('returns white for very dark blue', () {
        expect(
          ColorContrastHelper.getContrastingTextColor(
            const Color(0xFF000033),
          ),
          Colors.white,
        );
      });

      test('returns black for light backgrounds', () {
        expect(
          ColorContrastHelper.getContrastingTextColor(Colors.white),
          Colors.black,
        );
      });

      test('returns black for yellow background', () {
        // Yellow is very light in luminance
        expect(
          ColorContrastHelper.getContrastingTextColor(Colors.yellow),
          Colors.black,
        );
      });

      test('always returns either black or white', () {
        final backgrounds = [
          Colors.red,
          Colors.blue,
          Colors.green,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.pink,
          Colors.amber,
          Colors.cyan,
          Colors.indigo,
        ];

        for (final bg in backgrounds) {
          final result = ColorContrastHelper.getContrastingTextColor(bg);
          expect(
            result == Colors.white || result == Colors.black,
            isTrue,
            reason: 'Expected black or white for background $bg',
          );
        }
      });
    });

    group('adjustForContrast()', () {
      test('returns the same color if it already meets target ratio', () {
        // Black on white already has 21:1 contrast
        final adjusted = ColorContrastHelper.adjustForContrast(
          Colors.black,
          Colors.white,
        );
        expect(adjusted, Colors.black);
      });

      test('adjusts low-contrast color to meet target on light background', () {
        // Light gray on white has poor contrast
        const lowContrast = Color(0xFFDDDDDD);
        final adjusted = ColorContrastHelper.adjustForContrast(
          lowContrast,
          Colors.white,
        );

        final newRatio = ColorContrastHelper.contrastRatio(
          adjusted,
          Colors.white,
        );
        expect(newRatio, greaterThanOrEqualTo(4.5));
      });

      test('adjusts low-contrast color to meet target on dark background', () {
        // Dark gray on black has poor contrast
        const lowContrast = Color(0xFF222222);
        final adjusted = ColorContrastHelper.adjustForContrast(
          lowContrast,
          Colors.black,
        );

        final newRatio = ColorContrastHelper.contrastRatio(
          adjusted,
          Colors.black,
        );
        expect(newRatio, greaterThanOrEqualTo(4.5));
      });

      test('respects custom target ratio', () {
        const lowContrast = Color(0xFFDDDDDD);
        final adjusted = ColorContrastHelper.adjustForContrast(
          lowContrast,
          Colors.white,
          targetRatio: 3.0,
        );

        final newRatio = ColorContrastHelper.contrastRatio(
          adjusted,
          Colors.white,
        );
        expect(newRatio, greaterThanOrEqualTo(3.0));
      });

      test('darkens color on light backgrounds', () {
        const lightColor = Color(0xFFCCCCCC);
        final adjusted = ColorContrastHelper.adjustForContrast(
          lightColor,
          Colors.white,
        );

        // The adjusted color should be darker (lower luminance) than original
        // when background is light
        final originalRed = (lightColor.r * 255.0).round();
        final adjustedRed = (adjusted.r * 255.0).round();
        expect(adjustedRed, lessThanOrEqualTo(originalRed));
      });

      test('lightens color on dark backgrounds', () {
        const darkColor = Color(0xFF333333);
        final adjusted = ColorContrastHelper.adjustForContrast(
          darkColor,
          Colors.black,
        );

        // The adjusted color should be lighter (higher channel values)
        final originalRed = (darkColor.r * 255.0).round();
        final adjustedRed = (adjusted.r * 255.0).round();
        expect(adjustedRed, greaterThanOrEqualTo(originalRed));
      });
    });

    group('relativeLuminance (via contrastRatio)', () {
      // relativeLuminance is private, but we can test its behavior
      // indirectly through contrastRatio using known luminance values

      test('black has luminance 0 (contrast with itself is 1)', () {
        // L_black = 0, contrast = (0+0.05)/(0+0.05) = 1
        final ratio = ColorContrastHelper.contrastRatio(
          Colors.black,
          Colors.black,
        );
        expect(ratio, closeTo(1.0, 0.01));
      });

      test('white has luminance 1 (contrast with itself is 1)', () {
        final ratio = ColorContrastHelper.contrastRatio(
          Colors.white,
          Colors.white,
        );
        expect(ratio, closeTo(1.0, 0.01));
      });

      test('luminance formula gives 21:1 for black/white', () {
        // L_white = 1, L_black = 0
        // contrast = (1 + 0.05) / (0 + 0.05) = 1.05 / 0.05 = 21.0
        final ratio = ColorContrastHelper.contrastRatio(
          Colors.white,
          Colors.black,
        );
        expect(ratio, closeTo(21.0, 0.1));
      });

      test('pure red has known luminance (~0.2126)', () {
        // Pure red (255,0,0): linear R = 1.0
        // luminance = 0.2126*1 + 0.7152*0 + 0.0722*0 = 0.2126
        // contrast with black = (0.2126+0.05)/(0+0.05) = 0.2626/0.05 = 5.252
        final ratio = ColorContrastHelper.contrastRatio(
          const Color(0xFFFF0000),
          Colors.black,
        );
        expect(ratio, closeTo(5.252, 0.1));
      });

      test('pure green has known luminance (~0.7152)', () {
        // Pure green (0,255,0): linear G = 1.0
        // luminance = 0.2126*0 + 0.7152*1 + 0.0722*0 = 0.7152
        // contrast with black = (0.7152+0.05)/(0+0.05) = 0.7652/0.05 = 15.304
        final ratio = ColorContrastHelper.contrastRatio(
          const Color(0xFF00FF00),
          Colors.black,
        );
        expect(ratio, closeTo(15.304, 0.1));
      });

      test('pure blue has known luminance (~0.0722)', () {
        // Pure blue (0,0,255): linear B = 1.0
        // luminance = 0.2126*0 + 0.7152*0 + 0.0722*1 = 0.0722
        // contrast with black = (0.0722+0.05)/(0+0.05) = 0.1222/0.05 = 2.444
        final ratio = ColorContrastHelper.contrastRatio(
          const Color(0xFF0000FF),
          Colors.black,
        );
        expect(ratio, closeTo(2.444, 0.1));
      });
    });

    group('getStatusColors()', () {
      test('returns status colors for dark brightness', () {
        final status = ColorContrastHelper.getStatusColors(Brightness.dark);
        expect(status.success, isNotNull);
        expect(status.warning, isNotNull);
        expect(status.error, isNotNull);
        expect(status.info, isNotNull);
      });

      test('returns status colors for light brightness', () {
        final status = ColorContrastHelper.getStatusColors(Brightness.light);
        expect(status.success, isNotNull);
        expect(status.warning, isNotNull);
        expect(status.error, isNotNull);
        expect(status.info, isNotNull);
      });

      test('dark and light status colors differ', () {
        final dark = ColorContrastHelper.getStatusColors(Brightness.dark);
        final light = ColorContrastHelper.getStatusColors(Brightness.light);
        // At least some colors should differ between themes
        expect(
          dark.success != light.success ||
              dark.warning != light.warning ||
              dark.error != light.error ||
              dark.info != light.info,
          isTrue,
        );
      });
    });
  });
}
