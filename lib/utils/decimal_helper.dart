import 'package:decimal/decimal.dart';

/// Helper class for precise financial calculations using Decimal type
/// Prevents floating-point precision issues (e.g., 0.1 + 0.2 != 0.3)
class DecimalHelper {
  /// Convert double to Decimal (for internal calculations)
  /// FIX #33: Handle edge cases (infinity, nan, very large numbers)
  static Decimal fromDouble(double value) {
    // FIX #33 & #36: Handle special values and overflow
    if (!value.isFinite) {
      return Decimal.zero; // Treat infinity/nan as zero for safety
    }

    // FIX #36: Prevent overflow by capping at max safe value
    const maxSafeValue = 999999999.99;
    final clamped = value.clamp(-maxSafeValue, maxSafeValue);

    return Decimal.parse(clamped.toStringAsFixed(2));
  }

  /// Convert Decimal to double (for storage/display)
  /// FIX #33 & #36: Safe conversion with overflow protection
  static double toDouble(Decimal value) {
    try {
      final doubleValue = value.toDouble();

      // FIX #33: Check for special values after conversion
      if (!doubleValue.isFinite) {
        return 0.0; // Treat infinity/nan as zero
      }

      // FIX #36: Clamp to prevent overflow in display
      const maxSafeValue = 999999999.99;
      return doubleValue.clamp(-maxSafeValue, maxSafeValue);
    } catch (e) {
      // Fallback for any conversion errors
      return 0.0;
    }
  }

  /// Parse string to Decimal (for user input)
  /// Returns Decimal.zero if parsing fails
  /// FIX #33 & #36: Validate and clamp parsed values
  static Decimal parse(String value) {
    try {
      // Remove any whitespace and convert comma to dot for internationalization
      final cleaned = value.trim().replaceAll(',', '.');
      if (cleaned.isEmpty) return Decimal.zero;

      // Parse and round to 2 decimal places for currency
      final parsed = Decimal.parse(cleaned);

      // FIX #33: Check for infinity/nan in Decimal
      // Decimal library doesn't have isFinite, so check by conversion
      final asDouble = parsed.toDouble();
      if (!asDouble.isFinite) {
        return Decimal.zero;
      }

      // FIX #36: Clamp to safe range before rounding
      const maxSafeValue = 999999999.99;
      final maxDecimal = Decimal.parse(maxSafeValue.toString());
      final minDecimal = Decimal.parse((-maxSafeValue).toString());
      final clamped = clamp(parsed, minDecimal, maxDecimal);

      final rounded = (clamped * Decimal.fromInt(100)).round();
      return (rounded / Decimal.fromInt(100)).toDecimal();
    } catch (e) {
      return Decimal.zero;
    }
  }

  /// Parse double safely to Decimal with 2 decimal precision
  /// FIX #33 & #36: Enhanced safety checks
  static Decimal fromDoubleSafe(double? value) {
    if (value == null) return Decimal.zero;
    // fromDouble now handles all edge cases
    return fromDouble(value);
  }

  /// FIX #33: Validate Decimal value is safe for financial operations
  /// Returns true if value is finite and within safe range
  static bool isValidDecimal(Decimal value) {
    try {
      final asDouble = value.toDouble();
      if (!asDouble.isFinite) return false;

      const maxSafeValue = 999999999.99;
      return asDouble.abs() <= maxSafeValue;
    } catch (e) {
      return false;
    }
  }

  /// Add two amounts with precision
  static double add(double a, double b) {
    final decimalA = fromDouble(a);
    final decimalB = fromDouble(b);
    return toDouble(decimalA + decimalB);
  }

  /// Subtract two amounts with precision
  static double subtract(double a, double b) {
    final decimalA = fromDouble(a);
    final decimalB = fromDouble(b);
    return toDouble(decimalA - decimalB);
  }

  /// Multiply amount with precision
  static double multiply(double a, double b) {
    final decimalA = fromDouble(a);
    final decimalB = fromDouble(b);
    return toDouble(decimalA * decimalB);
  }

  /// Divide amount with precision
  static double divide(double a, double b) {
    if (b == 0) return 0;
    final decimalA = fromDouble(a);
    final decimalB = fromDouble(b);
    return toDouble((decimalA / decimalB).toDecimal());
  }

  /// Calculate percentage with precision
  static double percentage(double value, double total) {
    if (total == 0) return 0;
    return multiply(divide(value, total), 100);
  }

  /// Round to 2 decimal places
  static double round(double value) {
    return toDouble(fromDouble(value));
  }

  /// Check if two amounts are equal (accounting for precision)
  static bool equals(double a, double b) {
    return fromDouble(a) == fromDouble(b);
  }

  /// Compare amounts (-1 if a < b, 0 if equal, 1 if a > b)
  static int compare(double a, double b) {
    return fromDouble(a).compareTo(fromDouble(b));
  }

  /// Add Decimal values directly
  static Decimal addDecimal(Decimal a, Decimal b) {
    return a + b;
  }

  /// Subtract Decimal values directly
  static Decimal subtractDecimal(Decimal a, Decimal b) {
    return a - b;
  }

  /// Multiply Decimal values directly
  static Decimal multiplyDecimal(Decimal a, Decimal b) {
    return a * b;
  }

  /// Divide Decimal values directly
  static Decimal divideDecimal(Decimal a, Decimal b) {
    if (b == Decimal.zero) return Decimal.zero;
    return (a / b).toDecimal();
  }

  /// Compare Decimal values (-1 if a < b, 0 if equal, 1 if a > b)
  static int compareDecimal(Decimal a, Decimal b) {
    return a.compareTo(b);
  }

  /// Check if Decimal value is zero
  static bool isZero(Decimal value) {
    return value == Decimal.zero;
  }

  /// Get maximum of two Decimal values
  static Decimal max(Decimal a, Decimal b) {
    return a > b ? a : b;
  }

  /// Get minimum of two Decimal values
  static Decimal min(Decimal a, Decimal b) {
    return a < b ? a : b;
  }

  /// Clamp Decimal value between min and max
  static Decimal clamp(Decimal value, Decimal min, Decimal max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
