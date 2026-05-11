import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/providers/app_state.dart';

import '_test_helpers.dart';

/// FIX Phase 1.2 — `_pruneDistantMonths` must never evict the current month.
///
/// **Bug.** The pruner protected the current month with
/// `if (key != currentMonthKey)`, but the two sides used different
/// formats:
///
/// - `_monthKey(date)` (used to populate `_loadedExpenseMonths`)
///   returned `${date.year}-${date.month}` → `2026-5` (no zero pad).
/// - The local in `_pruneDistantMonths` did
///   `${now.year}-${now.month.toString().padLeft(2, '0')}` → `2026-05`.
///
/// `2026-5 != 2026-05`, so the guard never fired and the current month
/// got LRU-evicted along with the rest once memory crossed
/// `_maxMonthsInMemory` (6). Users with deep history would see the
/// home-screen totals momentarily show zero or stale data.
///
/// **Fix.** Build the local key with `_monthKey(now)` so the two sides
/// agree.
void main() {
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  test('current month survives _pruneDistantMonths even with many months loaded',
      () async {
    // Opening DatabaseHelper auto-seeds a default account at id=1
    // ("Main Account"). Use that account for every seeded row so the
    // expenses match what loadData()'s `_currentAccount` resolves to.
    final now = DateTime.now();
    final db = await DatabaseHelper().database;
    const accountId = 1;

    String dateStr(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    // Seed a distinctive expense in the *current* month so we can
    // detect whether it survives pruning.
    await seedExpense(
      db,
      accountId: accountId,
      date: dateStr(now),
      amount: 42.0,
      description: 'CURRENT_MONTH_SENTINEL',
    );

    // Seed expenses across 10 distinct historical months so that
    // loading them all forces eviction past _maxMonthsInMemory (6).
    for (var i = 1; i <= 10; i++) {
      final past = DateTime(now.year, now.month - i, 15);
      await seedExpense(
        db,
        accountId: accountId,
        date: dateStr(past),
        amount: 1.0,
        description: 'historical_$i',
      );
    }

    final appState = AppState();
    await appState.loadData();

    // The current month is auto-loaded by loadData. Now request each
    // historical month, which exceeds the cap and triggers
    // _pruneDistantMonths on every call after the 6th.
    for (var i = 1; i <= 10; i++) {
      final past = DateTime(now.year, now.month - i, 15);
      await appState.ensureMonthLoaded(past);
    }

    // The sentinel from the current month MUST still be in the raw
    // in-memory cache. Pre-fix, the format mismatch made the
    // current-month key unprotected and pruning could evict its rows
    // from `_expenses`. We probe `allExpenses` (no _selectedMonth filter,
    // no internal hash cache) so a green pre-fix run is impossible.
    final stillThere = appState.allExpenses
        .any((e) => e.description == 'CURRENT_MONTH_SENTINEL');
    expect(
      stillThere,
      isTrue,
      reason: 'Current month must never be pruned. If this fails, the '
          '`currentMonthKey` format does not match `_monthKey(...)`.',
    );

    appState.dispose();
  });
}
