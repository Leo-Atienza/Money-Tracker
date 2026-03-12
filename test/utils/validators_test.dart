import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/validators.dart';

void main() {
  // ========================================================================
  // validateAmount()
  // ========================================================================
  group('validateAmount', () {
    test('returns error for null input', () {
      expect(Validators.validateAmount(null), 'Please enter an amount');
    });

    test('returns error for empty string', () {
      expect(Validators.validateAmount(''), 'Please enter an amount');
    });

    test('returns error for non-numeric input', () {
      expect(Validators.validateAmount('abc'), 'Please enter a valid number');
    });

    test('returns error for negative amount', () {
      expect(
        Validators.validateAmount('-5'),
        'Amount must be greater than 0',
      );
    });

    test('returns error for zero when allowZero is false (default)', () {
      expect(
        Validators.validateAmount('0'),
        'Amount must be greater than 0',
      );
    });

    test('returns null for zero when allowZero is true', () {
      expect(Validators.validateAmount('0', allowZero: true), isNull);
    });

    test('returns error when amount exceeds max', () {
      expect(
        Validators.validateAmount('1000000000'),
        'Amount is too large (max 999,999,999.99)',
      );
    });

    test('returns null for valid amount', () {
      expect(Validators.validateAmount('100'), isNull);
    });

    test('returns null for valid decimal amount', () {
      expect(Validators.validateAmount('49.99'), isNull);
    });

    test('returns null for the exact max amount', () {
      expect(Validators.validateAmount('999999999.99'), isNull);
    });

    test('returns error for amount just above max', () {
      expect(
        Validators.validateAmount('1000000000.00'),
        'Amount is too large (max 999,999,999.99)',
      );
    });

    test('supports comma as decimal separator', () {
      // CurrencyHelper.parseDecimal normalizes "12,50" -> "12.50"
      expect(Validators.validateAmount('12,50'), isNull);
    });

    test('supports European thousands-and-decimal format', () {
      // "1.234,56" -> 1234.56
      expect(Validators.validateAmount('1.234,56'), isNull);
    });

    test('handles very small valid amount', () {
      expect(Validators.validateAmount('0.01'), isNull);
    });

    test('floating-point edge: 0.1 + 0.2 representation', () {
      // 0.30000000000000004 should still be valid
      final value = (0.1 + 0.2).toString();
      expect(Validators.validateAmount(value), isNull);
    });

    test('returns error for negative zero when allowZero is false', () {
      // -0.0 should be treated as 0
      expect(
        Validators.validateAmount('-0'),
        'Amount must be greater than 0',
      );
    });

    test('returns error when allowZero is true but amount is negative', () {
      expect(
        Validators.validateAmount('-5', allowZero: true),
        'Amount cannot be negative',
      );
    });
  });

  // ========================================================================
  // validateAmountPaid()
  // ========================================================================
  group('validateAmountPaid', () {
    test('returns null for null input (optional field)', () {
      expect(Validators.validateAmountPaid(null, 100.0), isNull);
    });

    test('returns null for empty input (optional field)', () {
      expect(Validators.validateAmountPaid('', 100.0), isNull);
    });

    test('returns error for non-numeric input', () {
      expect(
        Validators.validateAmountPaid('abc', 100.0),
        'Please enter a valid number',
      );
    });

    test('returns error for negative amount', () {
      expect(
        Validators.validateAmountPaid('-10', 100.0),
        'Amount paid cannot be negative',
      );
    });

    test('returns error when paid exceeds total', () {
      expect(
        Validators.validateAmountPaid('150', 100.0),
        'Amount paid cannot exceed total amount',
      );
    });

    test('returns null when paid equals total', () {
      expect(Validators.validateAmountPaid('100', 100.0), isNull);
    });

    test('returns null when paid is less than total', () {
      expect(Validators.validateAmountPaid('50', 100.0), isNull);
    });

    test('returns null for zero paid amount', () {
      expect(Validators.validateAmountPaid('0', 100.0), isNull);
    });

    test('integer cents comparison avoids floating-point errors', () {
      // Classic floating-point issue: 0.1 + 0.2 != 0.3
      // Without cents comparison, 99.999999999 might incorrectly pass/fail
      // With cents rounding: both become 10000 cents
      expect(Validators.validateAmountPaid('100.00', 100.0), isNull);
    });

    test('overpayment detected at 1 cent over', () {
      // total = 100.00 (10000 cents), paid = 100.01 (10001 cents)
      expect(
        Validators.validateAmountPaid('100.01', 100.0),
        'Amount paid cannot exceed total amount',
      );
    });

    test('paid exactly total with decimal precision', () {
      expect(Validators.validateAmountPaid('99.99', 99.99), isNull);
    });

    test('floating-point edge case: 33.33 * 3 total vs 99.99 paid', () {
      // 33.33 * 3 = 99.99000000000001 in floating-point
      final total = 33.33 * 3; // 99.99000000000001
      expect(Validators.validateAmountPaid('99.99', total), isNull);
    });
  });

  // ========================================================================
  // validateDescription()
  // ========================================================================
  group('validateDescription', () {
    test('returns error for null when required', () {
      expect(
        Validators.validateDescription(null, required: true),
        'Please enter a description',
      );
    });

    test('returns error for empty string when required', () {
      expect(
        Validators.validateDescription('', required: true),
        'Please enter a description',
      );
    });

    test('returns error for whitespace-only string when required', () {
      expect(
        Validators.validateDescription('   ', required: true),
        'Please enter a description',
      );
    });

    test('returns null for null when not required (default)', () {
      expect(Validators.validateDescription(null), isNull);
    });

    test('returns null for empty string when not required', () {
      expect(Validators.validateDescription(''), isNull);
    });

    test('returns error when description exceeds max length', () {
      final longDescription = 'a' * 201;
      expect(
        Validators.validateDescription(longDescription),
        contains('too long'),
      );
    });

    test('returns null for description at exact max length', () {
      final maxDescription = 'a' * 200;
      expect(Validators.validateDescription(maxDescription), isNull);
    });

    test('returns null for valid description', () {
      expect(Validators.validateDescription('Grocery shopping'), isNull);
    });

    test('returns null for valid description when required', () {
      expect(
        Validators.validateDescription('Monthly rent', required: true),
        isNull,
      );
    });

    test('returns null for whitespace-only when not required', () {
      // Not required, so whitespace-only is treated as not provided
      // and length check for empty string short-circuits
      expect(Validators.validateDescription('   '), isNull);
    });

    test('handles Unicode text', () {
      expect(Validators.validateDescription('Caf\u00e9 latte \u2615'), isNull);
    });
  });

  // ========================================================================
  // validateCategoryName()
  // ========================================================================
  group('validateCategoryName', () {
    test('returns error for null input', () {
      expect(
        Validators.validateCategoryName(null, []),
        'Please enter a category name',
      );
    });

    test('returns error for empty string', () {
      expect(
        Validators.validateCategoryName('', []),
        'Please enter a category name',
      );
    });

    test('returns error for whitespace-only input', () {
      expect(
        Validators.validateCategoryName('   ', []),
        'Please enter a category name',
      );
    });

    test('returns error when name exceeds max length', () {
      final longName = 'a' * 51;
      expect(
        Validators.validateCategoryName(longName, []),
        contains('too long'),
      );
    });

    test('returns null for name at exact max length', () {
      final maxName = 'a' * 50;
      expect(Validators.validateCategoryName(maxName, []), isNull);
    });

    test('detects duplicate name (case-insensitive)', () {
      expect(
        Validators.validateCategoryName('Food', ['food', 'Transport']),
        'A category with this name already exists',
      );
    });

    test('detects duplicate with different casing', () {
      expect(
        Validators.validateCategoryName('TRANSPORT', ['food', 'Transport']),
        'A category with this name already exists',
      );
    });

    test('allows same name when it matches originalName (editing)', () {
      expect(
        Validators.validateCategoryName(
          'Food',
          ['Food', 'Transport'],
          originalName: 'Food',
        ),
        isNull,
      );
    });

    test('returns error for angle brackets', () {
      expect(
        Validators.validateCategoryName('<script>', []),
        'Category name contains invalid characters',
      );
    });

    test('returns error for backslash', () {
      expect(
        Validators.validateCategoryName('path\\name', []),
        'Category name contains invalid characters',
      );
    });

    test('returns error for curly braces', () {
      expect(
        Validators.validateCategoryName('{json}', []),
        'Category name contains invalid characters',
      );
    });

    test('returns error for square brackets', () {
      expect(
        Validators.validateCategoryName('[array]', []),
        'Category name contains invalid characters',
      );
    });

    test('returns error for backtick', () {
      expect(
        Validators.validateCategoryName('name`cmd`', []),
        'Category name contains invalid characters',
      );
    });

    test('returns error for pipe character', () {
      expect(
        Validators.validateCategoryName('a|b', []),
        'Category name contains invalid characters',
      );
    });

    test('returns error for null character', () {
      expect(
        Validators.validateCategoryName('bad\x00name', []),
        'Category name contains invalid characters',
      );
    });

    test('returns null for valid name with normal special characters', () {
      // Characters like &, @, #, !, -, (, ) are allowed
      expect(
        Validators.validateCategoryName('Food & Drinks', []),
        isNull,
      );
    });

    test('returns null for valid name', () {
      expect(
        Validators.validateCategoryName('Groceries', ['Transport']),
        isNull,
      );
    });

    test('handles empty existing categories list', () {
      expect(Validators.validateCategoryName('NewCategory', []), isNull);
    });

    test('handles Unicode category names', () {
      expect(
        Validators.validateCategoryName('\u98df\u7269', []),
        isNull,
      );
    });

    test('trims whitespace before checking duplicates', () {
      expect(
        Validators.validateCategoryName('  Food  ', ['Food']),
        'A category with this name already exists',
      );
    });
  });

  // ========================================================================
  // validateTagName()
  // ========================================================================
  group('validateTagName', () {
    test('returns error for null input', () {
      expect(
        Validators.validateTagName(null, []),
        'Please enter a tag name',
      );
    });

    test('returns error for empty string', () {
      expect(
        Validators.validateTagName('', []),
        'Please enter a tag name',
      );
    });

    test('returns error for whitespace-only input', () {
      expect(
        Validators.validateTagName('   ', []),
        'Please enter a tag name',
      );
    });

    test('returns error when name exceeds max length (50)', () {
      final longName = 'a' * 51;
      expect(
        Validators.validateTagName(longName, []),
        contains('too long'),
      );
    });

    test('returns null for name at exact max length', () {
      final maxName = 'a' * 50;
      expect(Validators.validateTagName(maxName, []), isNull);
    });

    test('detects duplicate tag name (case-insensitive)', () {
      expect(
        Validators.validateTagName('urgent', ['Urgent', 'Personal']),
        'A tag with this name already exists',
      );
    });

    test('detects duplicate with different casing', () {
      expect(
        Validators.validateTagName('PERSONAL', ['urgent', 'Personal']),
        'A tag with this name already exists',
      );
    });

    test('returns null for valid tag name', () {
      expect(
        Validators.validateTagName('work', ['personal', 'urgent']),
        isNull,
      );
    });

    test('handles empty existing tags list', () {
      expect(Validators.validateTagName('first-tag', []), isNull);
    });

    test('handles Unicode tag names', () {
      expect(Validators.validateTagName('\u91cd\u8981', []), isNull);
    });

    test('trims whitespace before checking duplicates', () {
      expect(
        Validators.validateTagName('  urgent  ', ['urgent']),
        'A tag with this name already exists',
      );
    });
  });

  // ========================================================================
  // validateBudgetAmount()
  // ========================================================================
  group('validateBudgetAmount', () {
    test('returns error for null input', () {
      expect(
        Validators.validateBudgetAmount(null),
        'Please enter a budget amount',
      );
    });

    test('returns error for empty string', () {
      expect(
        Validators.validateBudgetAmount(''),
        'Please enter a budget amount',
      );
    });

    test('returns error for non-numeric input', () {
      expect(
        Validators.validateBudgetAmount('abc'),
        'Please enter a valid number',
      );
    });

    test('returns error for negative amount', () {
      expect(
        Validators.validateBudgetAmount('-100'),
        'Budget must be greater than 0',
      );
    });

    test('returns error for zero', () {
      expect(
        Validators.validateBudgetAmount('0'),
        'Budget must be greater than 0',
      );
    });

    test('returns error when amount exceeds max', () {
      expect(
        Validators.validateBudgetAmount('1000000000'),
        'Budget is too large (max 999,999,999.99)',
      );
    });

    test('returns null for valid budget amount', () {
      expect(Validators.validateBudgetAmount('500'), isNull);
    });

    test('returns null for valid decimal budget', () {
      expect(Validators.validateBudgetAmount('1000.50'), isNull);
    });

    test('returns null for exact max amount', () {
      expect(Validators.validateBudgetAmount('999999999.99'), isNull);
    });

    test('returns null for small valid budget', () {
      expect(Validators.validateBudgetAmount('0.01'), isNull);
    });
  });

  // ========================================================================
  // isDateInValidRange()
  // ========================================================================
  group('isDateInValidRange', () {
    test('returns true for today', () {
      expect(Validators.isDateInValidRange(DateTime.now()), isTrue);
    });

    test('returns true for yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(Validators.isDateInValidRange(yesterday), isTrue);
    });

    test('returns true for date within range (1 year ago)', () {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      expect(Validators.isDateInValidRange(oneYearAgo), isTrue);
    });

    test('returns false for date too far in the past (>5 years)', () {
      final now = DateTime.now();
      final tooOld = DateTime(now.year - 5, now.month, now.day)
          .subtract(const Duration(days: 1));
      expect(Validators.isDateInValidRange(tooOld), isFalse);
    });

    test('returns true for exactly 5 years ago (boundary)', () {
      final now = DateTime.now();
      final fiveYearsAgo = DateTime(now.year - 5, now.month, now.day);
      expect(Validators.isDateInValidRange(fiveYearsAgo), isTrue);
    });

    test('returns false for date too far in the future (>1 year)', () {
      final now = DateTime.now();
      final tooFuture = DateTime(now.year + 1, now.month, now.day)
          .add(const Duration(days: 1));
      expect(Validators.isDateInValidRange(tooFuture), isFalse);
    });

    test('returns true for exactly 1 year in the future (boundary)', () {
      final now = DateTime.now();
      final oneYearFuture = DateTime(now.year + 1, now.month, now.day);
      expect(Validators.isDateInValidRange(oneYearFuture), isTrue);
    });

    test('returns true for date 6 months in future', () {
      final sixMonthsFuture = DateTime.now().add(const Duration(days: 180));
      expect(Validators.isDateInValidRange(sixMonthsFuture), isTrue);
    });

    test('returns true for date 4 years ago', () {
      final now = DateTime.now();
      final fourYearsAgo = DateTime(now.year - 4, now.month, now.day);
      expect(Validators.isDateInValidRange(fourYearsAgo), isTrue);
    });
  });

  // ========================================================================
  // getTransactionMinDate() / getTransactionMaxDate()
  // ========================================================================
  group('getTransactionMinDate', () {
    test('returns a date 5 years ago from today', () {
      final now = DateTime.now();
      final expected = DateTime(now.year - 5, now.month, now.day);
      final result = Validators.getTransactionMinDate();

      expect(result.year, expected.year);
      expect(result.month, expected.month);
      expect(result.day, expected.day);
    });

    test('returns midnight (no time component)', () {
      final result = Validators.getTransactionMinDate();
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });
  });

  group('getTransactionMaxDate', () {
    test('returns a date 1 year in the future from today', () {
      final now = DateTime.now();
      final expected = DateTime(now.year + 1, now.month, now.day);
      final result = Validators.getTransactionMaxDate();

      expect(result.year, expected.year);
      expect(result.month, expected.month);
      expect(result.day, expected.day);
    });

    test('returns midnight (no time component)', () {
      final result = Validators.getTransactionMaxDate();
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
    });
  });

  // ========================================================================
  // getFilterMinDate() / getFilterMaxDate()
  // ========================================================================
  group('getFilterMinDate', () {
    test('returns same as getTransactionMinDate', () {
      final filterMin = Validators.getFilterMinDate();
      final txMin = Validators.getTransactionMinDate();

      expect(filterMin.year, txMin.year);
      expect(filterMin.month, txMin.month);
      expect(filterMin.day, txMin.day);
    });
  });

  group('getFilterMaxDate', () {
    test('returns current date/time (approximately now)', () {
      final before = DateTime.now();
      final result = Validators.getFilterMaxDate();
      final after = DateTime.now();

      // The result should be between the before and after timestamps
      expect(
        result.isAfter(before) || result.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        result.isBefore(after) || result.isAtSameMomentAs(after),
        isTrue,
      );
    });
  });

  // ========================================================================
  // sanitizeText()
  // ========================================================================
  group('sanitizeText', () {
    test('removes control characters', () {
      expect(
        Validators.sanitizeText('hello\x00world'),
        'helloworld',
      );
    });

    test('removes newlines and tabs', () {
      expect(
        Validators.sanitizeText('line1\nline2\ttab'),
        'line1line2tab',
      );
    });

    test('removes carriage return', () {
      expect(
        Validators.sanitizeText('hello\r\nworld'),
        'helloworld',
      );
    });

    test('removes DEL character (0x7F)', () {
      expect(
        Validators.sanitizeText('test\x7Fvalue'),
        'testvalue',
      );
    });

    test('trims leading and trailing whitespace', () {
      expect(
        Validators.sanitizeText('  hello  '),
        'hello',
      );
    });

    test('truncates to default max length (200)', () {
      final longText = 'a' * 250;
      final result = Validators.sanitizeText(longText);
      expect(result.length, 200);
    });

    test('truncates to custom max length', () {
      final longText = 'a' * 100;
      final result = Validators.sanitizeText(longText, maxLength: 50);
      expect(result.length, 50);
    });

    test('returns text unchanged when within limits', () {
      expect(Validators.sanitizeText('normal text'), 'normal text');
    });

    test('handles empty string', () {
      expect(Validators.sanitizeText(''), '');
    });

    test('preserves Unicode text', () {
      expect(
        Validators.sanitizeText(
            'Caf\u00e9 \u2615 \u00fc\u00f1\u00eec\u00f6d\u00e9'),
        'Caf\u00e9 \u2615 \u00fc\u00f1\u00eec\u00f6d\u00e9',
      );
    });

    test('handles string that is all control characters', () {
      expect(
        Validators.sanitizeText('\x00\x01\x02\x03'),
        '',
      );
    });

    test('trims whitespace before truncating', () {
      // Leading/trailing whitespace is trimmed first,
      // then length limit is applied
      final paddedText = '   ${'a' * 250}   ';
      final result = Validators.sanitizeText(paddedText, maxLength: 200);
      expect(result.length, 200);
    });

    test('handles very long string', () {
      final veryLong = 'x' * 10000;
      final result = Validators.sanitizeText(veryLong);
      expect(result.length, 200);
    });
  });

  // ========================================================================
  // validateDateRange()
  // ========================================================================
  group('validateDateRange', () {
    test('returns null when startDate is null', () {
      expect(
        Validators.validateDateRange(null, DateTime(2024, 6, 15)),
        isNull,
      );
    });

    test('returns null when endDate is null', () {
      expect(
        Validators.validateDateRange(DateTime(2024, 1, 1), null),
        isNull,
      );
    });

    test('returns null when both dates are null', () {
      expect(Validators.validateDateRange(null, null), isNull);
    });

    test('returns error when end date is before start date', () {
      final start = DateTime(2024, 6, 15);
      final end = DateTime(2024, 6, 1);
      expect(
        Validators.validateDateRange(start, end),
        'End date must be after start date',
      );
    });

    test('returns null when end date equals start date (same day)', () {
      final date = DateTime(2024, 6, 15);
      expect(Validators.validateDateRange(date, date), isNull);
    });

    test('returns null when end date is after start date', () {
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      expect(Validators.validateDateRange(start, end), isNull);
    });

    test('returns null when end date is one day after start date', () {
      final start = DateTime(2024, 6, 15);
      final end = DateTime(2024, 6, 16);
      expect(Validators.validateDateRange(start, end), isNull);
    });

    test('returns error when end is one second before start (same day)', () {
      // start at 12:00:01, end at 12:00:00 -> end is before start
      final start = DateTime(2024, 6, 15, 12, 0, 1);
      final end = DateTime(2024, 6, 15, 12, 0, 0);
      expect(
        Validators.validateDateRange(start, end),
        'End date must be after start date',
      );
    });
  });

  // ========================================================================
  // validateMaxOccurrences()
  // ========================================================================
  group('validateMaxOccurrences', () {
    test('returns null for null input (optional field)', () {
      expect(Validators.validateMaxOccurrences(null), isNull);
    });

    test('returns null for empty string (optional field)', () {
      expect(Validators.validateMaxOccurrences(''), isNull);
    });

    test('returns error for non-numeric input', () {
      expect(
        Validators.validateMaxOccurrences('abc'),
        'Please enter a valid number',
      );
    });

    test('returns error for zero', () {
      expect(
        Validators.validateMaxOccurrences('0'),
        'Must be at least 1 occurrence',
      );
    });

    test('returns error for negative number', () {
      expect(
        Validators.validateMaxOccurrences('-5'),
        'Must be at least 1 occurrence',
      );
    });

    test('returns error when exceeding 1000', () {
      expect(
        Validators.validateMaxOccurrences('1001'),
        'Maximum 1000 occurrences allowed',
      );
    });

    test('returns null for 1 (minimum valid)', () {
      expect(Validators.validateMaxOccurrences('1'), isNull);
    });

    test('returns null for 1000 (maximum valid boundary)', () {
      expect(Validators.validateMaxOccurrences('1000'), isNull);
    });

    test('returns null for a typical value', () {
      expect(Validators.validateMaxOccurrences('12'), isNull);
    });

    test('returns null for 500 (mid-range)', () {
      expect(Validators.validateMaxOccurrences('500'), isNull);
    });

    test('returns error for decimal input', () {
      expect(
        Validators.validateMaxOccurrences('5.5'),
        'Please enter a valid number',
      );
    });

    test('returns error for very large number', () {
      expect(
        Validators.validateMaxOccurrences('999999'),
        'Maximum 1000 occurrences allowed',
      );
    });
  });

  // ========================================================================
  // Constants
  // ========================================================================
  group('constants', () {
    test('maxAmount is 999999999.99', () {
      expect(Validators.maxAmount, 999999999.99);
    });

    test('maxDescriptionLength is 200', () {
      expect(Validators.maxDescriptionLength, 200);
    });

    test('maxCategoryNameLength is 50', () {
      expect(Validators.maxCategoryNameLength, 50);
    });

    test('maxTagNameLength is 50', () {
      expect(Validators.maxTagNameLength, 50);
    });
  });

  // ========================================================================
  // getCharacterCount() / willBeTruncated()
  // ========================================================================
  group('getCharacterCount', () {
    test('returns correct count string', () {
      expect(Validators.getCharacterCount('hello', 200), '5/200');
    });

    test('returns 0 for empty string', () {
      expect(Validators.getCharacterCount('', 200), '0/200');
    });

    test('returns max/max for exact limit', () {
      final text = 'a' * 50;
      expect(Validators.getCharacterCount(text, 50), '50/50');
    });
  });

  group('willBeTruncated', () {
    test('returns false when text is shorter than limit', () {
      expect(Validators.willBeTruncated('hello', 200), isFalse);
    });

    test('returns false when text equals limit', () {
      final text = 'a' * 200;
      expect(Validators.willBeTruncated(text, 200), isFalse);
    });

    test('returns true when text exceeds limit', () {
      final text = 'a' * 201;
      expect(Validators.willBeTruncated(text, 200), isTrue);
    });
  });

  // ========================================================================
  // isFutureDate()
  // ========================================================================
  group('isFutureDate', () {
    test('returns false for today', () {
      expect(Validators.isFutureDate(DateTime.now()), isFalse);
    });

    test('returns true for tomorrow', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(Validators.isFutureDate(tomorrow), isTrue);
    });

    test('returns false for yesterday', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(Validators.isFutureDate(yesterday), isFalse);
    });
  });

  // ========================================================================
  // getRecurringEndMinDate() / getRecurringEndMaxDate()
  // ========================================================================
  group('getRecurringEndMinDate', () {
    test('returns approximately today', () {
      final before = DateTime.now();
      final result = Validators.getRecurringEndMinDate();
      final after = DateTime.now();

      expect(
        result.isAfter(before) || result.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        result.isBefore(after) || result.isAtSameMomentAs(after),
        isTrue,
      );
    });
  });

  group('getRecurringEndMaxDate', () {
    test('returns approximately 10 years (3650 days) from now', () {
      final now = DateTime.now();
      final result = Validators.getRecurringEndMaxDate();
      final diff = result.difference(now).inDays;

      // Allow small tolerance for test execution time
      expect(diff, closeTo(3650, 1));
    });
  });
}
