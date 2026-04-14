import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budget_tracker/database/database_helper.dart';

import '_test_helpers.dart';

/// FIX Phase 3c — Regression tests for Bug #3 and Bug #9.
///
/// **Bug #3** — Backup restore round-trip lost both account-id linkages
/// and budget months. The old path piped every row through
/// `AppState.addExpense()` / `AppState.setBudget()` which resolved the
/// account from `currentAccountId` and the month from `_selectedMonth`,
/// collapsing historical data into "today's account, today's month".
/// The fix writes directly through the database and preserves the
/// original `account_id` and `month` fields.
///
/// **Bug #9** — `restoreFromJsonBackup` now validates
/// `schema_version` against the installed
/// `DatabaseConstants.databaseVersion` and throws
/// [BackupRestoreException] if the backup is newer than the app.
///
/// These tests drive the real DatabaseHelper end-to-end through
/// `sqflite_common_ffi` — no mocks, no fakes.
void main() {
  late Database db;

  setUp(() async {
    db = await makeFreshDb();
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  /// Build a backup map modeling a device with:
  /// - 2 accounts (Checking id=1, Savings id=2)
  /// - 5 expenses split across both accounts across multiple dates
  /// - 2 incomes, one per account
  /// - 3 budgets in 3 different historical months
  Map<String, dynamic> sampleBackup({int? schemaVersion}) {
    return {
      if (schemaVersion != null) 'schema_version': schemaVersion,
      'accounts': [
        {
          'id': 1,
          'name': 'Checking',
          'icon': '💳',
          'color': '#0000FF',
          'isDefault': 1,
          'currencyCode': 'USD',
        },
        {
          'id': 2,
          'name': 'Savings',
          'icon': '🏦',
          'color': '#00FF00',
          'isDefault': 0,
          'currencyCode': 'USD',
        },
      ],
      'expenses': [
        {
          'id': 100,
          'account_id': 1,
          'amount': 10.0,
          'category': 'Food',
          'description': 'coffee',
          'date': '2026-01-15',
          'amountPaid': 0.0,
          'paymentMethod': 'Cash',
        },
        {
          'id': 101,
          'account_id': 1,
          'amount': 20.0,
          'category': 'Food',
          'description': 'lunch',
          'date': '2026-02-10',
          'amountPaid': 0.0,
          'paymentMethod': 'Cash',
        },
        {
          'id': 102,
          'account_id': 2,
          'amount': 30.0,
          'category': 'Transport',
          'description': 'gas',
          'date': '2026-03-05',
          'amountPaid': 0.0,
          'paymentMethod': 'Card',
        },
        {
          'id': 103,
          'account_id': 2,
          'amount': 40.0,
          'category': 'Transport',
          'description': 'parking',
          'date': '2026-03-22',
          'amountPaid': 0.0,
          'paymentMethod': 'Card',
        },
        {
          'id': 104,
          'account_id': 1,
          'amount': 50.0,
          'category': 'Entertainment',
          'description': 'movie',
          'date': '2026-04-01',
          'amountPaid': 0.0,
          'paymentMethod': 'Cash',
        },
      ],
      'incomes': [
        {
          'id': 200,
          'account_id': 1,
          'amount': 1000.0,
          'category': 'Salary',
          'description': 'January payroll',
          'date': '2026-01-01',
        },
        {
          'id': 201,
          'account_id': 2,
          'amount': 500.0,
          'category': 'Interest',
          'description': 'CD payout',
          'date': '2026-03-31',
        },
      ],
      'budgets': [
        {
          'id': 300,
          'account_id': 1,
          'category': 'Food',
          'amount': 200.0,
          'month': '2026-01',
        },
        {
          'id': 301,
          'account_id': 1,
          'category': 'Food',
          'amount': 250.0,
          'month': '2026-02',
        },
        {
          'id': 302,
          'account_id': 2,
          'category': 'Transport',
          'amount': 150.0,
          'month': '2026-03',
        },
      ],
    };
  }

  group('restoreFromJsonBackup — Bug #3 regression', () {
    test('restores 2 accounts with distinct ids', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(sampleBackup());

      expect(stats.accountsAdded, 2);
      // _onCreate seeds a default "Main Account" row, so the table has
      // the two restored accounts alongside the pre-existing default.
      final accounts = await db.query('accounts', orderBy: 'name ASC');
      final names = accounts.map((a) => a['name']).toSet();
      expect(names, containsAll(['Checking', 'Savings']));
    });

    test('preserves expense → account linkage after restore', () async {
      await DatabaseHelper().restoreFromJsonBackup(sampleBackup());

      final accounts = await db.query('accounts', orderBy: 'name ASC');
      final checking = accounts.firstWhere((a) => a['name'] == 'Checking');
      final savings = accounts.firstWhere((a) => a['name'] == 'Savings');

      final checkingExpenses = await db.query(
        'expenses',
        where: 'account_id = ?',
        whereArgs: [checking['id']],
      );
      final savingsExpenses = await db.query(
        'expenses',
        where: 'account_id = ?',
        whereArgs: [savings['id']],
      );

      // 3 expenses were on Checking (id=1), 2 on Savings (id=2) in the backup.
      expect(checkingExpenses.length, 3);
      expect(savingsExpenses.length, 2);

      final checkingSum = checkingExpenses.fold<double>(
        0,
        (sum, row) => sum + (row['amount'] as num).toDouble(),
      );
      final savingsSum = savingsExpenses.fold<double>(
        0,
        (sum, row) => sum + (row['amount'] as num).toDouble(),
      );
      // 10 + 20 + 50 = 80 on Checking; 30 + 40 = 70 on Savings.
      expect(checkingSum, 80.0);
      expect(savingsSum, 70.0);
    });

    test('preserves expense dates verbatim — no today-collapse', () async {
      await DatabaseHelper().restoreFromJsonBackup(sampleBackup());

      final expenses = await db.query('expenses', orderBy: 'date ASC');
      final dates = expenses.map((e) => e['date'] as String).toList();
      expect(dates, [
        '2026-01-15',
        '2026-02-10',
        '2026-03-05',
        '2026-03-22',
        '2026-04-01',
      ]);
    });

    test('preserves budget months — no selected-month collapse', () async {
      await DatabaseHelper().restoreFromJsonBackup(sampleBackup());

      final budgets = await db.query('budgets', orderBy: 'month ASC');
      expect(budgets.length, 3);
      final months = budgets.map((b) => b['month'] as String).toList();
      // Each budget was authored in a different historical month.
      expect(months, ['2026-01', '2026-02', '2026-03']);
    });

    test('income rows preserve account mapping', () async {
      await DatabaseHelper().restoreFromJsonBackup(sampleBackup());

      final accounts = await db.query('accounts', orderBy: 'name ASC');
      final checking = accounts.firstWhere((a) => a['name'] == 'Checking');
      final savings = accounts.firstWhere((a) => a['name'] == 'Savings');

      final checkingIncome = await db.query(
        'income',
        where: 'account_id = ?',
        whereArgs: [checking['id']],
      );
      final savingsIncome = await db.query(
        'income',
        where: 'account_id = ?',
        whereArgs: [savings['id']],
      );
      expect(checkingIncome.length, 1);
      expect((checkingIncome.first['amount'] as num).toDouble(), 1000.0);
      expect(savingsIncome.length, 1);
      expect((savingsIncome.first['amount'] as num).toDouble(), 500.0);
    });

    test('stats reflect every row inserted', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(sampleBackup());

      expect(stats.accountsAdded, 2);
      expect(stats.expensesAdded, 5);
      expect(stats.incomesAdded, 2);
      expect(stats.budgetsAdded, 3);
    });

    test('accounts with the same name merge instead of duplicating', () async {
      // Seed Checking before restore — the backup's Checking should map onto it.
      final existingId = await seedAccount(db, name: 'Checking');

      final stats = await DatabaseHelper().restoreFromJsonBackup(sampleBackup());

      // Only Savings should be freshly added. Total table rows are
      // the default Main Account + the seeded Checking + the restored
      // Savings = 3.
      expect(stats.accountsAdded, 1);
      final accounts = await db.query('accounts');
      expect(accounts.length, 3);

      // Checking-backed expenses should target the pre-existing id.
      final checkingExpenses = await db.query(
        'expenses',
        where: 'account_id = ?',
        whereArgs: [existingId],
      );
      expect(checkingExpenses.length, 3);
    });
  });

  group('restoreFromJsonBackup — Bug #9 schema version', () {
    test('rejects a backup from a newer schema', () async {
      final future = DatabaseHelper().restoreFromJsonBackup(
        sampleBackup(schemaVersion: 999),
      );
      expect(future, throwsA(isA<BackupRestoreException>()));
    });

    test('rejected backups do not write any rows', () async {
      // Capture baseline — _onCreate seeds a default Main Account row.
      final baselineAccounts = (await db.query('accounts')).length;

      try {
        await DatabaseHelper().restoreFromJsonBackup(
          sampleBackup(schemaVersion: 999),
        );
      } catch (_) {
        // expected
      }
      // Schema-version rejection runs BEFORE the write transaction, so
      // the accounts count should be exactly the baseline and every
      // restore-targeted table should still be empty.
      final accounts = await db.query('accounts');
      final expenses = await db.query('expenses');
      final incomes = await db.query('income');
      final budgets = await db.query('budgets');
      expect(accounts.length, baselineAccounts);
      expect(expenses, isEmpty);
      expect(incomes, isEmpty);
      expect(budgets, isEmpty);
    });

    test('accepts a backup with the current schema version', () async {
      // 18 is the live DatabaseConstants.databaseVersion.
      final stats = await DatabaseHelper().restoreFromJsonBackup(
        sampleBackup(schemaVersion: 18),
      );
      expect(stats.accountsAdded, 2);
      expect(stats.expensesAdded, 5);
    });

    test('accepts a legacy backup with no schema_version field', () async {
      final stats = await DatabaseHelper().restoreFromJsonBackup(sampleBackup());
      expect(stats.accountsAdded, 2);
    });
  });
}
