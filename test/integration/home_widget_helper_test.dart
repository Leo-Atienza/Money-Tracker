import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/home_widget_helper.dart';

import '_test_helpers.dart';

/// FIX Phase 3c — Regression tests for Bug #4.
///
/// Bug #4: `HomeWidgetHelper.updateWidget` previously read current-month
/// totals from `appState.getExpensesForMonth(DateTime.now())`, which
/// scans the in-memory `_expenses` list inside `AppState`. That list
/// is subject to `_pruneDistantMonths` — after the user browsed
/// history and the app was backgrounded, the current month could be
/// evicted, and the widget rendered `0.00` despite the DB holding the
/// real numbers.
///
/// The fix reads directly from the DB via
/// `DatabaseHelper.calculateMonthBalance(accountId, year, month)`.
///
/// These tests mock the `home_widget` plugin MethodChannel so we can
/// capture the exact values the helper would hand off to the native
/// side, then assert they match the DB totals for the current month.
/// A bare `AppState()` is used with an empty in-memory expense list —
/// if the helper ever reverts to reading from `appState.getExpensesForMonth`,
/// the captured values would be zero and these tests would fail.
void main() {
  const channel = MethodChannel('home_widget');
  final capturedCalls = <MethodCall>[];

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    capturedCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      capturedCalls.add(call);
      // home_widget methods all return booleans for save/update and null
      // for the ones we don't exercise here.
      return true;
    });

    await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await DatabaseHelper.resetForTesting();
  });

  /// Helper: find the last value saved under [key] in the captured calls.
  String? savedStringFor(String key) {
    for (final call in capturedCalls.reversed) {
      if (call.method != 'saveWidgetData') continue;
      final args = call.arguments;
      if (args is Map && args['id'] == key) {
        return args['data'] as String?;
      }
    }
    return null;
  }

  bool? savedBoolFor(String key) {
    for (final call in capturedCalls.reversed) {
      if (call.method != 'saveWidgetData') continue;
      final args = call.arguments;
      if (args is Map && args['id'] == key) {
        return args['data'] as bool?;
      }
    }
    return null;
  }

  /// Current month in `yyyy-MM-dd` format, day 15 — far from month
  /// boundaries so the seed is unambiguously inside the window.
  String currentMonthSeedDate() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    return '$y-$m-15';
  }

  group('HomeWidgetHelper.updateWidget — Bug #4 regression', () {
    test('reads current-month totals from DB, not in-memory state', () async {
      // Seed current-month rows directly against the DB. Note that we
      // do NOT call AppState.initialize(), so `appState._expenses` is
      // empty — the old buggy path would see zero, the fixed path sees
      // the DB rows.
      final db = await DatabaseHelper().database;
      await seedExpense(
        db,
        accountId: 1, // _onCreate seeds 'Main Account' with id=1
        date: currentMonthSeedDate(),
        amount: 42.50,
      );
      await seedIncome(
        db,
        accountId: 1,
        date: currentMonthSeedDate(),
        amount: 1000.00,
      );

      final appState = AppState();
      await HomeWidgetHelper.updateWidget(appState);

      // The saved values must reflect the DB rows, not empty in-memory state.
      final expensesSaved = savedStringFor('expenses');
      final incomeSaved = savedStringFor('income');
      final balanceSaved = savedStringFor('balance');

      expect(expensesSaved, isNotNull);
      expect(incomeSaved, isNotNull);
      expect(balanceSaved, isNotNull);

      // Formatted as "USD" → "42.50" / "1,000.00" (no currency symbol
      // in the saved string). Use contains() rather than exact matching
      // so we're resilient to locale nuances.
      expect(expensesSaved!, contains('42.50'));
      expect(incomeSaved!, contains('1,000.00'));
      // Balance is income - expenses = 957.50, rendered positive.
      expect(balanceSaved!, contains('957.50'));
      expect(savedBoolFor('is_positive'), true);
    });

    test('reports a negative balance when expenses exceed income', () async {
      final db = await DatabaseHelper().database;
      await seedExpense(
        db,
        accountId: 1,
        date: currentMonthSeedDate(),
        amount: 500.00,
      );
      await seedIncome(
        db,
        accountId: 1,
        date: currentMonthSeedDate(),
        amount: 100.00,
      );

      final appState = AppState();
      await HomeWidgetHelper.updateWidget(appState);

      // Balance = -400, displayed as "-400.00" via abs() + sign prefix.
      final balanceSaved = savedStringFor('balance');
      expect(balanceSaved, contains('400.00'));
      expect(balanceSaved, startsWith('-'));
      expect(savedBoolFor('is_positive'), false);
    });

    test('returns zero totals when no current-month data exists', () async {
      final appState = AppState();
      await HomeWidgetHelper.updateWidget(appState);

      final expensesSaved = savedStringFor('expenses');
      final incomeSaved = savedStringFor('income');
      expect(expensesSaved, contains('0.00'));
      expect(incomeSaved, contains('0.00'));
      // A zero balance is still reported as positive (balance >= 0).
      expect(savedBoolFor('is_positive'), true);
    });

    test('saves the current month name', () async {
      final appState = AppState();
      await HomeWidgetHelper.updateWidget(appState);

      const monthNames = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final expectedMonth = monthNames[DateTime.now().month - 1];
      expect(savedStringFor('month_name'), expectedMonth);
    });

    test('excludes rows from other accounts (account-scoped query)', () async {
      // Seed a second account and put a big expense on it — it must
      // NOT show up in the default account's widget totals.
      final db = await DatabaseHelper().database;
      final otherAccountId = await seedAccount(db, name: 'Other', isDefault: 0);
      await seedExpense(
        db,
        accountId: otherAccountId,
        date: currentMonthSeedDate(),
        amount: 9999.99,
      );
      await seedExpense(
        db,
        accountId: 1,
        date: currentMonthSeedDate(),
        amount: 5.00,
      );

      final appState = AppState();
      await HomeWidgetHelper.updateWidget(appState);

      // Widget uses appState.currentAccountId which defaults to 1 when
      // no current account is set.
      final expensesSaved = savedStringFor('expenses');
      expect(expensesSaved, contains('5.00'));
      expect(expensesSaved, isNot(contains('9999')));
    });
  });
}
