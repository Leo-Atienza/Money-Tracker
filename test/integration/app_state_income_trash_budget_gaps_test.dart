import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/budget_model.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';

import '_test_helpers.dart';

/// Phase 7 / Stage D.1 remainder — coverage for the 🟡 Partial and ❌ Missing
/// gaps in AppState's INCOME mutators, TRASH round-trips, and BUDGET methods
/// that `app_state_crud_test.dart` does NOT already cover.
///
/// Spec slice: docs/NEXT_SESSION_HANDOFF.md lines 2645-2754.
///
/// Mirrors the seed → mutate → assert-in-memory(+on-disk) shape of
/// `app_state_crud_test.dart`. ✅ Covered cases there are intentionally NOT
/// repeated; this file only adds the missing cases.
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

    await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null)
      ..setMockMethodCallHandler(secureChannel, null)
      ..setMockMethodCallHandler(pathProviderChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  Future<AppState> bootstrap() async {
    final state = AppState();
    await state.loadData();
    return state;
  }

  Expense makeExpense(
    AppState state, {
    double amount = 25.0,
    String category = 'Food',
    String description = 'lunch',
    DateTime? date,
    double amountPaid = 0,
    String paymentMethod = 'Cash',
  }) {
    return Expense(
      amount: Decimal.parse(amount.toString()),
      category: category,
      description: description,
      date: date ?? DateTime.now(),
      accountId: state.currentAccountId,
      amountPaid: Decimal.parse(amountPaid.toString()),
      paymentMethod: paymentMethod,
    );
  }

  Income makeIncome(
    AppState state, {
    double amount = 3000.0,
    String category = 'Salary',
    String description = 'pay',
    DateTime? date,
  }) {
    return Income(
      amount: Decimal.parse(amount.toString()),
      category: category,
      description: description,
      date: date ?? DateTime.now(),
      accountId: state.currentAccountId,
    );
  }

  /// Pick a category name guaranteed to exist as an expense category in the
  /// bootstrapped default set, so budget tests don't fail the "category must
  /// exist" guard.
  String firstExpenseCategory(AppState state) {
    final names = state.expenseCategories.map((c) => c.name).toList();
    expect(names, isNotEmpty,
        reason: 'bootstrap must seed at least one expense category');
    return names.first;
  }

  // ===========================================================================
  // INCOME MUTATORS — gaps
  // ===========================================================================

  group('addIncome (validation + notify + disk gaps)', () {
    test('rejects empty category with ArgumentError', () async {
      final state = await bootstrap();
      expect(
        () => state.addIncome(makeIncome(state, category: '')),
        throwsArgumentError,
      );
    });

    test('rejects empty description with ArgumentError', () async {
      final state = await bootstrap();
      expect(
        () => state.addIncome(makeIncome(state, description: '')),
        throwsArgumentError,
      );
    });

    test('persists the row on disk (income table)', () async {
      final state = await bootstrap();
      final id = await state.addIncome(
        makeIncome(state, amount: 1234.0, description: 'disk-income'),
      );

      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'income',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows, hasLength(1),
          reason: 'addIncome must persist exactly one on-disk row');
      expect(rows.single['description'], 'disk-income');
      expect((rows.single['amount'] as num).toDouble(), closeTo(1234.0, 0.001));
    });

    test('calls notifyListeners at least once', () async {
      final state = await bootstrap();
      var notifies = 0;
      state.addListener(() => notifies++);

      await state.addIncome(makeIncome(state));

      expect(notifies, greaterThanOrEqualTo(1),
          reason: 'addIncome must notify after a successful insert');
    });
  });

  group('addIncomeRaw', () {
    test('round-trips through addIncome into cache + disk', () async {
      final state = await bootstrap();
      final before = state.incomes.length;

      await state.addIncomeRaw(
        amount: 500.0,
        category: 'Salary',
        description: 'raw-pay',
        date: DateTime.now(),
      );

      expect(state.incomes, hasLength(before + 1));
      final added = state.incomes.firstWhere((i) => i.description == 'raw-pay');
      expect(added.amount, closeTo(500.0, 0.001));
      expect(added.category, 'Salary');

      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'income',
        where: 'description = ?',
        whereArgs: ['raw-pay'],
      );
      expect(rows, hasLength(1));
    });

    test('invalid amount bubbles ArgumentError (delegates to addIncome guard)',
        () async {
      final state = await bootstrap();
      expect(
        () => state.addIncomeRaw(
          amount: 0,
          category: 'Salary',
          description: 'bad',
          date: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('updateIncome (amount edit + notify gaps)', () {
    test('persists an edited amount to cache + disk', () async {
      final state = await bootstrap();
      final id = await state.addIncome(
        makeIncome(state, amount: 1000.0, description: 'edit-amt'),
      );
      final original = state.incomes.firstWhere((i) => i.id == id);

      await state.updateIncome(
        original.copyWithDecimal(amount: Decimal.parse('1750.00')),
      );

      final after = state.incomes.firstWhere((i) => i.id == id);
      expect(after.amount, closeTo(1750.0, 0.001));
      expect(after.description, 'edit-amt',
          reason: 'amount edit must not touch the description');

      final db = await DatabaseHelper().database;
      final rows =
          await db.query('income', where: 'id = ?', whereArgs: [id]);
      expect((rows.single['amount'] as num).toDouble(), closeTo(1750.0, 0.001));
    });

    test('calls notifyListeners at least once', () async {
      final state = await bootstrap();
      final id = await state.addIncome(makeIncome(state));
      final original = state.incomes.firstWhere((i) => i.id == id);
      var notifies = 0;
      state.addListener(() => notifies++);

      await state.updateIncome(
        original.copyWithDecimal(amount: Decimal.parse('99.00')),
      );

      expect(notifies, greaterThanOrEqualTo(1));
    });
  });

  group('deleteIncome (unknown id + on-disk trash gaps)', () {
    test('unknown id early-returns without throwing and leaves cache intact',
        () async {
      final state = await bootstrap();
      final id = await state.addIncome(makeIncome(state, description: 'keep'));
      final before = state.incomes.length;

      // 999999 is an id that was never inserted.
      await state.deleteIncome(999999);

      expect(state.incomes, hasLength(before),
          reason: 'deleting an unknown id must not remove anything');
      expect(state.incomes.any((i) => i.id == id), isTrue);
      // The real row is still on disk.
      final db = await DatabaseHelper().database;
      final rows =
          await db.query('income', where: 'id = ?', whereArgs: [id]);
      expect(rows, hasLength(1));
    });

    test('deleting a real id moves it to the deleted_income table on disk',
        () async {
      final state = await bootstrap();
      final id = await state.addIncome(
        makeIncome(state, description: 'to-trash'),
      );

      await state.deleteIncome(id);

      final db = await DatabaseHelper().database;
      final live =
          await db.query('income', where: 'id = ?', whereArgs: [id]);
      expect(live, isEmpty,
          reason: 'deleted income must leave the live income table');
      final trashed = await db.query(
        'deleted_income',
        where: 'description = ?',
        whereArgs: ['to-trash'],
      );
      expect(trashed, isNotEmpty,
          reason: 'deleted income must land in deleted_income');
    });
  });

  // ===========================================================================
  // TRASH — round-trip gaps (restore updates BOTH cache and disk)
  // ===========================================================================

  group('trash restore round-trips touch disk', () {
    test('restoreDeletedIncome re-inserts the live row on disk', () async {
      final state = await bootstrap();
      final id = await state.addIncome(
        makeIncome(state, amount: 777.0, description: 'restore-disk'),
      );
      await state.deleteIncome(id);

      final deleted = await state.getDeletedIncome();
      final deletedId = deleted
          .firstWhere((row) => row['description'] == 'restore-disk')['id']
          as int;

      await state.restoreDeletedIncome(deletedId);

      // Cache reflects the restore.
      expect(
        state.incomes.any((i) => i.description == 'restore-disk'),
        isTrue,
      );
      // Trash row is gone.
      final afterTrash = await state.getDeletedIncome();
      expect(
        afterTrash.any((row) => row['description'] == 'restore-disk'),
        isFalse,
      );
      // A live on-disk income row exists again.
      final db = await DatabaseHelper().database;
      final live = await db.query(
        'income',
        where: 'description = ?',
        whereArgs: ['restore-disk'],
      );
      expect(live, isNotEmpty,
          reason: 'restore must re-materialize a live income row on disk');
    });

    test('restoreDeletedExpense re-inserts the live row on disk', () async {
      final state = await bootstrap();
      final id = await state.addExpense(
        makeExpense(state, description: 'exp-restore-disk'),
      );
      await state.deleteExpense(id);

      final deleted = await state.getDeletedExpenses();
      final deletedId = deleted
          .firstWhere((row) => row['description'] == 'exp-restore-disk')['id']
          as int;

      await state.restoreDeletedExpense(deletedId);

      final db = await DatabaseHelper().database;
      final live = await db.query(
        'expenses',
        where: 'description = ?',
        whereArgs: ['exp-restore-disk'],
      );
      expect(live, isNotEmpty,
          reason: 'restore must re-materialize a live expense row on disk');
      expect(
        state.expenses.any((e) => e.description == 'exp-restore-disk'),
        isTrue,
      );
    });

    test('permanentlyDeleteIncome wipes the deleted_income row on disk',
        () async {
      final state = await bootstrap();
      final id = await state.addIncome(
        makeIncome(state, description: 'perm-gone-inc'),
      );
      await state.deleteIncome(id);
      final deleted = await state.getDeletedIncome();
      final deletedId = deleted
          .firstWhere((row) => row['description'] == 'perm-gone-inc')['id']
          as int;

      await state.permanentlyDeleteIncome(deletedId);

      final db = await DatabaseHelper().database;
      final trashed = await db.query(
        'deleted_income',
        where: 'id = ?',
        whereArgs: [deletedId],
      );
      expect(trashed, isEmpty,
          reason: 'permanent delete must remove the on-disk trash row');
    });
  });

  // ===========================================================================
  // BUDGET — validation gaps (setBudget cases 3-5 + notify + decimal)
  // ===========================================================================

  group('setBudget validation gaps', () {
    test('amount <= 0 throws ArgumentError', () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      expect(() => state.setBudget(category, 0), throwsArgumentError);
      expect(() => state.setBudget(category, -50), throwsArgumentError);
    });

    test('empty category throws ArgumentError', () async {
      final state = await bootstrap();
      expect(() => state.setBudget('', 100), throwsArgumentError);
    });

    test('non-existent category throws ArgumentError', () async {
      final state = await bootstrap();
      expect(
        () => state.setBudget('NoSuchCategoryXYZ', 100),
        throwsArgumentError,
      );
    });

    test('a valid setBudget calls notifyListeners', () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      var notifies = 0;
      state.addListener(() => notifies++);

      await state.setBudget(category, 300);

      expect(notifies, greaterThanOrEqualTo(1));
    });

    test('stores a decimal amount precisely (199.99)', () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);

      await state.setBudget(category, 199.99);

      final budget =
          state.budgets.firstWhere((b) => b.category == category);
      expect(budget.amount, closeTo(199.99, 0.0001));
    });
  });

  // ===========================================================================
  // BUDGET — deleteBudget + undoBudgetDeletion (❌ Missing)
  // ===========================================================================

  group('deleteBudget', () {
    test('removes the budget from the budgets cache', () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      await state.setBudget(category, 250);
      final budget =
          state.budgets.firstWhere((b) => b.category == category);

      await state.deleteBudget(budget.id!);

      expect(state.budgets.any((b) => b.id == budget.id), isFalse,
          reason: 'deleted budget must vacate the in-memory list');
      // And on disk.
      final db = await DatabaseHelper().database;
      final rows =
          await db.query('budgets', where: 'id = ?', whereArgs: [budget.id]);
      expect(rows, isEmpty);
    });

    test('unknown id still notifies and does not throw', () async {
      final state = await bootstrap();
      var notifies = 0;
      state.addListener(() => notifies++);

      await state.deleteBudget(424242);

      // No exception thrown (reaching here is the assertion), and the public
      // contract is that it still notifies.
      expect(notifies, greaterThanOrEqualTo(1));
    });
  });

  group('undoBudgetDeletion', () {
    test('re-adds an equal budget after a deletion', () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      await state.setBudget(category, 250);
      final budget =
          state.budgets.firstWhere((b) => b.category == category);

      await state.deleteBudget(budget.id!);
      expect(state.budgets.any((b) => b.category == category), isFalse);

      await state.undoBudgetDeletion();

      final restored =
          state.budgets.where((b) => b.category == category).toList();
      expect(restored, hasLength(1),
          reason: 'undo must recreate exactly one matching budget');
      expect(restored.single.amount, closeTo(250.0, 0.0001));
      expect(restored.single.month.year, budget.month.year);
      expect(restored.single.month.month, budget.month.month);
    });

    test('no prior deletion is a no-op (no throw, no new budget)', () async {
      final state = await bootstrap();
      final before = state.budgets.length;

      await state.undoBudgetDeletion();

      expect(state.budgets, hasLength(before));
    });

    test('undo twice — the second call is a no-op (slot cleared)', () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      await state.setBudget(category, 100);
      final budget =
          state.budgets.firstWhere((b) => b.category == category);
      await state.deleteBudget(budget.id!);

      await state.undoBudgetDeletion();
      final afterFirstUndo =
          state.budgets.where((b) => b.category == category).length;

      await state.undoBudgetDeletion();
      final afterSecondUndo =
          state.budgets.where((b) => b.category == category).length;

      expect(afterFirstUndo, 1);
      expect(afterSecondUndo, afterFirstUndo,
          reason: 'a cleared last-deleted slot must not duplicate the budget');
    });
  });

  // ===========================================================================
  // BUDGET — spent getters (❌ Missing)
  // ===========================================================================

  group('getBudgetSpentBreakdown / getBudgetSpent / getBudgetSpentActual', () {
    test('no recurring: projected == 0, total == actual == summed expenses',
        () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      // Two expenses this month in the category.
      await state.addExpense(makeExpense(state, amount: 30, category: category));
      await state.addExpense(makeExpense(state, amount: 20, category: category));

      final breakdown = state.getBudgetSpentBreakdown(category);
      expect(breakdown['actual'], closeTo(50.0, 0.001));
      expect(breakdown['projected'], closeTo(0.0, 0.001),
          reason: 'no recurring in this category => projected is zero');
      expect(breakdown['total'], closeTo(50.0, 0.001));

      // getBudgetSpent == breakdown total; getBudgetSpentActual == actual.
      expect(state.getBudgetSpent(category), closeTo(50.0, 0.001));
      expect(state.getBudgetSpentActual(category), closeTo(50.0, 0.001));
    });

    test('unknown category => all zeros', () async {
      final state = await bootstrap();
      final breakdown = state.getBudgetSpentBreakdown('TotallyUnknownCat');
      expect(breakdown['actual'], closeTo(0.0, 0.001));
      expect(breakdown['projected'], closeTo(0.0, 0.001));
      expect(breakdown['total'], closeTo(0.0, 0.001));
      expect(state.getBudgetSpent('TotallyUnknownCat'), closeTo(0.0, 0.001));
      expect(
        state.getBudgetSpentActual('TotallyUnknownCat'),
        closeTo(0.0, 0.001),
      );
    });

    test('decimal precision on the actual sum (10.10 + 20.20 + 0.05)',
        () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      await state.addExpense(
          makeExpense(state, amount: 10.10, category: category));
      await state.addExpense(
          makeExpense(state, amount: 20.20, category: category));
      await state.addExpense(
          makeExpense(state, amount: 0.05, category: category));

      expect(
        state.getBudgetSpentActual(category),
        closeTo(30.35, 0.001),
        reason: 'Decimal-summed actuals must not drift on fractional cents',
      );
    });
  });

  // ===========================================================================
  // BUDGET — getBudgetProgress (❌ Missing)
  // ===========================================================================

  group('getBudgetProgress', () {
    test('half-spent budget => 0.5', () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      await state.setBudget(category, 100);
      await state.addExpense(makeExpense(state, amount: 50, category: category));

      final budget =
          state.budgets.firstWhere((b) => b.category == category);
      expect(state.getBudgetProgress(budget), closeTo(0.5, 0.001));
    });

    test('over-budget clamps to 1.0', () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      await state.setBudget(category, 100);
      await state.addExpense(
          makeExpense(state, amount: 250, category: category));

      final budget =
          state.budgets.firstWhere((b) => b.category == category);
      expect(state.getBudgetProgress(budget), closeTo(1.0, 0.001));
    });

    test('zero-amount budget => 0.0 (no div-by-zero)', () async {
      final state = await bootstrap();
      final category = firstExpenseCategory(state);
      // Construct a zero-amount Budget directly — setBudget rejects amount<=0,
      // but getBudgetProgress must still guard the Decimal.zero case.
      final zeroBudget = Budget(
        category: category,
        amount: Decimal.zero,
        accountId: state.currentAccountId,
        month: state.selectedMonth,
      );
      await state.addExpense(makeExpense(state, amount: 40, category: category));

      expect(state.getBudgetProgress(zeroBudget), 0.0);
    });
  });

  // ===========================================================================
  // OVERALL MONTHLY BUDGET — gaps (validation + carryover preservation + no-op)
  // ===========================================================================

  group('overall monthly budget gaps', () {
    test('amount <= 0 throws ArgumentError', () async {
      final state = await bootstrap();
      expect(() => state.setOverallMonthlyBudget(0), throwsArgumentError);
      expect(() => state.setOverallMonthlyBudget(-10), throwsArgumentError);
    });

    test('removeOverallMonthlyBudget when none set is a no-op (no throw)',
        () async {
      final state = await bootstrap();
      expect(state.overallMonthlyBudget, isNull);

      // Should not throw and should leave it null.
      await state.removeOverallMonthlyBudget();

      expect(state.overallMonthlyBudget, isNull);
    });

    test('set preserves the existing carryover (does not clobber)', () async {
      final state = await bootstrap();
      // The income/carryover machinery recomputes carryover during loadData,
      // so rather than seeding a synthetic carryover we capture whatever value
      // exists before the call and assert setOverallMonthlyBudget leaves it
      // untouched (the method copies carryoverFromPrevious forward).
      final before = state.carryoverForSelectedMonth;

      await state.setOverallMonthlyBudget(2000);

      expect(state.overallMonthlyBudget, closeTo(2000.0, 0.001));
      expect(state.carryoverForSelectedMonth, closeTo(before, 0.001),
          reason: 'setting the overall budget must not clobber carryover');
    });

    test('round-trips the value to disk via MonthlyBalance', () async {
      final state = await bootstrap();
      await state.setOverallMonthlyBudget(3200);

      // Re-read through a second AppState on the SAME db to confirm it
      // persisted (bootstrap uses the same DatabaseHelper singleton/file).
      final reloaded = AppState();
      await reloaded.loadData();
      expect(reloaded.overallMonthlyBudget, closeTo(3200.0, 0.001),
          reason: 'overall budget must survive a reload from disk');
    });
  });
}
