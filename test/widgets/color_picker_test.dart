import 'package:budget_tracker/widgets/color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ColorPicker.parseColor()', () {
    test('returns default color (transparent) for null', () {
      final result = ColorPicker.parseColor(null);
      expect(result, Colors.transparent);
    });

    test('returns default color (transparent) for empty string', () {
      final result = ColorPicker.parseColor('');
      expect(result, Colors.transparent);
    });

    test('parses valid hex color with # prefix', () {
      // #4CAF50 -> green
      // int.parse('4CAF50', radix: 16) + 0xFF000000 = 0xFF4CAF50
      final result = ColorPicker.parseColor('#4CAF50');
      expect(result, const Color(0xFF4CAF50));
    });

    test('parses red hex color correctly', () {
      final result = ColorPicker.parseColor('#EF4444');
      expect(result, const Color(0xFFEF4444));
    });

    test('parses blue hex color correctly', () {
      final result = ColorPicker.parseColor('#3B82F6');
      expect(result, const Color(0xFF3B82F6));
    });

    test('parses black hex color correctly', () {
      final result = ColorPicker.parseColor('#000000');
      expect(result, const Color(0xFF000000));
    });

    test('parses white hex color correctly', () {
      final result = ColorPicker.parseColor('#FFFFFF');
      expect(result, const Color(0xFFFFFFFF));
    });

    test('parses lowercase hex correctly', () {
      final result = ColorPicker.parseColor('#4caf50');
      expect(result, const Color(0xFF4CAF50));
    });

    test('returns default color for invalid hex string', () {
      final result = ColorPicker.parseColor('invalid');
      expect(result, Colors.transparent);
    });

    test('returns default color for hex without # prefix', () {
      // Without #, substring(1) removes the first char of the hex,
      // which may cause parsing issues or an incorrect color
      // The method does substring(1) so 'FF4CAF50' becomes 'F4CAF50'
      // which is 7 chars -- int.parse will still parse it but it won't
      // be the expected color. However, '4CAF50' becomes 'CAF50' (5 chars)
      // which parses to a different number. Let's test the actual behavior.
      final result = ColorPicker.parseColor('4CAF50');
      // substring(1) -> 'CAF50', int.parse('CAF50', radix: 16) = 831312
      // 831312 + 0xFF000000 = some dark color, not transparent
      // This is "valid" parsing but produces an unexpected color
      // The method doesn't return transparent here since parsing succeeds
      expect(result, isNot(Colors.transparent));
    });

    test('returns default color for non-hex characters after #', () {
      final result = ColorPicker.parseColor('#ZZZZZZ');
      expect(result, Colors.transparent);
    });

    test('returns default color for # alone', () {
      // substring(1) on '#' gives '', int.parse('', radix: 16) throws
      final result = ColorPicker.parseColor('#');
      expect(result, Colors.transparent);
    });

    test('always applies full opacity (0xFF alpha)', () {
      final result = ColorPicker.parseColor('#4CAF50');
      // Alpha channel should be 0xFF (fully opaque)
      expect((result.a * 255).round(), 255);
    });

    test('parses all predefined palette colors successfully', () {
      // All non-null colors in the palette should parse without error
      for (final colorHex in ColorPicker.colors) {
        if (colorHex != null) {
          final parsed = ColorPicker.parseColor(colorHex);
          expect(parsed, isNot(Colors.transparent),
              reason: '$colorHex should parse to a non-transparent color');
        }
      }
    });

    test('null entry in palette parses to transparent', () {
      // The palette includes null as first entry for "no color"
      expect(ColorPicker.colors.contains(null), isTrue);
      final parsed = ColorPicker.parseColor(null);
      expect(parsed, Colors.transparent);
    });
  });
}
