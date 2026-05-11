import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/quick_template_model.dart';
import 'package:budget_tracker/providers/app_state.dart';

import '_test_helpers.dart';

/// FIX Phase 1.1 — useTemplate must not auto-pay the new expense.
///
/// **Bug.** Templates only describe the *charge* — name, amount, category.
/// The previous code (app_state.dart:1594) wrote `amountPaid: template.amountDecimal`
/// into the new `Expense`, marking it fully paid the instant it was created.
/// That broke the AddPaymentDialog flow: tapping a "Coffee $5" chip created
/// a $5 expense with $5 already recorded as paid, so the user couldn't enter
/// a partial / different payment.
///
/// **Fix.** `amountPaid: Decimal.zero` so templated expenses start unpaid,
/// same as manually-entered ones.
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

    // OnboardingService + SettingsHelper read from SharedPreferences;
    // an in-memory empty backing store satisfies them in tests.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  group('Phase 1.1 — useTemplate (expense) starts unpaid', () {
    test('templated expense has amountPaid == 0 and isPaid == false', () async {
      final appState = AppState();
      // loadData() bootstraps a default account + default categories
      // (including 'Food'), which useTemplate's category validation needs.
      await appState.loadData();

      final template = QuickTemplate(
        name: 'Coffee',
        amount: Decimal.parse('5.00'),
        category: 'Food',
        paymentMethod: 'Cash',
        type: 'expense',
        accountId: appState.currentAccountId,
      );

      await appState.useTemplate(template);

      // The new expense lands in this month's cache. There may be no
      // other expenses, so `.last` is the templated one.
      expect(appState.expenses, isNotEmpty);
      final created = appState.expenses.last;
      expect(created.description, 'Coffee');
      expect(created.amount, 5.0);
      expect(
        created.amountPaid,
        0.0,
        reason: 'Templated expenses must not be marked paid on creation',
      );
      expect(
        created.isPaid,
        isFalse,
        reason: 'isPaid is derived from amountPaid >= amount; '
            'amountPaid must start at 0 so AddPaymentDialog can record '
            'a real payment.',
      );
      expect(created.remainingAmount, 5.0);

      appState.dispose();
    });

    test('useTemplate on a missing category falls back without auto-paying',
        () async {
      // Even when the template's category was deleted and useTemplate
      // re-routes to 'Other'/first available, the new expense must still
      // start unpaid.
      final appState = AppState();
      await appState.loadData();

      final template = QuickTemplate(
        name: 'Mystery purchase',
        amount: Decimal.parse('12.34'),
        category: 'NonExistentCategory',
        paymentMethod: 'Card',
        type: 'expense',
        accountId: appState.currentAccountId,
      );

      await appState.useTemplate(template);

      final created = appState.expenses.last;
      expect(created.amountPaid, 0.0);
      expect(created.isPaid, isFalse);

      appState.dispose();
    });
  });
}
