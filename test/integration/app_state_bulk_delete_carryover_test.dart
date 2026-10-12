import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/date_helper.dart';

import '_test_helpers.dart';

/// 2026-10 review — deleting a category's transactions removes rows from
/// earlier months too, which changes the balance carried into this one. The
/// carry-over was not recomputed, so Home showed the old balance until the
/// next resume.
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

  test('bulk-deleting a category refreshes the carried-in balance', () async {
    final db = await DatabaseHelper().database;
    final today = DateHelper.today();
    final lastMonth15 = DateHelper.toDateString(
      DateTime.utc(today.year, today.month - 1, 15),
    );
    await seedIncome(db, accountId: 1, date: lastMonth15, amount: 100.0);
    await seedExpense(
      db,
      accountId: 1,
      date: lastMonth15,
      amount: 40.0,
      category: 'Food',
    );

    final state = AppState();
    await state.loadData();
    expect(state.carryoverForSelectedMonth, 60.0);

    await state.bulkDeleteTransactionsByCategory('Food', 'expense');

    expect(state.carryoverForSelectedMonth, 100.0);
    state.dispose();
  });
}
