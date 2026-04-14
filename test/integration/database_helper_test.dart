import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:budget_tracker/database/database_helper.dart';

import '_test_helpers.dart';

/// FIX Phase 3c — Regression tests for Bug #2.
///
/// Bug #2: `calculateMonthBalance`, `getExpensesByMonth`, and
/// `getIncomeByMonth` previously built range bounds via
/// `DateTime.toIso8601String()` which emits `"YYYY-MM-DDT00:00:00.000Z"`.
/// The stored `date` column is a 10-char `"YYYY-MM-DD"` string, so the
/// SQLite comparison `date >= "2026-04-01T00:00:00.000Z"` returned false
/// for an expense dated `"2026-04-01"` — the 1st of every month was
/// silently excluded from every month-balance query.
///
/// The fix uses `DateHelper.toDateString(...)` to produce bounds like
/// `"2026-04-01"` / `"2026-04-30"` that match the stored format. These
/// tests drive the real `DatabaseHelper` end-to-end through
/// `sqflite_common_ffi` to prevent regression.
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

  group('calculateMonthBalance — Bug #2 regression', () {
    test('includes expense dated on the 1st of the month', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 10.0);

      final result = await DatabaseHelper().calculateMonthBalance(accountId, 2026, 4);

      expect(result.expenses, 10.0);
      expect(result.income, 0.0);
    });

    test('includes income dated on the 1st of the month', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-01', amount: 500.0);

      final result = await DatabaseHelper().calculateMonthBalance(accountId, 2026, 4);

      expect(result.income, 500.0);
      expect(result.expenses, 0.0);
    });

    test('sums day-1, day-15, and last-day transactions', () async {
      // April 2026 has 30 days → last day is the 30th.
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 10.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-15', amount: 20.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-30', amount: 30.0);

      await seedIncome(db, accountId: accountId, date: '2026-04-01', amount: 100.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-15', amount: 200.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-30', amount: 300.0);

      final result = await DatabaseHelper().calculateMonthBalance(accountId, 2026, 4);

      expect(result.expenses, 60.0);
      expect(result.income, 600.0);
    });

    test('handles February in a leap year (Feb 29 included)', () async {
      // 2028 is a leap year: Feb has 29 days.
      await seedExpense(db, accountId: accountId, date: '2028-02-01', amount: 1.0);
      await seedExpense(db, accountId: accountId, date: '2028-02-29', amount: 2.0);

      final result = await DatabaseHelper().calculateMonthBalance(accountId, 2028, 2);

      expect(result.expenses, 3.0);
    });

    test('excludes transactions outside the month window', () async {
      // One day before and one day after the April window.
      await seedExpense(db, accountId: accountId, date: '2026-03-31', amount: 99.0);
      await seedExpense(db, accountId: accountId, date: '2026-05-01', amount: 99.0);
      // Inside the window.
      await seedExpense(db, accountId: accountId, date: '2026-04-10', amount: 5.0);

      final result = await DatabaseHelper().calculateMonthBalance(accountId, 2026, 4);

      expect(result.expenses, 5.0);
    });

    test('excludes transactions on a different account', () async {
      final otherAccount = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedExpense(db, accountId: otherAccount, date: '2026-04-01', amount: 42.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 7.0);

      final result = await DatabaseHelper().calculateMonthBalance(accountId, 2026, 4);

      expect(result.expenses, 7.0);
    });

    test('returns zeros for a month with no transactions', () async {
      final result = await DatabaseHelper().calculateMonthBalance(accountId, 2026, 4);

      expect(result.expenses, 0.0);
      expect(result.income, 0.0);
    });
  });

  group('getExpensesByMonth — Bug #2 regression', () {
    test('includes expense on the 1st of the month', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 10.0);

      final rows = await DatabaseHelper().getExpensesByMonth(accountId, 2026, 4);

      expect(rows.length, 1);
      expect(rows.first.amount, 10.0);
    });

    test('returns day-1, day-15, and last-day rows in a single query', () async {
      await seedExpense(db, accountId: accountId, date: '2026-04-01', amount: 1.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-15', amount: 2.0);
      await seedExpense(db, accountId: accountId, date: '2026-04-30', amount: 3.0);

      final rows = await DatabaseHelper().getExpensesByMonth(accountId, 2026, 4);

      expect(rows.length, 3);
      final amounts = rows.map((e) => e.amount).toSet();
      expect(amounts, {1.0, 2.0, 3.0});
    });
  });

  group('getIncomeByMonth — Bug #2 regression', () {
    test('includes income on the 1st of the month', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-01', amount: 500.0);

      final rows = await DatabaseHelper().getIncomeByMonth(accountId, 2026, 4);

      expect(rows.length, 1);
      expect(rows.first.amount, 500.0);
    });

    test('returns day-1, day-15, and last-day rows in a single query', () async {
      await seedIncome(db, accountId: accountId, date: '2026-04-01', amount: 100.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-15', amount: 200.0);
      await seedIncome(db, accountId: accountId, date: '2026-04-30', amount: 300.0);

      final rows = await DatabaseHelper().getIncomeByMonth(accountId, 2026, 4);

      expect(rows.length, 3);
      final amounts = rows.map((e) => e.amount).toSet();
      expect(amounts, {100.0, 200.0, 300.0});
    });
  });
}
