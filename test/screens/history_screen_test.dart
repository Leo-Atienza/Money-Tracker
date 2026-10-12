import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/add_transaction_screen.dart';
import 'package:budget_tracker/screens/history/history_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/loading_skeleton.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.6 / Stage D.2 — `HistoryScreen` seeded widget tests.
///
/// The history feature spans 4 files under `lib/screens/history/`:
/// the screen state itself, the filter bar, the list shell, and the
/// grouping helpers. Each of those has its own unit tests; this file
/// pins the **integrated** view — the tab bar, the empty-state copy,
/// and that seeded expenses + income surface through to the list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (_) async => null);
    messenger.setMockMethodCallHandler(homeWidgetChannel, (_) async => null);
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
    // Intentional: skip `DatabaseHelper.resetForTesting()` — HistoryScreen
    // posts async DB reads through several initState-borrowed futures and
    // closing the DB in tearDown races them. `makeFreshDb()` picks a
    // fresh unique database name per setUp anyway.
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    required AppState state,
    Size surface = const Size(800, 1600),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: const HistoryScreen(),
        ),
      ),
    );
  }

  Future<void> pumpAndDrain(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// Pumps while letting real async work (sqflite) run, until [done] holds
  /// or the attempts run out — the expectations after it report what's off.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  bool shows(String text) => find.text(text).evaluate().isNotEmpty;

  bool loading() => find.byType(TransactionListSkeleton).evaluate().isNotEmpty;

  Future<AppState> seedState(
    WidgetTester tester, {
    List<Expense> expenses = const [],
    List<Income> incomes = const [],
  }) async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      for (final e in expenses) {
        await state.addExpense(e);
      }
      for (final i in incomes) {
        await state.addIncome(i);
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    return state;
  }

  Expense expense(
    AppState state, {
    required double amount,
    required String description,
    String category = 'Food',
    DateTime? date,
  }) {
    return Expense(
      amount: Decimal.parse(amount.toString()),
      category: category,
      description: description,
      date: date ?? DateTime.now(),
      accountId: state.currentAccountId,
    );
  }

  Income income(
    AppState state, {
    required double amount,
    required String description,
    String category = 'Salary',
    DateTime? date,
  }) {
    return Income(
      amount: Decimal.parse(amount.toString()),
      category: category,
      description: description,
      date: date ?? DateTime.now(),
      accountId: state.currentAccountId,
    );
  }

  testWidgets('header renders "History" and the tab bar shows the 3 tabs',
      (tester) async {
    final state = await seedState(tester);
    await pumpHarness(tester, state: state);
    await pumpAndDrain(tester);

    expect(find.text('History'), findsOneWidget);
    // TabBar tabs.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
  });

  testWidgets('empty state messaging renders on a fresh state',
      (tester) async {
    final state = await seedState(tester);
    await pumpHarness(tester, state: state);
    await pumpAndDrain(tester);

    // The empty-state copy contains "No expenses" on the All tab when
    // the screen has nothing to show.
    expect(
      find.textContaining('No '),
      findsAtLeastNWidgets(1),
      reason: 'The empty-state heading should appear somewhere in the '
          'list area.',
    );
  });

  testWidgets(
    'seeded expenses appear in the list with their descriptions',
    (tester) async {
      final state = await seedState(
        tester,
        expenses: [],
      );
      // Use the existing AppState to add typed expenses (descriptions are
      // what the list renders).
      await tester.runAsync(() async {
        await state.addExpense(expense(state,
            amount: 25, description: 'lunch', category: 'Food'));
        await state.addExpense(expense(state,
            amount: 50, description: 'gas', category: 'Transport'));
        await state.addExpense(expense(state,
            amount: 12.5, description: 'coffee', category: 'Food'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      await pumpHarness(tester, state: state);
      await pumpAndDrain(tester);

      // All three descriptions show up on the All tab.
      expect(find.text('lunch'), findsOneWidget);
      expect(find.text('gas'), findsOneWidget);
      expect(find.text('coffee'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the Income tab shows income descriptions and hides expense ones',
    (tester) async {
      final state = await seedState(tester);
      await tester.runAsync(() async {
        await state.addExpense(expense(state,
            amount: 25, description: 'lunch', category: 'Food'));
        await state.addIncome(income(state,
            amount: 3000, description: 'paycheck', category: 'Salary'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      await pumpHarness(tester, state: state);
      await pumpAndDrain(tester);

      // Both visible on the All tab.
      expect(find.text('lunch'), findsOneWidget);
      expect(find.text('paycheck'), findsOneWidget);

      // Tap the Income tab.
      await tester.tap(find.text('Income').first);
      await pumpAndDrain(tester);

      // Now only income shows.
      expect(find.text('paycheck'), findsOneWidget);
      expect(find.text('lunch'), findsNothing);
    },
  );

  testWidgets(
    'state.expenses is filtered by selectedMonth; allExpenses spans months',
    (tester) async {
      final state = await seedState(tester);
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 15);

      await tester.runAsync(() async {
        await state.addExpense(expense(state,
            amount: 25, description: 'this month', date: now));
        await state.addExpense(expense(state,
            amount: 60, description: 'last month', date: lastMonth));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });

      await pumpHarness(tester, state: state);
      await pumpAndDrain(tester);

      // Default view = selected (current) month — only "this month" visible.
      expect(find.text('this month'), findsOneWidget);
      expect(find.text('last month'), findsNothing);

      // But the underlying state knows about both rows.
      expect(state.expenses.length, 1,
          reason: 'state.expenses is filtered by selectedMonth');
      expect(state.allExpenses.length, 2,
          reason: 'state.allExpenses spans months');
    },
  );

  // ---------------------------------------------------------------------------
  // All time / date range / live rows
  // ---------------------------------------------------------------------------

  testWidgets(
    'All time lists every transaction with no search term, and re-reads a '
    'row once it is paid',
    (tester) async {
      final state = await seedState(tester);
      final now = DateTime.now();
      // Last month: in AppState's loaded window, outside the month view.
      await tester.runAsync(() => state.addExpense(expense(state,
          amount: 1000,
          description: 'rent',
          date: DateTime.utc(now.year, now.month - 1, 15))));

      await pumpHarness(tester, state: state);
      await pumpAndDrain(tester);
      expect(find.text('rent'), findsNothing);

      await tester.tap(find.text('All time'));
      await settle(tester, () => shows('rent') && !loading());
      expect(find.text('rent'), findsOneWidget,
          reason: 'All time used to say "No transactions found" without a '
              'search term');
      expect(find.text(r'$1,000.00 left'), findsOneWidget);

      final rent = state.allExpenses.singleWhere((e) => e.description == 'rent');
      await tester.runAsync(() => state.addPayment(rent, 300));
      await settle(tester, () => shows(r'$700.00 left'));
      expect(find.text(r'$700.00 left'), findsOneWidget,
          reason: 'the all-time tile must show the live row, not the snapshot');
      expect(find.text(r'$1,000.00 left'), findsNothing);
      await pumpAndDrain(tester);
    },
  );

  testWidgets(
    'a date range lists its rows without a search term, keeps its first day, '
    'and clearing it re-queries',
    (tester) async {
      final state = await seedState(tester);
      final now = DateTime.now();
      await tester.runAsync(() async {
        await state.addExpense(expense(state,
            amount: 20,
            description: 'first of month',
            date: DateTime.utc(now.year, now.month, 1)));
        await state.addExpense(expense(state,
            amount: 30,
            description: 'last month',
            date: DateTime.utc(now.year, now.month - 1, 15)));
      });

      await pumpHarness(tester, state: state);
      await pumpAndDrain(tester);

      // The picker opens on "this month so far"; keep that range.
      await tester.tap(find.text('Date range'));
      await pumpAndDrain(tester);
      await tester.tap(find.text('Save'));
      await tester.pump();
      await settle(tester, () => shows('first of month') && !loading());
      expect(find.text('first of month'), findsOneWidget,
          reason: 'the range starts on the 1st and must include it');
      expect(find.text('last month'), findsNothing);

      // Clearing the chip drops the range from the rows (All time stays on).
      await pumpAndDrain(tester);
      await tester.tap(find.descendant(
          of: find.byType(FilterChip), matching: find.byIcon(Icons.close)));
      await tester.pump();
      await settle(tester, () => shows('last month') && !loading());
      expect(find.text('first of month'), findsOneWidget);
      expect(find.text('last month'), findsOneWidget);
      await pumpAndDrain(tester);
    },
  );

  testWidgets('a date range picked during a search narrows the search',
      (tester) async {
    final state = await seedState(tester);
    final now = DateTime.now();
    await tester.runAsync(() async {
      await state.addExpense(expense(state,
          amount: 4,
          description: 'coffee now',
          date: DateTime.utc(now.year, now.month, 1)));
      await state.addExpense(expense(state,
          amount: 5,
          description: 'coffee old',
          date: DateTime.utc(now.year, now.month - 1, 15)));
    });

    await pumpHarness(tester, state: state);
    await pumpAndDrain(tester);

    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await settle(tester, () => shows('coffee old') && !loading());
    expect(find.text('coffee now'), findsOneWidget);
    expect(find.text('coffee old'), findsOneWidget);

    await tester.tap(find.text('Date range'));
    await pumpAndDrain(tester);
    await tester.tap(find.text('Save'));
    await tester.pump();
    await settle(tester, () => !shows('coffee old') && !loading());
    expect(find.text('coffee now'), findsOneWidget);
    expect(find.text('coffee old'), findsNothing,
        reason: 'the range used to be stored but never applied to a search');
    await pumpAndDrain(tester);
  });

  testWidgets(
    'switching tabs while All time loads does not leave a skeleton behind',
    (tester) async {
      final state = await seedState(tester);
      await tester.runAsync(() =>
          state.addExpense(expense(state, amount: 10, description: 'lunch')));

      await pumpHarness(tester, state: state);
      await pumpAndDrain(tester);

      // Start the all-time load, then switch tab before it lands: the tab
      // switch cancels the request in flight.
      await tester.tap(find.text('All time'));
      await tester.pump();
      await tester.tap(find.text('Expenses'));
      await tester.pump();
      await settle(tester, () => shows('lunch') && !loading());
      expect(find.byType(TransactionListSkeleton), findsNothing);
      expect(find.text('lunch'), findsOneWidget);

      // And the month view is fine too.
      await tester.tap(find.text('All time'));
      await tester.pump();
      await settle(tester, () => shows('lunch') && !loading());
      expect(find.byType(TransactionListSkeleton), findsNothing);
      expect(find.text('lunch'), findsOneWidget);
      await pumpAndDrain(tester);
    },
  );

  // ---------------------------------------------------------------------------
  // Tabs and filters
  // ---------------------------------------------------------------------------

  testWidgets('swiping to another tab resets the payment filter like a tap',
      (tester) async {
    final state = await seedState(tester);
    await tester.runAsync(() async {
      await state.addExpense(
          expense(state, amount: 40, description: 'unpaid bill'));
      await state.addExpense(Expense(
        amount: Decimal.parse('25'),
        amountPaid: Decimal.parse('25'),
        category: 'Food',
        description: 'paid bill',
        date: DateTime.now(),
        accountId: state.currentAccountId,
      ));
    });

    // Wide enough for the whole chip row, payment chips included.
    await pumpHarness(tester, state: state, surface: const Size(2400, 1600));
    await pumpAndDrain(tester);

    await tester.tap(find.text('Expenses'));
    await pumpAndDrain(tester);
    await tester.tap(find.text('Unpaid'));
    await pumpAndDrain(tester);
    expect(find.text('paid bill'), findsNothing);
    expect(find.text('unpaid bill'), findsOneWidget);

    // A swipe settles the tab index without ever setting indexIsChanging.
    await tester.fling(find.byType(TabBarView), const Offset(400, 0), 1000);
    await pumpAndDrain(tester);
    expect(find.text('Unpaid'), findsNothing,
        reason: 'the payment chips belong to the Expenses tab only');
    expect(find.text('paid bill'), findsOneWidget,
        reason: 'the Unpaid filter must not follow the swipe to All');
    expect(find.text('unpaid bill'), findsOneWidget);
    await pumpAndDrain(tester);
  });

  testWidgets('a category filter counts as a filter in the empty state',
      (tester) async {
    final state = await seedState(tester);
    await tester.runAsync(() => state.addExpense(
        expense(state, amount: 10, description: 'lunch', category: 'Food')));

    await pumpHarness(tester, state: state);
    await pumpAndDrain(tester);

    await tester.tap(find.text('Bills'));
    await pumpAndDrain(tester);
    expect(find.text('No transactions found'), findsOneWidget);
    expect(find.text('Try adjusting your search or filters'), findsOneWidget);
    expect(find.text('Get started by adding your first transaction'),
        findsNothing);
  });

  // ---------------------------------------------------------------------------
  // Tile actions
  // ---------------------------------------------------------------------------

  testWidgets('deleting the last All time row closes the progress dialog',
      (tester) async {
    final state = await seedState(tester);
    final now = DateTime.now();
    await tester.runAsync(() => state.addExpense(expense(state,
        amount: 10,
        description: 'old lunch',
        date: DateTime.utc(now.year, now.month - 1, 15))));

    await pumpHarness(tester, state: state);
    await pumpAndDrain(tester);
    await tester.tap(find.text('All time'));
    await settle(tester, () => shows('old lunch') && !loading());

    await tester.drag(find.text('old lunch'), const Offset(-600, 0));
    await pumpAndDrain(tester);
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await settle(tester, () => shows('Expense moved to trash'));
    await pumpAndDrain(tester);

    expect(find.text('Deleting expense...'), findsNothing,
        reason: 'the row unmounting must not strand the progress dialog');
    expect(find.text('Expense moved to trash'), findsOneWidget);
    expect(find.text('No transactions found'), findsOneWidget);
    await pumpAndDrain(tester);
  });

  testWidgets('Edit Details opens the expense form as a full page',
      (tester) async {
    final state = await seedState(tester);
    await tester.runAsync(() =>
        state.addExpense(expense(state, amount: 10, description: 'lunch')));

    await pumpHarness(tester, state: state);
    await pumpAndDrain(tester);

    await tester.tap(find.text('Edit Details'));
    await pumpAndDrain(tester);

    final form = find.byType(AddTransactionScreen);
    expect(form, findsOneWidget);
    expect(ModalRoute.of(tester.element(form)), isA<PageRoute<dynamic>>(),
        reason: 'not a transparent bottom sheet over the list');

    // Let the form's own database reads (tags) finish before teardown.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await pumpAndDrain(tester);
  });
}
