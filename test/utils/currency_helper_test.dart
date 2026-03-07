import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/currency_helper.dart';
import 'package:flutter/services.dart';

void main() {
  // =========================================================================
  // formatAmount()
  // =========================================================================
  group('formatAmount', () {
    test('formats USD with US locale (comma thousands, dot decimal)', () {
      final result = CurrencyHelper.formatAmount(1234.56, 'USD');
      expect(result, '1,234.56');
    });

    test('formats EUR with European locale (dot thousands, comma decimal)', () {
      final result = CurrencyHelper.formatAmount(1234.56, 'EUR');
      // German locale: 1.234,56
      expect(result, '1.234,56');
    });

    test('formats JPY with zero decimal digits', () {
      final result =
          CurrencyHelper.formatAmount(1234.0, 'JPY', decimalDigits: 0);
      expect(result, '1,234');
    });

    test('formats INR with Indian grouping (lakhs/crores)', () {
      // Indian format: 12,34,567.89
      final result = CurrencyHelper.formatAmount(1234567.89, 'INR');
      expect(result, '12,34,567.89');
    });

    test('formats CHF with Swiss locale', () {
      final result = CurrencyHelper.formatAmount(1234.56, 'CHF');
      // Swiss German locale uses apostrophe as thousands separator
      expect(result, contains('234'));
      expect(result, contains('56'));
    });

    test('formats zero correctly', () {
      expect(CurrencyHelper.formatAmount(0, 'USD'), '0.00');
    });

    test('formats negative numbers', () {
      final result = CurrencyHelper.formatAmount(-1234.56, 'USD');
      expect(result, contains('1,234.56'));
      expect(result, contains('-'));
    });

    test('formats very large numbers', () {
      final result = CurrencyHelper.formatAmount(1234567890.12, 'USD');
      expect(result, '1,234,567,890.12');
    });

    test('formats very small numbers', () {
      final result = CurrencyHelper.formatAmount(0.01, 'USD');
      expect(result, '0.01');
    });

    test('unknown currency code falls back to en_US locale', () {
      final result = CurrencyHelper.formatAmount(1234.56, 'XYZ');
      expect(result, '1,234.56');
    });

    test('respects custom decimalDigits parameter', () {
      expect(CurrencyHelper.formatAmount(1234.5, 'USD', decimalDigits: 0),
          '1,235');
      expect(CurrencyHelper.formatAmount(1234.5, 'USD', decimalDigits: 1),
          '1,234.5');
      expect(CurrencyHelper.formatAmount(1234.5, 'USD', decimalDigits: 3),
          '1,234.500');
    });

    test('different locales produce different thousand separators', () {
      final usd = CurrencyHelper.formatAmount(1234.56, 'USD');
      final eur = CurrencyHelper.formatAmount(1234.56, 'EUR');
      // USD uses comma for thousands, EUR uses dot
      expect(usd, isNot(equals(eur)));
    });

    test('formats BRL with Brazilian locale', () {
      final result = CurrencyHelper.formatAmount(1234.56, 'BRL');
      // Brazilian Portuguese uses dot for thousands, comma for decimal
      expect(result, '1.234,56');
    });
  });

  // =========================================================================
  // formatWithSymbol()
  // =========================================================================
  group('formatWithSymbol', () {
    test('prepends dollar sign for USD', () {
      final result = CurrencyHelper.formatWithSymbol(1234.56, '\$', 'USD');
      expect(result, '\$1,234.56');
    });

    test('prepends euro sign for EUR', () {
      final result = CurrencyHelper.formatWithSymbol(1234.56, '\u20AC', 'EUR');
      expect(result, '\u20AC1.234,56');
    });

    test('prepends rupee sign for INR', () {
      final result =
          CurrencyHelper.formatWithSymbol(1234567.89, '\u20B9', 'INR');
      expect(result, '\u20B912,34,567.89');
    });

    test('handles zero amount', () {
      final result = CurrencyHelper.formatWithSymbol(0, '\$', 'USD');
      expect(result, '\$0.00');
    });

    test('handles negative amount', () {
      final result = CurrencyHelper.formatWithSymbol(-50.0, '\$', 'USD');
      expect(result, contains('\$'));
      expect(result, contains('50.00'));
    });

    test('respects custom decimalDigits', () {
      final result = CurrencyHelper.formatWithSymbol(1234.5, '\$', 'USD',
          decimalDigits: 0);
      expect(result, '\$1,235');
    });

    test('works with multi-character symbols', () {
      final result = CurrencyHelper.formatWithSymbol(1234.56, 'HK\$', 'HKD');
      expect(result, startsWith('HK\$'));
    });
  });

  // =========================================================================
  // formatCompact()
  // =========================================================================
  group('formatCompact', () {
    test('formats millions with M suffix for USD', () {
      final result = CurrencyHelper.formatCompact(1200000.0, 'USD');
      // NumberFormat.compact may produce "1.2M" or "1M" depending on locale
      expect(result, contains('M'));
    });

    test('formats thousands with K suffix for USD', () {
      final result = CurrencyHelper.formatCompact(1500.0, 'USD');
      // Should produce something like "1.5K" or "2K"
      expect(result, contains('K'));
    });

    test('formats small numbers without suffix', () {
      final result = CurrencyHelper.formatCompact(42.0, 'USD');
      expect(result, isNot(contains('K')));
      expect(result, isNot(contains('M')));
    });

    test('formats zero', () {
      final result = CurrencyHelper.formatCompact(0, 'USD');
      expect(result, contains('0'));
    });

    test('handles unknown currency code (falls back to en_US)', () {
      final result = CurrencyHelper.formatCompact(1500000.0, 'XYZ');
      expect(result, contains('M'));
    });

    test('formats very large numbers', () {
      final result = CurrencyHelper.formatCompact(1500000000.0, 'USD');
      // Should produce something like "1.5B"
      expect(result, contains('B'));
    });
  });

  // =========================================================================
  // getSymbol()
  // =========================================================================
  group('getSymbol', () {
    test('returns \$ for USD', () {
      expect(CurrencyHelper.getSymbol('USD'), '\$');
    });

    test('returns euro sign for EUR', () {
      expect(CurrencyHelper.getSymbol('EUR'), '\u20AC');
    });

    test('returns pound sign for GBP', () {
      expect(CurrencyHelper.getSymbol('GBP'), '\u00A3');
    });

    test('returns yen sign for JPY', () {
      expect(CurrencyHelper.getSymbol('JPY'), '\u00A5');
    });

    test('returns rupee sign for INR', () {
      expect(CurrencyHelper.getSymbol('INR'), '\u20B9');
    });

    test('returns multi-char symbols correctly', () {
      expect(CurrencyHelper.getSymbol('AUD'), 'A\$');
      expect(CurrencyHelper.getSymbol('CAD'), 'C\$');
      expect(CurrencyHelper.getSymbol('HKD'), 'HK\$');
      expect(CurrencyHelper.getSymbol('NZD'), 'NZ\$');
      expect(CurrencyHelper.getSymbol('MXN'), 'MX\$');
      expect(CurrencyHelper.getSymbol('SGD'), 'S\$');
      expect(CurrencyHelper.getSymbol('BRL'), 'R\$');
    });

    test('returns CHF string for Swiss Franc', () {
      expect(CurrencyHelper.getSymbol('CHF'), 'CHF');
    });

    test('falls back to \$ for unknown currency code', () {
      expect(CurrencyHelper.getSymbol('XYZ'), '\$');
      expect(CurrencyHelper.getSymbol(''), '\$');
      expect(CurrencyHelper.getSymbol('UNKNOWN'), '\$');
    });

    test('is case-sensitive (lowercase returns fallback)', () {
      expect(CurrencyHelper.getSymbol('usd'), '\$');
      expect(CurrencyHelper.getSymbol('eur'), '\$');
    });

    test('returns all known currency symbols', () {
      // Verify every key in the currencies map returns a non-null value
      for (final code in CurrencyHelper.currencies.keys) {
        expect(CurrencyHelper.getSymbol(code), isNotNull);
        expect(CurrencyHelper.getSymbol(code), isNotEmpty);
      }
    });
  });

  // =========================================================================
  // getName()
  // =========================================================================
  group('getName', () {
    test('returns full name for known currencies', () {
      expect(CurrencyHelper.getName('USD'), 'US Dollar');
      expect(CurrencyHelper.getName('EUR'), 'Euro');
      expect(CurrencyHelper.getName('GBP'), 'British Pound');
      expect(CurrencyHelper.getName('JPY'), 'Japanese Yen');
      expect(CurrencyHelper.getName('INR'), 'Indian Rupee');
      expect(CurrencyHelper.getName('CHF'), 'Swiss Franc');
      expect(CurrencyHelper.getName('BRL'), 'Brazilian Real');
      expect(CurrencyHelper.getName('KRW'), 'South Korean Won');
      expect(CurrencyHelper.getName('PLN'), 'Polish Z\u0142oty');
    });

    test('returns the code itself for unknown currencies', () {
      expect(CurrencyHelper.getName('XYZ'), 'XYZ');
      expect(CurrencyHelper.getName('ABC'), 'ABC');
      expect(CurrencyHelper.getName('UNKNOWN'), 'UNKNOWN');
    });

    test('returns empty string for empty input', () {
      expect(CurrencyHelper.getName(''), '');
    });

    test('is case-sensitive (lowercase returns the code)', () {
      expect(CurrencyHelper.getName('usd'), 'usd');
      expect(CurrencyHelper.getName('eur'), 'eur');
    });
  });

  // =========================================================================
  // currencyList
  // =========================================================================
  group('currencyList', () {
    test('returns a non-empty list', () {
      expect(CurrencyHelper.currencyList, isNotEmpty);
    });

    test('contains all expected currency codes', () {
      final list = CurrencyHelper.currencyList;
      expect(list, contains('USD'));
      expect(list, contains('EUR'));
      expect(list, contains('GBP'));
      expect(list, contains('JPY'));
      expect(list, contains('INR'));
      expect(list, contains('CHF'));
      expect(list, contains('HKD'));
    });

    test('length matches the currencies map', () {
      expect(
          CurrencyHelper.currencyList.length, CurrencyHelper.currencies.length);
    });

    test('returns a new list instance each time', () {
      final list1 = CurrencyHelper.currencyList;
      final list2 = CurrencyHelper.currencyList;
      expect(identical(list1, list2), isFalse);
    });

    test('all entries are uppercase 3-letter codes', () {
      for (final code in CurrencyHelper.currencyList) {
        expect(code.length, 3);
        expect(code, equals(code.toUpperCase()));
      }
    });
  });

  // =========================================================================
  // stripThousandsSeparators()
  // =========================================================================
  group('stripThousandsSeparators', () {
    group('space-based thousands separators', () {
      test('strips regular spaces', () {
        expect(CurrencyHelper.stripThousandsSeparators('1 234 567'), '1234567');
      });

      test('strips non-breaking spaces (\\u00A0)', () {
        expect(CurrencyHelper.stripThousandsSeparators('1\u00A0234\u00A0567'),
            '1234567');
      });

      test('strips narrow no-break spaces (\\u202F)', () {
        expect(CurrencyHelper.stripThousandsSeparators('1\u202F234\u202F567'),
            '1234567');
      });
    });

    group('apostrophe thousands separator (Swiss)', () {
      test('strips apostrophes from Swiss format', () {
        expect(CurrencyHelper.stripThousandsSeparators("1'234'567"), '1234567');
      });

      test('preserves decimal with apostrophe thousands', () {
        expect(CurrencyHelper.stripThousandsSeparators("1'234.56"), '1234.56');
      });
    });

    group('comma as thousands separator (US/UK style)', () {
      test('"1,234.56" -> comma is thousands (dot after comma)', () {
        expect(CurrencyHelper.stripThousandsSeparators('1,234.56'), '1234.56');
      });

      test('"1,234,567.89" -> multiple commas before dot', () {
        expect(CurrencyHelper.stripThousandsSeparators('1,234,567.89'),
            '1234567.89');
      });

      test('"1,234,567" -> multiple commas = thousands separators', () {
        expect(CurrencyHelper.stripThousandsSeparators('1,234,567'), '1234567');
      });

      test('"1,234" with exactly 3 digits after = thousands separator', () {
        // Single comma with exactly 3 digits after -> thousands
        expect(CurrencyHelper.stripThousandsSeparators('1,234'), '1234');
      });
    });

    group('dot as thousands separator (European style)', () {
      test('"1.234,56" -> dot is thousands (comma after dot)', () {
        expect(CurrencyHelper.stripThousandsSeparators('1.234,56'), '1234,56');
      });

      test('"1.234.567,89" -> multiple dots before comma', () {
        expect(CurrencyHelper.stripThousandsSeparators('1.234.567,89'),
            '1234567,89');
      });

      test('"1.234.567" -> multiple dots = thousands separators', () {
        expect(CurrencyHelper.stripThousandsSeparators('1.234.567'), '1234567');
      });
    });

    group('comma as decimal separator', () {
      test('"1234,56" -> single comma with 2 digits = decimal', () {
        // One comma, 2 digits after -> decimal separator, preserved
        expect(CurrencyHelper.stripThousandsSeparators('1234,56'), '1234,56');
      });

      test('"1234,5" -> single comma with 1 digit = decimal', () {
        expect(CurrencyHelper.stripThousandsSeparators('1234,5'), '1234,5');
      });
    });

    group('dot as decimal separator', () {
      test('"1234.56" -> single dot with 2 digits = decimal', () {
        // Single dot, not long enough for thousands pattern -> decimal
        expect(CurrencyHelper.stripThousandsSeparators('1234.56'), '1234.56');
      });

      test('"0.99" -> small number with decimal dot preserved', () {
        expect(CurrencyHelper.stripThousandsSeparators('0.99'), '0.99');
      });
    });

    group('edge cases', () {
      test('empty string returns empty', () {
        expect(CurrencyHelper.stripThousandsSeparators(''), '');
      });

      test('plain integer without separators unchanged', () {
        expect(CurrencyHelper.stripThousandsSeparators('1234'), '1234');
      });

      test('already clean decimal unchanged', () {
        expect(CurrencyHelper.stripThousandsSeparators('12.50'), '12.50');
      });

      test('very large number with commas', () {
        expect(CurrencyHelper.stripThousandsSeparators('1,234,567,890.12'),
            '1234567890.12');
      });

      test('mixed spaces and commas', () {
        // Space is stripped first, then comma logic applies
        expect(CurrencyHelper.stripThousandsSeparators('1 234,56'), '1234,56');
      });
    });
  });

  // =========================================================================
  // normalizeDecimalInput()
  // =========================================================================
  group('normalizeDecimalInput', () {
    group('currency symbol stripping', () {
      test('strips dollar sign', () {
        expect(CurrencyHelper.normalizeDecimalInput('\$50.00'), '50.00');
      });

      test('strips euro sign', () {
        expect(CurrencyHelper.normalizeDecimalInput('\u20AC50,00'), '50.00');
      });

      test('strips pound sign', () {
        expect(CurrencyHelper.normalizeDecimalInput('\u00A350.00'), '50.00');
      });

      test('strips yen sign', () {
        expect(CurrencyHelper.normalizeDecimalInput('\u00A51234'), '1234');
      });

      test('strips rupee sign', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('\u20B91234.56'), '1234.56');
      });

      test('strips multi-char symbols like A\$', () {
        expect(CurrencyHelper.normalizeDecimalInput('A\$1234.56'), '1234.56');
      });

      test('strips HK\$ symbol', () {
        expect(CurrencyHelper.normalizeDecimalInput('HK\$500.00'), '500.00');
      });

      test('strips R\$ (BRL)', () {
        expect(CurrencyHelper.normalizeDecimalInput('R\$1.234,56'), '1234.56');
      });
    });

    group('currency code stripping', () {
      test('strips USD code', () {
        expect(CurrencyHelper.normalizeDecimalInput('USD 1234.56'), '1234.56');
      });

      test('strips EUR code', () {
        expect(CurrencyHelper.normalizeDecimalInput('EUR 1234,56'), '1234.56');
      });
    });

    group('thousands separator handling', () {
      test('strips US-style thousands from pasted banking value', () {
        expect(CurrencyHelper.normalizeDecimalInput('\$1,234.56'), '1234.56');
      });

      test('strips European-style thousands from pasted value', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('\u20AC1.234,56'), '1234.56');
      });

      test('handles Swiss format with apostrophe thousands', () {
        expect(CurrencyHelper.normalizeDecimalInput("1'234.56"), '1234.56');
      });

      test('handles space thousands (French style)', () {
        expect(CurrencyHelper.normalizeDecimalInput('1 234,56'), '1234.56');
      });
    });

    group('decimal separator normalization', () {
      test('normalizes comma to dot', () {
        expect(CurrencyHelper.normalizeDecimalInput('12,50'), '12.50');
      });

      test('preserves existing dot decimal', () {
        expect(CurrencyHelper.normalizeDecimalInput('12.50'), '12.50');
      });

      test('normalizes Arabic decimal separator', () {
        // U+066B Arabic decimal separator
        expect(CurrencyHelper.normalizeDecimalInput('12\u066B50'), '12.50');
      });

      test('normalizes Arabic comma', () {
        // U+060C Arabic comma
        expect(CurrencyHelper.normalizeDecimalInput('12\u060C50'), '12.50');
      });
    });

    group('multiple dots handling', () {
      test('keeps only the last dot when multiple exist', () {
        // e.g., user error entering "12.34.56" -> "1234.56"
        expect(CurrencyHelper.normalizeDecimalInput('12.34.56'), '1234.56');
      });

      test('handles three dots', () {
        expect(CurrencyHelper.normalizeDecimalInput('1.2.3.4'), '123.4');
      });
    });

    group('edge cases', () {
      test('empty string returns empty (after trim)', () {
        expect(CurrencyHelper.normalizeDecimalInput(''), '');
      });

      test('whitespace-only input returns empty', () {
        expect(CurrencyHelper.normalizeDecimalInput('   '), '');
      });

      test('plain integer unchanged', () {
        expect(CurrencyHelper.normalizeDecimalInput('1234'), '1234');
      });

      test('leading/trailing whitespace stripped', () {
        expect(CurrencyHelper.normalizeDecimalInput('  50.00  '), '50.00');
      });

      test('handles a complex pasted banking value', () {
        expect(CurrencyHelper.normalizeDecimalInput('\$1,234,567.89'),
            '1234567.89');
      });

      test('handles European pasted banking value', () {
        expect(CurrencyHelper.normalizeDecimalInput('\u20AC1.234.567,89'),
            '1234567.89');
      });
    });
  });

  // =========================================================================
  // parseDecimal()
  // =========================================================================
  group('parseDecimal', () {
    test('parses standard US decimal', () {
      expect(CurrencyHelper.parseDecimal('1234.56'), 1234.56);
    });

    test('parses European comma decimal', () {
      expect(CurrencyHelper.parseDecimal('1234,56'), 1234.56);
    });

    test('parses pasted US banking value with \$ and thousands', () {
      expect(CurrencyHelper.parseDecimal('\$1,234.56'), 1234.56);
    });

    test('parses pasted European banking value', () {
      expect(CurrencyHelper.parseDecimal('\u20AC1.234,56'), 1234.56);
    });

    test('parses Swiss format', () {
      expect(CurrencyHelper.parseDecimal("1'234.56"), 1234.56);
    });

    test('parses integer', () {
      expect(CurrencyHelper.parseDecimal('1234'), 1234.0);
    });

    test('parses zero', () {
      expect(CurrencyHelper.parseDecimal('0'), 0.0);
    });

    test('parses small decimal', () {
      expect(CurrencyHelper.parseDecimal('0.01'), 0.01);
    });

    test('returns null for empty string', () {
      expect(CurrencyHelper.parseDecimal(''), isNull);
    });

    test('returns null for whitespace only', () {
      expect(CurrencyHelper.parseDecimal('   '), isNull);
    });

    test('returns null for non-numeric text', () {
      expect(CurrencyHelper.parseDecimal('abc'), isNull);
    });

    test('returns null for pure text with no digits', () {
      expect(CurrencyHelper.parseDecimal('hello world'), isNull);
    });

    test('parses negative numbers after normalization', () {
      // The negative sign should be preserved through normalization
      expect(CurrencyHelper.parseDecimal('-50.00'), -50.0);
    });

    test('parses very large number', () {
      expect(CurrencyHelper.parseDecimal('999999999.99'),
          closeTo(999999999.99, 0.01));
    });

    test('handles value with just a currency symbol', () {
      // "\$" -> "" after symbol stripping -> null
      expect(CurrencyHelper.parseDecimal('\$'), isNull);
    });
  });

  // =========================================================================
  // decimalInputFormatter()
  // =========================================================================
  group('decimalInputFormatter', () {
    late TextInputFormatter formatter;

    setUp(() {
      formatter = CurrencyHelper.decimalInputFormatter();
    });

    TextEditingValue apply(String oldText, String newText) {
      return formatter.formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        ),
      );
    }

    test('allows empty input', () {
      final result = apply('', '');
      expect(result.text, '');
    });

    test('allows single digit', () {
      final result = apply('', '5');
      expect(result.text, '5');
    });

    test('allows integer', () {
      final result = apply('', '123');
      expect(result.text, '123');
    });

    test('allows decimal with dot', () {
      final result = apply('', '12.34');
      expect(result.text, '12.34');
    });

    test('allows decimal with 1 digit after dot', () {
      final result = apply('', '12.3');
      expect(result.text, '12.3');
    });

    test('allows leading dot (e.g., ".5")', () {
      final result = apply('', '.5');
      expect(result.text, '.5');
    });

    test('allows dot without trailing digits (e.g., "12.")', () {
      final result = apply('', '12.');
      expect(result.text, '12.');
    });

    test('rejects more than 2 decimal places', () {
      final result = apply('12.34', '12.345');
      // Should reject and keep old value
      expect(result.text, '12.34');
    });

    test('rejects alphabetic characters', () {
      final result = apply('12', '12a');
      expect(result.text, '12');
    });

    test('normalizes comma decimal to dot and accepts if valid', () {
      // Typing "12,50" -> normalizes to "12.50" which is valid
      final result = apply('', '12,50');
      // After normalization, the formatter should return "12.50"
      expect(result.text, '12.50');
    });

    test('handles pasted value with thousands separator', () {
      // Pasting "1,234.56" -> normalized to "1234.56"
      final result = apply('', '1,234.56');
      expect(result.text, '1234.56');
    });

    test('rejects multiple dots after normalization', () {
      // If input after normalization still fails regex
      final result = apply('12.34', '12.34.5');
      // Normalization collapses dots: "1234.5" which is valid
      // But the regex check happens after normalization
      // "12.34.5" -> normalizeDecimalInput -> "1234.5" -> passes regex
      expect(result.text, '1234.5');
    });

    test('rejects special characters', () {
      final result = apply('12', '12!');
      expect(result.text, '12');
    });
  });

  // =========================================================================
  // sanitizeText()
  // =========================================================================
  group('sanitizeText', () {
    test('returns empty string for empty input', () {
      expect(CurrencyHelper.sanitizeText(''), '');
    });

    test('trims leading and trailing whitespace', () {
      expect(CurrencyHelper.sanitizeText('  hello  '), 'hello');
    });

    test('removes null characters (\\x00)', () {
      expect(CurrencyHelper.sanitizeText('hello\x00world'), 'helloworld');
    });

    test('removes tab characters (\\x09)', () {
      expect(CurrencyHelper.sanitizeText('hello\tworld'), 'helloworld');
    });

    test('removes newline characters (\\x0A)', () {
      expect(CurrencyHelper.sanitizeText('hello\nworld'), 'helloworld');
    });

    test('removes carriage return characters (\\x0D)', () {
      expect(CurrencyHelper.sanitizeText('hello\rworld'), 'helloworld');
    });

    test('removes escape character (\\x1B)', () {
      expect(CurrencyHelper.sanitizeText('hello\x1Bworld'), 'helloworld');
    });

    test('removes DEL character (\\x7F)', () {
      expect(CurrencyHelper.sanitizeText('hello\x7Fworld'), 'helloworld');
    });

    test('removes multiple control characters at once', () {
      expect(CurrencyHelper.sanitizeText('\x00hello\x01\x02world\x1F'),
          'helloworld');
    });

    test('limits length to default maxLength (200)', () {
      final longInput = 'a' * 300;
      final result = CurrencyHelper.sanitizeText(longInput);
      expect(result.length, 200);
    });

    test('limits length to custom maxLength', () {
      final longInput = 'a' * 100;
      final result = CurrencyHelper.sanitizeText(longInput, maxLength: 50);
      expect(result.length, 50);
    });

    test('does not truncate strings shorter than maxLength', () {
      final result = CurrencyHelper.sanitizeText('hello', maxLength: 50);
      expect(result, 'hello');
      expect(result.length, 5);
    });

    test('preserves normal text with no control characters', () {
      expect(
          CurrencyHelper.sanitizeText('Hello World 123!'), 'Hello World 123!');
    });

    test('preserves Unicode characters (non-control)', () {
      expect(CurrencyHelper.sanitizeText('\u20AC\u00A3\u00A5'),
          '\u20AC\u00A3\u00A5');
    });

    test('trims before removing control chars and truncating', () {
      // Leading/trailing whitespace is trimmed first
      final input = '  \x00hello\x01  ';
      final result = CurrencyHelper.sanitizeText(input);
      expect(result, 'hello');
    });

    test('handles string that is all control characters', () {
      expect(CurrencyHelper.sanitizeText('\x00\x01\x02\x03'), '');
    });

    test('handles maxLength of 0', () {
      expect(CurrencyHelper.sanitizeText('hello', maxLength: 0), '');
    });

    test('handles maxLength of 1', () {
      expect(CurrencyHelper.sanitizeText('hello', maxLength: 1), 'h');
    });
  });

  // =========================================================================
  // Static constants / maps
  // =========================================================================
  group('currencies map', () {
    test('all keys are 3-letter uppercase strings', () {
      for (final key in CurrencyHelper.currencies.keys) {
        expect(key.length, 3);
        expect(key, equals(key.toUpperCase()));
      }
    });

    test('all values are non-empty strings', () {
      for (final value in CurrencyHelper.currencies.values) {
        expect(value, isNotEmpty);
      }
    });

    test('contains expected number of currencies', () {
      // From the source: 25 currencies
      expect(CurrencyHelper.currencies.length, 25);
    });

    test('JPY and CNY both map to yen sign', () {
      expect(CurrencyHelper.currencies['JPY'], '\u00A5');
      expect(CurrencyHelper.currencies['CNY'], '\u00A5');
    });
  });

  group('currencyLocales map', () {
    test('has the same keys as currencies map', () {
      // Every currency should have a locale mapping
      for (final code in CurrencyHelper.currencies.keys) {
        expect(CurrencyHelper.currencyLocales.containsKey(code), isTrue,
            reason: '$code should have a locale mapping');
      }
    });
  });

  // =========================================================================
  // Integration / cross-method tests
  // =========================================================================
  group('integration tests', () {
    test('parseDecimal -> formatAmount round-trip preserves value', () {
      final parsed = CurrencyHelper.parseDecimal('1234.56');
      expect(parsed, isNotNull);
      final formatted = CurrencyHelper.formatAmount(parsed!, 'USD');
      expect(formatted, '1,234.56');
    });

    test('getSymbol + formatWithSymbol produces expected output', () {
      final symbol = CurrencyHelper.getSymbol('EUR');
      final result = CurrencyHelper.formatWithSymbol(99.99, symbol, 'EUR');
      expect(result, startsWith('\u20AC'));
      expect(result, contains('99'));
    });

    test('European pasted value: normalize -> parse -> format round-trip', () {
      final parsed = CurrencyHelper.parseDecimal('\u20AC1.234,56');
      expect(parsed, 1234.56);
      final formatted = CurrencyHelper.formatAmount(parsed!, 'EUR');
      expect(formatted, '1.234,56');
    });

    test('US pasted value: normalize -> parse -> format round-trip', () {
      final parsed = CurrencyHelper.parseDecimal('\$1,234.56');
      expect(parsed, 1234.56);
      final formatted = CurrencyHelper.formatAmount(parsed!, 'USD');
      expect(formatted, '1,234.56');
    });

    test('all currencies in currencyList have a symbol and name', () {
      for (final code in CurrencyHelper.currencyList) {
        expect(CurrencyHelper.getSymbol(code), isNotEmpty,
            reason: '$code should have a symbol');
        expect(CurrencyHelper.getName(code), isNotEmpty,
            reason: '$code should have a name');
        expect(CurrencyHelper.getName(code), isNot(equals(code)),
            reason: '$code name should not be the code itself');
      }
    });
  });
}
