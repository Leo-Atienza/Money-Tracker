import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budget_tracker/database/database_helper.dart';

import '_test_helpers.dart';

/// Phase 5 (Wave 5 — giant test gaps): row-parse resilience + backup input
/// validators.
///
/// Everything under test here is PRIVATE in `database_helper.dart`, so each
/// case drives it through a public caller:
///
///  * `_parseExpenseRows` / `_parseIncomeRows` — exercised by inserting a
///    deliberately-corrupt row via raw `db.insert` (empty-string `category`,
///    which satisfies the `TEXT NOT NULL` column but makes `Expense.tryFromMap`
///    / `Income.tryFromMap` return null) alongside valid rows, then asserting
///    `readAllExpenses` / `readAllIncome` returns only the valid rows with no
///    throw. The DB schema forbids NULL `category` / `account_id`, so an empty
///    string is the only constraint-legal way to forge a row that the parser
///    must drop.
///
///  * `_isValidAmount` / `_isValidBackupDate` / `_isValidDescription` —
///    exercised through `restoreFromJsonBackup`. The expense/income row gate is
///    `validAmount && validDate && validDescription && non-empty-String
///    category`; a row that fails any one increments `stats.rowsSkipped`, while
///    a clean row increments `stats.expensesAdded` / `incomesAdded`. To isolate
///    one validator, the other inputs are held valid and only the field under
///    test is varied.
///
/// Backup JSON shape (only the keys these tests need):
///   {
///     'accounts': [ {id, name, ...} ],
///     'expenses': [ {id, amount, category, description, date, account_id} ],
///     'incomes':  [ {id, amount, category, description, date, account_id} ],
///   }
/// `restoreFromJsonBackup` returns a `BackupRestoreStats` with `expensesAdded`,
/// `incomesAdded`, and `rowsSkipped` counters.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late int accountId;

  setUp(() async {
    db = await makeFreshDb();
    accountId = await seedAccount(db);
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  /// Build a minimal, valid backup whose only `accounts` entry maps to the
  /// seeded account by name. Expense/income rows reference `account_id`, which
  /// `restoreFromJsonBackup` remaps (and falls back to the first account if no
  /// mapping exists), so the original numeric id here is not load-bearing.
  Map<String, dynamic> backupWith({
    List<Map<String, dynamic>> expenses = const [],
    List<Map<String, dynamic>> incomes = const [],
  }) {
    return <String, dynamic>{
      'accounts': [
        {
          'id': 1,
          'name': 'Test Account',
          'icon': '💼',
          'color': '#FF0000',
          'isDefault': 1,
          'currencyCode': 'USD',
        },
      ],
      'expenses': expenses,
      'incomes': incomes,
    };
  }

  Map<String, dynamic> expenseRow({
    dynamic amount = 25.00,
    dynamic category = 'Food',
    dynamic description = 'valid',
    dynamic date = '2026-04-10',
    int accountId = 1,
    int id = 1,
  }) {
    return <String, dynamic>{
      'id': id,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date,
      'account_id': accountId,
    };
  }

  Map<String, dynamic> incomeRow({
    dynamic amount = 100.00,
    dynamic category = 'Salary',
    dynamic description = 'valid',
    dynamic date = '2026-04-10',
    int accountId = 1,
    int id = 1,
  }) {
    return <String, dynamic>{
      'id': id,
      'amount': amount,
      'category': category,
      'description': description,
      'date': date,
      'account_id': accountId,
    };
  }

  // ---------------------------------------------------------------------------
  // _parseExpenseRows / _parseIncomeRows — corrupt-row resilience
  // ---------------------------------------------------------------------------

  group('_parseExpenseRows (via readAllExpenses)', () {
    test('all-valid rows pass through unchanged', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 10.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-02', amount: 20.0);

      final rows = await DatabaseHelper().readAllExpenses(accountId);

      expect(rows.length, 2);
      expect(rows.map((e) => e.amount).toSet(), {10.0, 20.0});
    });

    test('corrupt row (empty-string category) is dropped, valid neighbours kept',
        () async {
      // Two valid rows.
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 10.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-03', amount: 30.0);
      // A constraint-legal but parser-corrupt row: empty category. The
      // `TEXT NOT NULL` column accepts '', but `Expense.fromMap` throws
      // ArgumentError on an empty category, so `tryFromMap` returns null and
      // `_parseExpenseRows` must drop it.
      await db.insert('expenses', {
        'amount': 99.0,
        'category': '',
        'description': 'corrupt',
        'date': '2026-04-02',
        'account_id': accountId,
        'amountPaid': 0.0,
        'paymentMethod': 'Cash',
      });

      final rows = await DatabaseHelper().readAllExpenses(accountId);

      // Corrupt row dropped, no throw, both valid rows survive.
      expect(rows.length, 2);
      final amounts = rows.map((e) => e.amount).toSet();
      expect(amounts, {10.0, 30.0});
      expect(amounts.contains(99.0), isFalse);
    });

    test('all-corrupt input yields empty list (no throw)', () async {
      await db.insert('expenses', {
        'amount': 5.0,
        'category': '',
        'description': 'corrupt',
        'date': '2026-04-02',
        'account_id': accountId,
        'amountPaid': 0.0,
        'paymentMethod': 'Cash',
      });

      final rows = await DatabaseHelper().readAllExpenses(accountId);

      expect(rows, isEmpty);
    });

    test('empty table returns empty list', () async {
      final rows = await DatabaseHelper().readAllExpenses(accountId);
      expect(rows, isEmpty);
    });

    test('rows come back in date DESC order', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 1.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-03', amount: 3.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-02', amount: 2.0);

      final rows = await DatabaseHelper().readAllExpenses(accountId);

      expect(rows.length, 3);
      // date DESC → newest first.
      expect(rows.first.amount, 3.0);
      expect(rows.last.amount, 1.0);
    });
  });

  group('_parseIncomeRows (via readAllIncome)', () {
    test('all-valid rows pass through unchanged', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-01', amount: 100.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-02', amount: 200.0);

      final rows = await DatabaseHelper().readAllIncome(accountId);

      expect(rows.length, 2);
      expect(rows.map((e) => e.amount).toSet(), {100.0, 200.0});
    });

    test('corrupt row (empty-string category) is dropped, valid neighbours kept',
        () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-01', amount: 100.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-03', amount: 300.0);
      await db.insert('income', {
        'amount': 999.0,
        'category': '',
        'description': 'corrupt',
        'date': '2026-04-02',
        'account_id': accountId,
      });

      final rows = await DatabaseHelper().readAllIncome(accountId);

      expect(rows.length, 2);
      final amounts = rows.map((e) => e.amount).toSet();
      expect(amounts, {100.0, 300.0});
      expect(amounts.contains(999.0), isFalse);
    });

    test('empty table returns empty list', () async {
      final rows = await DatabaseHelper().readAllIncome(accountId);
      expect(rows, isEmpty);
    });

    test('rows come back in date DESC order', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-01', amount: 10.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-03', amount: 30.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-02', amount: 20.0);

      final rows = await DatabaseHelper().readAllIncome(accountId);

      expect(rows.length, 3);
      expect(rows.first.amount, 30.0);
      expect(rows.last.amount, 10.0);
    });
  });

  // ---------------------------------------------------------------------------
  // _isValidAmount (via restoreFromJsonBackup)
  // ---------------------------------------------------------------------------

  group('_isValidAmount (via restoreFromJsonBackup)', () {
    test('valid mid-range amount is added', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: 25.00)]),
      );

      expect(stats.expensesAdded, 1);
      expect(stats.rowsSkipped, 0);
    });

    test('zero amount is accepted', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: 0)]),
      );

      expect(stats.expensesAdded, 1);
      expect(stats.rowsSkipped, 0);
    });

    test('negative amount (-0.01) is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: -0.01)]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('amount exactly 1e10 is rejected (>= 1e10 guard)', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: 1e10)]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('amount just under 1e10 (1e10 - 1) is accepted', () async {
      // 1e10 - 1 == 9999999999.0, which is < 1e10.
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: 1e10 - 1)]),
      );

      expect(stats.expensesAdded, 1);
      expect(stats.rowsSkipped, 0);
    });

    test('overflow-injection amount (1e308) is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: 1e308)]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('infinity amount is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: double.infinity)]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('NaN amount is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: double.nan)]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('non-numeric amount (String) is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: 'not-a-number')]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('null amount is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(amount: null)]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('valid and invalid amounts in one backup: valid added, invalid skipped',
        () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [
          expenseRow(id: 1, amount: 25.00),
          expenseRow(id: 2, amount: -5.0),
          expenseRow(id: 3, amount: 1e10),
          expenseRow(id: 4, amount: 50.00),
        ]),
      );

      expect(stats.expensesAdded, 2);
      expect(stats.rowsSkipped, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // _isValidBackupDate (via restoreFromJsonBackup)
  // ---------------------------------------------------------------------------

  group('_isValidBackupDate (via restoreFromJsonBackup)', () {
    test('valid recent date is added', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(date: '2026-04-10')]),
      );

      expect(stats.expensesAdded, 1);
      expect(stats.rowsSkipped, 0);
    });

    test('lower-bound date 2000-01-01 is accepted', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(date: '2000-01-01')]),
      );

      expect(stats.expensesAdded, 1);
      expect(stats.rowsSkipped, 0);
    });

    test('date below lower bound (1999-12-31) is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(date: '1999-12-31')]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('unparseable date string is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(date: 'not-a-date')]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('non-string date (int) is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(date: 20260410)]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('far-future date well beyond +100y (year 9999) is rejected', () async {
      // The upper bound is now + 365*100 days; year 9999 is far past it
      // regardless of the exact run date, so this is a stable assertion.
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(date: '9999-12-31')]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // _isValidDescription (via restoreFromJsonBackup)
  // ---------------------------------------------------------------------------

  group('_isValidDescription (via restoreFromJsonBackup)', () {
    test('null description is accepted (optional field)', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(description: null)]),
      );

      expect(stats.expensesAdded, 1);
      expect(stats.rowsSkipped, 0);
    });

    test('1024-char description is accepted (boundary)', () async {
      final desc = 'a' * 1024;
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(description: desc)]),
      );

      expect(stats.expensesAdded, 1);
      expect(stats.rowsSkipped, 0);
    });

    test('1025-char description is rejected (over boundary)', () async {
      final desc = 'a' * 1025;
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(description: desc)]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('non-string description (int) is rejected', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [expenseRow(description: 42)]),
      );

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Validators also gate the income restore path (same helpers, parallel gate)
  // ---------------------------------------------------------------------------

  group('validators gate income rows too', () {
    test('valid income row is added', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(incomes: [incomeRow(amount: 100.0)]),
      );

      expect(stats.incomesAdded, 1);
      expect(stats.rowsSkipped, 0);
    });

    test('income with invalid amount is skipped', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(incomes: [incomeRow(amount: -1.0)]),
      );

      expect(stats.incomesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });

    test('income with empty-string category is skipped', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(incomes: [incomeRow(category: '')]),
      );

      expect(stats.incomesAdded, 0);
      expect(stats.rowsSkipped, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // End-to-end: a restored valid row is readable back through the parse path,
  // tying the validator gate and the row-parser together.
  // ---------------------------------------------------------------------------

  group('restore → readback round-trip', () {
    test('a valid restored expense is readable via readAllExpenses', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        backupWith(expenses: [
          expenseRow(amount: 42.50, category: 'Food', date: '2026-04-10'),
        ]),
      );
      expect(stats.expensesAdded, 1);

      final rows = await DatabaseHelper().readAllExpenses(accountId);
      expect(rows.length, 1);
      expect(rows.first.amount, 42.50);
      expect(rows.first.category, 'Food');
    });
  });
}
