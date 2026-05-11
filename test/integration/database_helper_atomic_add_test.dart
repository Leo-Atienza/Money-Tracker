import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/models/monthly_balance_model.dart';
import 'package:budget_tracker/utils/date_helper.dart';
import 'package:budget_tracker/utils/decimal_helper.dart';

import '_test_helpers.dart';

/// FIX Phase 1.6 — `createExpenseWithCarryover` / `createIncomeWithCarryover`
/// run the row insert and the carryover upsert(s) in a single SQLite
/// transaction. If any step throws, the whole batch rolls back — the
/// user never observes a half-applied write.
///
/// We can't easily force the carryover step to fail in code (the
/// schema doesn't allow many bad-write paths), so instead we drive a
/// happy-path roundtrip plus a deliberate-throw test that uses a
/// MonthlyBalance with an INVALID `accountId` foreign key. SQLite's
/// FK enforcement rolls the whole transaction back, which is the
/// behaviour we want.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await makeFreshDb();
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  test('createExpenseWithCarryover commits both writes on success',
      () async {
    final db = await DatabaseHelper().database;
    final accountId = await seedAccount(db);

    final today = DateHelper.today();
    final expense = Expense(
      amount: DecimalHelper.fromDouble(10.0),
      category: 'Food',
      description: 'lunch',
      date: today,
      accountId: accountId,
      amountPaid: DecimalHelper.fromDouble(0.0),
    );

    final balance = MonthlyBalance(
      accountId: accountId,
      month: DateHelper.startOfMonth(today),
      carryoverFromPrevious: DecimalHelper.fromDouble(5.0),
    );

    final expenseId = await DatabaseHelper()
        .createExpenseWithCarryover(expense, [balance]);

    expect(expenseId, isNonZero);
    final expenseRows = await db.query('expenses', where: 'id = ?', whereArgs: [expenseId]);
    final balanceRows = await db.query('monthly_balances',
        where: 'account_id = ?', whereArgs: [accountId]);

    expect(expenseRows, hasLength(1));
    expect(balanceRows, hasLength(1));
  });

  test('createExpenseWithCarryover rolls BOTH back when the upsert throws',
      () async {
    final db = await DatabaseHelper().database;
    final accountId = await seedAccount(db);

    final today = DateHelper.today();
    final expense = Expense(
      amount: DecimalHelper.fromDouble(10.0),
      category: 'Food',
      description: 'should_not_persist',
      date: today,
      accountId: accountId,
      amountPaid: DecimalHelper.fromDouble(0.0),
    );

    // MonthlyBalance with a NON-EXISTENT accountId — the FK in
    // schema v15+ rejects this, which forces the txn to abort.
    final badBalance = MonthlyBalance(
      accountId: 999999,
      month: DateHelper.startOfMonth(today),
      carryoverFromPrevious: DecimalHelper.fromDouble(0.0),
    );

    // Verify FK enforcement is on (the schema sets it at open time).
    final fkRow = await db.rawQuery('PRAGMA foreign_keys');
    expect(fkRow.first.values.first, 1,
        reason: 'Test assumes foreign_keys=ON.');

    Object? thrown;
    try {
      await DatabaseHelper().createExpenseWithCarryover(expense, [badBalance]);
    } catch (e) {
      thrown = e;
    }
    expect(thrown, isNotNull,
        reason: 'A FOREIGN KEY violation should abort the transaction.');

    // Critical: the expense row must NOT exist. Pre-fix
    // (separate insert + upsert), the insert would have committed
    // before the upsert failed, leaving an orphan expense.
    final expenseRows = await db.query(
      'expenses',
      where: 'description = ?',
      whereArgs: ['should_not_persist'],
    );
    expect(
      expenseRows,
      isEmpty,
      reason: 'When the carryover step fails, the expense INSERT must '
          'roll back too. Phase 1.6 wraps both in one SQLite transaction; '
          'without the wrapper this would leave a partial commit.',
    );
  });

  test('createIncomeWithCarryover has the same atomicity contract',
      () async {
    final db = await DatabaseHelper().database;
    final accountId = await seedAccount(db);

    final income = Income(
      amount: DecimalHelper.fromDouble(100.0),
      category: 'Salary',
      description: 'should_not_persist_income',
      date: DateHelper.today(),
      accountId: accountId,
    );

    final badBalance = MonthlyBalance(
      accountId: 999999, // bad FK
      month: DateHelper.startOfMonth(DateHelper.today()),
      carryoverFromPrevious: DecimalHelper.fromDouble(0.0),
    );

    Object? thrown;
    try {
      await DatabaseHelper().createIncomeWithCarryover(income, [badBalance]);
    } catch (e) {
      thrown = e;
    }
    expect(thrown, isNotNull);

    final incomeRows = await db.query(
      'income',
      where: 'description = ?',
      whereArgs: ['should_not_persist_income'],
    );
    expect(incomeRows, isEmpty,
        reason: 'Failed carryover must roll back the income row too.');
  });
}
