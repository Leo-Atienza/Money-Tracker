import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';

import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/models/budget_model.dart';
import 'package:budget_tracker/models/account_model.dart';
import 'package:budget_tracker/models/recurring_expense_model.dart';
import 'package:budget_tracker/models/recurring_income_model.dart';
import 'package:budget_tracker/models/quick_template_model.dart';
import 'package:budget_tracker/models/monthly_balance_model.dart';
import 'package:budget_tracker/models/category_model.dart';
import 'package:budget_tracker/models/tag_model.dart';
import 'package:budget_tracker/utils/date_helper.dart';
import 'package:budget_tracker/utils/decimal_helper.dart';

void main() {
  // =========================================================================
  // 1. MODEL ROUNDTRIP INTEGRITY (toMap -> fromMap -> toMap)
  // =========================================================================

  group('Model roundtrip integrity', () {
    test('Expense roundtrip with all fields populated', () {
      final expense = Expense(
        id: 1,
        amount: Decimal.parse('0.01'),
        category: 'Food',
        description: 'Lunch',
        date: DateTime.utc(2025, 6, 15),
        accountId: 2,
        amountPaid: Decimal.parse('0.01'),
        paymentMethod: 'Card',
      );

      final map1 = expense.toMap();
      final restored = Expense.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['amount'], equals(map1['amount']));
      expect(map2['category'], equals(map1['category']));
      expect(map2['description'], equals(map1['description']));
      expect(map2['date'], equals(map1['date']));
      expect(map2['account_id'], equals(map1['account_id']));
      expect(map2['amountPaid'], equals(map1['amountPaid']));
      expect(map2['paymentMethod'], equals(map1['paymentMethod']));
    });

    test('Expense roundtrip with edge case amount 999999.99', () {
      final expense = Expense(
        id: 2,
        amount: Decimal.parse('999999.99'),
        category: 'Rent',
        description: 'Big payment',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
        amountPaid: Decimal.parse('500000.00'),
        paymentMethod: 'Transfer',
      );

      final map1 = expense.toMap();
      final restored = Expense.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['amount'], equals(map1['amount']));
      expect(map2['amountPaid'], equals(map1['amountPaid']));
    });

    test('Income roundtrip with all fields populated', () {
      final income = Income(
        id: 10,
        amount: Decimal.parse('5000.50'),
        category: 'Salary',
        description: 'Monthly salary',
        date: DateTime.utc(2025, 3, 1),
        accountId: 1,
      );

      final map1 = income.toMap();
      final restored = Income.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['amount'], equals(map1['amount']));
      expect(map2['category'], equals(map1['category']));
      expect(map2['description'], equals(map1['description']));
      expect(map2['date'], equals(map1['date']));
      expect(map2['account_id'], equals(map1['account_id']));
    });

    test('Budget roundtrip with all fields populated', () {
      final budget = Budget(
        id: 5,
        category: 'Food',
        amount: Decimal.parse('300.00'),
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      final map1 = budget.toMap();
      final restored = Budget.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['category'], equals(map1['category']));
      expect(map2['amount'], equals(map1['amount']));
      expect(map2['account_id'], equals(map1['account_id']));
      expect(map2['month'], equals(map1['month']));
    });

    test('Account roundtrip with all fields populated', () {
      final account = Account(
        id: 1,
        name: 'Main Account',
        icon: '0xe1234',
        color: '#FF5733',
        isDefault: true,
        currencyCode: 'EUR',
      );

      final map1 = account.toMap();
      final restored = Account.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['name'], equals(map1['name']));
      expect(map2['icon'], equals(map1['icon']));
      expect(map2['color'], equals(map1['color']));
      expect(map2['isDefault'], equals(map1['isDefault']));
      expect(map2['currencyCode'], equals(map1['currencyCode']));
    });

    test('RecurringExpense roundtrip with all fields populated', () {
      final recurring = RecurringExpense(
        id: 3,
        description: 'Netflix',
        amount: Decimal.parse('15.99'),
        category: 'Entertainment',
        dayOfMonth: 15,
        isActive: true,
        lastCreated: DateTime.utc(2025, 5, 15),
        accountId: 1,
        paymentMethod: 'Card',
        endDate: DateTime.utc(2026, 12, 31),
        maxOccurrences: 24,
        occurrenceCount: 5,
        frequency: RecurringExpenseFrequency.monthly,
        startDate: DateTime.utc(2025, 1, 15),
      );

      final map1 = recurring.toMap();
      final restored = RecurringExpense.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['description'], equals(map1['description']));
      expect(map2['amount'], equals(map1['amount']));
      expect(map2['category'], equals(map1['category']));
      expect(map2['dayOfMonth'], equals(map1['dayOfMonth']));
      expect(map2['isActive'], equals(map1['isActive']));
      expect(map2['lastCreated'], equals(map1['lastCreated']));
      expect(map2['account_id'], equals(map1['account_id']));
      expect(map2['paymentMethod'], equals(map1['paymentMethod']));
      expect(map2['endDate'], equals(map1['endDate']));
      expect(map2['maxOccurrences'], equals(map1['maxOccurrences']));
      expect(map2['occurrenceCount'], equals(map1['occurrenceCount']));
      expect(map2['frequency'], equals(map1['frequency']));
      expect(map2['startDate'], equals(map1['startDate']));
    });

    test('RecurringIncome roundtrip with all fields populated', () {
      final recurring = RecurringIncome(
        id: 7,
        description: 'Freelance gig',
        amount: Decimal.parse('2500.00'),
        category: 'Freelance',
        dayOfMonth: 1,
        isActive: true,
        lastCreated: DateTime.utc(2025, 6, 1),
        accountId: 2,
        frequency: RecurringFrequency.biweekly,
        startDate: DateTime.utc(2025, 1, 1),
        endDate: DateTime.utc(2026, 6, 1),
        maxOccurrences: 52,
        occurrenceCount: 10,
      );

      final map1 = recurring.toMap();
      final restored = RecurringIncome.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['description'], equals(map1['description']));
      expect(map2['amount'], equals(map1['amount']));
      expect(map2['category'], equals(map1['category']));
      expect(map2['dayOfMonth'], equals(map1['dayOfMonth']));
      expect(map2['isActive'], equals(map1['isActive']));
      expect(map2['lastCreated'], equals(map1['lastCreated']));
      expect(map2['account_id'], equals(map1['account_id']));
      expect(map2['frequency'], equals(map1['frequency']));
      expect(map2['startDate'], equals(map1['startDate']));
      expect(map2['endDate'], equals(map1['endDate']));
      expect(map2['maxOccurrences'], equals(map1['maxOccurrences']));
      expect(map2['occurrenceCount'], equals(map1['occurrenceCount']));
    });

    test('QuickTemplate roundtrip with all fields populated', () {
      final template = QuickTemplate(
        id: 4,
        name: 'Morning Coffee',
        amount: Decimal.parse('4.50'),
        category: 'Food',
        paymentMethod: 'Cash',
        type: 'expense',
        accountId: 1,
        sortOrder: 3,
      );

      final map1 = template.toMap();
      final restored = QuickTemplate.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['name'], equals(map1['name']));
      expect(map2['amount'], equals(map1['amount']));
      expect(map2['category'], equals(map1['category']));
      expect(map2['paymentMethod'], equals(map1['paymentMethod']));
      expect(map2['type'], equals(map1['type']));
      expect(map2['account_id'], equals(map1['account_id']));
      expect(map2['sortOrder'], equals(map1['sortOrder']));
    });

    test('MonthlyBalance roundtrip with all fields including overallBudget',
        () {
      final balance = MonthlyBalance(
        id: 1,
        carryoverFromPrevious: Decimal.parse('150.75'),
        overallBudget: Decimal.parse('3000.00'),
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      final map1 = balance.toMap();
      final restored = MonthlyBalance.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['carryover_from_previous'],
          equals(map1['carryover_from_previous']));
      expect(map2['overall_budget'], equals(map1['overall_budget']));
      expect(map2['account_id'], equals(map1['account_id']));
      expect(map2['month'], equals(map1['month']));
    });

    test('MonthlyBalance roundtrip with null overallBudget', () {
      final balance = MonthlyBalance(
        id: 2,
        carryoverFromPrevious: Decimal.parse('-50.00'),
        accountId: 1,
        month: DateTime.utc(2025, 7, 1),
      );

      final map1 = balance.toMap();
      final restored = MonthlyBalance.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['overall_budget'], isNull);
      expect(map2['carryover_from_previous'],
          equals(map1['carryover_from_previous']));
    });

    test('Category roundtrip with all fields including color and icon', () {
      final category = Category(
        id: 1,
        name: 'Food',
        accountId: 1,
        isDefault: true,
        type: 'expense',
        color: '#FF5733',
        icon: '0xe1234',
      );

      final map1 = category.toMap();
      final restored = Category.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['name'], equals(map1['name']));
      expect(map2['account_id'], equals(map1['account_id']));
      expect(map2['isDefault'], equals(map1['isDefault']));
      expect(map2['type'], equals(map1['type']));
      expect(map2['color'], equals(map1['color']));
      expect(map2['icon'], equals(map1['icon']));
    });

    test('Tag roundtrip with all fields', () {
      final tag = Tag(
        id: 1,
        name: 'Urgent',
        color: '#FF0000',
        accountId: 1,
      );

      final map1 = tag.toMap();
      final restored = Tag.fromMap(map1);
      final map2 = restored.toMap();

      expect(map2['id'], equals(map1['id']));
      expect(map2['name'], equals(map1['name']));
      expect(map2['color'], equals(map1['color']));
      expect(map2['account_id'], equals(map1['account_id']));
    });
  });

  // =========================================================================
  // 2. CROSS-MODEL CONSISTENCY
  // =========================================================================

  group('Cross-model consistency', () {
    test('Expense.accountId type matches Account.id type', () {
      final account = Account(id: 1, name: 'Main');
      final expense = Expense(
        id: 1,
        amount: Decimal.parse('10.00'),
        category: 'Food',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: account.id!,
      );

      // Both should be int
      expect(expense.accountId, isA<int>());
      expect(account.id, isA<int>());
      expect(expense.accountId, equals(account.id));
    });

    test('Budget.category type matches Category.name type', () {
      final category = Category(id: 1, name: 'Food', accountId: 1);
      final budget = Budget(
        id: 1,
        category: category.name,
        amount: Decimal.parse('300.00'),
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      // Both should be String
      expect(budget.category, isA<String>());
      expect(category.name, isA<String>());
      expect(budget.category, equals(category.name));
    });

    test(
        'RecurringExpense fields match Expense constructor requirements', () {
      final recurring = RecurringExpense(
        id: 1,
        description: 'Netflix',
        amount: Decimal.parse('15.99'),
        category: 'Entertainment',
        dayOfMonth: 15,
        accountId: 1,
      );

      // Should be able to create an Expense from RecurringExpense fields
      final expense = Expense(
        amount: recurring.amountDecimal,
        category: recurring.category,
        description: recurring.description,
        date: DateTime.utc(2025, 6, 15),
        accountId: recurring.accountId,
        paymentMethod: recurring.paymentMethod,
      );

      expect(expense.amount, equals(recurring.amount));
      expect(expense.category, equals(recurring.category));
      expect(expense.description, equals(recurring.description));
      expect(expense.accountId, equals(recurring.accountId));
    });

    test('RecurringIncome fields match Income constructor requirements', () {
      final recurring = RecurringIncome(
        id: 1,
        description: 'Salary',
        amount: Decimal.parse('5000.00'),
        category: 'Employment',
        dayOfMonth: 1,
        accountId: 1,
      );

      // Should be able to create an Income from RecurringIncome fields
      final income = Income(
        amount: recurring.amountDecimal,
        category: recurring.category,
        description: recurring.description,
        date: DateTime.utc(2025, 6, 1),
        accountId: recurring.accountId,
      );

      expect(income.amount, equals(recurring.amount));
      expect(income.category, equals(recurring.category));
      expect(income.description, equals(recurring.description));
      expect(income.accountId, equals(recurring.accountId));
    });

    test(
        'QuickTemplate type field values match Category type values', () {
      final expenseTemplate = QuickTemplate(
        name: 'Coffee',
        amount: Decimal.parse('4.50'),
        category: 'Food',
        type: 'expense',
        accountId: 1,
      );

      final incomeTemplate = QuickTemplate(
        name: 'Salary',
        amount: Decimal.parse('5000.00'),
        category: 'Employment',
        type: 'income',
        accountId: 1,
      );

      final expenseCategory = Category(
        name: 'Food',
        accountId: 1,
        type: 'expense',
      );

      final incomeCategory = Category(
        name: 'Employment',
        accountId: 1,
        type: 'income',
      );

      expect(expenseTemplate.type, equals(expenseCategory.type));
      expect(incomeTemplate.type, equals(incomeCategory.type));
      // Verify the valid values
      expect(expenseTemplate.type, equals('expense'));
      expect(incomeTemplate.type, equals('income'));
    });
  });

  // =========================================================================
  // 3. DECIMAL PRECISION TESTS
  // =========================================================================

  group('Decimal precision tests', () {
    test('adding many small amounts: 0.01 * 100 should equal 1.00', () {
      Decimal sum = Decimal.zero;
      final penny = Decimal.parse('0.01');
      for (int i = 0; i < 100; i++) {
        sum = sum + penny;
      }
      expect(sum, equals(Decimal.parse('1.00')));
      expect(DecimalHelper.toDouble(sum), equals(1.0));
    });

    test('subtracting from a large amount preserves precision', () {
      final large = Decimal.parse('999999.99');
      final small = Decimal.parse('0.01');
      final result = large - small;
      expect(result, equals(Decimal.parse('999999.98')));
      expect(DecimalHelper.toDouble(result), equals(999999.98));
    });

    test('DecimalHelper.add preserves precision', () {
      // Classic floating-point problem: 0.1 + 0.2
      final result = DecimalHelper.add(0.1, 0.2);
      expect(result, equals(0.3));
    });

    test('DecimalHelper.subtract preserves precision', () {
      final result = DecimalHelper.subtract(1.0, 0.01);
      expect(result, equals(0.99));
    });

    test('Expense.remainingAmount = amount - amountPaid', () {
      final expense = Expense(
        amount: Decimal.parse('100.00'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
        amountPaid: Decimal.parse('37.50'),
      );

      expect(expense.remainingAmount, equals(62.50));
    });

    test('Expense.remainingAmount with zero paid', () {
      final expense = Expense(
        amount: Decimal.parse('99.99'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
      );

      expect(expense.remainingAmount, equals(99.99));
    });

    test('Expense.isPaid when amountPaid >= amount', () {
      final fullyPaid = Expense(
        amount: Decimal.parse('100.00'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
        amountPaid: Decimal.parse('100.00'),
      );
      expect(fullyPaid.isPaid, isTrue);

      final overPaid = Expense(
        amount: Decimal.parse('100.00'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
        amountPaid: Decimal.parse('150.00'),
      );
      expect(overPaid.isPaid, isTrue);

      final partiallyPaid = Expense(
        amount: Decimal.parse('100.00'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
        amountPaid: Decimal.parse('99.99'),
      );
      expect(partiallyPaid.isPaid, isFalse);
    });

    test('Expense.paymentProgress = amountPaid / amount', () {
      final halfPaid = Expense(
        amount: Decimal.parse('200.00'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
        amountPaid: Decimal.parse('100.00'),
      );
      expect(halfPaid.paymentProgress, equals(0.5));

      final fullyPaid = Expense(
        amount: Decimal.parse('100.00'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
        amountPaid: Decimal.parse('100.00'),
      );
      expect(fullyPaid.paymentProgress, equals(1.0));

      final nothingPaid = Expense(
        amount: Decimal.parse('100.00'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
      );
      expect(nothingPaid.paymentProgress, equals(0.0));
    });

    test('Expense.paymentProgress clamped to 1.0 when overpaid', () {
      final overPaid = Expense(
        amount: Decimal.parse('100.00'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
        amountPaid: Decimal.parse('200.00'),
      );
      expect(overPaid.paymentProgress, equals(1.0));
    });

    test('Expense.paymentProgress is 0 when amount is zero', () {
      final zeroAmount = Expense(
        amount: Decimal.parse('0.00'),
        category: 'Test',
        description: 'Test',
        date: DateTime.utc(2025, 1, 1),
        accountId: 1,
      );
      expect(zeroAmount.paymentProgress, equals(0.0));
    });

    test('DecimalHelper handles infinity and NaN', () {
      expect(DecimalHelper.fromDouble(double.infinity), equals(Decimal.zero));
      expect(
          DecimalHelper.fromDouble(double.negativeInfinity), equals(Decimal.zero));
      expect(DecimalHelper.fromDouble(double.nan), equals(Decimal.zero));
    });

    test('DecimalHelper.fromDoubleSafe handles null', () {
      expect(DecimalHelper.fromDoubleSafe(null), equals(Decimal.zero));
    });

    test('DecimalHelper.divide by zero returns 0', () {
      expect(DecimalHelper.divide(100.0, 0.0), equals(0.0));
    });

    test('DecimalHelper.percentage calculation', () {
      expect(DecimalHelper.percentage(50, 200), equals(25.0));
      expect(DecimalHelper.percentage(0, 200), equals(0.0));
      expect(DecimalHelper.percentage(100, 0), equals(0.0));
    });

    test('DecimalHelper.equals checks precision-safe equality', () {
      expect(DecimalHelper.equals(0.1 + 0.2, 0.3), isTrue);
      expect(DecimalHelper.equals(1.0, 1.0), isTrue);
      expect(DecimalHelper.equals(1.0, 1.01), isFalse);
    });

    test('DecimalHelper.compare returns correct ordering', () {
      expect(DecimalHelper.compare(1.0, 2.0), lessThan(0));
      expect(DecimalHelper.compare(2.0, 1.0), greaterThan(0));
      expect(DecimalHelper.compare(1.0, 1.0), equals(0));
    });
  });

  // =========================================================================
  // 4. DATE HANDLING CONSISTENCY
  // =========================================================================

  group('Date handling consistency', () {
    test('DateHelper.normalize strips time components', () {
      final dateWithTime = DateTime(2025, 6, 15, 14, 30, 45, 123, 456);
      final normalized = DateHelper.normalize(dateWithTime);

      expect(normalized.hour, equals(0));
      expect(normalized.minute, equals(0));
      expect(normalized.second, equals(0));
      expect(normalized.millisecond, equals(0));
      expect(normalized.microsecond, equals(0));
      expect(normalized.year, equals(2025));
      expect(normalized.month, equals(6));
      expect(normalized.day, equals(15));
      expect(normalized.isUtc, isTrue);
    });

    test('DateHelper.startOfMonth returns day 1', () {
      final midMonth = DateTime.utc(2025, 6, 15);
      final start = DateHelper.startOfMonth(midMonth);

      expect(start.day, equals(1));
      expect(start.month, equals(6));
      expect(start.year, equals(2025));
      expect(start.hour, equals(0));
    });

    test('DateHelper.endOfMonth returns first of next month', () {
      final date = DateTime.utc(2025, 6, 15);
      final end = DateHelper.endOfMonth(date);

      expect(end.day, equals(1));
      expect(end.month, equals(7));
      expect(end.year, equals(2025));
    });

    test('DateHelper.endOfMonth handles December correctly', () {
      final december = DateTime.utc(2025, 12, 15);
      final end = DateHelper.endOfMonth(december);

      expect(end.day, equals(1));
      expect(end.month, equals(1));
      expect(end.year, equals(2026));
    });

    test('DateHelper.lastDayOfMonth handles February (non-leap year)', () {
      final feb = DateTime.utc(2025, 2, 10);
      final lastDay = DateHelper.lastDayOfMonth(feb);
      expect(lastDay.day, equals(28));
      expect(lastDay.month, equals(2));
    });

    test('DateHelper.lastDayOfMonth handles February (leap year)', () {
      final feb = DateTime.utc(2024, 2, 10);
      final lastDay = DateHelper.lastDayOfMonth(feb);
      expect(lastDay.day, equals(29));
      expect(lastDay.month, equals(2));
    });

    test('DateHelper.lastDayOfMonth handles April (30 days)', () {
      final april = DateTime.utc(2025, 4, 10);
      final lastDay = DateHelper.lastDayOfMonth(april);
      expect(lastDay.day, equals(30));
    });

    test('DateHelper.lastDayOfMonth handles December (31 days)', () {
      final dec = DateTime.utc(2025, 12, 10);
      final lastDay = DateHelper.lastDayOfMonth(dec);
      expect(lastDay.day, equals(31));
    });

    test('DateHelper.addMonths handles year rollover (Dec -> Jan)', () {
      final dec = DateTime.utc(2025, 12, 15);
      final result = DateHelper.addMonths(dec, 1);

      expect(result.month, equals(1));
      expect(result.year, equals(2026));
      expect(result.day, equals(15));
    });

    test('DateHelper.addMonths handles day overflow (Jan 31 + 1 = Feb 28)', () {
      final jan31 = DateTime.utc(2025, 1, 31);
      final result = DateHelper.addMonths(jan31, 1);

      expect(result.month, equals(2));
      expect(result.day, equals(28)); // Feb has 28 days in 2025
    });

    test('DateHelper.addMonths handles leap year (Jan 31 + 1 = Feb 29)', () {
      final jan31 = DateTime.utc(2024, 1, 31);
      final result = DateHelper.addMonths(jan31, 1);

      expect(result.month, equals(2));
      expect(result.day, equals(29)); // Feb has 29 days in 2024
    });

    test('DateHelper.subtractMonths handles year rollover (Jan -> Dec)', () {
      final jan = DateTime.utc(2025, 1, 15);
      final result = DateHelper.subtractMonths(jan, 1);

      expect(result.month, equals(12));
      expect(result.year, equals(2024));
      expect(result.day, equals(15));
    });

    test('DateHelper.subtractMonths handles multiple months', () {
      final march = DateTime.utc(2025, 3, 15);
      final result = DateHelper.subtractMonths(march, 3);

      expect(result.month, equals(12));
      expect(result.year, equals(2024));
      expect(result.day, equals(15));
    });

    test('DateHelper.isSameDay ignores time', () {
      final morning = DateTime(2025, 6, 15, 8, 0, 0);
      final evening = DateTime(2025, 6, 15, 22, 30, 0);
      final nextDay = DateTime(2025, 6, 16, 8, 0, 0);

      expect(DateHelper.isSameDay(morning, evening), isTrue);
      expect(DateHelper.isSameDay(morning, nextDay), isFalse);
    });

    test('DateHelper.isSameDay works across UTC and local', () {
      final utc = DateTime.utc(2025, 6, 15, 12, 0);
      final local = DateTime(2025, 6, 15, 8, 0);

      expect(DateHelper.isSameDay(utc, local), isTrue);
    });

    test('DateHelper.toDateString produces yyyy-MM-dd format', () {
      final date = DateTime.utc(2025, 1, 5);
      expect(DateHelper.toDateString(date), equals('2025-01-05'));

      final date2 = DateTime.utc(2025, 12, 31);
      expect(DateHelper.toDateString(date2), equals('2025-12-31'));

      final date3 = DateTime(2025, 6, 15, 14, 30);
      // Should strip time and format correctly
      expect(DateHelper.toDateString(date3), equals('2025-06-15'));
    });

    test('DateHelper.parseDate parses ISO 8601 strings', () {
      final result = DateHelper.parseDate('2025-06-15');
      expect(result, isNotNull);
      expect(result!.year, equals(2025));
      expect(result.month, equals(6));
      expect(result.day, equals(15));
      expect(result.isUtc, isTrue);
    });

    test('DateHelper.parseDate returns null for invalid strings', () {
      expect(DateHelper.parseDate(null), isNull);
      expect(DateHelper.parseDate(''), isNull);
      expect(DateHelper.parseDate('not-a-date'), isNull);
    });

    test('DateHelper.toDateString -> parseDate roundtrip', () {
      final original = DateTime.utc(2025, 6, 15);
      final string = DateHelper.toDateString(original);
      final parsed = DateHelper.parseDate(string);

      expect(parsed, isNotNull);
      expect(DateHelper.isSameDay(original, parsed!), isTrue);
    });

    test('DateHelper.daysBetween calculates correctly', () {
      final start = DateTime.utc(2025, 1, 1);
      final end = DateTime.utc(2025, 1, 31);
      expect(DateHelper.daysBetween(start, end), equals(30));

      // Same day = 0
      expect(DateHelper.daysBetween(start, start), equals(0));
    });
  });

  // =========================================================================
  // 5. BUDGET CALCULATION EDGE CASES
  // =========================================================================

  group('Budget calculation edge cases', () {
    test('Budget with zero amount: progress should be handled safely', () {
      final budget = Budget(
        category: 'Test',
        amount: Decimal.zero,
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      // When budget amount is zero, any spent amount results in 0 or infinity.
      // The app should handle this - verify budget amount is zero.
      expect(budget.amount, equals(0.0));
      expect(budget.amountDecimal, equals(Decimal.zero));

      // Using DecimalHelper.divide for safe division
      final spent = 50.0;
      final progress = DecimalHelper.divide(spent, budget.amount);
      expect(progress, equals(0.0)); // Division by zero returns 0
    });

    test('Budget with matching spent: progress should be 1.0', () {
      final budget = Budget(
        category: 'Food',
        amount: Decimal.parse('300.00'),
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      final spent = 300.0;
      final progress = DecimalHelper.divide(spent, budget.amount);
      expect(progress, equals(1.0));
    });

    test('Budget with overspent: progress should be > 1.0', () {
      final budget = Budget(
        category: 'Food',
        amount: Decimal.parse('300.00'),
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      final spent = 450.0;
      final progress = DecimalHelper.divide(spent, budget.amount);
      expect(progress, equals(1.5));
    });

    test('Budget percentage calculation with precision', () {
      final budget = Budget(
        category: 'Food',
        amount: Decimal.parse('300.00'),
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      final spent = 100.0;
      final percentage = DecimalHelper.percentage(spent, budget.amount);
      // DecimalHelper.divide rounds to 2 decimal places internally,
      // so 100/300 = 0.33, then 0.33 * 100 = 33.0
      expect(percentage, equals(33.0));
    });

    test('MonthlyBalance.hasOverallBudget with zero budget', () {
      final balance = MonthlyBalance(
        carryoverFromPrevious: Decimal.zero,
        overallBudget: Decimal.zero,
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      // Zero budget should be treated as no budget
      expect(balance.hasOverallBudget, isFalse);
    });

    test('MonthlyBalance.hasOverallBudget with positive budget', () {
      final balance = MonthlyBalance(
        carryoverFromPrevious: Decimal.zero,
        overallBudget: Decimal.parse('3000.00'),
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      expect(balance.hasOverallBudget, isTrue);
      expect(balance.overallBudget, equals(3000.0));
    });

    test('MonthlyBalance.hasOverallBudget with null budget', () {
      final balance = MonthlyBalance(
        carryoverFromPrevious: Decimal.zero,
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      expect(balance.hasOverallBudget, isFalse);
      expect(balance.overallBudget, isNull);
    });

    test('MonthlyBalance negative carryover (deficit from previous month)', () {
      final balance = MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('-500.00'),
        accountId: 1,
        month: DateTime.utc(2025, 6, 1),
      );

      expect(balance.carryoverFromPrevious, equals(-500.0));
      expect(balance.carryoverFromPreviousDecimal, equals(Decimal.parse('-500.00')));
    });
  });

  // =========================================================================
  // BONUS: Enum accessibility
  // =========================================================================

  group('Enum accessibility', () {
    test('RecurringExpenseFrequency enum values are accessible', () {
      expect(RecurringExpenseFrequency.values.length, equals(3));
      expect(RecurringExpenseFrequency.monthly.index, equals(0));
      expect(RecurringExpenseFrequency.biweekly.index, equals(1));
      expect(RecurringExpenseFrequency.weekly.index, equals(2));
    });

    test('RecurringFrequency enum values are accessible', () {
      expect(RecurringFrequency.values.length, equals(3));
      expect(RecurringFrequency.monthly.index, equals(0));
      expect(RecurringFrequency.biweekly.index, equals(1));
      expect(RecurringFrequency.weekly.index, equals(2));
    });
  });
}
