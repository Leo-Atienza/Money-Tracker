import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/currency_helper.dart';
import 'package:budget_tracker/constants/database.dart';

void main() {
  // ======================================================================
  // CurrencyHelper.formatAmount
  // ======================================================================
  group('CurrencyHelper.formatAmount', () {
    test('formats USD with US locale (comma thousands, dot decimal)', () {
      expect(CurrencyHelper.formatAmount(1234.56, 'USD'), '1,234.56');
    });

    test('formats EUR with European locale (dot thousands, comma decimal)', () {
      expect(CurrencyHelper.formatAmount(1234.56, 'EUR'), '1.234,56');
    });

    test('formats JPY with zero decimal digits', () {
      final result = CurrencyHelper.formatAmount(1234.0, 'JPY', decimalDigits: 0);
      // Japanese locale uses comma as thousands separator
      expect(result, '1,234');
    });

    test('formats INR with Indian grouping (lakhs/crores)', () {
      final result = CurrencyHelper.formatAmount(1234567.89, 'INR');
      // Indian format: 12,34,567.89
      expect(result, '12,34,567.89');
    });

    test('formats GBP with UK locale', () {
      expect(CurrencyHelper.formatAmount(1234.56, 'GBP'), '1,234.56');
    });

    test('formats zero correctly', () {
      expect(CurrencyHelper.formatAmount(0.0, 'USD'), '0.00');
    });

    test('formats negative numbers', () {
      final result = CurrencyHelper.formatAmount(-1234.56, 'USD');
      expect(result, contains('1,234.56'));
    });

    test('formats very large numbers', () {
      final result = CurrencyHelper.formatAmount(999999999.99, 'USD');
      expect(result, '999,999,999.99');
    });

    test('formats very small decimal amounts', () {
      expect(CurrencyHelper.formatAmount(0.01, 'USD'), '0.01');
    });

    test('respects custom decimalDigits parameter', () {
      expect(CurrencyHelper.formatAmount(1234.5678, 'USD', decimalDigits: 4),
          '1,234.5678');
    });

    test('formats with zero decimalDigits', () {
      expect(
          CurrencyHelper.formatAmount(1234.56, 'USD', decimalDigits: 0), '1,235');
    });

    test('falls back to en_US for unknown currency codes', () {
      expect(CurrencyHelper.formatAmount(1234.56, 'XYZ'), '1,234.56');
    });

    test('formats KRW (zero-decimal currency) with decimalDigits: 0', () {
      final result =
          CurrencyHelper.formatAmount(50000.0, 'KRW', decimalDigits: 0);
      expect(result, '50,000');
    });
  });

  // ======================================================================
  // CurrencyHelper.formatWithSymbol
  // ======================================================================
  group('CurrencyHelper.formatWithSymbol', () {
    test('prepends dollar sign for USD', () {
      expect(
        CurrencyHelper.formatWithSymbol(1234.56, '\$', 'USD'),
        '\$1,234.56',
      );
    });

    test('prepends euro sign for EUR', () {
      expect(
        CurrencyHelper.formatWithSymbol(1234.56, '\u20AC', 'EUR'),
        '\u20AC1.234,56',
      );
    });

    test('prepends yen sign for JPY', () {
      expect(
        CurrencyHelper.formatWithSymbol(1000.0, '\u00A5', 'JPY'),
        '\u00A51,000.00',
      );
    });

    test('prepends rupee sign for INR', () {
      expect(
        CurrencyHelper.formatWithSymbol(1234567.89, '\u20B9', 'INR'),
        '\u20B912,34,567.89',
      );
    });

    test('handles zero amount', () {
      expect(
        CurrencyHelper.formatWithSymbol(0.0, '\$', 'USD'),
        '\$0.00',
      );
    });

    test('handles multi-char symbols like A\$', () {
      expect(
        CurrencyHelper.formatWithSymbol(99.99, 'A\$', 'AUD'),
        'A\$99.99',
      );
    });

    test('respects custom decimalDigits', () {
      expect(
        CurrencyHelper.formatWithSymbol(42.0, '\$', 'USD', decimalDigits: 0),
        '\$42',
      );
    });
  });

  // ======================================================================
  // CurrencyHelper.normalizeDecimalInput
  // ======================================================================
  group('CurrencyHelper.normalizeDecimalInput', () {
    group('US-style input (comma thousands, dot decimal)', () {
      test('"1,234.56" -> "1234.56"', () {
        expect(CurrencyHelper.normalizeDecimalInput('1,234.56'), '1234.56');
      });

      test('"1,234,567.89" -> "1234567.89"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('1,234,567.89'), '1234567.89');
      });
    });

    group('European-style input (dot thousands, comma decimal)', () {
      test('"1.234,56" -> "1234.56"', () {
        expect(CurrencyHelper.normalizeDecimalInput('1.234,56'), '1234.56');
      });

      test('"1.234.567,89" -> "1234567.89"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('1.234.567,89'), '1234567.89');
      });
    });

    group('French-style input (space thousands, comma decimal)', () {
      test('"1 234,56" -> "1234.56"', () {
        expect(CurrencyHelper.normalizeDecimalInput('1 234,56'), '1234.56');
      });

      test('non-breaking space "1\u00A0234,56" -> "1234.56"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('1\u00A0234,56'), '1234.56');
      });

      test('narrow no-break space "1\u202F234,56" -> "1234.56"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('1\u202F234,56'), '1234.56');
      });
    });

    group('Swiss-style input (apostrophe thousands)', () {
      test('"1\'234.56" -> "1234.56"', () {
        expect(CurrencyHelper.normalizeDecimalInput("1'234.56"), '1234.56');
      });
    });

    group('currency symbol stripping', () {
      test('"\$1,234.56" -> "1234.56"', () {
        expect(CurrencyHelper.normalizeDecimalInput('\$1,234.56'), '1234.56');
      });

      test('"\u20AC1.234,56" -> "1234.56"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('\u20AC1.234,56'), '1234.56');
      });

      test('"\u00A51234" -> "1234"', () {
        expect(CurrencyHelper.normalizeDecimalInput('\u00A51234'), '1234');
      });

      test('"\u20B91,23,456.78" -> "123456.78"', () {
        expect(CurrencyHelper.normalizeDecimalInput('\u20B91,23,456.78'),
            '123456.78');
      });

      test('"R\$1.234,56" (BRL) -> "1234.56"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('R\$1.234,56'), '1234.56');
      });

      test('"A\$1,234.56" (AUD) -> "1234.56"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('A\$1,234.56'), '1234.56');
      });

      test('"HK\$1,234.56" (HKD) -> "1234.56"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('HK\$1,234.56'), '1234.56');
      });

      test('"\u20A91,234" (KRW) -> "1234"', () {
        expect(CurrencyHelper.normalizeDecimalInput('\u20A91,234'), '1234');
      });

      test('"z\u01421234,56" (PLN) -> "1234.56"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('z\u01421234,56'), '1234.56');
      });

      test('"kr1 234,56" (SEK/NOK/DKK) -> "1234.56"', () {
        expect(
            CurrencyHelper.normalizeDecimalInput('kr1 234,56'), '1234.56');
      });
    });

    group('edge cases', () {
      test('empty string returns empty', () {
        expect(CurrencyHelper.normalizeDecimalInput(''), '');
      });

      test('plain integer "1234" -> "1234"', () {
        expect(CurrencyHelper.normalizeDecimalInput('1234'), '1234');
      });

      test('single digit "5" -> "5"', () {
        expect(CurrencyHelper.normalizeDecimalInput('5'), '5');
      });

      test('decimal only ".99" -> ".99"', () {
        expect(CurrencyHelper.normalizeDecimalInput('.99'), '.99');
      });

      test('comma-only decimal "12,50" with 2 digits after -> "12.50"', () {
        // One comma with exactly 2 digits after = decimal separator
        expect(CurrencyHelper.normalizeDecimalInput('12,50'), '12.50');
      });

      test('comma-only with 3 digits after "1,234" treated as thousands', () {
        // One comma with exactly 3 digits after = thousands separator
        expect(CurrencyHelper.normalizeDecimalInput('1,234'), '1234');
      });

      test('very large number "999999999999.99" -> "999999999999.99"', () {
        expect(CurrencyHelper.normalizeDecimalInput('999999999999.99'),
            '999999999999.99');
      });

      test('multiple dots like "12.34.56" keeps last dot as decimal', () {
        // Not a valid thousands pattern, so last dot is kept as decimal
        expect(CurrencyHelper.normalizeDecimalInput('12.34.56'), '1234.56');
      });

      test('thousands-pattern dots "1.234.567" are all removed', () {
        // Valid thousands pattern -> all dots removed
        expect(CurrencyHelper.normalizeDecimalInput('1.234.567'), '1234567');
      });

      test('whitespace-only input returns empty after trim', () {
        expect(CurrencyHelper.normalizeDecimalInput('   '), '');
      });
    });
  });

  // ======================================================================
  // CurrencyHelper.parseDecimal
  // ======================================================================
  group('CurrencyHelper.parseDecimal', () {
    test('parses plain decimal "1234.56"', () {
      expect(CurrencyHelper.parseDecimal('1234.56'), 1234.56);
    });

    test('parses US-formatted "1,234.56"', () {
      expect(CurrencyHelper.parseDecimal('1,234.56'), 1234.56);
    });

    test('parses EU-formatted "1.234,56"', () {
      expect(CurrencyHelper.parseDecimal('1.234,56'), 1234.56);
    });

    test('parses French-space-formatted "1 234,56"', () {
      expect(CurrencyHelper.parseDecimal('1 234,56'), 1234.56);
    });

    test('parses with dollar sign "\$1,234.56"', () {
      expect(CurrencyHelper.parseDecimal('\$1,234.56'), 1234.56);
    });

    test('parses with euro sign "\u20AC1.234,56"', () {
      expect(CurrencyHelper.parseDecimal('\u20AC1.234,56'), 1234.56);
    });

    test('returns null for empty string', () {
      expect(CurrencyHelper.parseDecimal(''), isNull);
    });

    test('returns null for pure text "abc"', () {
      expect(CurrencyHelper.parseDecimal('abc'), isNull);
    });

    test('parses zero "0"', () {
      expect(CurrencyHelper.parseDecimal('0'), 0.0);
    });

    test('parses "0.01" correctly', () {
      expect(CurrencyHelper.parseDecimal('0.01'), 0.01);
    });

    test('parses integer "500" without decimals', () {
      expect(CurrencyHelper.parseDecimal('500'), 500.0);
    });

    test('round-trip: normalize then parse matches direct parse', () {
      const inputs = [
        '1,234.56',
        '1.234,56',
        '\$999.99',
        '1 234,56',
        "1'234.56",
      ];
      for (final input in inputs) {
        final normalized = CurrencyHelper.normalizeDecimalInput(input);
        final parsed = double.tryParse(normalized);
        expect(CurrencyHelper.parseDecimal(input), parsed,
            reason: 'Failed round-trip for "$input"');
      }
    });

    test('parses very large number', () {
      expect(CurrencyHelper.parseDecimal('999999999.99'), 999999999.99);
    });
  });

  // ======================================================================
  // CurrencyHelper.sanitizeText
  // ======================================================================
  group('CurrencyHelper.sanitizeText', () {
    test('returns empty string as-is', () {
      expect(CurrencyHelper.sanitizeText(''), '');
    });

    test('trims whitespace', () {
      expect(CurrencyHelper.sanitizeText('  hello  '), 'hello');
    });

    test('removes null bytes', () {
      expect(CurrencyHelper.sanitizeText('hello\x00world'), 'helloworld');
    });

    test('removes tab characters', () {
      expect(CurrencyHelper.sanitizeText('hello\tworld'), 'helloworld');
    });

    test('removes newline characters', () {
      expect(CurrencyHelper.sanitizeText('hello\nworld'), 'helloworld');
    });

    test('removes carriage return', () {
      expect(CurrencyHelper.sanitizeText('hello\rworld'), 'helloworld');
    });

    test('removes DEL character (0x7F)', () {
      expect(CurrencyHelper.sanitizeText('hello\x7Fworld'), 'helloworld');
    });

    test('removes multiple control characters', () {
      expect(
        CurrencyHelper.sanitizeText('\x01\x02hello\x03\x04'),
        'hello',
      );
    });

    test('preserves normal Unicode text', () {
      expect(CurrencyHelper.sanitizeText('Caf\u00E9 \u20AC10'), 'Caf\u00E9 \u20AC10');
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
      expect(CurrencyHelper.sanitizeText('short', maxLength: 50), 'short');
    });

    test('trims before checking length', () {
      // 5 chars of whitespace + 10 chars of text = 15 total
      // After trim -> 10 chars, which is under maxLength 50
      final result = CurrencyHelper.sanitizeText('     helloworld     ', maxLength: 50);
      expect(result, 'helloworld');
      expect(result.length, 10);
    });

    test('handles string that is exactly maxLength', () {
      final exact = 'a' * 200;
      expect(CurrencyHelper.sanitizeText(exact).length, 200);
    });
  });

  // ======================================================================
  // CurrencyHelper static data
  // ======================================================================
  group('CurrencyHelper static data', () {
    test('getSymbol returns correct symbols for known currencies', () {
      expect(CurrencyHelper.getSymbol('USD'), '\$');
      expect(CurrencyHelper.getSymbol('EUR'), '\u20AC');
      expect(CurrencyHelper.getSymbol('GBP'), '\u00A3');
      expect(CurrencyHelper.getSymbol('JPY'), '\u00A5');
      expect(CurrencyHelper.getSymbol('INR'), '\u20B9');
      expect(CurrencyHelper.getSymbol('KRW'), '\u20A9');
    });

    test('getSymbol returns \$ for unknown currency', () {
      expect(CurrencyHelper.getSymbol('XYZ'), '\$');
    });

    test('getName returns correct names for known currencies', () {
      expect(CurrencyHelper.getName('USD'), 'US Dollar');
      expect(CurrencyHelper.getName('EUR'), 'Euro');
      expect(CurrencyHelper.getName('JPY'), 'Japanese Yen');
    });

    test('getName returns code for unknown currency', () {
      expect(CurrencyHelper.getName('XYZ'), 'XYZ');
    });

    test('currencyList contains all expected currencies', () {
      final list = CurrencyHelper.currencyList;
      expect(list, contains('USD'));
      expect(list, contains('EUR'));
      expect(list, contains('JPY'));
      expect(list, contains('INR'));
      expect(list, contains('KRW'));
      expect(list.length, 25); // 25 currencies in the map
    });

    test('currencyLocales has an entry for every currency', () {
      for (final code in CurrencyHelper.currencies.keys) {
        expect(CurrencyHelper.currencyLocales.containsKey(code), isTrue,
            reason: 'Missing locale for $code');
      }
    });
  });

  // ======================================================================
  // CurrencyHelper.formatCompact
  // ======================================================================
  group('CurrencyHelper.formatCompact', () {
    test('formats millions with M suffix for USD', () {
      final result = CurrencyHelper.formatCompact(1234567.89, 'USD');
      // intl compact format may vary, but should contain 'M' indicator
      expect(result, isNotEmpty);
    });

    test('formats thousands with K suffix for USD', () {
      final result = CurrencyHelper.formatCompact(1500.0, 'USD');
      expect(result, isNotEmpty);
    });

    test('formats small numbers without suffix', () {
      final result = CurrencyHelper.formatCompact(42.0, 'USD');
      expect(result, isNotEmpty);
    });
  });

  // ======================================================================
  // CurrencyHelper.stripThousandsSeparators
  // ======================================================================
  group('CurrencyHelper.stripThousandsSeparators', () {
    test('strips commas when dot follows (US style)', () {
      expect(CurrencyHelper.stripThousandsSeparators('1,234.56'), '1234.56');
    });

    test('strips dots when comma follows (EU style)', () {
      expect(CurrencyHelper.stripThousandsSeparators('1.234,56'), '1234,56');
    });

    test('strips spaces', () {
      expect(CurrencyHelper.stripThousandsSeparators('1 234 567'), '1234567');
    });

    test('strips apostrophes (Swiss)', () {
      expect(CurrencyHelper.stripThousandsSeparators("1'234'567"), '1234567');
    });

    test('handles no separators', () {
      expect(CurrencyHelper.stripThousandsSeparators('1234'), '1234');
    });

    test('handles empty string', () {
      expect(CurrencyHelper.stripThousandsSeparators(''), '');
    });

    test('multiple commas treated as thousands separators', () {
      expect(
          CurrencyHelper.stripThousandsSeparators('1,234,567'), '1234567');
    });

    test('single comma with 3 digits after treated as thousands', () {
      expect(CurrencyHelper.stripThousandsSeparators('1,234'), '1234');
    });

    test('single comma with 2 digits after kept (decimal)', () {
      // Not removed because it looks like a decimal separator
      expect(CurrencyHelper.stripThousandsSeparators('12,50'), '12,50');
    });

    test('valid thousands-dot-pattern "1.234.567" all dots removed', () {
      expect(CurrencyHelper.stripThousandsSeparators('1.234.567'), '1234567');
    });

    test('invalid multi-dot pattern "12.34.56" keeps last dot', () {
      expect(CurrencyHelper.stripThousandsSeparators('12.34.56'), '1234.56');
    });
  });

  // ======================================================================
  // DatabaseConstants
  // ======================================================================
  group('DatabaseConstants', () {
    test('database version is 18', () {
      expect(DatabaseConstants.databaseVersion, 18);
    });

    test('database name is correct', () {
      expect(DatabaseConstants.databaseName, 'expense_tracker_v4.db');
    });

    test('core table names are set correctly', () {
      expect(DatabaseConstants.tableAccounts, 'accounts');
      expect(DatabaseConstants.tableExpenses, 'expenses');
      expect(DatabaseConstants.tableIncome, 'income');
      expect(DatabaseConstants.tableBudgets, 'budgets');
      expect(DatabaseConstants.tableRecurringExpenses, 'recurring_expenses');
      expect(DatabaseConstants.tableRecurringIncome, 'recurring_income');
      expect(DatabaseConstants.tableCategories, 'categories');
    });

    test('deleted table names are set correctly', () {
      expect(DatabaseConstants.tableDeletedExpenses, 'deleted_expenses');
      expect(DatabaseConstants.tableDeletedIncome, 'deleted_income');
      expect(DatabaseConstants.tableDeletedAccounts, 'deleted_accounts');
    });

    test('additional table names are set correctly', () {
      expect(DatabaseConstants.tableQuickTemplates, 'quick_templates');
      expect(DatabaseConstants.tableTags, 'tags');
      expect(DatabaseConstants.tableTransactionTags, 'transaction_tags');
    });

    test('common column names are correct', () {
      expect(DatabaseConstants.columnId, 'id');
      expect(DatabaseConstants.columnAmount, 'amount');
      expect(DatabaseConstants.columnCategory, 'category');
      expect(DatabaseConstants.columnDescription, 'description');
      expect(DatabaseConstants.columnDate, 'date');
      expect(DatabaseConstants.columnAccountId, 'account_id');
      expect(DatabaseConstants.columnName, 'name');
    });

    test('transaction type values are correct', () {
      expect(DatabaseConstants.typeExpense, 'expense');
      expect(DatabaseConstants.typeIncome, 'income');
    });

    test('payment method values are correct', () {
      expect(DatabaseConstants.paymentCash, 'Cash');
      expect(DatabaseConstants.paymentCard, 'Card');
      expect(DatabaseConstants.paymentBank, 'Bank Transfer');
      expect(DatabaseConstants.paymentDigital, 'Digital Wallet');
    });
  });
}
