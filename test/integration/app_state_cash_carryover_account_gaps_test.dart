import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/date_helper.dart';

import '_test_helpers.dart';

/// Phase 7 / Stage D.1 remainder — AppState computed-getter, carryover, and
/// account-method coverage for the gaps flagged 🟡 Partial / ❌ Missing in
/// docs/NEXT_SESSION_HANDOFF.md (lines 2755-2832).
///
/// These complement `app_state_crud_test.dart` (~44 CRUD mutator tests) by
/// exercising the *derived* surface the CRUD file leaves untested:
///   * Budget/cash computed getters (totalSpent / totalIncome /
///     availableIncomeBalance / totalAvailableCash / projectedEndOfMonthBalance
///     / totalCategoryBudget / totalMonthlyBudget / currentMonthBudgets).
///   * Carryover compute/apply (carryoverForSelectedMonth + Decimal variant +
///     hasCarryover + getCarryoverForMonth + recalculateCarryovers).
///   * Account methods not covered by crud_test: current-account deletion
///     reload, resetAccount, permanentlyDeleteAccount, refreshCurrentMonthData.
///
/// Every expected number is DERIVED by tracing AppState, never guessed. All
/// dates are anchored to the wall-clock month via `DateHelper.today()` so the
/// rows stay resident in the windowed (prev + current month) in-memory cache,
/// exactly like the crud_test "editing the date moves the row across months"
/// case.
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

  // Per-test UNIQUE app-documents dir. The account tests below
  // (deleteAccount, resetAccount → loadData → performMaintenance) write the
  // account-backup JSON and run orphaned-file cleanup under
  // getApplicationDocumentsDirectory(). With the old shared
  // `.dart_tool/test_path_provider`, those file ops collided with other
  // parallel test-file isolates, surfacing on Windows as
  // PathAccessException ("used by another process") and a 30s timeout. A
  // fresh unique dir per test is the file-system analog of makeFreshDb's
  // unique DB name.
  int ppCounter = 0;
  late Directory ppDir;

  setUp(() async {
    ppCounter++;
    ppDir = Directory(
      '.dart_tool/test_pp_cash_${ppCounter}_${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null)
      ..setMockMethodCallHandler(secureChannel, (_) async => null)
      ..setMockMethodCallHandler(
        pathProviderChannel,
        (_) async => ppDir.path,
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
    try {
      if (ppDir.existsSync()) ppDir.deleteSync(recursive: true);
    } catch (_) {
      // Best-effort cleanup; a lingering temp dir under .dart_tool is harmless.
    }
  });

  Future<AppState> bootstrap() async {
    final state = AppState();
    await state.loadData();
    return state;
  }

  // Mid-month anchors keep every seeded row inside the windowed cache that
  // `_loadExpensesInternal` / `_loadIncomesInternal` load (previous + current
  // month only). Day 15 avoids end-of-month / first-of-month edge cases.
  DateTime currentMonthDate() {
    final now = DateHelper.today();
    return DateHelper.normalize(DateTime.utc(now.year, now.month, 15));
  }

  DateTime previousMonthDate() {
    final prev = DateHelper.subtractMonths(DateHelper.today(), 1);
    return DateHelper.normalize(DateTime.utc(prev.year, prev.month, 15));
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
      date: date ?? currentMonthDate(),
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
      date: date ?? currentMonthDate(),
      accountId: state.currentAccountId,
    );
  }

  // ---------------------------------------------------------------------------
  // Budget / cash computed getters — derived from a known seed in the current
  // (selected) month, no carryover (fresh DB → no prior-month data).
  // ---------------------------------------------------------------------------

  group('cash + income computed getters (seeded current month)', () {
    // Shared seed used by several tests:
    //   income  3000 + 500            -> totalIncome      = 3500
    //   expense 200 (paid 50)
    //   expense 100 (paid 100)        -> totalSpent       = 300, totalPaid = 150
    // No prior month -> carryoverForSelectedMonth = 0.
    Future<AppState> seedKnownMonth() async {
      final state = await bootstrap();
      await state.addIncome(makeIncome(state, amount: 3000, description: 'a'));
      await state.addIncome(makeIncome(state, amount: 500, description: 'b'));
      await state.addExpense(
        makeExpense(state, amount: 200, amountPaid: 50, description: 'x'),
      );
      await state.addExpense(
        makeExpense(state, amount: 100, amountPaid: 100, description: 'y'),
      );
      return state;
    }

    test('totalIncome / totalSpent / totalPaid sum the seeded rows', () async {
      final state = await seedKnownMonth();
      expect(state.totalIncome, closeTo(3500, 0.001));
      expect(state.totalIncomeThisMonth, closeTo(3500, 0.001));
      expect(state.totalSpent, closeTo(300, 0.001));
      expect(state.totalExpensesThisMonth, closeTo(300, 0.001));
      expect(state.totalPaid, closeTo(150, 0.001));
    });

    test('balanceThisMonth / netSavings = income - expenses', () async {
      final state = await seedKnownMonth();
      // 3500 - 300 = 3200
      expect(state.balanceThisMonth, closeTo(3200, 0.001));
      expect(state.netSavings, closeTo(3200, 0.001));
    });

    test('availableIncomeBalance = totalIncome - totalPaid', () async {
      final state = await seedKnownMonth();
      // 3500 - 150 = 3350
      expect(state.availableIncomeBalance, closeTo(3350, 0.001));
    });

    test('totalAvailableCash = income + carryover(0) - totalPaid', () async {
      final state = await seedKnownMonth();
      expect(state.carryoverForSelectedMonth, closeTo(0, 0.001),
          reason: 'fresh DB current month has no prior-month carryover');
      // 3500 + 0 - 150 = 3350
      expect(state.totalAvailableCash, closeTo(3350, 0.001));
    });

    test('totalIncomeWithCarryover = income + carryover(0)', () async {
      final state = await seedKnownMonth();
      expect(state.totalIncomeWithCarryover, closeTo(3500, 0.001));
    });

    test('projectedEndOfMonthBalance = income + carryover(0) - expenses',
        () async {
      final state = await seedKnownMonth();
      // 3500 + 0 - 300 = 3200
      expect(state.projectedEndOfMonthBalance, closeTo(3200, 0.001));
    });

    test('totalAvailableCash goes negative when paid exceeds income+carryover',
        () async {
      final state = await bootstrap();
      // income 100, one expense fully paid for 250 -> 100 + 0 - 250 = -150
      await state.addIncome(makeIncome(state, amount: 100, description: 'i'));
      await state.addExpense(
        makeExpense(state, amount: 250, amountPaid: 250, description: 'big'),
      );
      expect(state.totalPaid, closeTo(250, 0.001));
      expect(state.totalAvailableCash, closeTo(-150, 0.001),
          reason: 'sign must be correct when outflow exceeds inflow');
    });
  });

  group('category budget getters', () {
    test('totalCategoryBudget is 0.0 with no budgets, sums when present',
        () async {
      final state = await bootstrap();
      expect(state.totalCategoryBudget, 0.0);

      final expenseCats = state.expenseCategories.map((c) => c.name).toList();
      expect(expenseCats.length, greaterThanOrEqualTo(2),
          reason: 'default seed provides several expense categories');

      await state.setBudget(expenseCats[0], 250);
      await state.setBudget(expenseCats[1], 150);

      // sum = 400, derived from the two setBudget calls above
      expect(state.totalCategoryBudget, closeTo(400, 0.001));
    });

    test('currentMonthBudgets only returns budgets for the selected month',
        () async {
      final state = await bootstrap();
      final cat = state.expenseCategories.first.name;

      await state.setBudget(cat, 300);
      expect(state.currentMonthBudgets, hasLength(1));
      expect(state.currentMonthBudgets.single.category, cat);
      expect(state.currentMonthBudgets.single.month.year,
          state.selectedMonth.year);
      expect(state.currentMonthBudgets.single.month.month,
          state.selectedMonth.month);

      // Navigate to the previous month: the budget set above is for the
      // (original) current month, so the previous month must be empty.
      await state.goToPreviousMonth();
      expect(state.currentMonthBudgets, isEmpty,
          reason: 'currentMonthBudgets is filtered to the selected month');
    });

    test('totalMonthlyBudget falls back to category sum, then overall budget',
        () async {
      final state = await bootstrap();
      final cat = state.expenseCategories.first.name;
      await state.setBudget(cat, 200);

      // No overall budget set -> totalMonthlyBudget == category sum.
      expect(state.hasOverallMonthlyBudget, isFalse);
      expect(state.overallMonthlyBudget, isNull);
      expect(state.totalMonthlyBudget, closeTo(200, 0.001));

      // Set an overall budget -> precedence flips to the overall value.
      await state.setOverallMonthlyBudget(900);
      expect(state.hasOverallMonthlyBudget, isTrue);
      expect(state.overallMonthlyBudget, closeTo(900, 0.001));
      expect(state.totalMonthlyBudget, closeTo(900, 0.001),
          reason: 'overall budget takes precedence over category sum');
    });
  });

  // ---------------------------------------------------------------------------
  // Carryover compute / apply.
  // ---------------------------------------------------------------------------

  group('carryover getters + compute/apply', () {
    test('no prior data -> carryover 0 / Decimal.zero / hasCarryover false',
        () async {
      final state = await bootstrap();
      expect(state.carryoverForSelectedMonth, closeTo(0, 0.001));
      expect(state.carryoverForSelectedMonthDecimal, Decimal.zero);
      expect(state.hasCarryover, isFalse);
    });

    test('income in the previous month carries into the current month',
        () async {
      final state = await bootstrap();
      // Seed a prior-month income, then recompute carryover. NOTE: add* folds
      // carryover from the PRE-insert month sums (the Phase 1.6 atomic design),
      // so a back-dated transaction's effect on the current month only
      // materialises on the next recompute / month navigation — which is what
      // the app does at loadData / navigation. recalculateCarryovers() is the
      // on-demand equivalent and reflects (prevIncome - prevExpenses) = 1000.
      await state.addIncome(
        makeIncome(state, amount: 1000, date: previousMonthDate()),
      );
      await state.recalculateCarryovers();

      expect(state.carryoverForSelectedMonth, closeTo(1000, 0.001));
      expect(state.carryoverForSelectedMonthDecimal,
          Decimal.parse('1000'));
      expect(state.hasCarryover, isTrue);
    });

    test('previous-month deficit produces a negative carryover', () async {
      final state = await bootstrap();
      // prev income 100, prev expense 400 -> carryover = (100 - 400) = -300.
      await state.addIncome(
        makeIncome(state, amount: 100, date: previousMonthDate()),
      );
      await state.addExpense(
        makeExpense(state, amount: 400, date: previousMonthDate()),
      );
      await state.recalculateCarryovers();

      expect(state.carryoverForSelectedMonth, closeTo(-300, 0.001),
          reason: 'a prior-month deficit carries forward as a negative');
      expect(state.hasCarryover, isTrue,
          reason: 'a non-zero (negative) carryover still counts');
    });

    test('getCarryoverForMonth returns the cached current-month value',
        () async {
      final state = await bootstrap();
      await state.addIncome(
        makeIncome(state, amount: 500, date: previousMonthDate()),
      );
      await state.recalculateCarryovers();

      // After the recompute the current month is cached; getCarryoverForMonth
      // must return the same value as the getter (cache-hit path).
      final cached = await state.getCarryoverForMonth(state.selectedMonth);
      expect(cached, closeTo(state.carryoverForSelectedMonth, 0.001));
      expect(cached, closeTo(500, 0.001));
    });

    test('getCarryoverForMonth computes 0.0 for an untouched future month',
        () async {
      final state = await bootstrap();
      // A month two ahead has no balance row and no prior data -> compute
      // path returns 0.0 (no carryover).
      final future = DateHelper.addMonths(state.selectedMonth, 2);
      final value = await state.getCarryoverForMonth(future);
      expect(value, closeTo(0, 0.001));
    });

    test('recalculateCarryovers updates carryover after a past-month edit',
        () async {
      final state = await bootstrap();
      // Seed a prior-month income, then add a prior-month expense and force a
      // recompute. Net prior balance = 800 income - 300 expense = 500.
      await state.addIncome(
        makeIncome(state, amount: 800, date: previousMonthDate()),
      );
      await state.addExpense(
        makeExpense(state, amount: 300, date: previousMonthDate()),
      );

      var notifies = 0;
      state.addListener(() => notifies++);

      await state.recalculateCarryovers();

      expect(state.carryoverForSelectedMonth, closeTo(500, 0.001),
          reason: 'recompute must reflect prior-month income minus expenses');
      expect(notifies, greaterThanOrEqualTo(1),
          reason: 'recalculateCarryovers fires at least one notification');
    });
  });

  group('overall monthly budget validation', () {
    test('setOverallMonthlyBudget rejects zero / negative', () async {
      final state = await bootstrap();
      expect(() => state.setOverallMonthlyBudget(0), throwsArgumentError);
      expect(() => state.setOverallMonthlyBudget(-5), throwsArgumentError);
    });

    test('setting then removing the overall budget round-trips through balance',
        () async {
      final state = await bootstrap();
      // Establish a carryover first (recompute on demand — see the carryover
      // group above), then ensure setting/removing the overall budget
      // preserves it (setOverallMonthlyBudget copies the existing carryover).
      await state.addIncome(
        makeIncome(state, amount: 600, date: previousMonthDate()),
      );
      await state.recalculateCarryovers();
      expect(state.carryoverForSelectedMonth, closeTo(600, 0.001));

      await state.setOverallMonthlyBudget(1500);
      expect(state.overallMonthlyBudget, closeTo(1500, 0.001));
      expect(state.carryoverForSelectedMonth, closeTo(600, 0.001),
          reason: 'setting an overall budget must not clobber the carryover');

      await state.removeOverallMonthlyBudget();
      expect(state.overallMonthlyBudget, isNull);
      expect(state.carryoverForSelectedMonth, closeTo(600, 0.001),
          reason: 'removing the overall budget must keep the carryover');
    });
  });

  // ---------------------------------------------------------------------------
  // Account methods — the gaps crud_test does not cover.
  // ---------------------------------------------------------------------------

  group('deleteAccount of the CURRENT account', () {
    test('falls back to the default account + reloads its data', () async {
      final state = await bootstrap();
      final defaultAccount = state.accounts.single;
      expect(defaultAccount.isDefault, isTrue);
      // Seed data on the default account so we can prove the post-deletion
      // reload surfaces ITS dataset.
      await state.addExpense(makeExpense(state, description: 'on-default'));

      // Add a second, NON-default account, make it current, and seed it.
      // (The DB layer refuses to delete the default account, so the
      // current-account-deletion path can only be exercised on a non-default
      // account.)
      await state.addAccount('Secondary');
      final secondary =
          state.accounts.firstWhere((a) => a.name == 'Secondary');
      await state.switchAccount(secondary);
      expect(state.currentAccountId, secondary.id);
      expect(state.expenses, isEmpty, reason: 'Secondary starts empty');
      await state.addExpense(makeExpense(state, description: 'on-secondary'));

      // Delete the CURRENT (Secondary) account. AppState must fall back to the
      // default account and reload the default's data. (Filter-reset is a
      // cosmetic side effect gated on the post-_loadAccounts current-account
      // check and is not asserted here — it carries no data-integrity weight.)
      await state.deleteAccount(secondary.id!);

      expect(state.accounts.any((a) => a.id == secondary.id), isFalse,
          reason: 'deleted account leaves the list');
      expect(state.currentAccountId, defaultAccount.id,
          reason: 'current account falls back to the default account');
      expect(
        state.expenses.any((e) => e.description == 'on-default'),
        isTrue,
        reason: 'reload after deletion surfaces the default account\'s data',
      );
      expect(
        state.expenses.any((e) => e.description == 'on-secondary'),
        isFalse,
        reason: 'the deleted account\'s data is no longer resident',
      );
    });
  });

  group('resetAccount', () {
    test('wipes the account\'s transactions but keeps default categories',
        () async {
      final state = await bootstrap();
      final defaultCategoryCount = state.categories.length;
      expect(defaultCategoryCount, greaterThan(0));

      // Seed a custom (non-default) category + a budget + transactions.
      await state.addCategory('CustomReset', type: 'expense');
      final cat = state.expenseCategories.first.name;
      await state.setBudget(cat, 100);
      await state.addExpense(makeExpense(state, description: 'reset-exp'));
      await state.addIncome(makeIncome(state, description: 'reset-inc'));

      expect(state.expenses, isNotEmpty);
      expect(state.incomes, isNotEmpty);
      expect(state.budgets, isNotEmpty);
      expect(state.categories.any((c) => c.name == 'CustomReset'), isTrue);

      // Let bootstrap's fire-and-forget recurring/maintenance pass settle so it
      // doesn't overlap resetAccount's own reload pass on the file system.
      for (var i = 0; i < 200 && state.isProcessingRecurring; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      await state.resetAccount(state.currentAccountId);

      expect(state.expenses, isEmpty, reason: 'expenses wiped');
      expect(state.incomes, isEmpty, reason: 'income wiped');
      expect(state.budgets, isEmpty, reason: 'budgets wiped');
      expect(state.categories.any((c) => c.name == 'CustomReset'), isFalse,
          reason: 'custom categories removed (isDefault = 0)');
      // Default categories survive the reset (DELETE guards isDefault = 0).
      expect(state.categories.length, defaultCategoryCount,
          reason: 'default categories survive resetAccount');
    });

    test('resetting a NON-current account leaves current data intact',
        () async {
      final state = await bootstrap();
      // Current (default) account gets a transaction we expect to survive.
      await state.addExpense(makeExpense(state, description: 'keep-me'));

      // A second account with its own transaction.
      await state.addAccount('Other');
      final other = state.accounts.firstWhere((a) => a.name == 'Other');
      await state.switchAccount(other);
      await state.addExpense(makeExpense(state, description: 'other-exp'));

      // Back to the default account (the current one we want to protect).
      final defaultAccount =
          state.accounts.firstWhere((a) => a.isDefault);
      await state.switchAccount(defaultAccount);
      expect(state.expenses.any((e) => e.description == 'keep-me'), isTrue);

      // Reset the OTHER (non-current) account: current data must not change.
      await state.resetAccount(other.id!);

      expect(state.currentAccountId, defaultAccount.id);
      expect(state.expenses.any((e) => e.description == 'keep-me'), isTrue,
          reason: 'resetting a non-current account must not touch the current '
              'account\'s in-memory data');
    });
  });

  group('permanentlyDeleteAccount', () {
    test('removes the trashed account row entirely', () async {
      final state = await bootstrap();
      await state.addAccount('ToPurge');
      final toPurge = state.accounts.firstWhere((a) => a.name == 'ToPurge');

      await state.deleteAccount(toPurge.id!);
      final deleted = await state.getDeletedAccounts();
      final trashedRow =
          deleted.firstWhere((row) => row['name'] == 'ToPurge');
      final trashedId = trashedRow['id'] as int;

      await state.permanentlyDeleteAccount(trashedId);

      final after = await state.getDeletedAccounts();
      expect(after.any((row) => row['id'] == trashedId), isFalse,
          reason: 'permanently deleted account leaves the trash table');
    });
  });

  group('refreshCurrentMonthData', () {
    test('surfaces an out-of-band DB write + notifies', () async {
      final state = await bootstrap();
      expect(state.expenses, isEmpty);

      // Write an expense row DIRECTLY to the DB, bypassing AppState's cache.
      final db = await DatabaseHelper().database;
      await db.insert('expenses', {
        'amount': 42.0,
        'category': 'Food',
        'description': 'out-of-band',
        'date': DateHelper.toDateString(currentMonthDate()),
        'account_id': state.currentAccountId,
        'amountPaid': 0.0,
        'paymentMethod': 'Cash',
      });

      // Cache is still stale: the row is invisible until a refresh.
      expect(state.expenses.any((e) => e.description == 'out-of-band'), isFalse);

      var notifies = 0;
      state.addListener(() => notifies++);

      await state.refreshCurrentMonthData();

      expect(state.expenses.any((e) => e.description == 'out-of-band'), isTrue,
          reason: 'refresh must re-read expenses from the DB');
      expect(notifies, greaterThanOrEqualTo(1),
          reason: 'refreshCurrentMonthData notifies listeners');
    });
  });
}
