import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    // Phase 6.4 — `updateWidget` now consults `PinSecurityHelper.isPinEnabled`
    // before publishing the payload. `PinSecurityHelper` reads through
    // `SecurePrefs`, which falls back to `SharedPreferences` when the
    // platform channel for `flutter_secure_storage` is unavailable (true
    // in `flutter_test`). Without a SharedPreferences mock the fallback
    // throws `MissingPluginException` and `updateWidget`'s try/catch
    // swallows the whole pipeline — these tests would then see null for
    // every captured payload field.
    SharedPreferences.setMockInitialValues(<String, Object>{});

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

  /// Day 15 of the month [offset] months from now, `yyyy-MM-dd` — far from
  /// month boundaries so the seed is unambiguously inside the window.
  String seedDate({int offset = 0}) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month + offset);
    final y = month.year.toString().padLeft(4, '0');
    final m = month.month.toString().padLeft(2, '0');
    return '$y-$m-15';
  }

  String currentMonthSeedDate() => seedDate();

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
        amountPaid: 42.50,
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
      // Balance is income - paid = 957.50, printed like Home: no sign.
      expect(balanceSaved!, contains('957.50'));
      expect(balanceSaved, isNot(startsWith('-')));
      expect(balanceSaved, isNot(startsWith('+')));
    });

    test('reports a negative balance when expenses exceed income', () async {
      final db = await DatabaseHelper().database;
      await seedExpense(
        db,
        accountId: 1,
        date: currentMonthSeedDate(),
        amount: 500.00,
        amountPaid: 500.00,
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
    });

    test('returns zero totals when no current-month data exists', () async {
      final appState = AppState();
      await HomeWidgetHelper.updateWidget(appState);

      final expensesSaved = savedStringFor('expenses');
      final incomeSaved = savedStringFor('income');
      expect(expensesSaved, contains('0.00'));
      expect(incomeSaved, contains('0.00'));
      // A zero balance prints without a sign.
      expect(savedStringFor('balance'), isNot(startsWith('-')));
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

    test('an unpaid bill does not lower the balance, exactly like Home',
        () async {
      // Home's "Total Balance" is income + carried in - PAID; the bill still
      // shows in Expenses. The widget must print the same two numbers.
      final db = await DatabaseHelper().database;
      await seedIncome(db, accountId: 1, date: seedDate(), amount: 1000.00);
      await seedExpense(db, accountId: 1, date: seedDate(), amount: 200.00);

      await HomeWidgetHelper.updateWidget(AppState());

      expect(savedStringFor('balance'), r'$1,000.00');
      expect(savedStringFor('expenses'), r'$200.00');
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

  group('HomeWidgetHelper.updateWidget — month rollover payload', () {
    test('keys this month and next month by yyyy-MM', () async {
      await HomeWidgetHelper.updateWidget(AppState());

      final now = DateTime.now();
      expect(
        savedStringFor('month_key'),
        HomeWidgetHelper.monthKey(DateTime(now.year, now.month)),
      );
      expect(
        savedStringFor('next_month_key'),
        HomeWidgetHelper.monthKey(DateTime(now.year, now.month + 1)),
      );
    });

    test('publishes next month separately, carrying this month in', () async {
      // Carry-over is on by default, so next month opens with this month's
      // net (1000 - 42.50 = 957.50) and then spends its own 100.
      final db = await DatabaseHelper().database;
      await seedIncome(db, accountId: 1, date: seedDate(), amount: 1000.00);
      await seedExpense(
        db,
        accountId: 1,
        date: seedDate(),
        amount: 42.50,
        amountPaid: 42.50,
      );
      await seedExpense(
        db,
        accountId: 1,
        date: seedDate(offset: 1),
        amount: 100.00,
        amountPaid: 100.00,
      );

      await HomeWidgetHelper.updateWidget(AppState());

      expect(savedStringFor('expenses'), contains('42.50'));
      expect(savedStringFor('next_expenses'), contains('100.00'));
      expect(savedStringFor('next_income'), contains('0.00'));
      expect(savedStringFor('next_balance'), contains('857.50'));
    });

    test('without carry-over, next month stands on its own', () async {
      final db = await DatabaseHelper().database;
      await seedIncome(db, accountId: 1, date: seedDate(), amount: 1000.00);
      await seedExpense(
        db,
        accountId: 1,
        date: seedDate(offset: 1),
        amount: 100.00,
        amountPaid: 100.00,
      );
      final appState = AppState();
      await appState.toggleCarryover(false);
      capturedCalls.clear();

      await HomeWidgetHelper.updateWidget(appState);

      expect(savedStringFor('balance'), contains('1,000.00'));
      expect(savedStringFor('next_balance'), startsWith('-'));
      expect(savedStringFor('next_balance'), contains('100.00'));
    });

    test('redacts both months when a PIN is set', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pin_enabled': true,
      });
      final db = await DatabaseHelper().database;
      await seedIncome(db, accountId: 1, date: seedDate(), amount: 1000.00);

      await HomeWidgetHelper.updateWidget(AppState());

      for (final key in [
        'balance',
        'income',
        'expenses',
        'next_balance',
        'next_income',
        'next_expenses',
      ]) {
        expect(savedStringFor(key), '•••', reason: key);
      }
    });
  });

  group('HomeWidgetHelper.quickAddType', () {
    test('reads the type from the quick-add buttons', () {
      expect(
        HomeWidgetHelper.quickAddType(
          Uri.parse('financeflow://add?type=expense'),
        ),
        'expense',
      );
      expect(
        HomeWidgetHelper.quickAddType(
          Uri.parse('financeflow://add?type=income'),
        ),
        'income',
      );
    });

    test('ignores every other launch', () {
      expect(HomeWidgetHelper.quickAddType(null), isNull);
      // The widget body launches with no data at all.
      expect(HomeWidgetHelper.quickAddType(Uri.parse('')), isNull);
      expect(
        HomeWidgetHelper.quickAddType(Uri.parse('financeflow://add')),
        isNull,
      );
      expect(
        HomeWidgetHelper.quickAddType(
          Uri.parse('financeflow://add?type=transfer'),
        ),
        isNull,
      );
      expect(
        HomeWidgetHelper.quickAddType(
          Uri.parse('https://add?type=expense'),
        ),
        isNull,
      );
    });
  });

  group('HomeWidgetHelper.takeQuickAdd', () {
    const launchChannel = MethodChannel('budget_tracker/widget_launch');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launchChannel, null);
    });

    test('decodes the tap MainActivity is holding', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launchChannel, (call) async {
        expect(call.method, 'takeLaunch');
        return 'financeflow://add?type=income';
      });
      expect(await HomeWidgetHelper.takeQuickAdd(), 'income');
    });

    test('is null when no tap is pending', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launchChannel, (call) async => null);
      expect(await HomeWidgetHelper.takeQuickAdd(), isNull);
    });

    test('is null, not an error, without a host activity', () async {
      // No mock handler: the call fails with MissingPluginException.
      expect(await HomeWidgetHelper.takeQuickAdd(), isNull);
    });
  });

  group('HomeWidgetHelper formatting', () {
    test('monthKey zero-pads to yyyy-MM', () {
      expect(HomeWidgetHelper.monthKey(DateTime(2026, 3)), '2026-03');
      expect(HomeWidgetHelper.monthKey(DateTime(2026, 12)), '2026-12');
    });

    test('formatBalance never prints a negative zero', () {
      expect(HomeWidgetHelper.formatBalance(-0.001, r'$', 'USD'), r'$0.00');
      expect(HomeWidgetHelper.formatBalance(-12.5, r'$', 'USD'), r'-$12.50');
      expect(HomeWidgetHelper.formatBalance(12.5, r'$', 'USD'), r'$12.50');
    });
  });
}
