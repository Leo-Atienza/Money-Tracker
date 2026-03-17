import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:budget_tracker/utils/csv_exporter.dart';

/// Recreates the private `_escapeCsv` logic for testing purposes.
/// This mirrors the implementation in CsvExporter exactly.
String escapeCsv(String value, CsvSeparator separator) {
  if (value.isEmpty) return value;

  String result = value;

  // Prevent formula injection
  const dangerousPrefixes = ['=', '+', '-', '@', '\t', '\r'];
  if (dangerousPrefixes.any((prefix) => result.startsWith(prefix))) {
    result = "'$result";
  }

  // Quote fields containing separator, double-quotes, or newlines
  if (result.contains(separator.value) ||
      result.contains('"') ||
      result.contains('\n')) {
    return '"${result.replaceAll('"', '""')}"';
  }
  return result;
}

/// Recreates the private `_formatNumber` logic for testing purposes.
String formatNumber(double value, CsvSeparator separator) {
  final NumberFormat formatter;

  if (separator == CsvSeparator.semicolon) {
    formatter = NumberFormat.decimalPattern('de_DE');
  } else {
    formatter = NumberFormat.decimalPattern('en_US');
  }

  formatter.minimumFractionDigits = 2;
  formatter.maximumFractionDigits = 2;

  return formatter.format(value);
}

