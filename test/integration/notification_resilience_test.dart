import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/providers/app_state.dart';

import '_test_helpers.dart';

/// Group 2 (notifications) resilience coverage.
///
///  * M18 — a throwing notifications plugin must NOT reject `addExpense`
///    after the expense is already committed.
///  * M17 — `_loadDataInternal` now always notifies and exposes a load-error
///    flag instead of silently leaving a stale UI.
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

  late TestDefaultBinaryMessenger messenger;

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null)
      ..setMockMethodCallHandler(secureChannel, (_) async => null)
      ..setMockMethodCallHandler(
        pathProviderChannel,
        (_) async => '.dart_tool/test_path_provider',
      );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() async {
    messenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null)
      ..setMockMethodCallHandler(secureChannel, null)
      ..setMockMethodCallHandler(pathProviderChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  Future<AppState> bootstrap() async {
    final state = AppState();
    await state.loadData();
    return state;
  }

  test('M18: budget-alert plugin failure does not reject addExpense', () async {
    final state = await bootstrap();

    // A budget the expense will blow past, so _checkBudgetAlerts fires.
    await state.setBudget('Food', 10.0);

    // From here, every notifications-plugin call throws — the failure mode
    // M18 guards against (revoked permission / OEM quirk mid-dispatch).
    messenger.setMockMethodCallHandler(
      notifChannel,
      (_) async => throw PlatformException(code: 'boom', message: 'denied'),
    );

    final expense = Expense(
      amount: Decimal.parse('25.00'),
      category: 'Food',
      description: 'lunch',
      date: DateTime.now(),
      accountId: state.currentAccountId,
      amountPaid: Decimal.zero,
      paymentMethod: 'Cash',
    );

    // Must NOT throw, must return the new id, and the expense must persist.
    final id = await state.addExpense(expense);
    expect(id, greaterThan(0));
    expect(
      state.expenses.any((e) => e.description == 'lunch'),
      isTrue,
      reason: 'expense should be committed + visible despite notif failure',
    );
  });

  test('M17: a successful load reports no load error', () async {
    final state = await bootstrap();
    expect(state.hasLoadError, isFalse);
    expect(state.lastLoadError, isNull);
  });

  test('M17: retryLoadData runs cleanly and keeps the error clear', () async {
    final state = await bootstrap();
    var notified = 0;
    state.addListener(() => notified++);

    await state.retryLoadData();

    expect(state.hasLoadError, isFalse);
    // retry clears the flag (notify) then reloads (notify again).
    expect(notified, greaterThan(0));
  });
}
