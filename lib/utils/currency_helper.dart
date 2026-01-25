import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyHelper {
  // Currency to locale mapping for proper number formatting
  static const Map<String, String> currencyLocales = {
    'USD': 'en_US',
    'EUR': 'de_DE',  // European format (1.234,56)
    'GBP': 'en_GB',
    'JPY': 'ja_JP',
    'CNY': 'zh_CN',
    'AUD': 'en_AU',
    'CAD': 'en_CA',
    'CHF': 'de_CH',  // Swiss format (1'234.56)
    'INR': 'en_IN',  // Indian format (1,23,456.78)
    'RUB': 'ru_RU',
    'BRL': 'pt_BR',
    'KRW': 'ko_KR',
    'MXN': 'es_MX',
    'ZAR': 'en_ZA',
    'SEK': 'sv_SE',
    'NOK': 'nb_NO',
    'DKK': 'da_DK',
    'PLN': 'pl_PL',
    'THB': 'th_TH',
    'IDR': 'id_ID',
    'MYR': 'ms_MY',
    'PHP': 'fil_PH',
    'SGD': 'en_SG',
    'NZD': 'en_NZ',
    'HKD': 'zh_HK',
  };

  /// Format a number according to the currency's locale
  /// e.g., formatAmount(1234.56, 'EUR') -> "1.234,56"
  /// e.g., formatAmount(1234.56, 'USD') -> "1,234.56"
  static String formatAmount(double amount, String currencyCode, {int decimalDigits = 2}) {
    final locale = currencyLocales[currencyCode] ?? 'en_US';
    try {
      final formatter = NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: decimalDigits,
      );
      return formatter.format(amount);
    } catch (e) {
      // Fallback to simple formatting if locale not available
      return amount.toStringAsFixed(decimalDigits);
    }
  }

  /// Format amount with currency symbol (localized)
  /// e.g., formatWithSymbol(1234.56, '\$', 'USD') -> "\$1,234.56"
  /// e.g., formatWithSymbol(1234.56, '€', 'EUR') -> "€1.234,56"
  static String formatWithSymbol(double amount, String symbol, String currencyCode, {int decimalDigits = 2}) {
    return '$symbol${formatAmount(amount, currencyCode, decimalDigits: decimalDigits)}';
  }

  /// Compact format for large numbers
  /// e.g., formatCompact(1234567.89, 'USD') -> "1.2M"
  static String formatCompact(double amount, String currencyCode) {
    final locale = currencyLocales[currencyCode] ?? 'en_US';
    try {
      final formatter = NumberFormat.compact(locale: locale);
      return formatter.format(amount);
    } catch (e) {
      // Fallback
      if (amount >= 1000000) {
        return '${(amount / 1000000).toStringAsFixed(1)}M';
      } else if (amount >= 1000) {
        return '${(amount / 1000).toStringAsFixed(1)}K';
      }
      return amount.toStringAsFixed(2);
    }
  }
  static const Map<String, String> currencies = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CNY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'CHF',
    'INR': '₹',
    'RUB': '₽',
    'BRL': 'R\$',
    'KRW': '₩',
    'MXN': 'MX\$',
    'ZAR': 'R',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'PLN': 'zł',
    'THB': '฿',
    'IDR': 'Rp',
    'MYR': 'RM',
    'PHP': '₱',
    'SGD': 'S\$',
    'NZD': 'NZ\$',
    'HKD': 'HK\$',
  };

  static List<String> get currencyList => currencies.keys.toList();

  static String getSymbol(String code) => currencies[code] ?? '\$';

  static String getName(String code) {
    const names = {
      'USD': 'US Dollar',
      'EUR': 'Euro',
      'GBP': 'British Pound',
      'JPY': 'Japanese Yen',
      'CNY': 'Chinese Yuan',
      'AUD': 'Australian Dollar',
      'CAD': 'Canadian Dollar',
      'CHF': 'Swiss Franc',
      'INR': 'Indian Rupee',
      'RUB': 'Russian Ruble',
      'BRL': 'Brazilian Real',
      'KRW': 'South Korean Won',
      'MXN': 'Mexican Peso',
      'ZAR': 'South African Rand',
      'SEK': 'Swedish Krona',
      'NOK': 'Norwegian Krone',
      'DKK': 'Danish Krone',
      'PLN': 'Polish Złoty',
      'THB': 'Thai Baht',
      'IDR': 'Indonesian Rupiah',
      'MYR': 'Malaysian Ringgit',
      'PHP': 'Philippine Peso',
      'SGD': 'Singapore Dollar',
      'NZD': 'New Zealand Dollar',
      'HKD': 'Hong Kong Dollar',
    };
    return names[code] ?? code;
  }

  // ========== DECIMAL INPUT HELPERS (International Support) ==========

  // Common Unicode characters that some keyboards use for decimal separators
  static const _decimalSeparators = [
    ',',      // Standard comma (European)
    '.',      // Standard dot (US/UK)
    '٫',      // Arabic decimal separator U+066B
    '،',      // Arabic comma U+060C
    '、',     // Japanese comma
  ];

  // Common thousands separators used globally
  static const _thousandsSeparators = [
    ' ',      // Space (European, e.g., 1 234,56)
    '\u00A0', // Non-breaking space
    '\u202F', // Narrow no-break space (French)
    "'",      // Apostrophe (Swiss, e.g., 1'234.56)
    '˙',      // Dot above (some locales)
  ];

  /// Strips thousands separators from input.
  /// Handles space, non-breaking space, apostrophe, etc.
  /// e.g., "1,234.56" -> "1234.56", "1 234,56" -> "1234,56"
  static String stripThousandsSeparators(String input) {
    String result = input;

    // Remove all thousands separators
    for (final sep in _thousandsSeparators) {
      result = result.replaceAll(sep, '');
    }

    // Handle comma as thousands separator (US/UK style: 1,234.56)
    // vs comma as decimal separator (European style: 1.234,56)
    // Heuristic: if there's a dot AFTER commas, commas are thousands separators
    // If there's a comma AFTER dots, dots are thousands separators
    final lastComma = result.lastIndexOf(',');
    final lastDot = result.lastIndexOf('.');

    if (lastComma != -1 && lastDot != -1) {
      if (lastDot > lastComma) {
        // Pattern like "1,234.56" - comma is thousands separator
        result = result.replaceAll(',', '');
      } else {
        // Pattern like "1.234,56" - dot is thousands separator
        result = result.replaceAll('.', '');
      }
    } else if (lastComma != -1) {
      // Only commas - check if it looks like thousands separator
      // "1,234,567" has multiple commas = thousands separators
      // "1234,56" has one comma with 2 digits after = decimal separator
      final commaCount = ','.allMatches(result).length;
      final afterLastComma = result.substring(lastComma + 1);
      if (commaCount > 1 || afterLastComma.length == 3) {
        // Multiple commas or exactly 3 digits after = thousands separator
        result = result.replaceAll(',', '');
      }
    } else if (lastDot != -1) {
      // Only dots - check if it looks like thousands separator
      final dotCount = '.'.allMatches(result).length;
      final afterLastDot = result.substring(lastDot + 1);
      if (dotCount > 1 || (dotCount == 1 && afterLastDot.length == 3 && result.length > 4)) {
        // Multiple dots or exactly 3 digits after in a longer number = thousands separator
        result = result.replaceAll('.', '');
      }
    }

    return result;
  }

  /// Normalizes a decimal string by replacing various regional decimal separators with dot.
  /// This supports international users who use comma or other regional separators.
  /// Also strips thousands separators and currency symbols for pasted values from banking apps.
  /// e.g., "12,50" -> "12.50", "$1,234.56" -> "1234.56", "€1.234,56" -> "1234.56"
  static String normalizeDecimalInput(String input) {
    // FIX: Strip currency symbols first (handles "$50.00", "€1,234.56", etc.)
    String result = input;
    for (final symbol in currencies.values) {
      result = result.replaceAll(symbol, '');
    }
    // Also strip common currency codes that might appear
    result = result.replaceAll(RegExp(r'[A-Z]{3}'), ''); // e.g., "USD", "EUR"
    result = result.trim();

    // Then strip thousands separators
    result = stripThousandsSeparators(result);

    // Then normalize decimal separators
    for (final sep in _decimalSeparators) {
      if (sep != '.') {
        result = result.replaceAll(sep, '.');
      }
    }

    // Handle case where normalization resulted in multiple dots (user error)
    // Keep only the last dot (most likely the decimal separator)
    final dotCount = '.'.allMatches(result).length;
    if (dotCount > 1) {
      final lastDot = result.lastIndexOf('.');
      final beforeLastDot = result.substring(0, lastDot).replaceAll('.', '');
      final afterLastDot = result.substring(lastDot);
      result = beforeLastDot + afterLastDot;
    }

    return result;
  }

  /// Parses a decimal string that may use comma or dot as separator.
  /// Also handles thousands separators from pasted banking app values.
  /// Returns null if the input is not a valid number.
  static double? parseDecimal(String input) {
    final normalized = normalizeDecimalInput(input);
    return double.tryParse(normalized);
  }

  /// Input formatter that allows both comma and dot as decimal separators.
  /// Allows digits, one decimal separator (dot or comma), and up to 2 decimal places.
  /// Also handles pasted values with thousands separators by stripping them.
  ///
  /// **Edge cases handled:**
  /// - Allows comma or dot interchangeably (normalized internally)
  /// - Prevents multiple decimal separators
  /// - Limits to 2 decimal places
  /// - Handles unusual Unicode decimal separators from regional keyboards
  /// - Strips thousands separators from pasted values (e.g., "1,234.56" -> "1234.56")
  static TextInputFormatter decimalInputFormatter() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text;

      // Allow empty input
      if (text.isEmpty) return newValue;

      // Normalize all regional separators to dot for validation
      final normalized = normalizeDecimalInput(text);

      // Regex: digits, optionally followed by dot and up to 2 decimal digits
      // Allows: "", "1", "12", "12.", "12.3", "12.34", ".5", ".50"
      final regex = RegExp(r'^\d*\.?\d{0,2}$');

      if (regex.hasMatch(normalized)) {
        // If the input was modified (thousands separators stripped),
        // return the normalized value
        if (normalized != text && normalized.isNotEmpty) {
          // Preserve cursor position at end
          return TextEditingValue(
            text: normalized,
            selection: TextSelection.collapsed(offset: normalized.length),
          );
        }
        return newValue;
      }

      return oldValue;
    });
  }

  /// Sanitizes text input by removing potentially dangerous characters
  /// and limiting length to prevent abuse
  static String sanitizeText(String input, {int maxLength = 200}) {
    if (input.isEmpty) return input;

    // Trim whitespace
    String sanitized = input.trim();

    // Remove control characters and other potentially dangerous characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Limit length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }
}