void main() {
  // -----------------------------------------------------------------
  // 1. CsvSeparator enum
  // -----------------------------------------------------------------
  group('CsvSeparator', () {
    group('value property', () {
      test('comma separator has value ","', () {
        expect(CsvSeparator.comma.value, ',');
      });

      test('semicolon separator has value ";"', () {
        expect(CsvSeparator.semicolon.value, ';');
      });
    });

    group('fromLocale - non-European locales return comma', () {
      test('en_US returns comma', () {
        expect(CsvSeparator.fromLocale('en_US'), CsvSeparator.comma);
      });

      test('ja_JP returns comma', () {
        expect(CsvSeparator.fromLocale('ja_JP'), CsvSeparator.comma);
      });

      test('ko returns comma', () {
        expect(CsvSeparator.fromLocale('ko'), CsvSeparator.comma);
      });

      test('zh_CN returns comma', () {
        expect(CsvSeparator.fromLocale('zh_CN'), CsvSeparator.comma);
      });

      test('ar returns comma', () {
        expect(CsvSeparator.fromLocale('ar'), CsvSeparator.comma);
      });

      test('en returns comma', () {
        expect(CsvSeparator.fromLocale('en'), CsvSeparator.comma);
      });

      test('en_GB returns comma', () {
        expect(CsvSeparator.fromLocale('en_GB'), CsvSeparator.comma);
      });
    });

    group('fromLocale - European locales return semicolon', () {
      test('de_DE returns semicolon', () {
        expect(CsvSeparator.fromLocale('de_DE'), CsvSeparator.semicolon);
      });

      test('fr_FR returns semicolon', () {
        expect(CsvSeparator.fromLocale('fr_FR'), CsvSeparator.semicolon);
      });

      test('es_ES returns semicolon', () {
        expect(CsvSeparator.fromLocale('es_ES'), CsvSeparator.semicolon);
      });

      test('it_IT returns semicolon', () {
        expect(CsvSeparator.fromLocale('it_IT'), CsvSeparator.semicolon);
      });

      test('nl_NL returns semicolon', () {
        expect(CsvSeparator.fromLocale('nl_NL'), CsvSeparator.semicolon);
      });

      test('pl_PL returns semicolon', () {
        expect(CsvSeparator.fromLocale('pl_PL'), CsvSeparator.semicolon);
      });

      test('pt_BR returns semicolon', () {
        expect(CsvSeparator.fromLocale('pt_BR'), CsvSeparator.semicolon);
      });

      test('ru_RU returns semicolon', () {
        expect(CsvSeparator.fromLocale('ru_RU'), CsvSeparator.semicolon);
      });

      test('sv returns semicolon', () {
        expect(CsvSeparator.fromLocale('sv'), CsvSeparator.semicolon);
      });

      test('da returns semicolon', () {
        expect(CsvSeparator.fromLocale('da'), CsvSeparator.semicolon);
      });

      test('fi returns semicolon', () {
        expect(CsvSeparator.fromLocale('fi'), CsvSeparator.semicolon);
      });

      test('no returns semicolon', () {
        expect(CsvSeparator.fromLocale('no'), CsvSeparator.semicolon);
      });

      test('cs returns semicolon', () {
        expect(CsvSeparator.fromLocale('cs'), CsvSeparator.semicolon);
      });

      test('el returns semicolon', () {
        expect(CsvSeparator.fromLocale('el'), CsvSeparator.semicolon);
      });

      test('hu returns semicolon', () {
        expect(CsvSeparator.fromLocale('hu'), CsvSeparator.semicolon);
      });

      test('ro returns semicolon', () {
        expect(CsvSeparator.fromLocale('ro'), CsvSeparator.semicolon);
      });

      test('sk returns semicolon', () {
        expect(CsvSeparator.fromLocale('sk'), CsvSeparator.semicolon);
      });

      test('tr returns semicolon', () {
        expect(CsvSeparator.fromLocale('tr'), CsvSeparator.semicolon);
      });

      test('bg returns semicolon', () {
        expect(CsvSeparator.fromLocale('bg'), CsvSeparator.semicolon);
      });

      test('hr returns semicolon', () {
        expect(CsvSeparator.fromLocale('hr'), CsvSeparator.semicolon);
      });

      test('et returns semicolon', () {
        expect(CsvSeparator.fromLocale('et'), CsvSeparator.semicolon);
      });

      test('lv returns semicolon', () {
        expect(CsvSeparator.fromLocale('lv'), CsvSeparator.semicolon);
      });

      test('lt returns semicolon', () {
        expect(CsvSeparator.fromLocale('lt'), CsvSeparator.semicolon);
      });

      test('sl returns semicolon', () {
        expect(CsvSeparator.fromLocale('sl'), CsvSeparator.semicolon);
      });
    });

    group('fromLocale - extracts language code correctly', () {
      test('handles locale with country code (de_DE)', () {
        expect(CsvSeparator.fromLocale('de_DE'), CsvSeparator.semicolon);
      });

      test('handles locale without country code (de)', () {
        expect(CsvSeparator.fromLocale('de'), CsvSeparator.semicolon);
      });

      test('handles uppercase language code (DE_de)', () {
        // The code lowercases the language portion
        expect(CsvSeparator.fromLocale('DE_de'), CsvSeparator.semicolon);
      });

      test('handles mixed case (Fr_fr)', () {
        expect(CsvSeparator.fromLocale('Fr_fr'), CsvSeparator.semicolon);
      });
    });
  });

  // -----------------------------------------------------------------
  // 2. CSV escaping logic (testing recreated _escapeCsv)
  // -----------------------------------------------------------------
  group('CSV escaping logic', () {
    group('formula injection prevention', () {
      test('equals sign gets prefixed with single quote', () {
        final result = escapeCsv('=SUM(A1:A10)', CsvSeparator.comma);
        expect(result, startsWith("'"));
        expect(result, contains('=SUM'));
      });

      test('plus sign gets prefixed with single quote', () {
        final result = escapeCsv('+cmd', CsvSeparator.comma);
        expect(result, equals("'+cmd"));
      });

      test('minus sign gets prefixed with single quote', () {
        final result = escapeCsv('-value', CsvSeparator.comma);
        expect(result, equals("'-value"));
      });

      test('at sign gets prefixed with single quote', () {
        final result = escapeCsv('@SUM(A1)', CsvSeparator.comma);
        expect(result, equals("'@SUM(A1)"));
      });

      test('tab character gets prefixed with single quote', () {
        final result = escapeCsv('\tdata', CsvSeparator.comma);
        expect(result, equals("'\tdata"));
      });

      test('carriage return gets prefixed with single quote', () {
        final result = escapeCsv('\rdata', CsvSeparator.comma);
        expect(result, equals("'\rdata"));
      });

      test('formula injection with comma separator also quotes if contains comma', () {
        final result = escapeCsv('=A1,B1', CsvSeparator.comma);
        // Should be prefixed AND quoted because it contains comma
        expect(result, equals("\"'=A1,B1\""));
      });
    });

    group('quoting for separator characters', () {
      test('field containing comma gets quoted (comma separator)', () {
        final result = escapeCsv('hello, world', CsvSeparator.comma);
        expect(result, equals('"hello, world"'));
      });

      test('field containing semicolon gets quoted (semicolon separator)', () {
        final result = escapeCsv('hello; world', CsvSeparator.semicolon);
        expect(result, equals('"hello; world"'));
      });

      test('field containing comma is NOT quoted with semicolon separator', () {
        final result = escapeCsv('hello, world', CsvSeparator.semicolon);
        expect(result, equals('hello, world'));
      });

      test('field containing semicolon is NOT quoted with comma separator', () {
        final result = escapeCsv('hello; world', CsvSeparator.comma);
        expect(result, equals('hello; world'));
      });
    });

    group('double-quote handling', () {
      test('field with quotes gets double-quoted and wrapped', () {
        final result = escapeCsv('say "hello"', CsvSeparator.comma);
        expect(result, equals('"say ""hello"""'));
      });

      test('field with only a quote', () {
        final result = escapeCsv('"', CsvSeparator.comma);
        expect(result, equals('""""'));
      });

      test('field with quotes and separator', () {
        final result = escapeCsv('a "b", c', CsvSeparator.comma);
        expect(result, equals('"a ""b"", c"'));
      });
    });

    group('newline handling', () {
      test('field with newline gets quoted', () {
        final result = escapeCsv('line1\nline2', CsvSeparator.comma);
        expect(result, equals('"line1\nline2"'));
      });

      test('field with newline and quotes', () {
        final result = escapeCsv('line1\n"line2"', CsvSeparator.comma);
        expect(result, equals('"line1\n""line2"""'));
      });
    });

    group('pass-through cases', () {
      test('empty field passes through unchanged', () {
        expect(escapeCsv('', CsvSeparator.comma), equals(''));
      });

      test('normal text passes through unchanged', () {
        expect(escapeCsv('Groceries', CsvSeparator.comma), equals('Groceries'));
      });

      test('digits pass through unchanged', () {
        expect(escapeCsv('12345', CsvSeparator.comma), equals('12345'));
      });

      test('simple category name passes through', () {
        expect(escapeCsv('Food & Drink', CsvSeparator.comma),
            equals('Food & Drink'));
      });
    });

    group('combined edge cases', () {
      test('formula injection prefix with newline gets both treatments', () {
        final result = escapeCsv('=formula\nnewline', CsvSeparator.comma);
        // Prefixed with ' for injection, then quoted for newline
        expect(result, equals("\"'=formula\nnewline\""));
      });

      test('minus prefix with separator gets both treatments', () {
        final result = escapeCsv('-100,50', CsvSeparator.comma);
        // Prefixed with ' for injection, then quoted for comma
        expect(result, equals("\"'-100,50\""));
      });
    });
  });

  // -----------------------------------------------------------------
  // 3. Number formatting logic (testing recreated _formatNumber)
  // -----------------------------------------------------------------
  group('Number formatting logic', () {
    group('comma separator uses en_US locale (dot decimal)', () {
      test('integer value gets .00 suffix', () {
        expect(formatNumber(100.0, CsvSeparator.comma), equals('100.00'));
      });

      test('value with decimals formatted to 2 places', () {
        expect(formatNumber(42.5, CsvSeparator.comma), equals('42.50'));
      });

      test('value with many decimals truncated to 2 places', () {
        expect(formatNumber(42.567, CsvSeparator.comma), equals('42.57'));
      });

      test('zero is formatted as 0.00', () {
        expect(formatNumber(0.0, CsvSeparator.comma), equals('0.00'));
      });

      test('large number gets thousand separator with comma', () {
        final result = formatNumber(1234567.89, CsvSeparator.comma);
        expect(result, equals('1,234,567.89'));
      });

      test('small decimal value', () {
        expect(formatNumber(0.01, CsvSeparator.comma), equals('0.01'));
      });

      test('negative value', () {
        final result = formatNumber(-500.75, CsvSeparator.comma);
        expect(result, contains('500.75'));
      });
    });

    group('semicolon separator uses de_DE locale (comma decimal)', () {
      test('integer value gets comma-separated decimals', () {
        expect(formatNumber(100.0, CsvSeparator.semicolon), equals('100,00'));
      });

      test('value with decimals uses comma', () {
        expect(formatNumber(42.5, CsvSeparator.semicolon), equals('42,50'));
      });

      test('value rounded to 2 decimal places', () {
        expect(formatNumber(42.567, CsvSeparator.semicolon), equals('42,57'));
      });

      test('zero is formatted as 0,00', () {
        expect(formatNumber(0.0, CsvSeparator.semicolon), equals('0,00'));
      });

      test('large number uses dot as thousand separator', () {
        final result = formatNumber(1234567.89, CsvSeparator.semicolon);
        expect(result, equals('1.234.567,89'));
      });

      test('small decimal value', () {
        expect(formatNumber(0.01, CsvSeparator.semicolon), equals('0,01'));
      });
    });

    group('exactly 2 decimal places always', () {
      test('integer gets 2 decimals (comma)', () {
        expect(formatNumber(5.0, CsvSeparator.comma), equals('5.00'));
      });

      test('integer gets 2 decimals (semicolon)', () {
        expect(formatNumber(5.0, CsvSeparator.semicolon), equals('5,00'));
      });

      test('one decimal digit gets padded (comma)', () {
        expect(formatNumber(5.1, CsvSeparator.comma), equals('5.10'));
      });

      test('one decimal digit gets padded (semicolon)', () {
        expect(formatNumber(5.1, CsvSeparator.semicolon), equals('5,10'));
      });

      test('three decimal digits get rounded (comma)', () {
        expect(formatNumber(5.125, CsvSeparator.comma), equals('5.13'));
      });

      test('three decimal digits get rounded (semicolon)', () {
        expect(formatNumber(5.125, CsvSeparator.semicolon), equals('5,13'));
      });

      test('rounding at .005 boundary (comma)', () {
        // 5.005 in IEEE 754 is actually 5.00499... so it rounds down
        expect(formatNumber(5.005, CsvSeparator.comma), equals('5.00'));
      });

      test('very small amount (comma)', () {
        expect(formatNumber(0.001, CsvSeparator.comma), equals('0.00'));
      });
    });
  });

  // -----------------------------------------------------------------
  // 4. CsvSeparator enum completeness
  // -----------------------------------------------------------------
  group('CsvSeparator enum completeness', () {
    test('enum has exactly 2 values', () {
      expect(CsvSeparator.values.length, 2);
    });

    test('enum values are comma and semicolon', () {
      expect(CsvSeparator.values, contains(CsvSeparator.comma));
      expect(CsvSeparator.values, contains(CsvSeparator.semicolon));
    });

    test('comma and semicolon have different values', () {
      expect(CsvSeparator.comma.value, isNot(CsvSeparator.semicolon.value));
    });
  });
}
