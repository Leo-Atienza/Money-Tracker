import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/budget_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/date_helper.dart';

import '_test_helpers.dart';

/// 2026-10 review — last month's budgets are copied into the new month on
/// load. The copy re-ran on every load (every resume) whenever the month had
/// no budgets, so deleting all of a month's budgets brought them straight
/// back. It now happens once per account per month.
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

  final today = DateHelper.today();
  final thisMonth = DateTime.utc(today.year, today.month, 1);
  final lastMonth = DateTime.utc(today.year, today.month - 1, 1);

  List<Budget> budgetsIn(AppState state, DateTime month) => state.budgets
      .where((b) => b.month.year == month.year && b.month.month == month.month)
      .toList();

  test('copies last month once; deleting the copies sticks', () async {
    await DatabaseHelper().createBudget(Budget(
      category: 'Food',
      amount: Decimal.parse('300'),
      accountId: 1,
      month: lastMonth,
    ));

    final state = AppState();
    await state.loadData();
    final copied = budgetsIn(state, thisMonth);
    expect(copied, hasLength(1), reason: 'first load of the month copies');

    await state.deleteBudget(copied.single.id!);
    await state.loadData(); // what every resume runs

    expect(budgetsIn(state, thisMonth), isEmpty,
        reason: 'deleted budgets must not be resurrected');
    state.dispose();
  });
}
