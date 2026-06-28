import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';

import '_test_helpers.dart';

/// Integration coverage for the SEARCH + JSON-RESTORE slice of
/// `DatabaseHelper` (handoff lines 2442–2468).
///
/// These tests drive the real `DatabaseHelper` end-to-end through
/// `sqflite_common_ffi` — no mocks, no fakes. Every expected value is
/// derived from the lib source (`lib/database/database_helper.dart`):
///   - `searchExpenses` / `searchIncome` — LIKE on description/category with
///     `ESCAPE '\'`, sanitised query, int-only LIMIT/OFFSET interpolation,
///     account scope, empty-query short-circuit.
///   - `searchTransactionsUnified` — UNION ALL of expenses+income, per-token
///     AND, numeric tokens also match `CAST(amount AS TEXT)`, category/date
///     filters, 5 sort orders, `hasMore` when `result.length >= limit`.
///   - `restoreFromJsonBackup` — happy-path counts, L31 malformed-month skip,
///     validation rowsSkipped counting, tag + transaction_tags remap, budget
///     last-write-wins, account fallback, `stats.total`.
///
/// Note: the private `_sanitizeSearchQuery` / `_parseSearchTokens` are tested
/// INDIRECTLY through their public callers (no reachable direct path).
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

  // ===========================================================================
  // searchExpenses
  // ===========================================================================
  group('searchExpenses', () {
    test('matches on description (case where category does not)', () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'morning coffee',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-02',
          description: 'taxi ride',
          category: 'Transport');

      final results = await DatabaseHelper().searchExpenses(accountId, 'coffee');

      expect(results.length, 1);
      expect(results.first.description, 'morning coffee');
    });

    test('matches on category', () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'lunch',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-02',
          description: 'bus',
          category: 'Transport');

      final results =
          await DatabaseHelper().searchExpenses(accountId, 'Transport');

      expect(results.length, 1);
      expect(results.first.category, 'Transport');
    });

    test('empty query returns [] without touching the table', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01');

      final results = await DatabaseHelper().searchExpenses(accountId, '');

      expect(results, isEmpty);
    });

    test('whitespace-only query returns [] (sanitiser trims to empty)',
        () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01');

      final results = await DatabaseHelper().searchExpenses(accountId, '   ');

      expect(results, isEmpty);
    });

    test('no-match query returns []', () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'groceries',
          category: 'Food');

      final results =
          await DatabaseHelper().searchExpenses(accountId, 'zzz-no-such-term');

      expect(results, isEmpty);
    });

    test('only returns rows for the requested account (account scope)',
        () async {
      final otherAccount = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'coffee here',
          category: 'Food');
      await seedExpense(db,
          accountId: otherAccount,
          date: '2026-04-01',
          description: 'coffee there',
          category: 'Food');

      final results = await DatabaseHelper().searchExpenses(accountId, 'coffee');

      expect(results.length, 1);
      expect(results.first.accountId, accountId);
      expect(results.first.description, 'coffee here');
    });

    test('LIKE-wildcard "%" is escaped to a literal, not treated as wildcard',
        () async {
      // _sanitizeSearchQuery turns '%' into '\%' and the query runs with
      // ESCAPE '\', so a search for '%' matches a literal percent sign only.
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: '50% off sale',
          category: 'Shopping');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-02',
          description: 'no special chars',
          category: 'Food');

      final results = await DatabaseHelper().searchExpenses(accountId, '%');

      // If '%' were treated as a wildcard it would match BOTH rows. Escaped,
      // it matches only the row that literally contains a percent sign.
      expect(results.length, 1);
      expect(results.first.description, '50% off sale');
    });

    test('limit caps the number of returned rows', () async {
      for (var i = 0; i < 5; i++) {
        await seedExpense(db,
            accountId: accountId,
            date: '2026-04-0${i + 1}',
            description: 'coffee $i',
            category: 'Food');
      }

      final limited =
          await DatabaseHelper().searchExpenses(accountId, 'coffee', limit: 2);

      expect(limited.length, 2);
    });

    test('limit + offset paginate without overlap', () async {
      for (var i = 0; i < 5; i++) {
        await seedExpense(db,
            accountId: accountId,
            date: '2026-04-0${i + 1}',
            description: 'coffee $i',
            category: 'Food');
      }

      final page1 =
          await DatabaseHelper().searchExpenses(accountId, 'coffee', limit: 2);
      final page2 = await DatabaseHelper()
          .searchExpenses(accountId, 'coffee', limit: 2, offset: 2);

      expect(page1.length, 2);
      expect(page2.length, 2);
      // No id appears on both pages — pagination is disjoint.
      final page1Ids = page1.map((e) => e.id).toSet();
      final page2Ids = page2.map((e) => e.id).toSet();
      expect(page1Ids.intersection(page2Ids), isEmpty);
    });

    test('results are ordered by date DESC', () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'coffee old',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-20',
          description: 'coffee new',
          category: 'Food');

      final results = await DatabaseHelper().searchExpenses(accountId, 'coffee');

      expect(results.length, 2);
      expect(results.first.description, 'coffee new'); // newest first
      expect(results.last.description, 'coffee old');
    });
  });

  // ===========================================================================
  // searchIncome
  // ===========================================================================
  group('searchIncome', () {
    test('matches on description and on category', () async {
      await seedIncome(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'monthly payroll',
          category: 'Salary');
      await seedIncome(db,
          accountId: accountId,
          date: '2026-04-02',
          description: 'side gig',
          category: 'Freelance');

      final byDescription =
          await DatabaseHelper().searchIncome(accountId, 'payroll');
      final byCategory =
          await DatabaseHelper().searchIncome(accountId, 'Freelance');

      expect(byDescription.length, 1);
      expect(byDescription.first.description, 'monthly payroll');
      expect(byCategory.length, 1);
      expect(byCategory.first.category, 'Freelance');
    });

    test('empty query returns []', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-01');

      final results = await DatabaseHelper().searchIncome(accountId, '');

      expect(results, isEmpty);
    });

    test('no-match query returns []', () async {
      await seedIncome(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'salary',
          category: 'Salary');

      final results =
          await DatabaseHelper().searchIncome(accountId, 'zzz-no-such-term');

      expect(results, isEmpty);
    });

    test('only returns rows for the requested account (account scope)',
        () async {
      final otherAccount = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedIncome(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'bonus here',
          category: 'Salary');
      await seedIncome(db,
          accountId: otherAccount,
          date: '2026-04-01',
          description: 'bonus there',
          category: 'Salary');

      final results = await DatabaseHelper().searchIncome(accountId, 'bonus');

      expect(results.length, 1);
      expect(results.first.accountId, accountId);
      expect(results.first.description, 'bonus here');
    });

    test('limit caps returned rows', () async {
      for (var i = 0; i < 4; i++) {
        await seedIncome(db,
            accountId: accountId,
            date: '2026-04-0${i + 1}',
            description: 'payroll $i',
            category: 'Salary');
      }

      final limited =
          await DatabaseHelper().searchIncome(accountId, 'payroll', limit: 2);

      expect(limited.length, 2);
    });
  });

  // ===========================================================================
  // searchTransactionsUnified
  // ===========================================================================
  group('searchTransactionsUnified', () {
    test('merges both expenses and income that match the term', () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'office supplies',
          category: 'Shopping');
      await seedIncome(db,
          accountId: accountId,
          date: '2026-04-02',
          description: 'office rent refund',
          category: 'Other');

      final result =
          await DatabaseHelper().searchTransactionsUnified(accountId, 'office');

      final expenses = result['expenses'] as List<Expense>;
      final income = result['income'] as List<Income>;
      expect(expenses.length, 1);
      expect(income.length, 1);
      expect(expenses.first.description, 'office supplies');
      expect(income.first.description, 'office rent refund');
    });

    test('empty token list returns empty result map (no rows)', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01');
      await seedIncome(db, accountId: accountId, date: '2026-04-01');

      final result =
          await DatabaseHelper().searchTransactionsUnified(accountId, '   ');

      expect(result['expenses'], isEmpty);
      expect(result['income'], isEmpty);
      expect(result['hasMore'], isFalse);
    });

    test('no-match query returns empty expense + income lists', () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'groceries',
          category: 'Food');

      final result = await DatabaseHelper()
          .searchTransactionsUnified(accountId, 'zzz-no-such');

      expect(result['expenses'], isEmpty);
      expect(result['income'], isEmpty);
    });

    test('only returns rows for the requested account (account scope)',
        () async {
      final otherAccount = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'coffee mine',
          category: 'Food');
      await seedExpense(db,
          accountId: otherAccount,
          date: '2026-04-01',
          description: 'coffee theirs',
          category: 'Food');

      final result =
          await DatabaseHelper().searchTransactionsUnified(accountId, 'coffee');

      final expenses = result['expenses'] as List<Expense>;
      expect(expenses.length, 1);
      expect(expenses.first.accountId, accountId);
    });

    test('multi-token query requires ALL tokens to match (AND semantics)',
        () async {
      // Row 1 has both tokens; row 2 has only one. Only row 1 should match.
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'coffee beans',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-02',
          description: 'coffee mug',
          category: 'Shopping');

      final result = await DatabaseHelper()
          .searchTransactionsUnified(accountId, 'coffee beans');

      final expenses = result['expenses'] as List<Expense>;
      expect(expenses.length, 1);
      expect(expenses.first.description, 'coffee beans');
    });

    test('a numeric token also matches the amount via CAST', () async {
      // The numeric token '25' should match an amount of 25.0 even though the
      // description/category do not contain '25'.
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          amount: 25.0,
          description: 'lunch',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-02',
          amount: 99.0,
          description: 'dinner',
          category: 'Food');

      final result =
          await DatabaseHelper().searchTransactionsUnified(accountId, '25');

      final expenses = result['expenses'] as List<Expense>;
      expect(expenses.length, 1);
      expect(expenses.first.amount, 25.0);
    });

    test("category='All' bypasses the category filter", () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'coffee',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-02',
          description: 'coffee maker',
          category: 'Shopping');

      final all = await DatabaseHelper()
          .searchTransactionsUnified(accountId, 'coffee', category: 'All');
      final foodOnly = await DatabaseHelper()
          .searchTransactionsUnified(accountId, 'coffee', category: 'Food');

      final allExpenses = all['expenses'] as List<Expense>;
      final foodExpenses = foodOnly['expenses'] as List<Expense>;
      // 'All' returns both matching rows; 'Food' filters to just the Food one.
      expect(allExpenses.length, 2);
      expect(foodExpenses.length, 1);
      expect(foodExpenses.first.category, 'Food');
    });

    test('startDate/endDate restrict results to the window', () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-03-31',
          description: 'coffee before',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-15',
          description: 'coffee inside',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-05-01',
          description: 'coffee after',
          category: 'Food');

      final result = await DatabaseHelper().searchTransactionsUnified(
        accountId,
        'coffee',
        startDate: '2026-04-01',
        endDate: '2026-04-30',
      );

      final expenses = result['expenses'] as List<Expense>;
      expect(expenses.length, 1);
      expect(expenses.first.description, 'coffee inside');
    });

    test('hasMore is true when result count reaches the limit', () async {
      for (var i = 0; i < 3; i++) {
        await seedExpense(db,
            accountId: accountId,
            date: '2026-04-0${i + 1}',
            description: 'coffee $i',
            category: 'Food');
      }

      final capped = await DatabaseHelper()
          .searchTransactionsUnified(accountId, 'coffee', limit: 2);
      final roomy = await DatabaseHelper()
          .searchTransactionsUnified(accountId, 'coffee', limit: 50);

      // 3 rows match. With limit 2, result.length (2) >= limit (2) → hasMore.
      expect((capped['expenses'] as List<Expense>).length, 2);
      expect(capped['hasMore'], isTrue);
      // With limit 50, only 3 rows come back → hasMore false.
      expect(roomy['hasMore'], isFalse);
    });

    test("sortOrder 'oldest' orders ascending by date", () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-20',
          description: 'coffee newest',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          description: 'coffee oldest',
          category: 'Food');

      final result = await DatabaseHelper().searchTransactionsUnified(
        accountId,
        'coffee',
        sortOrder: 'oldest',
      );

      final expenses = result['expenses'] as List<Expense>;
      expect(expenses.length, 2);
      expect(expenses.first.description, 'coffee oldest');
      expect(expenses.last.description, 'coffee newest');
    });

    test("sortOrder 'highest' orders descending by amount", () async {
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-01',
          amount: 5.0,
          description: 'coffee small',
          category: 'Food');
      await seedExpense(db,
          accountId: accountId,
          date: '2026-04-02',
          amount: 80.0,
          description: 'coffee big',
          category: 'Food');

      final result = await DatabaseHelper().searchTransactionsUnified(
        accountId,
        'coffee',
        sortOrder: 'highest',
      );

      final expenses = result['expenses'] as List<Expense>;
      expect(expenses.length, 2);
      expect(expenses.first.amount, 80.0); // highest first
      expect(expenses.last.amount, 5.0);
    });
  });

  // ===========================================================================
  // restoreFromJsonBackup — focused on the MISSING cases in the handoff slice
  // ===========================================================================
  group('restoreFromJsonBackup', () {
    /// A minimal well-formed backup: 1 account, expenses, incomes, budgets,
    /// categories. Account id 1 in the backup remaps onto the restored row.
    Map<String, dynamic> baseBackup() {
      return {
        'accounts': [
          {
            'id': 1,
            'name': 'Wallet',
            'icon': '💼',
            'color': '#112233',
            'isDefault': 1,
            'currencyCode': 'USD',
          },
        ],
        'categories': [
          {
            'id': 10,
            'account_id': 1,
            'name': 'Coffee',
            'type': 'expense',
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
        ],
        'incomes': [
          {
            'id': 200,
            'account_id': 1,
            'amount': 1000.0,
            'category': 'Salary',
            'description': 'payroll',
            'date': '2026-01-01',
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
        ],
      };
    }

    test('well-formed backup restores expenses/incomes/budgets/categories',
        () async {
      final stats =
          await DatabaseHelper().restoreFromJsonBackup(baseBackup());

      expect(stats.accountsAdded, 1);
      expect(stats.expensesAdded, 2);
      expect(stats.incomesAdded, 1);
      expect(stats.budgetsAdded, 1);
      expect(stats.categoriesAdded, 1);

      // Verify the rows actually landed in the DB on the restored account.
      final wallet = (await db.query('accounts',
              where: 'name = ?', whereArgs: ['Wallet'], limit: 1))
          .first;
      final walletId = wallet['id'] as int;
      final expenses = await db
          .query('expenses', where: 'account_id = ?', whereArgs: [walletId]);
      final incomes = await db
          .query('income', where: 'account_id = ?', whereArgs: [walletId]);
      final budgets = await db
          .query('budgets', where: 'account_id = ?', whereArgs: [walletId]);
      expect(expenses.length, 2);
      expect(incomes.length, 1);
      expect(budgets.length, 1);
      expect((budgets.first['month'] as String), '2026-01');
    });

    test(
        'L31: malformed budget months are skipped while a valid YYYY-MM budget '
        'is added', () async {
      final backup = baseBackup();
      backup['budgets'] = [
        {
          'id': 300,
          'account_id': 1,
          'category': 'Food',
          'amount': 200.0,
          'month': 'garbage', // not YYYY-MM → skipped
        },
        {
          'id': 301,
          'account_id': 1,
          'category': 'Transport',
          'amount': 150.0,
          'month': '99999-13', // does not match ^\d{4}-\d{2} → skipped
        },
        {
          'id': 302,
          'account_id': 1,
          'category': 'Shopping',
          'amount': 100.0,
          'month': '2026-05', // valid → added
        },
      ];

      final stats = await DatabaseHelper().restoreFromJsonBackup(backup);

      // Exactly one budget added; two malformed ones counted as skipped.
      expect(stats.budgetsAdded, 1);
      expect(stats.rowsSkipped, greaterThanOrEqualTo(2));

      final budgets = await db.query('budgets');
      expect(budgets.length, 1);
      expect(budgets.first['month'], '2026-05');
      expect(budgets.first['category'], 'Shopping');
    });

    test('invalid expense rows increment rowsSkipped and are not inserted',
        () async {
      final backup = baseBackup();
      backup['expenses'] = [
        {
          'id': 100,
          'account_id': 1,
          'amount': double.nan, // _isValidAmount → false
          'category': 'Food',
          'description': 'nan amount',
          'date': '2026-01-15',
        },
        {
          'id': 101,
          'account_id': 1,
          'amount': 1e308, // >= 1e10 → rejected
          'category': 'Food',
          'description': 'overflow amount',
          'date': '2026-01-15',
        },
        {
          'id': 102,
          'account_id': 1,
          'amount': 10.0,
          'category': 'Food',
          'description': 'bad date',
          'date': '1900-01-01', // before 2000-01-01 lower bound → rejected
        },
        {
          'id': 103,
          'account_id': 1,
          'amount': 10.0,
          'category': '', // empty category → rejected
          'description': 'no category',
          'date': '2026-01-15',
        },
        {
          'id': 104,
          'account_id': 1,
          'amount': 12.34,
          'category': 'Food',
          'description': 'the good one',
          'date': '2026-01-15',
        },
      ];

      final stats = await DatabaseHelper().restoreFromJsonBackup(backup);

      // Only the last expense is valid.
      expect(stats.expensesAdded, 1);
      expect(stats.rowsSkipped, greaterThanOrEqualTo(4));

      final wallet = (await db.query('accounts',
              where: 'name = ?', whereArgs: ['Wallet'], limit: 1))
          .first;
      final expenses = await db.query('expenses',
          where: 'account_id = ?', whereArgs: [wallet['id']]);
      expect(expenses.length, 1);
      expect(expenses.first['description'], 'the good one');
    });

    test('oversize description (>1024 chars) is rejected', () async {
      final backup = baseBackup();
      backup['expenses'] = [
        {
          'id': 100,
          'account_id': 1,
          'amount': 10.0,
          'category': 'Food',
          'description': 'x' * 1025, // _isValidDescription → false
          'date': '2026-01-15',
        },
      ];

      final stats = await DatabaseHelper().restoreFromJsonBackup(backup);

      expect(stats.expensesAdded, 0);
      expect(stats.rowsSkipped, greaterThanOrEqualTo(1));
    });

    test('tags and transaction_tags are remapped onto new ids', () async {
      final backup = baseBackup();
      // One tag, linked to the first expense (id 100 in the backup).
      backup['tags'] = [
        {
          'id': 50,
          'account_id': 1,
          'name': 'work',
          'color': '#FF00FF',
        },
      ];
      backup['transaction_tags'] = [
        {
          'id': 70,
          'tag_id': 50,
          'transaction_id': 100, // matches expense id 100 in backup
          'transaction_type': 'expense',
        },
        {
          'id': 71,
          'tag_id': 999, // unresolved tag → link dropped to rowsSkipped
          'transaction_id': 100,
          'transaction_type': 'expense',
        },
      ];

      final stats = await DatabaseHelper().restoreFromJsonBackup(backup);

      expect(stats.tagsAdded, 1);
      expect(stats.transactionTagsAdded, 1);
      expect(stats.rowsSkipped, greaterThanOrEqualTo(1));

      // The junction row must point at the NEW tag id and NEW expense id.
      final tags = await db.query('tags', where: 'name = ?', whereArgs: ['work']);
      expect(tags.length, 1);
      final newTagId = tags.first['id'] as int;

      final wallet = (await db.query('accounts',
              where: 'name = ?', whereArgs: ['Wallet'], limit: 1))
          .first;
      final expense = (await db.query('expenses',
              where: 'account_id = ? AND description = ?',
              whereArgs: [wallet['id'], 'coffee'],
              limit: 1))
          .first;
      final newExpenseId = expense['id'] as int;

      final links = await db.query('transaction_tags');
      expect(links.length, 1);
      expect(links.first['tag_id'], newTagId);
      expect(links.first['transaction_id'], newExpenseId);
      expect(links.first['transaction_type'], 'expense');
    });

    test('budget conflict on (account,category,month) is last-write-wins',
        () async {
      final backup = baseBackup();
      // Two budgets for the SAME (account, category, month). The second
      // updates the amount instead of inserting a duplicate.
      backup['budgets'] = [
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
          'amount': 350.0,
          'month': '2026-01',
        },
      ];

      final stats = await DatabaseHelper().restoreFromJsonBackup(backup);

      // First inserts (budgetsAdded == 1); second only updates (no increment).
      expect(stats.budgetsAdded, 1);

      final budgets = await db.query('budgets',
          where: 'category = ? AND month = ?', whereArgs: ['Food', '2026-01']);
      expect(budgets.length, 1);
      // Last write wins → amount is the second value.
      expect((budgets.first['amount'] as num).toDouble(), 350.0);
    });

    test('row with an unmapped account_id falls back to the first DB account',
        () async {
      // The backup carries account id 1 (→ Wallet). An expense referencing a
      // NON-EXISTENT account id 999 should fall back to the first DB account
      // ordered by id ASC, which is the _onCreate default "Main Account".
      final backup = baseBackup();
      backup['expenses'] = [
        {
          'id': 100,
          'account_id': 999, // not present in the backup's accounts
          'amount': 10.0,
          'category': 'Food',
          'description': 'orphan expense',
          'date': '2026-01-15',
        },
      ];

      final stats = await DatabaseHelper().restoreFromJsonBackup(backup);

      // The row is still inserted (fallback), not skipped.
      expect(stats.expensesAdded, 1);

      // First account by id ASC is the seeded default "Main Account".
      final firstAccount = (await db.query('accounts',
              columns: ['id', 'name'], orderBy: 'id ASC', limit: 1))
          .first;
      final orphan = (await db.query('expenses',
              where: 'description = ?', whereArgs: ['orphan expense'], limit: 1))
          .first;
      expect(orphan['account_id'], firstAccount['id']);
    });

    test('stats.total sums every section counter', () async {
      final backup = baseBackup();
      // Add a tag + junction so tagsAdded/transactionTagsAdded contribute too.
      backup['tags'] = [
        {'id': 50, 'account_id': 1, 'name': 'work', 'color': '#FFFFFF'},
      ];
      backup['transaction_tags'] = [
        {
          'id': 70,
          'tag_id': 50,
          'transaction_id': 100,
          'transaction_type': 'expense',
        },
      ];

      final stats = await DatabaseHelper().restoreFromJsonBackup(backup);

      final expectedTotal = stats.accountsAdded +
          stats.categoriesAdded +
          stats.expensesAdded +
          stats.incomesAdded +
          stats.budgetsAdded +
          stats.recurringExpensesAdded +
          stats.recurringIncomesAdded +
          stats.templatesAdded +
          stats.tagsAdded +
          stats.transactionTagsAdded;

      expect(stats.total, expectedTotal);
      // Sanity: at least the sections we populated contributed.
      expect(stats.total, greaterThanOrEqualTo(7));
    });

    test('recurring expense/income dedup on natural key', () async {
      final backup = baseBackup();
      // Two identical recurring expenses (same account/description/frequency/
      // dayOfMonth) → the second is a dup and is skipped (not added, not
      // counted as a validation-skip).
      backup['recurring_expenses'] = [
        {
          'id': 400,
          'account_id': 1,
          'description': 'Netflix',
          'amount': 15.0,
          'category': 'Entertainment',
          'dayOfMonth': 5,
          'frequency': 0,
        },
        {
          'id': 401,
          'account_id': 1,
          'description': 'Netflix',
          'amount': 15.0,
          'category': 'Entertainment',
          'dayOfMonth': 5,
          'frequency': 0,
        },
      ];

      final stats = await DatabaseHelper().restoreFromJsonBackup(backup);

      expect(stats.recurringExpensesAdded, 1);
      final wallet = (await db.query('accounts',
              where: 'name = ?', whereArgs: ['Wallet'], limit: 1))
          .first;
      final recurring = await db.query('recurring_expenses',
          where: 'account_id = ?', whereArgs: [wallet['id']]);
      expect(recurring.length, 1);
    });

    test('quick template with a bad amount is skipped; valid one is added',
        () async {
      // NOTE: the quick_templates schema declares `amount REAL NOT NULL`, so a
      // null-amount template would fail the insert and roll the whole txn back.
      // We therefore test the safe pair: a NaN-amount template is rejected by
      // validation (rowsSkipped++), and a valid-amount template is inserted.
      final backup = baseBackup();
      backup['quick_templates'] = [
        {
          'id': 500,
          'account_id': 1,
          'name': 'Bad Template',
          'amount': double.nan, // present but invalid → skipped
          'category': 'Food',
          'type': 'expense',
        },
        {
          'id': 501,
          'account_id': 1,
          'name': 'Good Template',
          'amount': 12.50, // valid
          'category': 'Food',
          'type': 'expense',
        },
      ];

      final stats = await DatabaseHelper().restoreFromJsonBackup(backup);

      // Only the valid-amount template is added; the NaN one is skipped.
      expect(stats.templatesAdded, 1);
      expect(stats.rowsSkipped, greaterThanOrEqualTo(1));
      final wallet = (await db.query('accounts',
              where: 'name = ?', whereArgs: ['Wallet'], limit: 1))
          .first;
      final templates = await db.query('quick_templates',
          where: 'account_id = ?', whereArgs: [wallet['id']]);
      expect(templates.length, 1);
      expect(templates.first['name'], 'Good Template');
    });
  });
}
