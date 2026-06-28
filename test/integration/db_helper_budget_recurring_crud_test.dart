import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/budget_model.dart';
import 'package:budget_tracker/models/monthly_balance_model.dart';
import 'package:budget_tracker/models/recurring_expense_model.dart';
import 'package:budget_tracker/models/recurring_income_model.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';

import '_test_helpers.dart';

/// Integration coverage for the Budget CRUD, monthly-balance, and
/// recurring expense/income CRUD + batch paths in [DatabaseHelper].
///
/// These methods were marked ❌ Missing / 🟡 Partial in the per-function
/// test plan (docs/NEXT_SESSION_HANDOFF.md lines 2368-2396). They drive the
/// real `DatabaseHelper` end-to-end through `sqflite_common_ffi` against a
/// fresh file-backed DB per test.
///
/// Assertion discipline: amounts are stored as REAL doubles but the models
/// expose `Decimal`. Round-trips construct `Decimal.parse('25.00')` and
/// assert on the public `double` getter (`.amount`) so the floating-point
/// representation is unambiguous. Where an exact internal value is not
/// derivable from the code, a weaker but definitely-true invariant
/// (row count / contains / non-null) is asserted instead.
void main() {
  late Database db;
  late int accountId;

  setUp(() async {
    db = await makeFreshDb();
    accountId = await seedAccount(db);
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  // ======================================================================
  // BUDGET CRUD
  // ======================================================================

  group('createBudget + readAllBudgets', () {
    test('round-trips a budget (amount, category, account, month)', () async {
      final budget = Budget(
        category: 'Food',
        amount: Decimal.parse('250.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      );
      final id = await DatabaseHelper().createBudget(budget);
      expect(id, greaterThan(0));

      final all = await DatabaseHelper().readAllBudgets(accountId);
      expect(all.length, 1);
      final read = all.first;
      expect(read.category, 'Food');
      expect(read.amount, 250.00);
      expect(read.accountId, accountId);
    });

    test('rejects a budget with a non-existent account_id (FK)', () async {
      // foreign_keys are enforced (see _initDatabase PRAGMA). account 999999
      // does not exist, so the insert must fail rather than silently orphan.
      final budget = Budget(
        category: 'Food',
        amount: Decimal.parse('10.00'),
        accountId: 999999,
        month: DateTime.utc(2026, 4, 1),
      );
      await expectLater(
        DatabaseHelper().createBudget(budget),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('returns all budgets when no month filter is given', () async {
      await DatabaseHelper().createBudget(Budget(
        category: 'Food',
        amount: Decimal.parse('100.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 1, 1),
      ));
      await DatabaseHelper().createBudget(Budget(
        category: 'Bills',
        amount: Decimal.parse('200.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 2, 1),
      ));
      await DatabaseHelper().createBudget(Budget(
        category: 'Fun',
        amount: Decimal.parse('300.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 3, 1),
      ));

      final all = await DatabaseHelper().readAllBudgets(accountId);
      expect(all.length, 3);
    });

    test('month filter keeps only budgets inside the YYYY-MM window', () async {
      // March budget — should be the only one returned for the March window.
      await DatabaseHelper().createBudget(Budget(
        category: 'Food',
        amount: Decimal.parse('100.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 3, 1),
      ));
      // April budget — outside the March window.
      await DatabaseHelper().createBudget(Budget(
        category: 'Food',
        amount: Decimal.parse('200.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));

      final marchOnly = await DatabaseHelper()
          .readAllBudgets(accountId, month: DateTime.utc(2026, 3, 15));
      expect(marchOnly.length, 1);
      expect(marchOnly.first.amount, 100.00);
    });

    test('Bug #2: month filter includes a budget dated on the 1st', () async {
      // The 1st-of-month budget must fall inside [YYYY-MM-01, YYYY-MM-last].
      await DatabaseHelper().createBudget(Budget(
        category: 'Food',
        amount: Decimal.parse('55.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));

      final april = await DatabaseHelper()
          .readAllBudgets(accountId, month: DateTime.utc(2026, 4, 1));
      expect(april.length, 1);
      expect(april.first.amount, 55.00);
    });

    test('default 100-row cap is applied when no limit is given', () async {
      // Insert 105 distinct-month budgets; the default limit is 100.
      for (var i = 0; i < 105; i++) {
        final year = 2000 + (i ~/ 12);
        final m = (i % 12) + 1;
        await DatabaseHelper().createBudget(Budget(
          category: 'Cat$i',
          amount: Decimal.parse('1.00'),
          accountId: accountId,
          month: DateTime.utc(year, m, 1),
        ));
      }
      final capped = await DatabaseHelper().readAllBudgets(accountId);
      expect(capped.length, 100);
    });

    test('a custom limit is honoured', () async {
      for (var i = 0; i < 5; i++) {
        await DatabaseHelper().createBudget(Budget(
          category: 'Cat$i',
          amount: Decimal.parse('1.00'),
          accountId: accountId,
          month: DateTime.utc(2020, i + 1, 1),
        ));
      }
      final limited = await DatabaseHelper().readAllBudgets(accountId, limit: 2);
      expect(limited.length, 2);
    });

    test('budgets are ordered by month DESC', () async {
      await DatabaseHelper().createBudget(Budget(
        category: 'Jan',
        amount: Decimal.parse('1.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 1, 1),
      ));
      await DatabaseHelper().createBudget(Budget(
        category: 'Mar',
        amount: Decimal.parse('3.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 3, 1),
      ));
      await DatabaseHelper().createBudget(Budget(
        category: 'Feb',
        amount: Decimal.parse('2.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 2, 1),
      ));

      final all = await DatabaseHelper().readAllBudgets(accountId);
      // Newest month first.
      expect(all.first.month.month, 3);
      expect(all.last.month.month, 1);
    });

    test('readAllBudgets is scoped to the account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().createBudget(Budget(
        category: 'Mine',
        amount: Decimal.parse('1.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));
      await DatabaseHelper().createBudget(Budget(
        category: 'Theirs',
        amount: Decimal.parse('1.00'),
        accountId: other,
        month: DateTime.utc(2026, 4, 1),
      ));

      final mine = await DatabaseHelper().readAllBudgets(accountId);
      expect(mine.length, 1);
      expect(mine.first.category, 'Mine');
    });
  });

  group('getBudgetsForMonth', () {
    test('matches both YYYY-MM and leftover YYYY-MM-DD month strings', () async {
      // A normally-written budget stores month as "2026-04-01".
      await DatabaseHelper().createBudget(Budget(
        category: 'Normal',
        amount: Decimal.parse('10.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));
      // A raw row that stores a bare "2026-04" key (LIKE 'YYYY-MM%' must match).
      await db.insert('budgets', {
        'category': 'BareKey',
        'amount': 20.0,
        'month': '2026-04',
        'account_id': accountId,
      });

      final april = await DatabaseHelper().getBudgetsForMonth(accountId, 2026, 4);
      expect(april.length, 2);
      final cats = april.map((b) => b.category).toSet();
      expect(cats, containsAll(<String>{'Normal', 'BareKey'}));
    });

    test('excludes budgets from a different month', () async {
      await DatabaseHelper().createBudget(Budget(
        category: 'April',
        amount: Decimal.parse('10.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));
      await DatabaseHelper().createBudget(Budget(
        category: 'May',
        amount: Decimal.parse('10.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 5, 1),
      ));

      final april = await DatabaseHelper().getBudgetsForMonth(accountId, 2026, 4);
      expect(april.length, 1);
      expect(april.first.category, 'April');
    });

    test('is scoped to the account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().createBudget(Budget(
        category: 'Mine',
        amount: Decimal.parse('10.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));
      await DatabaseHelper().createBudget(Budget(
        category: 'Theirs',
        amount: Decimal.parse('10.00'),
        accountId: other,
        month: DateTime.utc(2026, 4, 1),
      ));

      final mine = await DatabaseHelper().getBudgetsForMonth(accountId, 2026, 4);
      expect(mine.length, 1);
      expect(mine.first.category, 'Mine');
    });
  });

  group('updateBudget', () {
    test('updates the row identified by id', () async {
      final id = await DatabaseHelper().createBudget(Budget(
        category: 'Food',
        amount: Decimal.parse('100.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));

      final updated = Budget(
        id: id,
        category: 'Groceries',
        amount: Decimal.parse('175.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      );
      final rows = await DatabaseHelper().updateBudget(updated);
      expect(rows, 1);

      final all = await DatabaseHelper().readAllBudgets(accountId);
      expect(all.length, 1);
      expect(all.first.category, 'Groceries');
      expect(all.first.amount, 175.00);
    });

    test('updating a non-existent id changes no rows', () async {
      final ghost = Budget(
        id: 999999,
        category: 'Nope',
        amount: Decimal.parse('1.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      );
      final rows = await DatabaseHelper().updateBudget(ghost);
      expect(rows, 0);
    });
  });

  group('deleteBudget', () {
    test('deletes the row identified by id', () async {
      final id = await DatabaseHelper().createBudget(Budget(
        category: 'Food',
        amount: Decimal.parse('100.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));

      final rows = await DatabaseHelper().deleteBudget(id);
      expect(rows, 1);

      final all = await DatabaseHelper().readAllBudgets(accountId);
      expect(all, isEmpty);
    });

    test('deleting a non-existent id returns 0', () async {
      final rows = await DatabaseHelper().deleteBudget(999999);
      expect(rows, 0);
    });
  });

  // ======================================================================
  // MONTHLY BALANCE READ / WRITE
  // ======================================================================

  group('upsertMonthlyBalance + getMonthlyBalance', () {
    test('inserts a balance when none exists for the month', () async {
      final balance = MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('50.00'),
        overallBudget: Decimal.parse('1000.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      );
      await DatabaseHelper().upsertMonthlyBalance(balance);

      final read =
          await DatabaseHelper().getMonthlyBalance(accountId, DateTime.utc(2026, 4, 1));
      expect(read, isNotNull);
      expect(read!.carryoverFromPrevious, 50.00);
      expect(read.overallBudget, 1000.00);
      expect(read.accountId, accountId);
    });

    test('updates the existing row rather than inserting a duplicate', () async {
      await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('10.00'),
        overallBudget: Decimal.parse('500.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));
      // Second upsert for the SAME (account, month) — must update in place.
      await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('99.00'),
        overallBudget: Decimal.parse('750.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));

      final all = await DatabaseHelper().getMonthlyBalances(accountId);
      expect(all.length, 1, reason: 'upsert must not create a duplicate row');
      expect(all.first.carryoverFromPrevious, 99.00);
      expect(all.first.overallBudget, 750.00);
    });

    test('getMonthlyBalance returns null when no row exists', () async {
      final read =
          await DatabaseHelper().getMonthlyBalance(accountId, DateTime.utc(2026, 4, 1));
      expect(read, isNull);
    });

    test('getMonthlyBalance matches a leftover YYYY-MM-DD month via LIKE', () async {
      // Pre-v19 rows could store the full YYYY-MM-DD; the LIKE 'YYYY-MM%'
      // lookup must still find them.
      await db.insert('monthly_balances', {
        'carryover_from_previous': 12.0,
        'overall_budget': 300.0,
        'account_id': accountId,
        'month': '2026-04-01',
      });

      final read =
          await DatabaseHelper().getMonthlyBalance(accountId, DateTime.utc(2026, 4, 1));
      expect(read, isNotNull);
      expect(read!.carryoverFromPrevious, 12.0);
    });

    test('getMonthlyBalance is scoped to the account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('5.00'),
        accountId: other,
        month: DateTime.utc(2026, 4, 1),
      ));

      // The seeded account has no balance for April → null even though the
      // other account does.
      final mine =
          await DatabaseHelper().getMonthlyBalance(accountId, DateTime.utc(2026, 4, 1));
      expect(mine, isNull);
    });
  });

  group('getMonthlyBalances', () {
    test('returns rows in month-DESC order', () async {
      await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('1.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 1, 1),
      ));
      await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('3.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 3, 1),
      ));
      await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('2.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 2, 1),
      ));

      final all = await DatabaseHelper().getMonthlyBalances(accountId);
      expect(all.length, 3);
      expect(all.first.month.month, 3);
      expect(all.last.month.month, 1);
    });

    test('honours an explicit limit', () async {
      for (var m = 1; m <= 4; m++) {
        await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
          carryoverFromPrevious: Decimal.parse('1.00'),
          accountId: accountId,
          month: DateTime.utc(2026, m, 1),
        ));
      }
      final limited = await DatabaseHelper().getMonthlyBalances(accountId, limit: 2);
      expect(limited.length, 2);
    });

    test('is scoped to the account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('1.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));
      await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('1.00'),
        accountId: other,
        month: DateTime.utc(2026, 4, 1),
      ));

      final mine = await DatabaseHelper().getMonthlyBalances(accountId);
      expect(mine.length, 1);
      expect(mine.first.accountId, accountId);
    });

    test('returns an empty list when the account has no balances', () async {
      final all = await DatabaseHelper().getMonthlyBalances(accountId);
      expect(all, isEmpty);
    });
  });

  group('deleteMonthlyBalance', () {
    test('deletes the row identified by id', () async {
      await DatabaseHelper().upsertMonthlyBalance(MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('1.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      ));
      final rows = await DatabaseHelper().getMonthlyBalances(accountId);
      expect(rows.length, 1);
      final id = rows.first.id!;

      final deleted = await DatabaseHelper().deleteMonthlyBalance(id);
      expect(deleted, 1);
      expect(await DatabaseHelper().getMonthlyBalances(accountId), isEmpty);
    });

    test('deleting a non-existent id returns 0', () async {
      final rows = await DatabaseHelper().deleteMonthlyBalance(999999);
      expect(rows, 0);
    });
  });

  // ======================================================================
  // RECURRING EXPENSE CRUD + BATCH
  // ======================================================================

  group('createRecurringExpense + readAllRecurringExpenses', () {
    test('round-trips a recurring expense with defaults', () async {
      final rec = RecurringExpense(
        description: 'Rent',
        amount: Decimal.parse('1200.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
      );
      final id = await DatabaseHelper().createRecurringExpense(rec);
      expect(id, greaterThan(0));

      final all = await DatabaseHelper().readAllRecurringExpenses(accountId);
      expect(all.length, 1);
      final read = all.first;
      expect(read.description, 'Rent');
      expect(read.amount, 1200.00);
      expect(read.category, 'Bills');
      expect(read.dayOfMonth, 1);
      // Defaults from the model constructor.
      expect(read.isActive, isTrue);
      expect(read.occurrenceCount, 0);
      expect(read.frequency, RecurringExpenseFrequency.monthly);
      expect(read.paymentMethod, 'Cash');
    });

    test('rejects a recurring expense with a bad account_id (FK)', () async {
      final rec = RecurringExpense(
        description: 'Rent',
        amount: Decimal.parse('10.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: 999999,
      );
      await expectLater(
        DatabaseHelper().createRecurringExpense(rec),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('is scoped to the account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Mine',
        amount: Decimal.parse('1.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
      ));
      await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Theirs',
        amount: Decimal.parse('1.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: other,
      ));

      final mine = await DatabaseHelper().readAllRecurringExpenses(accountId);
      expect(mine.length, 1);
      expect(mine.first.description, 'Mine');
    });

    test('returns an empty list for an account with none', () async {
      final all = await DatabaseHelper().readAllRecurringExpenses(accountId);
      expect(all, isEmpty);
    });

    test('drops a corrupt row instead of crashing the read (tryFromMap)', () async {
      // Good row.
      await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Good',
        amount: Decimal.parse('1.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
      ));
      // Corrupt row: dayOfMonth stored as non-numeric TEXT in an INTEGER
      // column. SQLite keeps the literal string, so fromMap's
      // `map['dayOfMonth']` is a String assigned to non-nullable `int` →
      // TypeError → tryFromMap returns null → the row is dropped.
      await db.insert('recurring_expenses', {
        'description': 'Corrupt',
        'amount': 5.0,
        'category': 'Bills',
        'dayOfMonth': 'not-a-number',
        'isActive': 1,
        'account_id': accountId,
        'frequency': 0,
        'occurrenceCount': 0,
      });

      final all = await DatabaseHelper().readAllRecurringExpenses(accountId);
      // Only the good row survives; the read does not throw.
      expect(all.length, 1);
      expect(all.first.description, 'Good');
    });
  });

  group('readActiveRecurringExpenses', () {
    test('excludes inactive rows', () async {
      await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Active',
        amount: Decimal.parse('1.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
        isActive: true,
      ));
      await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Inactive',
        amount: Decimal.parse('1.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
        isActive: false,
      ));

      final active = await DatabaseHelper().readActiveRecurringExpenses(accountId);
      expect(active.length, 1);
      expect(active.first.description, 'Active');
    });

    test('is scoped to the account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Mine',
        amount: Decimal.parse('1.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
        isActive: true,
      ));
      await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Theirs',
        amount: Decimal.parse('1.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: other,
        isActive: true,
      ));

      final mine = await DatabaseHelper().readActiveRecurringExpenses(accountId);
      expect(mine.length, 1);
      expect(mine.first.description, 'Mine');
    });
  });

  group('updateRecurringExpense', () {
    test('updates the row identified by id', () async {
      final id = await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Rent',
        amount: Decimal.parse('1000.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
      ));

      final updated = RecurringExpense(
        id: id,
        description: 'Rent (raised)',
        amount: Decimal.parse('1100.00'),
        category: 'Bills',
        dayOfMonth: 5,
        accountId: accountId,
      );
      final rows = await DatabaseHelper().updateRecurringExpense(updated);
      expect(rows, 1);

      final all = await DatabaseHelper().readAllRecurringExpenses(accountId);
      expect(all.length, 1);
      expect(all.first.description, 'Rent (raised)');
      expect(all.first.amount, 1100.00);
      expect(all.first.dayOfMonth, 5);
    });

    test('updating a non-existent id changes no rows', () async {
      final ghost = RecurringExpense(
        id: 999999,
        description: 'Nope',
        amount: Decimal.parse('1.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
      );
      final rows = await DatabaseHelper().updateRecurringExpense(ghost);
      expect(rows, 0);
    });
  });

  group('deleteRecurringExpense', () {
    test('deletes the row identified by id', () async {
      final id = await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Rent',
        amount: Decimal.parse('1000.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
      ));

      final rows = await DatabaseHelper().deleteRecurringExpense(id);
      expect(rows, 1);
      expect(await DatabaseHelper().readAllRecurringExpenses(accountId), isEmpty);
    });

    test('deleting a non-existent id returns 0', () async {
      final rows = await DatabaseHelper().deleteRecurringExpense(999999);
      expect(rows, 0);
    });
  });

  group('createRecurringExpensesBatch', () {
    test('commits all expenses and the recurring update atomically', () async {
      final id = await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Rent',
        amount: Decimal.parse('1000.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
        occurrenceCount: 0,
      ));

      final recurring = RecurringExpense(
        id: id,
        description: 'Rent',
        amount: Decimal.parse('1000.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
        occurrenceCount: 2,
        lastCreated: DateTime.utc(2026, 4, 1),
      );

      final expenses = [
        Expense(
          amount: Decimal.parse('1000.00'),
          category: 'Bills',
          description: 'Rent Apr',
          date: DateTime.utc(2026, 4, 1),
          accountId: accountId,
        ),
        Expense(
          amount: Decimal.parse('1000.00'),
          category: 'Bills',
          description: 'Rent May',
          date: DateTime.utc(2026, 5, 1),
          accountId: accountId,
        ),
      ];

      await DatabaseHelper().createRecurringExpensesBatch(
        expenses: expenses,
        recurringToUpdate: recurring,
      );

      // Both expenses were inserted.
      final inserted = await db.query('expenses', where: 'account_id = ?', whereArgs: [accountId]);
      expect(inserted.length, 2);

      // The recurring row's occurrenceCount was updated to 2.
      final recRows = await DatabaseHelper().readAllRecurringExpenses(accountId);
      expect(recRows.length, 1);
      expect(recRows.first.occurrenceCount, 2);
    });

    test('rolls back every insert if one expense FK-fails', () async {
      final id = await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Rent',
        amount: Decimal.parse('1000.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
        occurrenceCount: 0,
      ));

      final recurring = RecurringExpense(
        id: id,
        description: 'Rent',
        amount: Decimal.parse('1000.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
        occurrenceCount: 5,
      );

      final expenses = [
        // Valid.
        Expense(
          amount: Decimal.parse('10.00'),
          category: 'Bills',
          description: 'Good',
          date: DateTime.utc(2026, 4, 1),
          accountId: accountId,
        ),
        // Invalid account → FK violation aborts the transaction.
        Expense(
          amount: Decimal.parse('10.00'),
          category: 'Bills',
          description: 'BadFk',
          date: DateTime.utc(2026, 4, 2),
          accountId: 999999,
        ),
      ];

      await expectLater(
        DatabaseHelper().createRecurringExpensesBatch(
          expenses: expenses,
          recurringToUpdate: recurring,
        ),
        throwsA(isA<DatabaseException>()),
      );

      // Nothing committed: no expenses, and the recurring update rolled back.
      final inserted = await db.query('expenses');
      expect(inserted, isEmpty, reason: 'the valid insert must roll back too');
      final recRows = await DatabaseHelper().readAllRecurringExpenses(accountId);
      expect(recRows.first.occurrenceCount, 0,
          reason: 'recurring update must roll back with the failed batch');
    });

    test('an empty expense list still updates the recurring row', () async {
      final id = await DatabaseHelper().createRecurringExpense(RecurringExpense(
        description: 'Rent',
        amount: Decimal.parse('1000.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
        occurrenceCount: 0,
      ));

      final recurring = RecurringExpense(
        id: id,
        description: 'Rent',
        amount: Decimal.parse('1000.00'),
        category: 'Bills',
        dayOfMonth: 1,
        accountId: accountId,
        occurrenceCount: 7,
      );

      await DatabaseHelper().createRecurringExpensesBatch(
        expenses: const [],
        recurringToUpdate: recurring,
      );

      final inserted = await db.query('expenses');
      expect(inserted, isEmpty);
      final recRows = await DatabaseHelper().readAllRecurringExpenses(accountId);
      expect(recRows.first.occurrenceCount, 7);
    });
  });

  // ======================================================================
  // RECURRING INCOME CRUD + BATCH
  // ======================================================================

  group('createRecurringIncome + readAllRecurringIncome', () {
    test('round-trips a recurring income with defaults', () async {
      final rec = RecurringIncome(
        description: 'Salary',
        amount: Decimal.parse('3000.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: accountId,
      );
      final id = await DatabaseHelper().createRecurringIncome(rec);
      expect(id, greaterThan(0));

      final all = await DatabaseHelper().readAllRecurringIncome(accountId);
      expect(all.length, 1);
      final read = all.first;
      expect(read.description, 'Salary');
      expect(read.amount, 3000.00);
      expect(read.category, 'Salary');
      expect(read.dayOfMonth, 28);
      expect(read.isActive, isTrue);
      expect(read.occurrenceCount, 0);
      expect(read.frequency, RecurringFrequency.monthly);
    });

    test('rejects a recurring income with a bad account_id (FK)', () async {
      final rec = RecurringIncome(
        description: 'Salary',
        amount: Decimal.parse('10.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: 999999,
      );
      await expectLater(
        DatabaseHelper().createRecurringIncome(rec),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('is scoped to the account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Mine',
        amount: Decimal.parse('1.00'),
        category: 'Salary',
        dayOfMonth: 1,
        accountId: accountId,
      ));
      await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Theirs',
        amount: Decimal.parse('1.00'),
        category: 'Salary',
        dayOfMonth: 1,
        accountId: other,
      ));

      final mine = await DatabaseHelper().readAllRecurringIncome(accountId);
      expect(mine.length, 1);
      expect(mine.first.description, 'Mine');
    });

    test('returns an empty list for an account with none', () async {
      final all = await DatabaseHelper().readAllRecurringIncome(accountId);
      expect(all, isEmpty);
    });

    test('drops a corrupt row instead of crashing the read (tryFromMap)', () async {
      await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Good',
        amount: Decimal.parse('1.00'),
        category: 'Salary',
        dayOfMonth: 1,
        accountId: accountId,
      ));
      // Corrupt: dayOfMonth as non-numeric TEXT → TypeError → dropped.
      await db.insert('recurring_income', {
        'description': 'Corrupt',
        'amount': 5.0,
        'category': 'Salary',
        'dayOfMonth': 'not-a-number',
        'isActive': 1,
        'account_id': accountId,
        'frequency': 0,
        'occurrenceCount': 0,
      });

      final all = await DatabaseHelper().readAllRecurringIncome(accountId);
      expect(all.length, 1);
      expect(all.first.description, 'Good');
    });
  });

  group('readActiveRecurringIncome', () {
    test('excludes inactive rows', () async {
      await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Active',
        amount: Decimal.parse('1.00'),
        category: 'Salary',
        dayOfMonth: 1,
        accountId: accountId,
        isActive: true,
      ));
      await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Inactive',
        amount: Decimal.parse('1.00'),
        category: 'Salary',
        dayOfMonth: 1,
        accountId: accountId,
        isActive: false,
      ));

      final active = await DatabaseHelper().readActiveRecurringIncome(accountId);
      expect(active.length, 1);
      expect(active.first.description, 'Active');
    });

    test('is scoped to the account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Mine',
        amount: Decimal.parse('1.00'),
        category: 'Salary',
        dayOfMonth: 1,
        accountId: accountId,
        isActive: true,
      ));
      await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Theirs',
        amount: Decimal.parse('1.00'),
        category: 'Salary',
        dayOfMonth: 1,
        accountId: other,
        isActive: true,
      ));

      final mine = await DatabaseHelper().readActiveRecurringIncome(accountId);
      expect(mine.length, 1);
      expect(mine.first.description, 'Mine');
    });
  });

  group('updateRecurringIncome', () {
    test('updates the row identified by id', () async {
      final id = await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Salary',
        amount: Decimal.parse('3000.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: accountId,
      ));

      final updated = RecurringIncome(
        id: id,
        description: 'Salary (raise)',
        amount: Decimal.parse('3300.00'),
        category: 'Salary',
        dayOfMonth: 30,
        accountId: accountId,
      );
      final rows = await DatabaseHelper().updateRecurringIncome(updated);
      expect(rows, 1);

      final all = await DatabaseHelper().readAllRecurringIncome(accountId);
      expect(all.length, 1);
      expect(all.first.description, 'Salary (raise)');
      expect(all.first.amount, 3300.00);
      expect(all.first.dayOfMonth, 30);
    });

    test('updating a non-existent id changes no rows', () async {
      final ghost = RecurringIncome(
        id: 999999,
        description: 'Nope',
        amount: Decimal.parse('1.00'),
        category: 'Salary',
        dayOfMonth: 1,
        accountId: accountId,
      );
      final rows = await DatabaseHelper().updateRecurringIncome(ghost);
      expect(rows, 0);
    });
  });

  group('deleteRecurringIncome', () {
    test('deletes the row identified by id', () async {
      final id = await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Salary',
        amount: Decimal.parse('3000.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: accountId,
      ));

      final rows = await DatabaseHelper().deleteRecurringIncome(id);
      expect(rows, 1);
      expect(await DatabaseHelper().readAllRecurringIncome(accountId), isEmpty);
    });

    test('deleting a non-existent id returns 0', () async {
      final rows = await DatabaseHelper().deleteRecurringIncome(999999);
      expect(rows, 0);
    });
  });

  group('createRecurringIncomeBatch', () {
    test('commits all income rows and the recurring update atomically', () async {
      final id = await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Salary',
        amount: Decimal.parse('3000.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: accountId,
        occurrenceCount: 0,
      ));

      final recurring = RecurringIncome(
        id: id,
        description: 'Salary',
        amount: Decimal.parse('3000.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: accountId,
        occurrenceCount: 2,
      );

      final incomes = [
        Income(
          amount: Decimal.parse('3000.00'),
          category: 'Salary',
          description: 'Salary Apr',
          date: DateTime.utc(2026, 4, 28),
          accountId: accountId,
        ),
        Income(
          amount: Decimal.parse('3000.00'),
          category: 'Salary',
          description: 'Salary May',
          date: DateTime.utc(2026, 5, 28),
          accountId: accountId,
        ),
      ];

      await DatabaseHelper().createRecurringIncomeBatch(
        incomes: incomes,
        recurringToUpdate: recurring,
      );

      final inserted = await db.query('income', where: 'account_id = ?', whereArgs: [accountId]);
      expect(inserted.length, 2);

      final recRows = await DatabaseHelper().readAllRecurringIncome(accountId);
      expect(recRows.length, 1);
      expect(recRows.first.occurrenceCount, 2);
    });

    test('rolls back every insert if one income FK-fails', () async {
      final id = await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Salary',
        amount: Decimal.parse('3000.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: accountId,
        occurrenceCount: 0,
      ));

      final recurring = RecurringIncome(
        id: id,
        description: 'Salary',
        amount: Decimal.parse('3000.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: accountId,
        occurrenceCount: 9,
      );

      final incomes = [
        Income(
          amount: Decimal.parse('10.00'),
          category: 'Salary',
          description: 'Good',
          date: DateTime.utc(2026, 4, 1),
          accountId: accountId,
        ),
        Income(
          amount: Decimal.parse('10.00'),
          category: 'Salary',
          description: 'BadFk',
          date: DateTime.utc(2026, 4, 2),
          accountId: 999999,
        ),
      ];

      await expectLater(
        DatabaseHelper().createRecurringIncomeBatch(
          incomes: incomes,
          recurringToUpdate: recurring,
        ),
        throwsA(isA<DatabaseException>()),
      );

      final inserted = await db.query('income');
      expect(inserted, isEmpty, reason: 'the valid insert must roll back too');
      final recRows = await DatabaseHelper().readAllRecurringIncome(accountId);
      expect(recRows.first.occurrenceCount, 0,
          reason: 'recurring update must roll back with the failed batch');
    });

    test('an empty income list still updates the recurring row', () async {
      final id = await DatabaseHelper().createRecurringIncome(RecurringIncome(
        description: 'Salary',
        amount: Decimal.parse('3000.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: accountId,
        occurrenceCount: 0,
      ));

      final recurring = RecurringIncome(
        id: id,
        description: 'Salary',
        amount: Decimal.parse('3000.00'),
        category: 'Salary',
        dayOfMonth: 28,
        accountId: accountId,
        occurrenceCount: 4,
      );

      await DatabaseHelper().createRecurringIncomeBatch(
        incomes: const [],
        recurringToUpdate: recurring,
      );

      final inserted = await db.query('income');
      expect(inserted, isEmpty);
      final recRows = await DatabaseHelper().readAllRecurringIncome(accountId);
      expect(recRows.first.occurrenceCount, 4);
    });
  });
}
