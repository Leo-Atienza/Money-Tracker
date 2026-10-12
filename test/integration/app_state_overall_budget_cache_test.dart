import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/date_helper.dart';

import '_test_helpers.dart';

/// 2026-10 review — only the 12 newest monthly-balance rows are cached. A
/// carry-over refresh for a month outside the cache rebuilt its row with no
/// overall budget, and the upsert rewrote the whole row: the user's overall
/// budget for that month was silently erased.
void main() {
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null)
      ..setMockMethodCallHandler(secureChannel, (_) async => null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null)
      ..setMockMethodCallHandler(secureChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  test("a carry-over refresh keeps an uncached month's overall budget",
      () async {
    final db = await DatabaseHelper().database;
    final today = DateHelper.today();
    final thisMonth = DateTime.utc(today.year, today.month, 1);

    await db.insert('monthly_balances', {
      'account_id': 1,
      'month': DateHelper.toMonthString(thisMonth),
      'carryover_from_previous': 0.0,
      'overall_budget': 2500.0,
    });
    // Twelve newer rows push this month out of the 12-row cache.
    for (var i = 1; i <= 12; i++) {
      await db.insert('monthly_balances', {
        'account_id': 1,
        'month': DateHelper.toMonthString(
          DateTime.utc(thisMonth.year, thisMonth.month + i, 1),
        ),
        'carryover_from_previous': 0.0,
        'overall_budget': null,
      });
    }
    // Income last month changes this month's carry-over, forcing a write.
    await seedIncome(
      db,
      accountId: 1,
      date: DateHelper.toDateString(
        DateTime.utc(thisMonth.year, thisMonth.month - 1, 15),
      ),
      amount: 100.0,
    );

    final state = AppState();
    await state.loadData(); // refreshes this month's carry-over

    final stored = await DatabaseHelper().getMonthlyBalance(1, thisMonth);
    expect(stored?.carryoverFromPrevious, 100.0);
    expect(stored?.overallBudget, 2500.0);
    expect(state.overallMonthlyBudget, 2500.0);
    state.dispose();
  });
}
