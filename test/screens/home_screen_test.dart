import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/models/income_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/home_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.8 — Home dashboard polish widget tests.
///
/// **Composition smoke** (the first group): Phase 1.7 perf-gate already pins
/// the RepaintBoundary placement structurally via test/lint/glass_blur_perf_test.dart;
/// these widget-level tests complement that —
///   * "FinanceFlow" brand label renders in the header strip.
///   * No [FloatingActionButton] (the bottom-nav Add tab owns this).
///   * Empty-state messaging shows when no expenses exist.
///
/// **Seeded behavioural states** (Stage D.2): with a real FFI-backed
/// [AppState] this exercises the Financial Summary Card totals, the
/// Recent Transactions list, and the section header — the three regions
/// users see most often on cold launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const accessibilityChannel = MethodChannel('flutter/accessibility');
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
    messenger.setMockMethodCallHandler(accessibilityChannel, (_) async => null);
    messenger.setMockMethodCallHandler(homeWidgetChannel, (_) async => null);
    messenger.setMockMethodCallHandler(notifChannel, (_) async => null);
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => '.dart_tool/test_path_provider',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(secureChannel, null);
    messenger.setMockMethodCallHandler(accessibilityChannel, null);
    messenger.setMockMethodCallHandler(homeWidgetChannel, null);
    messenger.setMockMethodCallHandler(notifChannel, null);
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    AppState? appState,
    Size surface = const Size(800, 1600),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = appState ?? AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: const HomeScreen(),
        ),
      ),
    );
  }

  testWidgets('header strip renders "FinanceFlow" brand label',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();
    expect(find.text('FinanceFlow'), findsOneWidget);
  });

  testWidgets('no FloatingActionButton on Home (bottom-nav Add tab owns this)',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();
    expect(
      find.byType(FloatingActionButton),
      findsNothing,
      reason: 'Phase 5 moved the Add entry point to the bottom-nav Add '
          'tab; no FAB should appear on Home.',
    );
  });

  testWidgets('empty state messaging renders when no expenses',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(
      find.text('No transactions this month'),
      findsOneWidget,
      reason: 'Empty AppState should yield the empty-state placeholder.',
    );
    expect(find.text('Tap to add'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Stage D.2 — seeded-data Home screen assertions.
  //
  // AppState.loadData() launches a fire-and-forget background recurring
  // processor (app_state.dart:354). pumpAndSettle() would wait forever
  // for it; we drain seeding inside tester.runAsync() then pump() with
  // a bounded duration.
  // -------------------------------------------------------------------------

  Future<AppState> seedHomeState(
    WidgetTester tester, {
    List<({double amount, String category, String description})> expenses =
        const [],
    List<({double amount, String category, String description})> incomes =
        const [],
  }) async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      for (final e in expenses) {
        await state.addExpense(Expense(
          amount: Decimal.parse(e.amount.toString()),
          category: e.category,
          description: e.description,
          date: DateTime.now(),
          accountId: state.currentAccountId,
        ));
      }
      for (final i in incomes) {
        await state.addIncome(Income(
          amount: Decimal.parse(i.amount.toString()),
          category: i.category,
          description: i.description,
          date: DateTime.now(),
          accountId: state.currentAccountId,
        ));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    return state;
  }

  Future<void> pumpAndDrain(WidgetTester tester) async {
    await tester.pump();
    // Drain FadeInOnLoad / BounceAnimation tickers without waiting for the
    // unsettleable recurring processor.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets(
    'seeded expenses render in the Recent Transactions list',
    (tester) async {
      final state = await seedHomeState(
        tester,
        expenses: [
          (amount: 25, category: 'Food', description: 'lunch'),
          (amount: 50, category: 'Transport', description: 'gas'),
          (amount: 12, category: 'Food', description: 'coffee'),
        ],
      );
      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // The Recent Transactions header is always present once data exists.
      expect(find.text('Recent Transactions'), findsOneWidget);

      // Each description shows up in the list.
      expect(find.text('lunch'), findsOneWidget);
      expect(find.text('gas'), findsOneWidget);
      expect(find.text('coffee'), findsOneWidget);

      // Empty state should be gone now that expenses exist.
      expect(find.text('No transactions this month'), findsNothing);
    },
  );

  testWidgets(
    'financial summary card shows Income / Expenses / Total balance from seeded data',
    (tester) async {
      final state = await seedHomeState(
        tester,
        expenses: [(amount: 100, category: 'Food', description: 'groceries')],
        incomes: [
          (amount: 3000, category: 'Salary', description: 'paycheck'),
        ],
      );
      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // Section labels are always present in the summary card.
      expect(find.text('Total Balance'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);

      // The seeded transactions feed AppState totals — assert via the
      // public selectors that back the AnimatedCounter widgets so the test
      // doesn't depend on the animation having reached its final frame.
      expect(state.totalIncome, 3000.0);
      expect(state.totalSpent, 100.0);
      // `availableIncomeBalance` is income − what you've already PAID, not
      // income − total billed (see app_state.dart:2207). The seeded
      // expense has amountPaid = 0, so the available balance equals
      // totalIncome here.
      expect(state.availableIncomeBalance, 3000.0);
    },
  );

  testWidgets(
    'header strip shows the selected-month name from AppState',
    (tester) async {
      final state = await seedHomeState(tester);
      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // The month name InkWell is in the header strip — read it from
      // AppState's public API and confirm the screen rendered the same
      // string.
      expect(find.text(state.selectedMonthName), findsOneWidget);
    },
  );

  testWidgets(
    'See All affordance is wired up next to Recent Transactions header',
    (tester) async {
      final state = await seedHomeState(
        tester,
        expenses: [
          (amount: 9, category: 'Food', description: 'snack'),
        ],
      );
      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // SEE ALL is a TextButton sibling of the Recent Transactions header.
      // It's the entry point to HistoryScreen.
      expect(
        find.widgetWithText(TextButton, 'SEE ALL'),
        findsOneWidget,
      );
    },
  );
}
