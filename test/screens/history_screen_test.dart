import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/history/history_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
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
}
