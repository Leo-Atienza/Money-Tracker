import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/decimal_helper.dart';
import 'package:decimal/decimal.dart';

void main() {
  // ---------------------------------------------------------------------------
  // fromDouble()
  // ---------------------------------------------------------------------------
  group('fromDouble', () {
    test('converts positive integer', () {
      expect(DecimalHelper.fromDouble(42.0), Decimal.parse('42.00'));
    });

    test('converts negative value', () {
      expect(DecimalHelper.fromDouble(-15.5), Decimal.parse('-15.50'));
    });

    test('converts zero', () {
      expect(DecimalHelper.fromDouble(0.0), Decimal.zero);
    });

    test('rounds to 2 decimal places', () {
      // 1.999 should round to 2.00
      expect(DecimalHelper.fromDouble(1.999), Decimal.parse('2.00'));
    });

    test('keeps 2 decimal places for exact values', () {
      expect(DecimalHelper.fromDouble(12.34), Decimal.parse('12.34'));
    });

    test('handles very small positive value', () {
      // 0.001 rounds to 0.00
      expect(DecimalHelper.fromDouble(0.001), Decimal.parse('0.00'));
    });

    test('returns zero for positive infinity', () {
      expect(DecimalHelper.fromDouble(double.infinity), Decimal.zero);
    });

    test('returns zero for negative infinity', () {
      expect(DecimalHelper.fromDouble(double.negativeInfinity), Decimal.zero);
    });

    test('returns zero for NaN', () {
      expect(DecimalHelper.fromDouble(double.nan), Decimal.zero);
    });

    test('clamps very large positive number to max safe value', () {
      final result = DecimalHelper.fromDouble(9999999999.99);
      expect(result, Decimal.parse('999999999.99'));
    });

    test('clamps very large negative number to min safe value', () {
      final result = DecimalHelper.fromDouble(-9999999999.99);
      expect(result, Decimal.parse('-999999999.99'));
    });

    test('value at positive boundary stays the same', () {
      expect(
        DecimalHelper.fromDouble(999999999.99),
        Decimal.parse('999999999.99'),
      );
    });

    test('value at negative boundary stays the same', () {
      expect(
        DecimalHelper.fromDouble(-999999999.99),
        Decimal.parse('-999999999.99'),
      );
    });

    test('value just inside positive boundary is kept', () {
      expect(
        DecimalHelper.fromDouble(999999999.98),
        Decimal.parse('999999999.98'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // toDouble()
  // ---------------------------------------------------------------------------
  group('toDouble', () {
    test('converts positive Decimal to double', () {
      expect(DecimalHelper.toDouble(Decimal.parse('42.50')), 42.50);
    });

    test('converts negative Decimal to double', () {
      expect(DecimalHelper.toDouble(Decimal.parse('-10.25')), -10.25);
    });

    test('converts zero', () {
      expect(DecimalHelper.toDouble(Decimal.zero), 0.0);
    });

    test('clamps oversized Decimal to max safe value', () {
      final huge = Decimal.parse('99999999999');
      expect(DecimalHelper.toDouble(huge), 999999999.99);
    });

    test('clamps very negative Decimal to min safe value', () {
      final hugeNeg = Decimal.parse('-99999999999');
      expect(DecimalHelper.toDouble(hugeNeg), -999999999.99);
    });

    test('value at positive boundary returns boundary', () {
      expect(
        DecimalHelper.toDouble(Decimal.parse('999999999.99')),
        999999999.99,
      );
    });

    test('preserves two-decimal precision', () {
      expect(DecimalHelper.toDouble(Decimal.parse('0.01')), 0.01);
    });
  });

  // ---------------------------------------------------------------------------
  // parse()
  // ---------------------------------------------------------------------------
  group('parse', () {
    test('parses simple positive string', () {
      expect(DecimalHelper.parse('42.50'), Decimal.parse('42.50'));
    });

    test('parses negative string', () {
      expect(DecimalHelper.parse('-7.25'), Decimal.parse('-7.25'));
    });

    test('parses string with comma as decimal separator', () {
      expect(DecimalHelper.parse('12,34'), Decimal.parse('12.34'));
    });

    test('returns zero for empty string', () {
      expect(DecimalHelper.parse(''), Decimal.zero);
    });

    test('returns zero for whitespace-only string', () {
      expect(DecimalHelper.parse('   '), Decimal.zero);
    });

    test('trims surrounding whitespace', () {
      expect(DecimalHelper.parse('  100.00  '), Decimal.parse('100.00'));
    });

    test('returns zero for non-numeric string', () {
      expect(DecimalHelper.parse('abc'), Decimal.zero);
    });

    test('rounds to 2 decimal places', () {
      // 1.999 should round to 2.00
      expect(DecimalHelper.parse('1.999'), Decimal.parse('2.00'));
    });

    test('rounds half-up at third decimal', () {
      // 1.005 -> rounded: (1.005 * 100).round() = 101 -> 1.01
      expect(DecimalHelper.parse('1.005'), Decimal.parse('1.01'));
    });

    test('clamps overflow to max safe value', () {
      expect(
        DecimalHelper.parse('99999999999'),
        Decimal.parse('999999999.99'),
      );
    });

    test('clamps negative overflow to min safe value', () {
      expect(
        DecimalHelper.parse('-99999999999'),
        Decimal.parse('-999999999.99'),
      );
    });

    test('parses integer string', () {
      expect(DecimalHelper.parse('5'), Decimal.parse('5.00'));
    });

    test('parses zero string', () {
      expect(DecimalHelper.parse('0'), Decimal.zero);
    });
  });

  // ---------------------------------------------------------------------------
  // fromDoubleSafe()
  // ---------------------------------------------------------------------------
  group('fromDoubleSafe', () {
    test('returns zero for null', () {
      expect(DecimalHelper.fromDoubleSafe(null), Decimal.zero);
    });

    test('delegates to fromDouble for normal value', () {
      expect(
        DecimalHelper.fromDoubleSafe(25.50),
        DecimalHelper.fromDouble(25.50),
      );
    });

    test('delegates to fromDouble for infinity', () {
      expect(DecimalHelper.fromDoubleSafe(double.infinity), Decimal.zero);
    });

    test('delegates to fromDouble for NaN', () {
      expect(DecimalHelper.fromDoubleSafe(double.nan), Decimal.zero);
    });

    test('delegates to fromDouble for negative value', () {
      expect(
        DecimalHelper.fromDoubleSafe(-99.99),
        DecimalHelper.fromDouble(-99.99),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // isValidDecimal()
  // ---------------------------------------------------------------------------
  group('isValidDecimal', () {
    test('returns true for zero', () {
      expect(DecimalHelper.isValidDecimal(Decimal.zero), isTrue);
    });

    test('returns true for normal positive value', () {
      expect(DecimalHelper.isValidDecimal(Decimal.parse('500.00')), isTrue);
    });

    test('returns true for normal negative value', () {
      expect(DecimalHelper.isValidDecimal(Decimal.parse('-500.00')), isTrue);
    });

    test('returns true at positive boundary', () {
      expect(
        DecimalHelper.isValidDecimal(Decimal.parse('999999999.99')),
        isTrue,
      );
    });

    test('returns true at negative boundary', () {
      expect(
        DecimalHelper.isValidDecimal(Decimal.parse('-999999999.99')),
        isTrue,
      );
    });

    test('returns false for value exceeding positive boundary', () {
      expect(
        DecimalHelper.isValidDecimal(Decimal.parse('1000000000')),
        isFalse,
      );
    });

    test('returns false for value exceeding negative boundary', () {
      expect(
        DecimalHelper.isValidDecimal(Decimal.parse('-1000000000')),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // add()
  // ---------------------------------------------------------------------------
  group('add', () {
    test('adds two positive values', () {
      expect(DecimalHelper.add(10.25, 5.75), 16.00);
    });

    test('adds positive and negative values', () {
      expect(DecimalHelper.add(10.0, -3.0), 7.0);
    });

    test('adds two negative values', () {
      expect(DecimalHelper.add(-5.0, -3.0), -8.0);
    });

    test('adds zero', () {
      expect(DecimalHelper.add(42.0, 0.0), 42.0);
    });

    test('handles floating-point precision (0.1 + 0.2)', () {
      // Classic floating-point issue: 0.1 + 0.2 should be 0.3 exactly
      expect(DecimalHelper.add(0.1, 0.2), 0.3);
    });

    test('handles infinity as operand', () {
      // Infinity gets converted to zero by fromDouble
      expect(DecimalHelper.add(double.infinity, 5.0), 5.0);
    });

    test('handles NaN as operand', () {
      expect(DecimalHelper.add(double.nan, 5.0), 5.0);
    });
  });

  // ---------------------------------------------------------------------------
  // subtract()
  // ---------------------------------------------------------------------------
  group('subtract', () {
    test('subtracts two positive values', () {
      expect(DecimalHelper.subtract(10.0, 3.0), 7.0);
    });

    test('subtracts resulting in negative', () {
      expect(DecimalHelper.subtract(3.0, 10.0), -7.0);
    });

    test('subtracts zero', () {
      expect(DecimalHelper.subtract(42.0, 0.0), 42.0);
    });

    test('handles floating-point precision', () {
      // 0.3 - 0.1 should be 0.2 exactly
      expect(DecimalHelper.subtract(0.3, 0.1), 0.2);
    });

    test('subtracts negative from positive', () {
      expect(DecimalHelper.subtract(5.0, -3.0), 8.0);
    });

    test('handles infinity as operand', () {
      expect(DecimalHelper.subtract(double.infinity, 5.0), -5.0);
    });
  });

  // ---------------------------------------------------------------------------
  // multiply()
  // ---------------------------------------------------------------------------
  group('multiply', () {
    test('multiplies two positive values', () {
      expect(DecimalHelper.multiply(3.0, 4.0), 12.0);
    });

    test('multiplies by zero', () {
      expect(DecimalHelper.multiply(42.0, 0.0), 0.0);
    });

    test('multiplies positive and negative', () {
      expect(DecimalHelper.multiply(5.0, -2.0), -10.0);
    });

    test('multiplies two negatives', () {
      expect(DecimalHelper.multiply(-3.0, -4.0), 12.0);
    });

    test('multiplies decimal values', () {
      expect(DecimalHelper.multiply(1.5, 2.0), 3.0);
    });

    test('handles infinity as operand', () {
      // infinity -> 0, so 0 * 5 = 0
      expect(DecimalHelper.multiply(double.infinity, 5.0), 0.0);
    });
  });

  // ---------------------------------------------------------------------------
  // divide()
  // ---------------------------------------------------------------------------
  group('divide', () {
    test('divides evenly', () {
      expect(DecimalHelper.divide(10.0, 2.0), 5.0);
    });

    // BUG: divide() calls .toDecimal() without scaleOnInfinitePrecision,
    // which throws for non-terminating decimals like 10/3.
    test('throws for non-terminating decimal result (known bug)', () {
      expect(() => DecimalHelper.divide(10.0, 3.0), throwsA(isA<Object>()));
    });

    test('returns zero for division by zero', () {
      expect(DecimalHelper.divide(10.0, 0.0), 0.0);
    });

    test('divides negative by positive', () {
      expect(DecimalHelper.divide(-10.0, 2.0), -5.0);
    });

    test('divides zero by non-zero', () {
      expect(DecimalHelper.divide(0.0, 5.0), 0.0);
    });

    test('handles infinity dividend', () {
      // infinity -> 0, so 0 / 5 = 0
      expect(DecimalHelper.divide(double.infinity, 5.0), 0.0);
    });

    test('handles NaN dividend (NaN -> 0, so 0/5 = 0)', () {
      expect(DecimalHelper.divide(double.nan, 5.0), 0.0);
    });
  });

  // ---------------------------------------------------------------------------
  // percentage()
  // ---------------------------------------------------------------------------
  group('percentage', () {
    test('calculates 50 percent', () {
      expect(DecimalHelper.percentage(50, 100), 50.0);
    });

    test('calculates 100 percent', () {
      expect(DecimalHelper.percentage(100, 100), 100.0);
    });

    test('calculates small percentage', () {
      expect(DecimalHelper.percentage(1, 100), 1.0);
    });

    test('returns zero when total is zero', () {
      expect(DecimalHelper.percentage(50, 0), 0.0);
    });

    test('calculates percentage greater than 100', () {
      expect(DecimalHelper.percentage(200, 100), 200.0);
    });

    test('handles negative value', () {
      expect(DecimalHelper.percentage(-25, 100), -25.0);
    });

    // BUG: percentage calls divide(), which calls .toDecimal() without
    // scaleOnInfinitePrecision. 1/3 is a non-terminating decimal -> throws.
    test('throws for non-terminating percentage (known bug)', () {
      expect(() => DecimalHelper.percentage(1, 3), throwsA(isA<Object>()));
    });
  });

  // ---------------------------------------------------------------------------
  // round()
  // ---------------------------------------------------------------------------
  group('round', () {
    test('rounds value with many decimal places', () {
      expect(DecimalHelper.round(1.999), 2.0);
    });

    test('rounds value to 2 decimal places', () {
      expect(DecimalHelper.round(1.234), 1.23);
    });

    test('keeps value already at 2 decimals', () {
      expect(DecimalHelper.round(1.25), 1.25);
    });

    test('rounds zero', () {
      expect(DecimalHelper.round(0.0), 0.0);
    });

    test('rounds negative value', () {
      expect(DecimalHelper.round(-1.999), -2.0);
    });

    test('returns zero for infinity', () {
      expect(DecimalHelper.round(double.infinity), 0.0);
    });

    test('returns zero for NaN', () {
      expect(DecimalHelper.round(double.nan), 0.0);
    });
  });

  // ---------------------------------------------------------------------------
  // equals()
  // ---------------------------------------------------------------------------
  group('equals', () {
    test('equal values are equal', () {
      expect(DecimalHelper.equals(1.0, 1.0), isTrue);
    });

    test('different values are not equal', () {
      expect(DecimalHelper.equals(1.0, 2.0), isFalse);
    });

    test('solves floating-point precision: 0.1+0.2 vs 0.3', () {
      // In raw doubles: 0.1 + 0.2 != 0.3, but after rounding to 2dp they match
      expect(DecimalHelper.equals(0.1 + 0.2, 0.3), isTrue);
    });

    test('negative and positive are not equal', () {
      expect(DecimalHelper.equals(-1.0, 1.0), isFalse);
    });

    test('zeros are equal', () {
      expect(DecimalHelper.equals(0.0, 0.0), isTrue);
    });

    test('values differing at 3rd decimal treated equal after rounding', () {
      // 1.001 rounds to 1.00, 1.004 rounds to 1.00
      expect(DecimalHelper.equals(1.001, 1.004), isTrue);
    });

    test('values differing at 2nd decimal are not equal', () {
      expect(DecimalHelper.equals(1.01, 1.02), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // compare()
  // ---------------------------------------------------------------------------
  group('compare', () {
    test('returns negative when a < b', () {
      expect(DecimalHelper.compare(1.0, 2.0), lessThan(0));
    });

    test('returns zero when a == b', () {
      expect(DecimalHelper.compare(5.0, 5.0), 0);
    });

    test('returns positive when a > b', () {
      expect(DecimalHelper.compare(10.0, 5.0), greaterThan(0));
    });

    test('compares negative values', () {
      expect(DecimalHelper.compare(-5.0, -3.0), lessThan(0));
    });

    test('returns zero for precision-equal values', () {
      // 0.1 + 0.2 vs 0.3 after rounding both to 2dp
      expect(DecimalHelper.compare(0.1 + 0.2, 0.3), 0);
    });

    test('compares negative and positive', () {
      expect(DecimalHelper.compare(-1.0, 1.0), lessThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // addDecimal()
  // ---------------------------------------------------------------------------
  group('addDecimal', () {
    test('adds two Decimal values', () {
      final a = Decimal.parse('10.50');
      final b = Decimal.parse('5.25');
      expect(DecimalHelper.addDecimal(a, b), Decimal.parse('15.75'));
    });

    test('adds zero', () {
      final a = Decimal.parse('42.00');
      expect(DecimalHelper.addDecimal(a, Decimal.zero), a);
    });

    test('adds negative Decimal', () {
      final a = Decimal.parse('10.00');
      final b = Decimal.parse('-3.00');
      expect(DecimalHelper.addDecimal(a, b), Decimal.parse('7.00'));
    });
  });

  // ---------------------------------------------------------------------------
  // subtractDecimal()
  // ---------------------------------------------------------------------------
  group('subtractDecimal', () {
    test('subtracts two Decimal values', () {
      final a = Decimal.parse('10.00');
      final b = Decimal.parse('3.50');
      expect(DecimalHelper.subtractDecimal(a, b), Decimal.parse('6.50'));
    });

    test('subtracts resulting in negative', () {
      final a = Decimal.parse('3.00');
      final b = Decimal.parse('10.00');
      expect(DecimalHelper.subtractDecimal(a, b), Decimal.parse('-7.00'));
    });

    test('subtracts zero', () {
      final a = Decimal.parse('42.00');
      expect(DecimalHelper.subtractDecimal(a, Decimal.zero), a);
    });
  });

  // ---------------------------------------------------------------------------
  // multiplyDecimal()
  // ---------------------------------------------------------------------------
  group('multiplyDecimal', () {
    test('multiplies two Decimal values', () {
      final a = Decimal.parse('3.00');
      final b = Decimal.parse('4.00');
      expect(DecimalHelper.multiplyDecimal(a, b), Decimal.parse('12.00'));
    });

    test('multiplies by zero', () {
      final a = Decimal.parse('42.00');
      expect(DecimalHelper.multiplyDecimal(a, Decimal.zero), Decimal.zero);
    });

    test('multiplies decimal fractions', () {
      final a = Decimal.parse('1.50');
      final b = Decimal.parse('2.00');
      expect(DecimalHelper.multiplyDecimal(a, b), Decimal.parse('3.00'));
    });

    test('multiplies negative values', () {
      final a = Decimal.parse('-3.00');
      final b = Decimal.parse('-4.00');
      expect(DecimalHelper.multiplyDecimal(a, b), Decimal.parse('12.00'));
    });
  });

  // ---------------------------------------------------------------------------
  // divideDecimal()
  // ---------------------------------------------------------------------------
  group('divideDecimal', () {
    test('divides evenly', () {
      final a = Decimal.parse('10.00');
      final b = Decimal.parse('2.00');
      expect(DecimalHelper.divideDecimal(a, b), Decimal.parse('5'));
    });

    test('returns zero for division by zero', () {
      final a = Decimal.parse('10.00');
      expect(DecimalHelper.divideDecimal(a, Decimal.zero), Decimal.zero);
    });

    test('divides zero by non-zero', () {
      final b = Decimal.parse('5.00');
      expect(DecimalHelper.divideDecimal(Decimal.zero, b), Decimal.zero);
    });

    test('divides negative by positive', () {
      final a = Decimal.parse('-10.00');
      final b = Decimal.parse('2.00');
      expect(DecimalHelper.divideDecimal(a, b), Decimal.parse('-5'));
    });
  });

  // ---------------------------------------------------------------------------
  // compareDecimal() (bonus — present in source)
  // ---------------------------------------------------------------------------
  group('compareDecimal', () {
    test('returns negative when a < b', () {
      expect(
        DecimalHelper.compareDecimal(
          Decimal.parse('1.00'),
          Decimal.parse('2.00'),
        ),
        lessThan(0),
      );
    });

    test('returns zero when equal', () {
      expect(
        DecimalHelper.compareDecimal(
          Decimal.parse('5.00'),
          Decimal.parse('5.00'),
        ),
        0,
      );
    });

    test('returns positive when a > b', () {
      expect(
        DecimalHelper.compareDecimal(
          Decimal.parse('10.00'),
          Decimal.parse('5.00'),
        ),
        greaterThan(0),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // clamp()
  // ---------------------------------------------------------------------------
  group('clamp', () {
    test('returns value when within range', () {
      final value = Decimal.parse('5.00');
      final lo = Decimal.parse('0.00');
      final hi = Decimal.parse('10.00');
      expect(DecimalHelper.clamp(value, lo, hi), value);
    });

    test('returns min when value is below range', () {
      final value = Decimal.parse('-5.00');
      final lo = Decimal.parse('0.00');
      final hi = Decimal.parse('10.00');
      expect(DecimalHelper.clamp(value, lo, hi), lo);
    });

    test('returns max when value is above range', () {
      final value = Decimal.parse('15.00');
      final lo = Decimal.parse('0.00');
      final hi = Decimal.parse('10.00');
      expect(DecimalHelper.clamp(value, lo, hi), hi);
    });

    test('returns min when value equals min', () {
      final lo = Decimal.parse('0.00');
      final hi = Decimal.parse('10.00');
      expect(DecimalHelper.clamp(lo, lo, hi), lo);
    });

    test('returns max when value equals max', () {
      final lo = Decimal.parse('0.00');
      final hi = Decimal.parse('10.00');
      expect(DecimalHelper.clamp(hi, lo, hi), hi);
    });

    test('works with negative range', () {
      final value = Decimal.parse('-50.00');
      final lo = Decimal.parse('-100.00');
      final hi = Decimal.parse('-10.00');
      expect(DecimalHelper.clamp(value, lo, hi), value);
    });
  });

  // ---------------------------------------------------------------------------
  // min()
  // ---------------------------------------------------------------------------
  group('min', () {
    test('returns smaller of two values', () {
      expect(
        DecimalHelper.min(Decimal.parse('3.00'), Decimal.parse('7.00')),
        Decimal.parse('3.00'),
      );
    });

    test('returns either when equal', () {
      expect(
        DecimalHelper.min(Decimal.parse('5.00'), Decimal.parse('5.00')),
        Decimal.parse('5.00'),
      );
    });

    test('returns negative over positive', () {
      expect(
        DecimalHelper.min(Decimal.parse('-1.00'), Decimal.parse('1.00')),
        Decimal.parse('-1.00'),
      );
    });

    test('returns more negative value', () {
      expect(
        DecimalHelper.min(Decimal.parse('-10.00'), Decimal.parse('-3.00')),
        Decimal.parse('-10.00'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // max()
  // ---------------------------------------------------------------------------
  group('max', () {
    test('returns larger of two values', () {
      expect(
        DecimalHelper.max(Decimal.parse('3.00'), Decimal.parse('7.00')),
        Decimal.parse('7.00'),
      );
    });

    test('returns either when equal', () {
      expect(
        DecimalHelper.max(Decimal.parse('5.00'), Decimal.parse('5.00')),
        Decimal.parse('5.00'),
      );
    });

    test('returns positive over negative', () {
      expect(
        DecimalHelper.max(Decimal.parse('-1.00'), Decimal.parse('1.00')),
        Decimal.parse('1.00'),
      );
    });

    test('returns less negative value', () {
      expect(
        DecimalHelper.max(Decimal.parse('-10.00'), Decimal.parse('-3.00')),
        Decimal.parse('-3.00'),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // isZero()
  // ---------------------------------------------------------------------------
  group('isZero', () {
    test('returns true for Decimal.zero', () {
      expect(DecimalHelper.isZero(Decimal.zero), isTrue);
    });

    test('returns true for parsed zero', () {
      expect(DecimalHelper.isZero(Decimal.parse('0.00')), isTrue);
    });

    test('returns false for non-zero positive', () {
      expect(DecimalHelper.isZero(Decimal.parse('0.01')), isFalse);
    });

    test('returns false for non-zero negative', () {
      expect(DecimalHelper.isZero(Decimal.parse('-0.01')), isFalse);
    });

    test('returns false for large value', () {
      expect(DecimalHelper.isZero(Decimal.parse('1000000')), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Integration / cross-method edge cases
  // ---------------------------------------------------------------------------
  group('integration and edge cases', () {
    test('fromDouble then toDouble roundtrips correctly', () {
      const original = 123.45;
      expect(
          DecimalHelper.toDouble(DecimalHelper.fromDouble(original)), original);
    });

    test('round is equivalent to fromDouble -> toDouble', () {
      const value = 3.14159;
      expect(DecimalHelper.round(value),
          DecimalHelper.toDouble(DecimalHelper.fromDouble(value)));
    });

    test('add handles both operands as infinity', () {
      expect(DecimalHelper.add(double.infinity, double.negativeInfinity), 0.0);
    });

    test('subtract handles both operands as NaN', () {
      expect(DecimalHelper.subtract(double.nan, double.nan), 0.0);
    });

    test('multiply handles NaN times NaN', () {
      expect(DecimalHelper.multiply(double.nan, double.nan), 0.0);
    });

    // BUG: NaN != 0 so the guard passes, but fromDouble(NaN) returns
    // Decimal.zero, causing a Decimal 0/0 which throws.
    test('divide throws for NaN / NaN (known bug)', () {
      expect(() => DecimalHelper.divide(double.nan, double.nan),
          throwsA(isA<Object>()));
    });

    test('divide handles 0 / 0', () {
      expect(DecimalHelper.divide(0.0, 0.0), 0.0);
    });

    test('repeated add of 0.1 ten times equals 1.0', () {
      double result = 0.0;
      for (int i = 0; i < 10; i++) {
        result = DecimalHelper.add(result, 0.1);
      }
      expect(result, 1.0);
    });

    // BUG: infinity != 0 so the guard in percentage passes, but
    // fromDouble(infinity) returns Decimal.zero, causing 0-division in divide.
    test('percentage throws for infinity total (known bug)', () {
      expect(
        () => DecimalHelper.percentage(50, double.infinity),
        throwsA(isA<Object>()),
      );
    });

    test('fromDoubleSafe handles max double', () {
      // Should clamp to max safe value
      final result = DecimalHelper.fromDoubleSafe(double.maxFinite);
      expect(result, Decimal.parse('999999999.99'));
    });

    test('parse handles string with leading zeros', () {
      expect(DecimalHelper.parse('007.50'), Decimal.parse('7.50'));
    });

    test('parse handles string of just a dot', () {
      // "." is not valid -> catch block returns zero
      expect(DecimalHelper.parse('.'), Decimal.zero);
    });
  });
}
