import 'package:decimal/decimal.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/models/recurring_expense_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/services/onboarding_service.dart';
import 'package:budget_tracker/utils/clock.dart';
import 'package:budget_tracker/utils/currency_helper.dart';
import 'package:budget_tracker/utils/date_helper.dart';
import 'package:budget_tracker/utils/pin_security_helper.dart';
import 'package:budget_tracker/utils/secure_window.dart';

import '_test_helpers.dart';

/// Phase 7 / Stage D — AppState gap coverage:
///   * Search & analytics (searchTransactionsUnified, MoM comparison,
///     spending trends, category spending, upcoming bills).
///   * Month navigation (goToPrevious/Next/Month/Today + selectedMonthName).
///   * Settings & filters (changeCurrency, filter APPLICATION on the
///     `expenses` getter, format* delegates, union/sort category getters).
///   * Calculations & aliases (the *ThisMonth getters, getExpensesForMonth,
///     totalIncome/totalSpent/netSavings aliases, getAll*ForBackup).
///   * PIN lock — only the deterministic parts reachable through the mocked
///     secure-storage channel + FakeClock/FakeAsync (isPinEnabled,
///     initializeLockState, unlock/lock/resetLockTimer + the 3-min timer).
///
/// These complement `app_state_crud_test.dart` (CRUD mutators) without
/// re-covering it. Expected values are DERIVED from app_state.dart, not
/// guessed; where a value can't be derived deterministically the test
/// asserts a weaker, definitely-true invariant.
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

  // Backing store for the mocked flutter_secure_storage channel, so the PIN
  // helper's writes/reads round-trip in-memory (the pin_lockout_test pattern).
  late Map<String, String> secureBacking;
  // Captured booleans from SecureWindow.setSecure. We use the SecureWindow
  // .testHandler seam (NOT the raw method channel): setSecure no-ops off-Android
  // before it ever touches the channel, so a channel mock would capture nothing.
  late List<bool> secureWindowCalls;

  setUp(() async {
    secureBacking = <String, String>{};
    secureWindowCalls = <bool>[];
    // Capture SecureWindow.setSecure via its @visibleForTesting seam — works
    // regardless of host platform and receives the bool directly.
    SecureWindow.testHandler = (on) async => secureWindowCalls.add(on);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null)
      ..setMockMethodCallHandler(secureChannel, (call) async {
        switch (call.method) {
          case 'read':
            final args = call.arguments as Map;
            return secureBacking[args['key'] as String];
          case 'write':
            final args = call.arguments as Map;
            final key = args['key'] as String;
            final value = args['value'] as String?;
            if (value == null) {
              secureBacking.remove(key);
            } else {
              secureBacking[key] = value;
            }
            return null;
          case 'delete':
            final args = call.arguments as Map;
            secureBacking.remove(args['key'] as String);
            return null;
          case 'readAll':
            return Map<String, String>.from(secureBacking);
          case 'deleteAll':
            secureBacking.clear();
            return null;
          case 'containsKey':
            final args = call.arguments as Map;
            return secureBacking.containsKey(args['key'] as String);
        }
        return null;
      })
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
    SecureWindow.testHandler = null;
    Clock.instance = const Clock();
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

  // The in-memory window only holds the previous + current calendar month
  // (see _loadExpensesInternal). Derive an in-window date for the current and
  // previous month so seeded rows stay resident regardless of when the suite
  // runs. Use day 15 to avoid month-boundary edge cases.
  DateTime currentMonthDate() {
    final now = DateHelper.today();
    return DateHelper.normalize(DateTime.utc(now.year, now.month, 15));
  }

  DateTime previousMonthDate() {
    final now = DateHelper.today();
    final prev = DateHelper.subtractMonths(now, 1);
    return DateHelper.normalize(DateTime.utc(prev.year, prev.month, 15));
  }

  // ===========================================================================
  // SEARCH & ANALYTICS
  // ===========================================================================

  group('searchTransactionsUnified', () {
    test('empty query short-circuits with empty result + hasMore:false',
        () async {
      final state = await bootstrap();
      await state.addExpense(makeExpense(state, description: 'coffee'));

      final result = await state.searchTransactionsUnified('');

      expect(result['expenses'], isEmpty);
      expect(result['income'], isEmpty);
      expect(result['hasMore'], isFalse);
    });

    test('matching query returns the expense, scoped to the account',
        () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(state, description: 'uniquegroceries', amount: 42),
      );
      await state.addIncome(
        makeIncome(state, description: 'uniquepaycheck', amount: 900),
      );

      final expenseHits =
          await state.searchTransactionsUnified('uniquegroceries');
      final expenses = expenseHits['expenses'] as List<Expense>;
      expect(expenses, isNotEmpty);
      expect(
        expenses.any((e) => e.description == 'uniquegroceries'),
        isTrue,
      );

      final incomeHits =
          await state.searchTransactionsUnified('uniquepaycheck');
      final incomes = incomeHits['income'] as List<Income>;
      expect(incomes, isNotEmpty);
      expect(
        incomes.any((i) => i.description == 'uniquepaycheck'),
        isTrue,
      );
    });

    test('non-matching query returns no rows', () async {
      final state = await bootstrap();
      await state.addExpense(makeExpense(state, description: 'lunch'));

      final result =
          await state.searchTransactionsUnified('zzznevermatcheszzz');

      expect(result['expenses'], isEmpty);
      expect(result['income'], isEmpty);
    });
  });

  group('getMonthOverMonthComparison', () {
    test('prev month zero → percentChange 0 (no div-by-zero)', () async {
      final state = await bootstrap();
      // Only a current-month expense; previous month has nothing.
      await state.addExpense(
        makeExpense(state, amount: 100, date: currentMonthDate()),
      );

      final mom = state.getMonthOverMonthComparison();

      expect(mom['currentTotal'], closeTo(100, 0.001));
      expect(mom['previousTotal'], closeTo(0, 0.001));
      expect(mom['percentChange'], closeTo(0, 0.001),
          reason: 'prevTotal == 0 must short-circuit to 0, never NaN/Inf');
    });

    test('100 → 150 yields +50% percentChange', () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(
          state,
          amount: 100,
          category: 'Food',
          description: 'prev',
          date: previousMonthDate(),
        ),
      );
      await state.addExpense(
        makeExpense(
          state,
          amount: 150,
          category: 'Food',
          description: 'cur',
          date: currentMonthDate(),
        ),
      );

      final mom = state.getMonthOverMonthComparison();

      expect(mom['currentTotal'], closeTo(150, 0.001));
      expect(mom['previousTotal'], closeTo(100, 0.001));
      expect(mom['percentChange'], closeTo(50, 0.001));

      final categoryComparison =
          mom['categoryComparison'] as Map<String, Map<String, double>>;
      expect(categoryComparison.containsKey('Food'), isTrue);
      expect(categoryComparison['Food']!['current'], closeTo(150, 0.001));
      expect(categoryComparison['Food']!['previous'], closeTo(100, 0.001));
      expect(categoryComparison['Food']!['change'], closeTo(50, 0.001));
    });
  });

  group('getIncomeMonthOverMonthComparison', () {
    test('prev income zero → percentChange 0', () async {
      final state = await bootstrap();
      await state.addIncome(
        makeIncome(state, amount: 200, date: currentMonthDate()),
      );

      final mom = state.getIncomeMonthOverMonthComparison();

      expect(mom['currentTotal'], closeTo(200, 0.001));
      expect(mom['previousTotal'], closeTo(0, 0.001));
      expect(mom['percentChange'], closeTo(0, 0.001));
    });
  });

  group('getSpendingTrends', () {
    test('returns N months oldest→newest with savings = income − expenses',
        () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(state, amount: 60, date: currentMonthDate()),
      );
      await state.addIncome(
        makeIncome(state, amount: 200, date: currentMonthDate()),
      );

      final trends = await state.getSpendingTrends(months: 3);

      expect(trends, hasLength(3));
      // Oldest → newest ordering: each month strictly after the previous.
      for (var i = 1; i < trends.length; i++) {
        final prev = trends[i - 1]['month'] as DateTime;
        final cur = trends[i]['month'] as DateTime;
        expect(cur.isAfter(prev), isTrue,
            reason: 'trends must be ordered oldest→newest');
      }
      // The last bucket is the selected (current) month and carries our seed.
      final last = trends.last;
      expect(last['expenses'], closeTo(60, 0.001));
      expect(last['income'], closeTo(200, 0.001));
      expect(
        last['savings'],
        closeTo(
          (last['income'] as double) - (last['expenses'] as double),
          0.001,
        ),
        reason: 'savings == income − expenses',
      );
    });
  });

  group('getCategorySpending', () {
    test('sums actual spend per category for the selected month', () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(
          state,
          amount: 30,
          category: 'Food',
          description: 'a',
          date: currentMonthDate(),
        ),
      );
      await state.addExpense(
        makeExpense(
          state,
          amount: 20,
          category: 'Food',
          description: 'b',
          date: currentMonthDate(),
        ),
      );
      await state.addExpense(
        makeExpense(
          state,
          amount: 15,
          category: 'Transport',
          description: 'c',
          date: currentMonthDate(),
        ),
      );

      final spending = state.getCategorySpending();

      expect(spending['Food'], closeTo(50, 0.001));
      expect(spending['Transport'], closeTo(15, 0.001));
    });

    test('getSpentForCategory aliases the budget-spent total', () async {
      final state = await bootstrap();
      await state.addExpense(
        makeExpense(
          state,
          amount: 40,
          category: 'Food',
          date: currentMonthDate(),
        ),
      );

      expect(
        state.getSpentForCategory('Food'),
        closeTo(state.getBudgetSpent('Food'), 0.001),
        reason: 'getSpentForCategory delegates to getBudgetSpent',
      );
    });
  });

  group('getUpcomingBillsThisMonth', () {
    test('returns maps sorted by dueDate with correct daysUntilDue', () async {
      // Anchor "today" to the 1st so a bill on day 10 and day 20 are both
      // strictly in the future this month, making the test deterministic.
      final now = DateHelper.today();
      Clock.instance =
          FakeClock.fixed(DateTime.utc(now.year, now.month, 1, 12));

      final state = await bootstrap();
      final expenseCat = state.expenseCategories.first.name;

      await state.addRecurringExpense(
        RecurringExpense(
          description: 'later-bill',
          amount: Decimal.parse('80'),
          category: expenseCat,
          accountId: state.currentAccountId,
          dayOfMonth: 20,
          frequency: RecurringExpenseFrequency.monthly,
        ),
      );
      await state.addRecurringExpense(
        RecurringExpense(
          description: 'sooner-bill',
          amount: Decimal.parse('30'),
          category: expenseCat,
          accountId: state.currentAccountId,
          dayOfMonth: 10,
          frequency: RecurringExpenseFrequency.monthly,
        ),
      );

      final bills = state.getUpcomingBillsThisMonth();

      expect(bills, hasLength(2));
      // Sorted ascending by dueDate → day-10 bill first.
      expect(bills.first['description'], 'sooner-bill');
      expect(bills.last['description'], 'later-bill');
      // today is day 1 → day-10 bill is 9 days out, day-20 bill 19 days out.
      expect(bills.first['daysUntilDue'], 9);
      expect(bills.last['daysUntilDue'], 19);
    });

    test('a bill already past today this month is excluded', () async {
      final now = DateHelper.today();
      // today = day 25; a bill on day 5 has already passed.
      Clock.instance =
          FakeClock.fixed(DateTime.utc(now.year, now.month, 25, 12));

      final state = await bootstrap();
      final expenseCat = state.expenseCategories.first.name;

      await state.addRecurringExpense(
        RecurringExpense(
          description: 'past-bill',
          amount: Decimal.parse('50'),
          category: expenseCat,
          accountId: state.currentAccountId,
          dayOfMonth: 5,
          frequency: RecurringExpenseFrequency.monthly,
        ),
      );

      final bills = state.getUpcomingBillsThisMonth();

      expect(
        bills.any((b) => b['description'] == 'past-bill'),
        isFalse,
        reason: 'a due date before today must be excluded',
      );
    });

    test('day-31 bill clamps to the last day of a short month', () async {
      // Pin to April (30 days), day 1, so a day-31 bill clamps to Apr 30.
      Clock.instance = FakeClock.fixed(DateTime.utc(2026, 4, 1, 12));

      final state = await bootstrap();
      final expenseCat = state.expenseCategories.first.name;
      await state.addRecurringExpense(
        RecurringExpense(
          description: 'eom-bill',
          amount: Decimal.parse('99'),
          category: expenseCat,
          accountId: state.currentAccountId,
          dayOfMonth: 31,
          frequency: RecurringExpenseFrequency.monthly,
        ),
      );

      final bills = state.getUpcomingBillsThisMonth();
      final eom = bills.firstWhere((b) => b['description'] == 'eom-bill');
      final due = eom['dueDate'] as DateTime;
      expect(due.month, 4);
      expect(due.day, 30, reason: 'day 31 clamps to Apr 30');
    });
  });

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  group('month navigation', () {
    test('goToNextMonth / goToPreviousMonth shift selectedMonth by ∓1',
        () async {
      final state = await bootstrap();
      final start = state.selectedMonth;

      await state.goToNextMonth();
      expect(state.selectedMonth.month, DateHelper.addMonths(start, 1).month);
      expect(state.selectedMonth.year, DateHelper.addMonths(start, 1).year);

      await state.goToPreviousMonth();
      expect(state.selectedMonth.month, start.month);
      expect(state.selectedMonth.year, start.year);
    });

    test('goToMonth snaps to start-of-month', () async {
      final state = await bootstrap();
      // A mid-month date in a fixed month.
      await state.goToMonth(DateTime.utc(2026, 3, 17));
      expect(state.selectedMonth, DateTime.utc(2026, 3, 1));
    });

    test('goToToday returns to the current calendar month', () async {
      final state = await bootstrap();
      await state.goToMonth(DateTime.utc(2025, 1, 9));
      expect(state.selectedMonth, DateTime.utc(2025, 1, 1));

      await state.goToToday();
      final todayMonth = DateHelper.startOfMonth(DateHelper.today());
      expect(state.selectedMonth, todayMonth);
    });

    test('year boundary: December → January increments the year', () async {
      final state = await bootstrap();
      await state.goToMonth(DateTime.utc(2026, 12, 1));
      expect(state.selectedMonth, DateTime.utc(2026, 12, 1));

      await state.goToNextMonth();
      expect(state.selectedMonth, DateTime.utc(2027, 1, 1));
    });

    test('each navigation call notifies exactly once', () async {
      final state = await bootstrap();
      var notifies = 0;
      state.addListener(() => notifies++);

      await state.goToNextMonth();
      expect(notifies, 1);

      await state.goToPreviousMonth();
      expect(notifies, 2);

      await state.goToToday();
      expect(notifies, 3);
    });

    test('navigating loads the target month rows into the window', () async {
      final state = await bootstrap();
      // Seed an expense two months in the past (outside the default window).
      final now = DateHelper.today();
      final twoBack = DateHelper.subtractMonths(now, 2);
      final seedDate =
          DateHelper.normalize(DateTime.utc(twoBack.year, twoBack.month, 12));
      await state.addExpense(
        makeExpense(state, amount: 33, description: 'old', date: seedDate),
      );

      // Not in the default (prev+current) window yet.
      expect(
        state.allExpenses.any((e) => e.description == 'old'),
        isFalse,
        reason: 'a 2-month-old row is outside the default window',
      );

      await state.goToMonth(seedDate);

      expect(
        state.allExpenses.any((e) => e.description == 'old'),
        isTrue,
        reason: 'goToMonth must ensure the target month is loaded',
      );
    });
  });

  group('selectedMonthName', () {
    test('formats as "Month YYYY" with 1-based month indexing', () async {
      final state = await bootstrap();
      await state.goToMonth(DateTime.utc(2026, 1, 1));
      expect(state.selectedMonthName, 'January 2026');

      await state.goToMonth(DateTime.utc(2026, 12, 1));
      expect(state.selectedMonthName, 'December 2026');
    });
  });

  // ===========================================================================
  // SETTINGS & FILTERS
  // ===========================================================================

  group('changeCurrency', () {
    test('updates currencyCode + symbol and persists onto the account',
        () async {
      final state = await bootstrap();
      expect(state.currencyCode, 'USD');
      var notifies = 0;
      state.addListener(() => notifies++);

      await state.changeCurrency('EUR');

      expect(state.currencyCode, 'EUR');
      expect(state.currency, CurrencyHelper.getSymbol('EUR'));
      expect(notifies, 1, reason: 'changeCurrency notifies exactly once');

      // Persisted onto the current account row in the DB.
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'accounts',
        where: 'id = ?',
        whereArgs: [state.currentAccountId],
      );
      expect(rows.single['currencyCode'], 'EUR');
    });
  });

  group('filter application on the expenses getter', () {
    test('category filter narrows the list', () async {
      final state = await bootstrap();
      final d = currentMonthDate();
      await state.addExpense(
        makeExpense(state, category: 'Food', description: 'f', date: d),
      );
      await state.addExpense(
        makeExpense(
            state, category: 'Transport', description: 't', date: d),
      );
      expect(state.expenses, hasLength(2));

      state.setFilterCategory('Food');

      expect(state.expenses, hasLength(1));
      expect(state.expenses.single.category, 'Food');

      state.clearFilters();
      expect(state.expenses, hasLength(2));
    });

    test('date range is inclusive of both endpoints', () async {
      final state = await bootstrap();
      final now = DateHelper.today();
      final d5 = DateHelper.normalize(DateTime.utc(now.year, now.month, 5));
      final d15 = DateHelper.normalize(DateTime.utc(now.year, now.month, 15));
      final d25 = DateHelper.normalize(DateTime.utc(now.year, now.month, 25));
      await state.addExpense(makeExpense(state, description: 'd5', date: d5));
      await state.addExpense(makeExpense(state, description: 'd15', date: d15));
      await state.addExpense(makeExpense(state, description: 'd25', date: d25));

      state.setDateRange(d5, d15);

      final descriptions =
          state.expenses.map((e) => e.description).toSet();
      expect(descriptions, containsAll(<String>['d5', 'd15']),
          reason: 'endpoints are inclusive');
      expect(descriptions.contains('d25'), isFalse);
    });

    test('amount min/max bounds the list', () async {
      final state = await bootstrap();
      final d = currentMonthDate();
      await state.addExpense(
        makeExpense(state, amount: 10, description: 'cheap', date: d),
      );
      await state.addExpense(
        makeExpense(state, amount: 50, description: 'mid', date: d),
      );
      await state.addExpense(
        makeExpense(state, amount: 200, description: 'pricey', date: d),
      );

      state.setAmountRange(20, 100);

      final descriptions =
          state.expenses.map((e) => e.description).toSet();
      expect(descriptions, {'mid'});
    });

    test('paid-status filter splits paid vs unpaid', () async {
      final state = await bootstrap();
      final d = currentMonthDate();
      // Fully paid (amountPaid == amount).
      await state.addExpense(
        makeExpense(
          state,
          amount: 40,
          amountPaid: 40,
          description: 'paid',
          date: d,
        ),
      );
      // Unpaid.
      await state.addExpense(
        makeExpense(state, amount: 40, description: 'unpaid', date: d),
      );

      state.setPaidStatusFilter(true);
      expect(state.expenses.map((e) => e.description), ['paid']);

      state.setPaidStatusFilter(false);
      expect(state.expenses.map((e) => e.description), ['unpaid']);
    });
  });

  group('format delegates use the state currency code', () {
    test('formatAmount / formatWithCurrency / formatCompact match helper',
        () async {
      final state = await bootstrap();
      await state.changeCurrency('EUR');

      expect(
        state.formatAmount(1234.56),
        CurrencyHelper.formatAmount(1234.56, 'EUR'),
      );
      expect(
        state.formatWithCurrency(1234.56),
        CurrencyHelper.formatWithSymbol(
          1234.56,
          CurrencyHelper.getSymbol('EUR'),
          'EUR',
        ),
      );
      expect(
        state.formatCompact(1234567.0),
        CurrencyHelper.formatCompact(1234567.0, 'EUR'),
      );
    });

    test('formatAmount respects decimalDigits', () async {
      final state = await bootstrap();
      expect(
        state.formatAmount(10.0, decimalDigits: 0),
        CurrencyHelper.formatAmount(10.0, 'USD', decimalDigits: 0),
      );
    });
  });

  group('union/sort category getters', () {
    test('allExpenseCategoryNames dedups + sorts, including tx-only category',
        () async {
      final state = await bootstrap();
      // Seed an expense in a category that is NOT a defined category.
      await state.addExpense(
        makeExpense(
          state,
          category: 'ZzzCustomTxOnly',
          description: 'x',
          date: currentMonthDate(),
        ),
      );

      final names = state.allExpenseCategoryNames;

      // The transaction-only category surfaces in the union.
      expect(names.contains('ZzzCustomTxOnly'), isTrue);
      // No duplicates.
      expect(names.toSet().length, names.length);
      // Sorted ascending.
      final sorted = [...names]..sort();
      expect(names, sorted);
    });

    test('expenseCategories and incomeCategories partition by type', () async {
      final state = await bootstrap();
      expect(state.expenseCategories.every((c) => c.type == 'expense'), isTrue);
      expect(state.incomeCategories.every((c) => c.type == 'income'), isTrue);
      expect(state.expenseCategories, isNotEmpty);
      expect(state.incomeCategories, isNotEmpty);
    });
  });

  // ===========================================================================
  // CALCULATIONS & ALIASES
  // ===========================================================================

  group('monthly total getters', () {
    test('totals + balance reflect the seeded month', () async {
      final state = await bootstrap();
      final d = currentMonthDate();
      await state.addExpense(
        makeExpense(state, amount: 30, description: 'e1', date: d),
      );
      await state.addExpense(
        makeExpense(
          state,
          amount: 20,
          amountPaid: 5,
          description: 'e2',
          date: d,
        ),
      );
      await state.addIncome(
        makeIncome(state, amount: 100, description: 'i1', date: d),
      );

      expect(state.totalExpensesThisMonth, closeTo(50, 0.001));
      expect(state.totalIncomeThisMonth, closeTo(100, 0.001));
      expect(state.balanceThisMonth, closeTo(50, 0.001),
          reason: 'income − expenses = 100 − 50');
      // totalPaid = 0 + 5; totalRemaining = (30−0) + (20−5) = 45.
      expect(state.totalPaid, closeTo(5, 0.001));
      expect(state.totalRemaining, closeTo(45, 0.001));
      // availableIncomeBalance = income − totalPaid = 100 − 5.
      expect(state.availableIncomeBalance, closeTo(95, 0.001));
    });

    test('decimal precision: 0.10 × 3 sums to 0.30 with no float drift',
        () async {
      final state = await bootstrap();
      final d = currentMonthDate();
      for (var i = 0; i < 3; i++) {
        await state.addExpense(
          makeExpense(state, amount: 0.10, description: 'dime$i', date: d),
        );
      }
      expect(state.totalExpensesThisMonth, closeTo(0.30, 0.0001));
    });
  });

  group('per-month calculation helpers', () {
    test('getExpensesForMonth / getIncomeForMonth sum a specific month',
        () async {
      final state = await bootstrap();
      final cur = currentMonthDate();
      await state.addExpense(
        makeExpense(state, amount: 25, description: 'c', date: cur),
      );
      await state.addIncome(
        makeIncome(state, amount: 70, description: 'ci', date: cur),
      );

      final month = DateHelper.startOfMonth(cur);
      expect(state.getExpensesForMonth(month), closeTo(25, 0.001));
      expect(state.getIncomeForMonth(month), closeTo(70, 0.001));
    });

    test('getExpensesForMonth is 0 for an empty (in-window) month', () async {
      final state = await bootstrap();
      // Previous month has nothing seeded but is in the window.
      final prevMonth = DateHelper.startOfMonth(previousMonthDate());
      expect(state.getExpensesForMonth(prevMonth), 0.0);
    });

    test('getAvailableIncomeForMonth = income − paid for that month',
        () async {
      final state = await bootstrap();
      final d = currentMonthDate();
      await state.addIncome(
        makeIncome(state, amount: 100, description: 'inc', date: d),
      );
      await state.addExpense(
        makeExpense(
          state,
          amount: 60,
          amountPaid: 25,
          description: 'partial',
          date: d,
        ),
      );

      final month = DateHelper.startOfMonth(d);
      // 100 income − 25 paid = 75.
      expect(state.getAvailableIncomeForMonth(month), closeTo(75, 0.001));
    });
  });

  group('aliases', () {
    test('totalIncome / totalSpent / netSavings equal their targets',
        () async {
      final state = await bootstrap();
      final d = currentMonthDate();
      await state.addExpense(
        makeExpense(state, amount: 40, description: 'e', date: d),
      );
      await state.addIncome(
        makeIncome(state, amount: 90, description: 'i', date: d),
      );

      expect(state.totalIncome, state.totalIncomeThisMonth);
      expect(state.totalSpent, state.totalExpensesThisMonth);
      expect(state.netSavings, state.balanceThisMonth);
    });
  });

  group('backup readers (un-windowed)', () {
    test('getAllExpensesForBackup returns rows outside the in-memory window',
        () async {
      final state = await bootstrap();
      // A row 3 months back is outside the default prev+current window.
      final now = DateHelper.today();
      final old = DateHelper.subtractMonths(now, 3);
      final oldDate =
          DateHelper.normalize(DateTime.utc(old.year, old.month, 10));
      await state.addExpense(
        makeExpense(state, amount: 12, description: 'archived', date: oldDate),
      );

      // Not in the windowed cache.
      expect(
        state.allExpenses.any((e) => e.description == 'archived'),
        isFalse,
      );

      final all = await state.getAllExpensesForBackup();
      expect(
        all.any((e) => e.description == 'archived'),
        isTrue,
        reason: 'backup read must include out-of-window rows',
      );
    });

    test('getAllIncomesForBackup returns rows outside the window', () async {
      final state = await bootstrap();
      final now = DateHelper.today();
      final old = DateHelper.subtractMonths(now, 3);
      final oldDate =
          DateHelper.normalize(DateTime.utc(old.year, old.month, 10));
      await state.addIncome(
        makeIncome(state, amount: 80, description: 'archived-inc', date: oldDate),
      );

      final all = await state.getAllIncomesForBackup();
      expect(all.any((i) => i.description == 'archived-inc'), isTrue);
    });
  });

  // ===========================================================================
  // PIN LOCK (deterministic, channel-mock-reachable parts only)
  // ===========================================================================

  group('isPinEnabled', () {
    test('false when no PIN configured', () async {
      final state = await bootstrap();
      expect(await state.isPinEnabled(), isFalse);
    });

    test('true after a PIN is configured', () async {
      final state = await bootstrap();
      await PinSecurityHelper.setPin('9027');
      expect(await state.isPinEnabled(), isTrue);
    });
  });

  group('initializeLockState', () {
    test('PIN disabled → isLocked false and SecureWindow.setSecure(false)',
        () async {
      final state = await bootstrap();
      await state.initializeLockState();

      expect(state.isLocked, isFalse);
      // setSecure is unawaited; flush microtasks so the channel call lands.
      await Future<void>.delayed(Duration.zero);
      expect(secureWindowCalls, contains(false));
    });

    test('PIN enabled → isLocked true and SecureWindow.setSecure(true)',
        () async {
      final state = await bootstrap();
      await PinSecurityHelper.setPin('9027');

      await state.initializeLockState();

      expect(state.isLocked, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(secureWindowCalls, contains(true));
    });

    test('idempotent across repeated cold-start calls', () async {
      final state = await bootstrap();
      await PinSecurityHelper.setPin('9027');

      await state.initializeLockState();
      await state.initializeLockState();

      expect(state.isLocked, isTrue,
          reason: 'repeated init with PIN enabled stays locked');
    });
  });

  // Regression: a cold-start ordering race presented the PIN unlock screen to
  // users who never set a PIN. `_isLocked` defaults to `true` (fail-closed) and
  // is only reset once initializeLockState() finishes its async secure-storage
  // read; the UI gate (`_checkPinLock`) ran from a separate post-frame callback
  // and could read the stale `true` before that resolution — trapping the user
  // on a screen no PIN could dismiss. The fix exposes `lockStateReady` and the
  // gate awaits it before reading `isLocked`.
  group('cold-start lock-state race (regression)', () {
    test('lockStateReady stays pending until initializeLockState resolves',
        () async {
      final state = AppState();
      var ready = false;
      final readyFuture = state.lockStateReady.then((_) => ready = true);

      // Let any synchronous/microtask completion settle. The gate MUST still be
      // pending — completing it early (e.g. in the constructor) would re-open
      // the race this guards against.
      await Future<void>.delayed(Duration.zero);
      expect(ready, isFalse,
          reason: 'lock-state gate must not resolve before the PIN state is '
              'read');

      await state.initializeLockState();
      await readyFuture;
      expect(ready, isTrue,
          reason: 'gate resolves once initializeLockState finishes');
      state.dispose();
    });

    test('no PIN: isLocked is false after awaiting lockStateReady', () async {
      final state = AppState();
      // Fail-closed default before the real PIN state is resolved.
      expect(state.isLocked, isTrue);

      // Mirror main.dart: kick off init fire-and-forget, then gate on readiness
      // exactly as the fixed `_checkPinLock` does.
      final init = state.initializeLockState();
      await state.lockStateReady;

      expect(state.isLocked, isFalse,
          reason: 'a user who never set a PIN must end up unlocked — the gate '
              'must never present the unlock screen here');
      await init;
      state.dispose();
    });

    test('PIN set: isLocked is true after awaiting lockStateReady', () async {
      final state = AppState();
      await PinSecurityHelper.setPin('9027');

      final init = state.initializeLockState();
      await state.lockStateReady;

      expect(state.isLocked, isTrue,
          reason: 'a configured PIN must still gate access after the fix');
      await init;
      state.dispose();
    });
  });

  group('unlock / lock', () {
    test('unlock clears the lock and notifies', () async {
      final state = await bootstrap();
      await PinSecurityHelper.setPin('9027');
      await state.initializeLockState();
      expect(state.isLocked, isTrue);

      var notifies = 0;
      state.addListener(() => notifies++);

      state.unlock();

      expect(state.isLocked, isFalse);
      expect(notifies, 1);
    });

    test('lock sets the lock and notifies', () async {
      final state = await bootstrap();
      state.unlock(); // ensure unlocked first
      var notifies = 0;
      state.addListener(() => notifies++);

      state.lock();

      expect(state.isLocked, isTrue);
      expect(notifies, 1);
    });
  });

  group('resetLockTimer', () {
    test('is a no-op while locked (no notify, stays locked)', () async {
      final state = await bootstrap();
      await PinSecurityHelper.setPin('9027');
      await state.initializeLockState();
      expect(state.isLocked, isTrue);

      var notifies = 0;
      state.addListener(() => notifies++);

      state.resetLockTimer();

      expect(state.isLocked, isTrue);
      expect(notifies, 0,
          reason: 'resetLockTimer does nothing when already locked');
    });
  });

  group('inactivity lock timer (FakeAsync)', () {
    // NOTE: the 3-minute timer callback awaits PinSecurityHelper.isPinEnabled(),
    // which crosses the flutter_secure_storage platform channel. The channel
    // reply is NOT guaranteed to be delivered inside FakeAsync's zone, so a
    // test that elapses time and then asserts the POST-await lock() ran would
    // be flaky. We therefore only assert the parts that are deterministic
    // without the channel resolving: the timer is armed before the timeout and
    // dispose cancels it so no post-dispose lock can fire. (The full
    // "re-locks after 3 min with PIN enabled" path is device-verified per the
    // session handoff, and would need a PinSecurityHelper test seam to unit-test
    // deterministically.)
    test('the timer does NOT fire before the 3-minute timeout', () {
      fakeAsync((async) {
        final state = AppState();
        secureBacking['pin_enabled'] = 'true';

        state.unlock(); // arms the 3-minute timer; isLocked == false
        expect(state.isLocked, isFalse);

        // Well short of the 3-minute deadline — must still be unlocked.
        async.elapse(const Duration(minutes: 2, seconds: 30));
        expect(state.isLocked, isFalse,
            reason: 'no lock before the 3-minute deadline');
        state.dispose();
      });
    });

    test('dispose during the timer prevents a post-dispose lock', () {
      fakeAsync((async) {
        final state = AppState();
        secureBacking['pin_enabled'] = 'true';
        state.unlock();

        // Dispose before the timer fires. _cancelLockTimer cancels it, and the
        // callback's _isDisposed guards short-circuit even if it had run.
        state.dispose();

        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();

        expect(state.isLocked, isFalse,
            reason: 'disposed timer must not flip lock state');
      });
    });
  });

  // ===========================================================================
  // OnboardingService — the Phase 5.5 tooltip pair (untested elsewhere)
  // ===========================================================================

  group('OnboardingService add-transaction tooltip', () {
    test('false on fresh install', () async {
      final svc = OnboardingService();
      expect(await svc.hasSeenAddTransactionTooltip(), isFalse);
    });

    test('true after markAddTransactionTooltipSeen (idempotent)', () async {
      final svc = OnboardingService();
      await svc.markAddTransactionTooltipSeen();
      expect(await svc.hasSeenAddTransactionTooltip(), isTrue);
      // Idempotent — second call keeps it true.
      await svc.markAddTransactionTooltipSeen();
      expect(await svc.hasSeenAddTransactionTooltip(), isTrue);
    });

    test('false again after resetOnboarding', () async {
      final svc = OnboardingService();
      await svc.markAddTransactionTooltipSeen();
      expect(await svc.hasSeenAddTransactionTooltip(), isTrue);

      await svc.resetOnboarding();
      expect(await svc.hasSeenAddTransactionTooltip(), isFalse);
    });
  });
}
