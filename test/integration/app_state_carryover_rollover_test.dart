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
import 'package:budget_tracker/utils/settings_helper.dart';

import '_test_helpers.dart';

/// Month-to-month roll-over ("whatever is left transfers to the next month").
///
/// The carry-over into a month is every prior income minus every prior
/// expense, folded from the transaction rows in one aggregate query
/// (`DatabaseHelper.calculateNetBalanceBefore`). These tests pin the
/// behaviours the previous stored-row chain got wrong:
///
///   * a month the app was never opened in no longer breaks the chain;
///   * a back-dated insert is reflected in the selected month at once, in the
///     same SQLite transaction as the row (no "stale until you navigate");
///   * navigating to a month always recomputes it;
///   * the Settings toggle gates every derived figure and persists;
///   * recomputing a month keeps its overall budget (the old rebuild dropped
///     the `overall_budget` column).
///
/// Dates are anchored to the wall-clock month via [DateHelper.today] like the
/// sibling carry-over tests, so the seeded rows stay inside AppState's
/// prev+current in-memory window where it matters.
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

  int ppCounter = 0;
  late Directory ppDir;

  setUp(() async {
    ppCounter++;
    ppDir = Directory(
      '.dart_tool/test_pp_rollover_${ppCounter}_${DateTime.now().microsecondsSinceEpoch}',
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

  /// The 15th of the month [n] months before today (n = 0 is this month).
  DateTime monthsAgo(int n, {int day = 15}) {
    final m = DateHelper.subtractMonths(DateHelper.today(), n);
    return DateTime.utc(m.year, m.month, day);
  }

  Future<void> income(AppState state, double amount, DateTime date) {
    return state.addIncome(Income(
      amount: Decimal.parse(amount.toString()),
      category: 'Salary',
      description: 'pay',
      date: date,
      accountId: state.currentAccountId,
    ));
  }

  Future<void> expense(
    AppState state,
    double amount,
    DateTime date, {
    double paid = 0,
  }) {
    return state.addExpense(Expense(
      amount: Decimal.parse(amount.toString()),
      category: 'Food',
      description: 'lunch',
      date: date,
      accountId: state.currentAccountId,
      amountPaid: Decimal.parse(paid.toString()),
      paymentMethod: 'Cash',
    ));
  }

  group('cumulative carry-over across many months', () {
    test('income two months back still arrives, net of last month', () async {
      final state = await bootstrap();
      // The month in between was never "opened" (no stored balance row for
      // it) — the old chain read its missing row as zero and lost the 1000.
      await income(state, 1000, monthsAgo(2));
      await expense(state, 300, monthsAgo(1));

      await state.recalculateCarryovers();

      expect(state.carryoverForSelectedMonth, closeTo(700, 0.001));
      expect(state.hasCarryover, isTrue);
    });

    test('a back-dated insert updates the selected month immediately',
        () async {
      final state = await bootstrap(); // selected = current month
      await income(state, 500, monthsAgo(2));
      // No recalculateCarryovers() — the value written alongside the row
      // in the same transaction must already include it.
      expect(state.carryoverForSelectedMonth, closeTo(500, 0.001));

      await expense(state, 120, monthsAgo(3));
      expect(state.carryoverForSelectedMonth, closeTo(380, 0.001));
    });

    test('a row dated in the selected month itself does not carry in',
        () async {
      final state = await bootstrap();
      await income(state, 900, monthsAgo(0));
      expect(state.carryoverForSelectedMonth, closeTo(0, 0.001),
          reason: 'this month\'s own income is income, not carry-over');
      expect(state.totalIncomeThisMonth, closeTo(900, 0.001));
    });

    test('navigating to a month recomputes it from the rows', () async {
      final state = await bootstrap();
      await expense(state, 200, monthsAgo(2, day: 10));

      await state.goToMonth(monthsAgo(1, day: 1));
      expect(state.carryoverForSelectedMonth, closeTo(-200, 0.001),
          reason: 'last month starts with the deficit from two months ago');

      // Edit further back while viewing last month.
      await income(state, 1000, monthsAgo(3));
      expect(state.carryoverForSelectedMonth, closeTo(800, 0.001));

      await state.goToToday();
      expect(state.carryoverForSelectedMonth, closeTo(800, 0.001),
          reason: 'nothing happened last month, so the same 800 rolls on');
    });

    test('a future month carries everything through the current month',
        () async {
      final state = await bootstrap();
      await income(state, 300, monthsAgo(0));
      await expense(state, 50, monthsAgo(0), paid: 50);

      final next = DateHelper.addMonths(state.selectedMonth, 1);
      expect(await state.getCarryoverForMonth(next), closeTo(250, 0.001));
    });
  });

  group('Carry Over Balance setting', () {
    test('off zeroes every derived figure, on restores it, and it persists',
        () async {
      final state = await bootstrap();
      await income(state, 900, monthsAgo(1));
      await expense(state, 100, monthsAgo(0), paid: 100);
      await state.recalculateCarryovers();

      expect(state.carryoverEnabled, isTrue);
      expect(state.carryoverForSelectedMonth, closeTo(900, 0.001));
      // income 0 + carried 900 - paid 100
      expect(state.totalAvailableCash, closeTo(800, 0.001));

      await state.toggleCarryover(false);

      expect(state.carryoverEnabled, isFalse);
      expect(state.carryoverForSelectedMonth, closeTo(0, 0.001));
      expect(state.carryoverForSelectedMonthDecimal, Decimal.zero);
      expect(state.hasCarryover, isFalse);
      expect(state.totalAvailableCash, closeTo(-100, 0.001));
      expect(state.projectedEndOfMonthBalance, closeTo(-100, 0.001));
      expect(await SettingsHelper.getCarryoverEnabled(), isFalse,
          reason: 'the toggle is persisted, not just in-memory');

      await state.toggleCarryover(true);
      expect(state.carryoverForSelectedMonth, closeTo(900, 0.001),
          reason: 'balances kept computing while off, so on is instant');
    });

    test('a fresh AppState reads the persisted setting', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'carryover_enabled': false},
      );
      final state = await bootstrap();
      expect(state.carryoverEnabled, isFalse);
    });
  });

  group('regressions', () {
    test('recomputing carry-over keeps the overall monthly budget', () async {
      final state = await bootstrap();
      await state.setOverallMonthlyBudget(500);

      // Both recompute paths rebuild the month's MonthlyBalance row; the old
      // rebuild omitted overall_budget and wiped it.
      await income(state, 200, monthsAgo(1));
      expect(state.hasOverallMonthlyBudget, isTrue);
      expect(state.overallMonthlyBudget, closeTo(500, 0.001));
      expect(state.carryoverForSelectedMonth, closeTo(200, 0.001));

      await state.recalculateCarryovers();
      expect(state.hasOverallMonthlyBudget, isTrue);
      expect(state.overallMonthlyBudget, closeTo(500, 0.001));
    });

    test('previousMonthName names the month before the selected one',
        () async {
      final state = await bootstrap();
      const names = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      final prev = DateHelper.subtractMonths(state.selectedMonth, 1);
      expect(state.previousMonthName, names[prev.month - 1]);

      await state.goToMonth(DateTime.utc(2026, 1, 1));
      expect(state.previousMonthName, 'December',
          reason: 'wraps across the year boundary');
    });
  });

  group('DatabaseHelper.calculateNetBalanceBefore', () {
    test('sums strictly before the boundary, for that account only',
        () async {
      final state = await bootstrap();
      final accountId = state.currentAccountId;
      final monthStart = DateHelper.startOfMonth(DateHelper.today());
      final lastMonth = DateHelper.subtractMonths(monthStart, 1);

      // Included: the last day of the previous month, and four months back.
      await income(state, 100, DateHelper.lastDayOfMonth(lastMonth));
      await income(state, 50, monthsAgo(4));
      await expense(state, 20, monthsAgo(2));
      // Excluded: dated ON the boundary (the month itself).
      await expense(state, 30, monthsAgo(0, day: 1));

      final db = DatabaseHelper();
      final before = await db.calculateNetBalanceBefore(accountId, monthStart);
      expect(before.income, closeTo(150, 0.001));
      expect(before.expenses, closeTo(20, 0.001));

      // Another account's rows never leak in.
      final otherId = await seedAccount(
        await db.database,
        name: 'Other',
        isDefault: 0,
      );
      await db.createIncome(Income(
        amount: Decimal.parse('999'),
        category: 'Salary',
        description: 'other',
        date: monthsAgo(1),
        accountId: otherId,
      ));
      final again = await db.calculateNetBalanceBefore(accountId, monthStart);
      expect(again.income, closeTo(150, 0.001));
      final other = await db.calculateNetBalanceBefore(otherId, monthStart);
      expect(other.income, closeTo(999, 0.001));
      expect(other.expenses, closeTo(0, 0.001));
    });
  });
}
