import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/add_payment_dialog.dart';
import 'package:budget_tracker/screens/analytics_screen.dart';
import 'package:budget_tracker/screens/budget_screen.dart';
import 'package:budget_tracker/screens/history/history_screen.dart';
import 'package:budget_tracker/screens/home_screen.dart';
import 'package:budget_tracker/screens/pin_setup_screen.dart';
import 'package:budget_tracker/screens/pin_unlock_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';
import '_large_text.dart';

/// S22 (audit Open, UI row): every main screen at 360dp wide with the text
/// scaled 1.3x, measured in the app's real typeface. Each one overflowed on
/// the emulator before (Home's Expenses tile by 15px, History's subtitle by
/// 28px, Analytics' trends header by 51px, the PIN pads' bottom row by 55px,
/// Budgets squeezing its title to "Bu…"). An overflow fails the test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  late Map<String, String> secureStore;

  setUpAll(loadAppFont);

  setUp(() async {
    secureStore = <String, String>{};
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      final key = (call.arguments as Map)['key'] as String?;
      return call.method == 'read' ? secureStore[key] : null;
    });
    messenger.setMockMethodCallHandler(homeWidgetChannel, (_) async => true);
    messenger.setMockMethodCallHandler(notifChannel, (_) async => null);
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => '.dart_tool/test_path_provider',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
    messenger.setMockMethodCallHandler(homeWidgetChannel, null);
    messenger.setMockMethodCallHandler(notifChannel, null);
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
  });

  Future<AppState> seededState(WidgetTester tester) async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      // An unpaid cash bill: the History tile's longest subtitle (category,
      // method chip, date, amount left).
      await state.addExpense(Expense(
        amount: Decimal.parse('15'),
        category: 'Bills',
        description: 'Reminder test bill',
        date: DateTime.now(),
        accountId: state.currentAccountId,
        paymentMethod: 'Cash',
      ));
      // Income for the trends chart (it shows an empty state without data).
      await state.addIncome(Income(
        amount: Decimal.parse('120'),
        category: 'Salary',
        description: 'Salary income',
        date: DateTime.now(),
        accountId: state.currentAccountId,
      ));
    });
    return state;
  }

  Future<void> pumpCompact(
    WidgetTester tester,
    Widget screen, {
    AppState? state,
  }) async {
    await tester.binding.setSurfaceSize(compactPhone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final app = MaterialApp(
      theme: buildLuminousTheme(
        brightness: Brightness.light,
        appColorsExtension: AppColors.fromBrightness(Brightness.light),
      ),
      builder: largeTextBuilder,
      home: screen,
    );
    await tester.pumpWidget(
      state == null
          ? app
          : ChangeNotifierProvider<AppState>.value(value: state, child: app),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 900));
  }

  testWidgets('Home', (tester) async {
    await pumpCompact(tester, const HomeScreen(),
        state: await seededState(tester));
    expect(find.text('Expenses'), findsWidgets);
  });

  testWidgets('History, with an unpaid cash bill', (tester) async {
    await pumpCompact(tester, const HistoryScreen(),
        state: await seededState(tester));
    expect(find.text('Reminder test bill'), findsOneWidget);
    // The tab labels show whole (Tab(text:) faded "Expenses" out).
    for (final label in ['All', 'Expenses', 'Income']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5),
        reason: '"$label" is cut off',
      );
    }
    // ...and never grow past the tab style ("All" fits, so it stays 1:1).
    final all = tester.renderObject<RenderBox>(find.text('All'));
    expect(all.localToGlobal(Offset(all.size.width, 0)).dx -
            all.localToGlobal(Offset.zero).dx,
        closeTo(all.size.width, 0.5));
  });

  testWidgets('Analytics', (tester) async {
    await pumpCompact(tester, const AnalyticsScreen(),
        state: await seededState(tester));
    // The trends card loads its six months from the database (real async,
    // one query per step): let it settle before looking for its header.
    for (var i = 0;
        i < 40 &&
            find
                .text('6-MONTH TRENDS', skipOffstage: false)
                .evaluate()
                .isEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Below the fold on a short phone: scroll it in (and built) first.
    await tester.scrollUntilVisible(
      find.text('6-MONTH TRENDS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('6-MONTH TRENDS'), findsOneWidget);
  });

  testWidgets('Budgets keeps its title', (tester) async {
    await pumpCompact(tester, const BudgetScreen(),
        state: await seededState(tester));
    expect(find.text('Budgets'), findsOneWidget);
    expect(
      tester.renderObject<RenderParagraph>(find.text('Budgets'))
          .didExceedMaxLines,
      isFalse,
      reason: 'the month navigator no longer squeezes it to "Bu…"',
    );
  });

  testWidgets('Add payment, a seven-figure bill (IDR-size amounts)', (tester) async {
    final state = await seededState(tester);
    final bill = Expense(
      id: 1,
      amount: Decimal.parse('1500000.00'),
      category: 'Bills',
      description: 'Quarterly insurance premium',
      date: DateTime.now(),
      accountId: state.currentAccountId,
      amountPaid: Decimal.parse('250000.00'),
      paymentMethod: 'Cash',
    );
    await pumpCompact(
      tester,
      Scaffold(body: AddPaymentDialog(expense: bill)),
      state: state,
    );
    expect(find.text('PAID'), findsOneWidget);
  });

  testWidgets('PIN setup: the whole pad is reachable', (tester) async {
    await pumpCompact(tester, const PinSetupScreen());
    await tester.ensureVisible(find.text('0'));
    await tester.pump();
    expect(find.text('0').hitTestable(), findsOneWidget);
  });

  testWidgets('PIN unlock: the whole pad is reachable', (tester) async {
    secureStore['pin_enabled'] = 'true';
    secureStore['app_pin_hash'] = 'pbkdf2_sha256\$100000\$c2FsdA==\$a2V5\$4';
    await pumpCompact(tester, const PinUnlockScreen());
    await tester.ensureVisible(find.text('0'));
    await tester.pump();
    expect(find.text('0').hitTestable(), findsOneWidget);
  });
}
