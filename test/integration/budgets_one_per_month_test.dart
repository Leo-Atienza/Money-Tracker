import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/budget_model.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '_test_helpers.dart';

/// S22 (audit Open, data row): one budget per category per month.
///
/// Moving a category's transactions into another retargeted its budgets
/// blindly, so the target could hold two budgets for one month. The move now
/// merges them, schema v20 collapses what older builds left, and a UNIQUE
/// index keeps it that way.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late int account;

  setUp(() async {
    db = await makeFreshDb();
    account = await seedAccount(db);
  });

  tearDown(() async {
    await DatabaseHelper.resetForTesting();
  });

  Future<void> addBudget(String category, double amount, String month) =>
      db.insert('budgets', {
        'category': category,
        'amount': amount,
        'month': month,
        'account_id': account,
      });

  Future<List<Map<String, Object?>>> budgetRows() => db.query(
        'budgets',
        where: 'account_id = ?',
        whereArgs: [account],
        orderBy: 'category, month',
      );

  group('moving a category merges its budgets', () {
    test('delete-and-move adds the moved budget to the target, per month',
        () async {
      await addBudget('Coffee', 50, '2026-10-01');
      await addBudget('Food', 300, '2026-10-01');
      await addBudget('Coffee', 40, '2026-09-01'); // Food has none in Sept

      await DatabaseHelper()
          .bulkReassignCategory(account, 'Coffee', 'Food', 'expense');

      final rows = await budgetRows();
      expect(
        rows.map((r) => (r['category'], r['month'], r['amount'])),
        [('Food', '2026-09-01', 40.0), ('Food', '2026-10-01', 350.0)],
      );
    });

    test('a rename onto an existing name merges the same way', () async {
      await addBudget('Snacks', 19.99, '2026-10-01');
      await addBudget('Food', 0.01, '2026-10-01');

      await DatabaseHelper()
          .renameCategoryInAllTables(account, 'Snacks', 'Food', 'expense');

      final rows = await budgetRows();
      expect(rows, hasLength(1));
      expect(rows.single['amount'], 20.0, reason: 'rounded to the cent');
    });
  });

  test('a second budget for a category and month replaces the first',
      () async {
    final helper = DatabaseHelper();
    final october = DateTime.utc(2026, 10, 1);
    await helper.createBudget(Budget(
        category: 'Food',
        amount: Decimal.fromInt(300),
        accountId: account,
        month: october));
    await helper.createBudget(Budget(
        category: 'Food',
        amount: Decimal.fromInt(320),
        accountId: account,
        month: october));

    final rows = await budgetRows();
    expect(rows, hasLength(1));
    expect(rows.single['amount'], 320.0);
  });

  test('v19 -> v20 collapses duplicates and installs the index', () async {
    // Turn the fresh v20 database back into what a v19 install can hold:
    // no index, two Food budgets for October (one with an old timestamp
    // month), then reopen so the upgrade runs.
    await db.execute('DROP INDEX idx_budgets_account_category_month');
    await addBudget('Food', 300, '2026-10-01');
    await addBudget('Food', 999, '2026-10-01T00:00:00.000');
    await addBudget('Rent', 1200, '2026-10-01');
    final keptId = (await budgetRows())
        .firstWhere((r) => r['category'] == 'Food')['id'];
    await db.execute('PRAGMA user_version = 19');
    await DatabaseHelper().closeDatabase();

    db = await DatabaseHelper().database;

    final rows = await budgetRows();
    expect(rows.map((r) => (r['category'], r['month'])),
        [('Food', '2026-10-01'), ('Rent', '2026-10-01')]);
    expect(rows.first['id'], keptId,
        reason: 'the row setBudget edited (the lowest id) is kept');
    expect(rows.first['amount'], 300.0);
    final index = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name = 'idx_budgets_account_category_month'",
    );
    expect(index, hasLength(1));
  });
}
