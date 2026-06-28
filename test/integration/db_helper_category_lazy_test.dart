import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/category_model.dart';

import '_test_helpers.dart';

/// Integration tests for Category CRUD + the lazy-loading / count / range-query
/// surface of [DatabaseHelper]. These drive the real helper end-to-end through
/// `sqflite_common_ffi` against a file-backed SQLite DB.
///
/// Covers the ❌ Missing slice from `docs/NEXT_SESSION_HANDOFF.md`:
///   createCategory, readAllCategories({type}), updateCategory, deleteCategory,
///   countExpensesByCategory, countIncomesByCategory,
///   getExpensesInRange, getIncomeInRange, getExpenseCount.
///
/// Notes for the integrator (these tests run unverified by the author):
///   * Money is stored as REAL doubles; models expose `double get amount`, so
///     round-trips compare the double getters, not Decimal.
///   * `category` columns are `TEXT NOT NULL`, so a "corrupt" row is simulated
///     with an EMPTY-string category (passes NOT NULL but fails
///     `Expense.fromMap`/`Income.fromMap` validation → dropped by the bulk
///     parsers).
///   * `foreign_keys = ON` is set in the helper's `onConfigure`, so inserting a
///     category against a non-existent account throws a DB exception.
///   * `getIncomeCount(...)` does NOT exist in `database_helper.dart`; it was in
///     the task FOCUS line but is not a real method, so it is intentionally not
///     tested here.
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

  // ======================= Category CRUD =======================

  group('createCategory', () {
    test('round-trips: inserted category is readable with same fields', () async {
      final id = await DatabaseHelper().createCategory(
        Category(
          name: 'Groceries',
          accountId: accountId,
          type: 'expense',
          color: '#112233',
          icon: '57344',
        ),
      );
      expect(id, greaterThan(0));

      final all = await DatabaseHelper().readAllCategories(accountId);
      final created = all.firstWhere((c) => c.id == id);

      expect(created.name, 'Groceries');
      expect(created.accountId, accountId);
      expect(created.type, 'expense');
      expect(created.color, '#112233');
      expect(created.icon, '57344');
      expect(created.isDefault, isFalse);
    });

    test('defaults type to "expense" when constructed without a type', () async {
      // Category() defaults `type` to 'expense' and that is what gets stored.
      final id = await DatabaseHelper().createCategory(
        Category(name: 'NoType', accountId: accountId),
      );

      final all = await DatabaseHelper().readAllCategories(accountId);
      final created = all.firstWhere((c) => c.id == id);
      expect(created.type, 'expense');
    });

    test('rejects a category whose account_id violates the FK', () async {
      // No account with id 999999 exists; foreign_keys = ON should reject it.
      expect(
        () => DatabaseHelper().createCategory(
          Category(name: 'Orphan', accountId: 999999, type: 'expense'),
        ),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('readAllCategories', () {
    test('returns all categories for the account when no type filter is given', () async {
      await DatabaseHelper().createCategory(
        Category(name: 'Food', accountId: accountId, type: 'expense'),
      );
      await DatabaseHelper().createCategory(
        Category(name: 'Salary', accountId: accountId, type: 'income'),
      );

      final all = await DatabaseHelper().readAllCategories(accountId);
      final names = all.map((c) => c.name).toSet();

      expect(names.contains('Food'), isTrue);
      expect(names.contains('Salary'), isTrue);
      expect(all.length, 2);
    });

    test('filters by type = expense', () async {
      await DatabaseHelper().createCategory(
        Category(name: 'Food', accountId: accountId, type: 'expense'),
      );
      await DatabaseHelper().createCategory(
        Category(name: 'Rent', accountId: accountId, type: 'expense'),
      );
      await DatabaseHelper().createCategory(
        Category(name: 'Salary', accountId: accountId, type: 'income'),
      );

      final expenses = await DatabaseHelper().readAllCategories(accountId, type: 'expense');

      expect(expenses.length, 2);
      expect(expenses.every((c) => c.type == 'expense'), isTrue);
    });

    test('filters by type = income', () async {
      await DatabaseHelper().createCategory(
        Category(name: 'Food', accountId: accountId, type: 'expense'),
      );
      await DatabaseHelper().createCategory(
        Category(name: 'Salary', accountId: accountId, type: 'income'),
      );

      final income = await DatabaseHelper().readAllCategories(accountId, type: 'income');

      expect(income.length, 1);
      expect(income.single.name, 'Salary');
      expect(income.single.type, 'income');
    });

    test('is scoped to the given account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await DatabaseHelper().createCategory(
        Category(name: 'MineOnly', accountId: accountId, type: 'expense'),
      );
      await DatabaseHelper().createCategory(
        Category(name: 'TheirOnly', accountId: other, type: 'expense'),
      );

      final mine = await DatabaseHelper().readAllCategories(accountId);
      final theirs = await DatabaseHelper().readAllCategories(other);

      expect(mine.map((c) => c.name).toList(), ['MineOnly']);
      expect(theirs.map((c) => c.name).toList(), ['TheirOnly']);
    });

    test('returns an empty list for an account with no categories', () async {
      final empty = await DatabaseHelper().readAllCategories(accountId);
      expect(empty, isEmpty);
    });
  });

  group('updateCategory', () {
    test('updates the matching row by id', () async {
      final id = await DatabaseHelper().createCategory(
        Category(name: 'Old', accountId: accountId, type: 'expense', color: '#000000'),
      );

      final rows = await DatabaseHelper().updateCategory(
        Category(id: id, name: 'New', accountId: accountId, type: 'expense', color: '#FFFFFF'),
      );
      expect(rows, 1);

      final all = await DatabaseHelper().readAllCategories(accountId);
      final updated = all.firstWhere((c) => c.id == id);
      expect(updated.name, 'New');
      expect(updated.color, '#FFFFFF');
    });

    test('is a no-op (0 rows) for a non-existent id', () async {
      final rows = await DatabaseHelper().updateCategory(
        Category(id: 987654, name: 'Ghost', accountId: accountId, type: 'expense'),
      );
      expect(rows, 0);
    });
  });

  group('deleteCategory', () {
    test('deletes a non-default category', () async {
      final id = await DatabaseHelper().createCategory(
        Category(name: 'Temp', accountId: accountId, type: 'expense', isDefault: false),
      );

      final deleted = await DatabaseHelper().deleteCategory(id);
      expect(deleted, 1);

      final all = await DatabaseHelper().readAllCategories(accountId);
      expect(all.any((c) => c.id == id), isFalse);
    });

    test('does NOT delete a default category (isDefault = 1 guard)', () async {
      final id = await DatabaseHelper().createCategory(
        Category(name: 'Locked', accountId: accountId, type: 'expense', isDefault: true),
      );

      final deleted = await DatabaseHelper().deleteCategory(id);
      expect(deleted, 0);

      final all = await DatabaseHelper().readAllCategories(accountId);
      expect(all.any((c) => c.id == id), isTrue);
    });

    test('returns 0 for a missing id', () async {
      final deleted = await DatabaseHelper().deleteCategory(424242);
      expect(deleted, 0);
    });
  });

  // ============== Counts / range queries (lazy loading) ==============

  group('countExpensesByCategory', () {
    test('counts only rows matching the account and category', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01', category: 'Food');
      await seedExpense(db, accountId: accountId, date: '2026-04-02', category: 'Food');
      await seedExpense(db, accountId: accountId, date: '2026-04-03', category: 'Transport');

      expect(await DatabaseHelper().countExpensesByCategory(accountId, 'Food'), 2);
      expect(await DatabaseHelper().countExpensesByCategory(accountId, 'Transport'), 1);
    });

    test('returns 0 for a category with no expenses', () async {
      expect(await DatabaseHelper().countExpensesByCategory(accountId, 'Nonexistent'), 0);
    });

    test('is scoped to the given account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-04-01', category: 'Food');
      await seedExpense(db, accountId: other, date: '2026-04-01', category: 'Food');

      expect(await DatabaseHelper().countExpensesByCategory(accountId, 'Food'), 1);
      expect(await DatabaseHelper().countExpensesByCategory(other, 'Food'), 1);
    });
  });

  group('countIncomesByCategory', () {
    test('counts only rows matching the account and category', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-01', category: 'Salary');
      await seedIncome(db, accountId: accountId, date: '2026-04-02', category: 'Salary');
      await seedIncome(db, accountId: accountId, date: '2026-04-03', category: 'Gift');

      expect(await DatabaseHelper().countIncomesByCategory(accountId, 'Salary'), 2);
      expect(await DatabaseHelper().countIncomesByCategory(accountId, 'Gift'), 1);
    });

    test('returns 0 for a category with no income', () async {
      expect(await DatabaseHelper().countIncomesByCategory(accountId, 'Nonexistent'), 0);
    });

    test('is scoped to the given account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedIncome(db, accountId: accountId, date: '2026-04-01', category: 'Salary');
      await seedIncome(db, accountId: other, date: '2026-04-01', category: 'Salary');

      expect(await DatabaseHelper().countIncomesByCategory(accountId, 'Salary'), 1);
    });
  });

  group('getExpensesInRange', () {
    test('includes rows on the inclusive start and end boundaries', () async {
      // Range Apr 1..Apr 30; rows on both boundaries must be included (Bug #2).
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 1.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-30', amount: 2.0);

      final rows = await DatabaseHelper().getExpensesInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(rows.length, 2);
      expect(rows.map((e) => e.amount).toSet(), {1.0, 2.0});
    });

    test('excludes rows just outside the range bounds', () async {
      await seedExpense(db, accountId: accountId, date: '2026-03-31', amount: 99.0);
      await seedExpense(db, accountId: accountId, date: '2026-05-01', amount: 88.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-15', amount: 5.0);

      final rows = await DatabaseHelper().getExpensesInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(rows.length, 1);
      expect(rows.single.amount, 5.0);
    });

    test('orders results by date DESC', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-05', amount: 5.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 1.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-20', amount: 20.0);

      final rows = await DatabaseHelper().getExpensesInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      // date DESC → 04-20, 04-05, 04-01
      final dates = rows.map((e) => e.date).toList();
      for (var i = 0; i < dates.length - 1; i++) {
        expect(
          dates[i].isAfter(dates[i + 1]) || dates[i].isAtSameMomentAs(dates[i + 1]),
          isTrue,
          reason: 'expected non-increasing dates, got $dates',
        );
      }
      expect(rows.first.amount, 20.0);
      expect(rows.last.amount, 1.0);
    });

    test('is scoped to the given account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-04-10', amount: 7.0);
      await seedExpense(db, accountId: other, date: '2026-04-10', amount: 9.0);

      final rows = await DatabaseHelper().getExpensesInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(rows.length, 1);
      expect(rows.single.amount, 7.0);
    });

    test('drops corrupt rows (empty category) via _parseExpenseRows', () async {
      // Valid row.
      await seedExpense(db, accountId: accountId, date: '2026-04-10', amount: 5.0, category: 'Food');
      // Corrupt row: empty category passes NOT NULL but fails Expense.fromMap,
      // so tryFromMap returns null and the parser drops it.
      await db.insert('expenses', {
        'amount': 50.0,
        'category': '',
        'description': 'corrupt',
        'date': '2026-04-11',
        'account_id': accountId,
        'amountPaid': 0.0,
        'paymentMethod': 'Cash',
      });

      final rows = await DatabaseHelper().getExpensesInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(rows.length, 1);
      expect(rows.single.amount, 5.0);
    });

    test('returns an empty list when no rows fall in range', () async {
      await seedExpense(db, accountId: accountId, date: '2026-01-01', amount: 1.0);
      final rows = await DatabaseHelper().getExpensesInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );
      expect(rows, isEmpty);
    });
  });

  group('getIncomeInRange', () {
    test('includes rows on the inclusive start and end boundaries', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-01', amount: 100.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-30', amount: 200.0);

      final rows = await DatabaseHelper().getIncomeInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(rows.length, 2);
      expect(rows.map((e) => e.amount).toSet(), {100.0, 200.0});
    });

    test('excludes rows just outside the range bounds', () async {
      await seedIncome(db, accountId: accountId, date: '2026-03-31', amount: 999.0);
      await seedIncome(db, accountId: accountId, date: '2026-05-01', amount: 888.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-15', amount: 50.0);

      final rows = await DatabaseHelper().getIncomeInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(rows.length, 1);
      expect(rows.single.amount, 50.0);
    });

    test('orders results by date DESC', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-05', amount: 5.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-01', amount: 1.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-20', amount: 20.0);

      final rows = await DatabaseHelper().getIncomeInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      final dates = rows.map((e) => e.date).toList();
      for (var i = 0; i < dates.length - 1; i++) {
        expect(
          dates[i].isAfter(dates[i + 1]) || dates[i].isAtSameMomentAs(dates[i + 1]),
          isTrue,
          reason: 'expected non-increasing dates, got $dates',
        );
      }
      expect(rows.first.amount, 20.0);
      expect(rows.last.amount, 1.0);
    });

    test('is scoped to the given account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedIncome(db, accountId: accountId, date: '2026-04-10', amount: 70.0);
      await seedIncome(db, accountId: other, date: '2026-04-10', amount: 90.0);

      final rows = await DatabaseHelper().getIncomeInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(rows.length, 1);
      expect(rows.single.amount, 70.0);
    });

    test('skips corrupt rows (empty category) via inline try/catch', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-10', amount: 100.0, category: 'Salary');
      await db.insert('income', {
        'amount': 500.0,
        'category': '',
        'description': 'corrupt',
        'date': '2026-04-11',
        'account_id': accountId,
      });

      final rows = await DatabaseHelper().getIncomeInRange(
        accountId,
        DateTime(2026, 4, 1),
        DateTime(2026, 4, 30),
      );

      expect(rows.length, 1);
      expect(rows.single.amount, 100.0);
    });
  });

  group('getExpenseCount', () {
    test('returns the number of expenses for the account', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01');
      await seedExpense(db, accountId: accountId, date: '2026-04-02');
      await seedExpense(db, accountId: accountId, date: '2026-04-03');

      expect(await DatabaseHelper().getExpenseCount(accountId), 3);
    });

    test('returns 0 for an account with no expenses', () async {
      expect(await DatabaseHelper().getExpenseCount(accountId), 0);
    });

    test('is scoped to the given account', () async {
      final other = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-04-01');
      await seedExpense(db, accountId: accountId, date: '2026-04-02');
      await seedExpense(db, accountId: other, date: '2026-04-01');

      expect(await DatabaseHelper().getExpenseCount(accountId), 2);
      expect(await DatabaseHelper().getExpenseCount(other), 1);
    });
  });
}
