import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/date_helper.dart';

import '_test_helpers.dart';

/// 2026-10 review — every reload (after each write, and on every resume)
/// reset memory to this month and last only. Whoever was viewing an older
/// month saw it go empty after any edit or app switch.
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
  // Well outside the this-month/last-month reload window.
  final viewed = DateTime.utc(today.year, today.month - 4, 1);
  final viewedDay = DateTime.utc(viewed.year, viewed.month, 10);

  Future<AppState> viewingOldMonthWithOneExpense() async {
    final db = await DatabaseHelper().database;
    await seedExpense(
      db,
      accountId: 1,
      date: DateHelper.toDateString(viewedDay),
      amount: 42.0,
      description: 'old month',
    );
    final state = AppState();
    await state.loadData();
    await state.goToMonth(viewed);
    expect(state.getExpensesForSelectedMonth(), hasLength(1));
    return state;
  }

  test('the viewed month survives a write to another month', () async {
    final state = await viewingOldMonthWithOneExpense();

    await state.addExpense(Expense(
      amount: Decimal.parse('5'),
      category: 'Food',
      description: 'today',
      date: today,
      accountId: state.currentAccountId,
    ));

    expect(state.getExpensesForSelectedMonth(), hasLength(1));
    expect(state.totalExpensesThisMonth, 42.0);
    state.dispose();
  });

  test('the viewed month survives a resume reload', () async {
    final state = await viewingOldMonthWithOneExpense();

    await state.loadData(); // what main.dart runs on every resume

    expect(state.getExpensesForSelectedMonth(), hasLength(1));
    state.dispose();
  });
}
