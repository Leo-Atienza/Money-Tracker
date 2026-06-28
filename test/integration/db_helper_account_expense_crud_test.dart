import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/account_model.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/monthly_balance_model.dart';

import '_test_helpers.dart';

/// Wave 5 — DB-level Account CRUD + Expense CRUD + carryover coverage.
///
/// Targets the 🟡 Partial / ❌ Missing rows of the "Account CRUD" and
/// "Expense CRUD + carryover" slices in
/// `docs/NEXT_SESSION_HANDOFF.md` (lines 2330–2367). Every test drives the
/// real [DatabaseHelper] end-to-end through `sqflite_common_ffi` against a
/// fresh file-backed DB (see `_test_helpers.dart`), so expected values are
/// derived from the lib source, not from a mock.
///
/// Boilerplate (mock channels + SharedPreferences then `makeFreshDb`) mirrors
/// `app_state_crud_test.dart`. The DB CRUD paths exercised here do not touch
/// those plugin channels, but the stubs keep the file robust if a method is
/// later reached that does.
void main() {
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null)
      ..setMockMethodCallHandler(secureChannel, (_) async => null)
      ..setMockMethodCallHandler(
        pathProviderChannel,
        (_) async => '.dart_tool/test_path_provider',
      );

    SharedPreferences.setMockInitialValues(<String, Object>{});

    db = await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null)
      ..setMockMethodCallHandler(secureChannel, null)
      ..setMockMethodCallHandler(pathProviderChannel, null);

    await DatabaseHelper.resetForTesting();
  });

  // -------------------------------------------------------------------------
  // Account CRUD
  // -------------------------------------------------------------------------
  group('createAccount', () {
    test('round-trips name/icon/color/isDefault/currencyCode', () async {
      final id = await DatabaseHelper().createAccount(
        Account(
          name: 'Travel',
          icon: '✈️',
          color: '#112233',
          isDefault: false,
          currencyCode: 'EUR',
        ),
      );
      expect(id, greaterThan(0));

      final accounts = await DatabaseHelper().readAllAccounts();
      final loaded = accounts.firstWhere((a) => a.id == id);
      expect(loaded.name, 'Travel');
      expect(loaded.icon, '✈️');
      expect(loaded.color, '#112233');
      expect(loaded.isDefault, isFalse);
      expect(loaded.currencyCode, 'EUR');
    });

    test('defaults currencyCode to USD when not provided', () async {
      // The Account model defaults currencyCode to 'USD'; toMap serialises it.
      final id = await DatabaseHelper().createAccount(
        Account(name: 'NoCurrency'),
      );

      final accounts = await DatabaseHelper().readAllAccounts();
      final loaded = accounts.firstWhere((a) => a.id == id);
      expect(loaded.currencyCode, 'USD');
    });
  });

  group('readAllAccounts', () {
    test('orders by isDefault DESC then name ASC', () async {
      // makeFreshDb seeds a default "Main Account" (isDefault=1) via _initDatabase.
      // Add three non-default accounts out of alphabetical order.
      await DatabaseHelper()
          .createAccount(Account(name: 'Zebra', isDefault: false));
      await DatabaseHelper()
          .createAccount(Account(name: 'Alpha', isDefault: false));
      await DatabaseHelper()
          .createAccount(Account(name: 'Mango', isDefault: false));

      final accounts = await DatabaseHelper().readAllAccounts();

      // First row must be the default account.
      expect(accounts.first.isDefault, isTrue);

      // Among the non-default rows, names must be ascending.
      final nonDefaultNames =
          accounts.where((a) => !a.isDefault).map((a) => a.name).toList();
      final sorted = [...nonDefaultNames]..sort();
      expect(nonDefaultNames, sorted);
      expect(nonDefaultNames, containsAll(['Alpha', 'Mango', 'Zebra']));
    });

    test('skips a corrupt account row instead of crashing', () async {
      // Insert a raw row with an empty name — Account.fromMap throws
      // ArgumentError on empty name, and readAllAccounts catches + skips it.
      await db.insert('accounts', {
        'name': '',
        'icon': '?',
        'color': '#000000',
        'isDefault': 0,
        'currencyCode': 'USD',
      });
      // And a valid row to prove the good one still loads.
      final goodId =
          await DatabaseHelper().createAccount(Account(name: 'Healthy'));

      final accounts = await DatabaseHelper().readAllAccounts();

      // The empty-name row is dropped; the healthy one survives.
      expect(accounts.any((a) => a.name.isEmpty), isFalse);
      expect(accounts.any((a) => a.id == goodId), isTrue);
    });

    test('returns only the seeded default for a freshly initialised DB',
        () async {
      final accounts = await DatabaseHelper().readAllAccounts();
      expect(accounts.length, 1);
      expect(accounts.first.isDefault, isTrue);
    });
  });

  group('updateAccount', () {
    test('updates the matching row and reports one row affected', () async {
      final id = await DatabaseHelper()
          .createAccount(Account(name: 'Before', currencyCode: 'USD'));

      final rows = await DatabaseHelper().updateAccount(
        Account(id: id, name: 'After', currencyCode: 'GBP'),
      );
      expect(rows, 1);

      final accounts = await DatabaseHelper().readAllAccounts();
      final loaded = accounts.firstWhere((a) => a.id == id);
      expect(loaded.name, 'After');
      expect(loaded.currencyCode, 'GBP');
    });

    test('is a no-op (zero rows) for a nonexistent id', () async {
      final rows = await DatabaseHelper().updateAccount(
        Account(id: 999999, name: 'Ghost'),
      );
      expect(rows, 0);
    });
  });

  group('setDefaultAccountById', () {
    test('leaves exactly one default and clears the previous one', () async {
      // Seeded default is "Main Account". Add a second account.
      final newId =
          await DatabaseHelper().createAccount(Account(name: 'Secondary'));

      await DatabaseHelper().setDefaultAccountById(newId);

      final accounts = await DatabaseHelper().readAllAccounts();
      final defaults = accounts.where((a) => a.isDefault).toList();
      expect(defaults.length, 1);
      expect(defaults.single.id, newId);

      // The originally-seeded default must no longer be flagged.
      final previousDefault =
          accounts.firstWhere((a) => a.name == 'Main Account');
      expect(previousDefault.isDefault, isFalse);
    });

    test('clears all defaults when the target id does not exist', () async {
      // The txn unconditionally clears every isDefault, then the targeted
      // UPDATE matches nothing — leaving zero defaults.
      await DatabaseHelper().setDefaultAccountById(424242);

      final accounts = await DatabaseHelper().readAllAccounts();
      expect(accounts.where((a) => a.isDefault), isEmpty);
    });
  });

  group('deleteAccount guard clauses', () {
    test('throws when asked to delete the default account', () async {
      final accounts = await DatabaseHelper().readAllAccounts();
      final defaultId = accounts.firstWhere((a) => a.isDefault).id!;

      await expectLater(
        DatabaseHelper().deleteAccount(defaultId),
        throwsA(isA<Exception>()),
      );

      // The default account is still present.
      final after = await DatabaseHelper().readAllAccounts();
      expect(after.any((a) => a.id == defaultId), isTrue);
    });

    test('throws when the account id does not exist', () async {
      await expectLater(
        DatabaseHelper().deleteAccount(987654),
        throwsA(isA<Exception>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Expense CRUD
  // -------------------------------------------------------------------------
  group('createExpense', () {
    test('round-trips all fields including amountPaid/paymentMethod',
        () async {
      final accountId = await seedAccount(db, name: 'ExpAcct', isDefault: 0);

      final id = await DatabaseHelper().createExpense(
        Expense(
          amount: Decimal.parse('25.00'),
          category: 'Groceries',
          description: 'weekly shop',
          date: DateTime.utc(2026, 4, 10),
          accountId: accountId,
          amountPaid: Decimal.parse('10.00'),
          paymentMethod: 'Card',
        ),
      );
      expect(id, greaterThan(0));

      final expenses = await DatabaseHelper().readAllExpenses(accountId);
      final loaded = expenses.firstWhere((e) => e.id == id);
      expect(loaded.amount, 25.0);
      expect(loaded.category, 'Groceries');
      expect(loaded.description, 'weekly shop');
      expect(loaded.accountId, accountId);
      expect(loaded.amountPaid, 10.0);
      expect(loaded.paymentMethod, 'Card');
      // date column stored as yyyy-MM-dd; readback normalises to UTC midnight.
      expect(loaded.date.year, 2026);
      expect(loaded.date.month, 4);
      expect(loaded.date.day, 10);
    });

    test('applies amountPaid=0 and paymentMethod=Cash defaults', () async {
      final accountId = await seedAccount(db, name: 'Defaults', isDefault: 0);

      // Expense model defaults amountPaid -> Decimal.zero, paymentMethod -> 'Cash'.
      final id = await DatabaseHelper().createExpense(
        Expense(
          amount: Decimal.parse('40.00'),
          category: 'Misc',
          description: '',
          date: DateTime.utc(2026, 4, 5),
          accountId: accountId,
        ),
      );

      final expenses = await DatabaseHelper().readAllExpenses(accountId);
      final loaded = expenses.firstWhere((e) => e.id == id);
      expect(loaded.amountPaid, 0.0);
      expect(loaded.paymentMethod, 'Cash');
    });

    test('rejects an expense whose account_id has no parent account',
        () async {
      // foreign_keys=ON (onConfigure) makes the FK violation throw.
      await expectLater(
        DatabaseHelper().createExpense(
          Expense(
            amount: Decimal.parse('5.00'),
            category: 'Food',
            description: 'orphan',
            date: DateTime.utc(2026, 4, 1),
            accountId: 555555, // no such account
          ),
        ),
        throwsA(anything),
      );
    });

    test('preserves amountPaid/remaining/isPaid fidelity on round-trip',
        () async {
      final accountId = await seedAccount(db, name: 'Fidelity', isDefault: 0);

      final id = await DatabaseHelper().createExpense(
        Expense(
          amount: Decimal.parse('99.99'),
          category: 'Bills',
          description: 'partial',
          date: DateTime.utc(2026, 4, 2),
          accountId: accountId,
          amountPaid: Decimal.parse('30.00'),
        ),
      );

      final expenses = await DatabaseHelper().readAllExpenses(accountId);
      final loaded = expenses.firstWhere((e) => e.id == id);
      expect(loaded.amount, 99.99);
      expect(loaded.amountPaid, 30.0);
      // remainingAmount = amount - amountPaid (Decimal math).
      expect(loaded.remainingAmount, closeTo(69.99, 1e-9));
      expect(loaded.isPaid, isFalse);
    });

    test('marks isPaid true and remaining zero when fully paid', () async {
      final accountId = await seedAccount(db, name: 'Paid', isDefault: 0);

      final id = await DatabaseHelper().createExpense(
        Expense(
          amount: Decimal.parse('50.00'),
          category: 'Bills',
          description: 'settled',
          date: DateTime.utc(2026, 4, 3),
          accountId: accountId,
          amountPaid: Decimal.parse('50.00'),
        ),
      );

      final expenses = await DatabaseHelper().readAllExpenses(accountId);
      final loaded = expenses.firstWhere((e) => e.id == id);
      expect(loaded.isPaid, isTrue);
      expect(loaded.remainingAmount, closeTo(0.0, 1e-9));
    });
  });

  group('readAllExpenses', () {
    test('orders by date DESC', () async {
      final accountId = await seedAccount(db, name: 'Ordered', isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 1.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-15', amount: 2.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-10', amount: 3.0);

      final expenses = await DatabaseHelper().readAllExpenses(accountId);

      final dates = expenses.map((e) => e.date).toList();
      // Each date should be >= the next (descending).
      for (var i = 0; i + 1 < dates.length; i++) {
        expect(
          dates[i].isAfter(dates[i + 1]) || dates[i].isAtSameMomentAs(dates[i + 1]),
          isTrue,
        );
      }
      expect(expenses.first.date, DateTime.utc(2026, 4, 15));
    });

    test('is scoped to the requested account', () async {
      final a = await seedAccount(db, name: 'A', isDefault: 0);
      final b = await seedAccount(db, name: 'B', isDefault: 0);
      await seedExpense(db, accountId: a, date: '2026-04-01', amount: 11.0);
      await seedExpense(db, accountId: a, date: '2026-04-02', amount: 12.0);
      await seedExpense(db, accountId: b, date: '2026-04-01', amount: 99.0);

      final forA = await DatabaseHelper().readAllExpenses(a);
      expect(forA.length, 2);
      expect(forA.every((e) => e.accountId == a), isTrue);
    });

    test('drops a corrupt expense row (missing category) but keeps the rest',
        () async {
      final accountId = await seedAccount(db, name: 'Corrupt', isDefault: 0);
      // Valid row.
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 5.0);
      // Corrupt row: the `category` column is NOT NULL, so the only
      // constraint-legal way to forge a row that the DB accepts but
      // Expense.fromMap rejects is an EMPTY-STRING category (fromMap throws on
      // category.isEmpty). tryFromMap then returns null and _parseExpenseRows
      // skips it.
      await db.insert('expenses', {
        'amount': 7.0,
        'category': '',
        'description': 'bad',
        'date': '2026-04-02',
        'account_id': accountId,
        'amountPaid': 0.0,
        'paymentMethod': 'Cash',
      });

      final expenses = await DatabaseHelper().readAllExpenses(accountId);
      expect(expenses.length, 1);
      expect(expenses.single.amount, 5.0);
    });

    test('returns an empty list for an account with no expenses', () async {
      final accountId = await seedAccount(db, name: 'Empty', isDefault: 0);
      final expenses = await DatabaseHelper().readAllExpenses(accountId);
      expect(expenses, isEmpty);
    });
  });

  group('updateExpense', () {
    test('updates the row and reports one row affected', () async {
      final accountId = await seedAccount(db, name: 'Upd', isDefault: 0);
      final id = await DatabaseHelper().createExpense(
        Expense(
          amount: Decimal.parse('10.00'),
          category: 'Old',
          description: 'old',
          date: DateTime.utc(2026, 4, 1),
          accountId: accountId,
        ),
      );

      final rows = await DatabaseHelper().updateExpense(
        Expense(
          id: id,
          amount: Decimal.parse('22.50'),
          category: 'New',
          description: 'new',
          date: DateTime.utc(2026, 4, 1),
          accountId: accountId,
          amountPaid: Decimal.parse('5.00'),
          paymentMethod: 'Card',
        ),
      );
      expect(rows, 1);

      final loaded = await DatabaseHelper().getExpenseById(id);
      expect(loaded, isNotNull);
      expect(loaded!.amount, 22.50);
      expect(loaded.category, 'New');
      expect(loaded.amountPaid, 5.0);
      expect(loaded.paymentMethod, 'Card');
    });

    test('is a no-op (zero rows) for a nonexistent id', () async {
      final accountId = await seedAccount(db, name: 'NoExp', isDefault: 0);
      final rows = await DatabaseHelper().updateExpense(
        Expense(
          id: 999999,
          amount: Decimal.parse('1.00'),
          category: 'Ghost',
          description: '',
          date: DateTime.utc(2026, 4, 1),
          accountId: accountId,
        ),
      );
      expect(rows, 0);
    });
  });

  group('deleteExpense', () {
    test('deletes the expense row and reports one row removed', () async {
      final accountId = await seedAccount(db, name: 'Del', isDefault: 0);
      final id =
          await seedExpense(db, accountId: accountId, date: '2026-04-01');

      final removed = await DatabaseHelper().deleteExpense(id);
      expect(removed, 1);

      final after = await DatabaseHelper().getExpenseById(id);
      expect(after, isNull);
    });

    test('scrubs the expense transaction_tags links before delete', () async {
      final accountId = await seedAccount(db, name: 'DelTags', isDefault: 0);
      final id =
          await seedExpense(db, accountId: accountId, date: '2026-04-01');

      // Seed a tag + an expense-side link, plus an income-side link with the
      // same id to prove the scrub is type-scoped (only 'expense' removed).
      final tagId = await db.insert('tags', {
        'name': 'food',
        'color': '#FF0000',
        'account_id': accountId,
      });
      await db.insert('transaction_tags', {
        'transaction_id': id,
        'transaction_type': 'expense',
        'tag_id': tagId,
      });
      await db.insert('transaction_tags', {
        'transaction_id': id,
        'transaction_type': 'income',
        'tag_id': tagId,
      });

      await DatabaseHelper().deleteExpense(id);

      final expenseLinks = await db.rawQuery(
        'SELECT COUNT(*) c FROM transaction_tags '
        'WHERE transaction_id = ? AND transaction_type = ?',
        [id, 'expense'],
      );
      final incomeLinks = await db.rawQuery(
        'SELECT COUNT(*) c FROM transaction_tags '
        'WHERE transaction_id = ? AND transaction_type = ?',
        [id, 'income'],
      );
      expect((expenseLinks.first['c'] as int?) ?? -1, 0);
      // Income-side link with the same id must be untouched.
      expect((incomeLinks.first['c'] as int?) ?? -1, 1);
    });

    test('returns zero rows for a nonexistent id', () async {
      final removed = await DatabaseHelper().deleteExpense(999999);
      expect(removed, 0);
    });
  });

  group('getExpenseById / getIncomeById', () {
    test('getExpenseById returns the row when present', () async {
      final accountId = await seedAccount(db, name: 'ById', isDefault: 0);
      final id = await seedExpense(
        db,
        accountId: accountId,
        date: '2026-04-07',
        amount: 33.0,
        category: 'Fuel',
      );

      final loaded = await DatabaseHelper().getExpenseById(id);
      expect(loaded, isNotNull);
      expect(loaded!.id, id);
      expect(loaded.amount, 33.0);
      expect(loaded.category, 'Fuel');
    });

    test('getExpenseById returns null for a missing id', () async {
      final loaded = await DatabaseHelper().getExpenseById(999999);
      expect(loaded, isNull);
    });

    test('getExpenseById throws on a corrupt row (fromMap, not tryFromMap)',
        () async {
      final accountId = await seedAccount(db, name: 'Throws', isDefault: 0);
      // Insert a row with an EMPTY-STRING category (NOT NULL column forbids a
      // null). getExpenseById uses Expense.fromMap directly, which throws
      // ArgumentError on the empty category — divergent from the list readers
      // that silently skip corrupt rows.
      final id = await db.insert('expenses', {
        'amount': 1.0,
        'category': '',
        'description': 'bad',
        'date': '2026-04-01',
        'account_id': accountId,
        'amountPaid': 0.0,
        'paymentMethod': 'Cash',
      });

      await expectLater(
        DatabaseHelper().getExpenseById(id),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('getIncomeById returns null for a missing id', () async {
      final loaded = await DatabaseHelper().getIncomeById(999999);
      expect(loaded, isNull);
    });

    test('getIncomeById returns the row when present', () async {
      final accountId = await seedAccount(db, name: 'IncById', isDefault: 0);
      final id = await seedIncome(
        db,
        accountId: accountId,
        date: '2026-04-09',
        amount: 250.0,
        category: 'Bonus',
      );

      final loaded = await DatabaseHelper().getIncomeById(id);
      expect(loaded, isNotNull);
      expect(loaded!.id, id);
      expect(loaded.amount, 250.0);
      expect(loaded.category, 'Bonus');
    });
  });

  // -------------------------------------------------------------------------
  // Month-window readers (getExpensesByMonth scoping + getExpensesInRange)
  // -------------------------------------------------------------------------
  group('getExpensesByMonth scoping', () {
    test('is scoped to the requested account', () async {
      final a = await seedAccount(db, name: 'MonthA', isDefault: 0);
      final b = await seedAccount(db, name: 'MonthB', isDefault: 0);
      await seedExpense(db, accountId: a, date: '2026-04-01', amount: 7.0);
      await seedExpense(db, accountId: b, date: '2026-04-01', amount: 99.0);

      final rows = await DatabaseHelper().getExpensesByMonth(a, 2026, 4);
      expect(rows.length, 1);
      expect(rows.single.amount, 7.0);
      expect(rows.single.accountId, a);
    });

    test('excludes rows outside the month window', () async {
      final accountId = await seedAccount(db, name: 'Window', isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-03-31', amount: 1.0);
      await seedExpense(db, accountId: accountId, date: '2026-05-01', amount: 2.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-30', amount: 3.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 4.0);

      final rows = await DatabaseHelper().getExpensesByMonth(accountId, 2026, 4);
      final amounts = rows.map((e) => e.amount).toSet();
      expect(amounts, {3.0, 4.0});
    });
  });

  group('getExpensesInRange', () {
    test('includes the inclusive start and end dates', () async {
      final accountId = await seedAccount(db, name: 'Range', isDefault: 0);
      await seedExpense(db, accountId: accountId, date: '2026-04-10', amount: 10.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-20', amount: 20.0);
      // Just outside the [10th, 20th] window.
      await seedExpense(db, accountId: accountId, date: '2026-04-09', amount: 9.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-21', amount: 21.0);

      final rows = await DatabaseHelper().getExpensesInRange(
        accountId,
        DateTime.utc(2026, 4, 10),
        DateTime.utc(2026, 4, 20),
      );
      final amounts = rows.map((e) => e.amount).toSet();
      expect(amounts, {10.0, 20.0});
    });

    test('is scoped to the requested account', () async {
      final a = await seedAccount(db, name: 'RngA', isDefault: 0);
      final b = await seedAccount(db, name: 'RngB', isDefault: 0);
      await seedExpense(db, accountId: a, date: '2026-04-15', amount: 5.0);
      await seedExpense(db, accountId: b, date: '2026-04-15', amount: 6.0);

      final rows = await DatabaseHelper().getExpensesInRange(
        a,
        DateTime.utc(2026, 4, 1),
        DateTime.utc(2026, 4, 30),
      );
      expect(rows.length, 1);
      expect(rows.single.accountId, a);
    });
  });

  // -------------------------------------------------------------------------
  // Carryover: _upsertMonthlyBalanceTxn YYYY-MM-DD leftover match (indirect)
  // -------------------------------------------------------------------------
  group('createExpenseWithCarryover / _upsertMonthlyBalanceTxn', () {
    test('commits both the expense insert and a new monthly_balance row',
        () async {
      final accountId = await seedAccount(db, name: 'Carry', isDefault: 0);

      final balance = MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('12.34'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      );
      final expense = Expense(
        amount: Decimal.parse('15.00'),
        category: 'Food',
        description: 'lunch',
        date: DateTime.utc(2026, 4, 12),
        accountId: accountId,
      );

      final expenseId = await DatabaseHelper()
          .createExpenseWithCarryover(expense, [balance]);
      expect(expenseId, greaterThan(0));

      // Expense landed.
      final loadedExpense = await DatabaseHelper().getExpenseById(expenseId);
      expect(loadedExpense, isNotNull);
      expect(loadedExpense!.amount, 15.0);

      // Exactly one monthly_balance row for this (account, 2026-04).
      final mbRows = await db.query(
        'monthly_balances',
        where: 'account_id = ? AND month LIKE ?',
        whereArgs: [accountId, '2026-04%'],
      );
      expect(mbRows.length, 1);
      expect((mbRows.single['carryover_from_previous'] as num).toDouble(),
          closeTo(12.34, 1e-9));
    });

    test(
        'updates a pre-existing YYYY-MM-DD leftover row via the LIKE prefix '
        '(no duplicate insert)', () async {
      final accountId = await seedAccount(db, name: 'Leftover', isDefault: 0);

      // Simulate a pre-v19 leftover row stored with a full YYYY-MM-DD month
      // key that escaped the substr(month,1,7) normalisation.
      final leftoverId = await db.insert('monthly_balances', {
        'carryover_from_previous': 1.00,
        'overall_budget': null,
        'account_id': accountId,
        'month': '2026-04-01', // YYYY-MM-DD leftover
      });

      // Upsert a MonthlyBalance for the same (account, 2026-04). The txn helper
      // matches via `month LIKE '2026-04%'` and UPDATEs the leftover row
      // rather than inserting a second row.
      final balance = MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('77.00'),
        accountId: accountId,
        month: DateTime.utc(2026, 4, 1),
      );
      final expense = Expense(
        amount: Decimal.parse('5.00'),
        category: 'Food',
        description: 'snack',
        date: DateTime.utc(2026, 4, 3),
        accountId: accountId,
      );

      await DatabaseHelper().createExpenseWithCarryover(expense, [balance]);

      // Still exactly one row for this account+month — the leftover was
      // updated, not duplicated.
      final rows = await db.query(
        'monthly_balances',
        where: 'account_id = ? AND month LIKE ?',
        whereArgs: [accountId, '2026-04%'],
      );
      expect(rows.length, 1);
      // Same row id, updated carryover value.
      expect(rows.single['id'], leftoverId);
      expect((rows.single['carryover_from_previous'] as num).toDouble(),
          closeTo(77.00, 1e-9));
    });

    test('rolls back the expense when a balance upsert hits an FK violation',
        () async {
      final accountId = await seedAccount(db, name: 'Rollback', isDefault: 0);

      final expense = Expense(
        amount: Decimal.parse('8.00'),
        category: 'Food',
        description: 'fk-rollback',
        date: DateTime.utc(2026, 4, 4),
        accountId: accountId,
      );
      // Balance points at a nonexistent account_id, so the monthly_balances
      // FK fails inside the txn and the whole batch rolls back.
      final badBalance = MonthlyBalance(
        carryoverFromPrevious: Decimal.parse('1.00'),
        accountId: 313131, // no such account
        month: DateTime.utc(2026, 4, 1),
      );

      await expectLater(
        DatabaseHelper().createExpenseWithCarryover(expense, [badBalance]),
        throwsA(anything),
      );

      // The expense insert must have rolled back — no fk-rollback row remains.
      final expenses = await DatabaseHelper().readAllExpenses(accountId);
      expect(expenses.any((e) => e.description == 'fk-rollback'), isFalse);
    });
  });
}
