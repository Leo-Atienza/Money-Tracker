import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/budget_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_panel.dart';
import 'package:budget_tracker/widgets/luminous/glass_progress_bar.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.3 — Budgets & Planning widget tests.
///
/// **Composition smoke** (the first group): the spec acceptance criteria
/// for B.3 — top app bar title, empty state in a GlassPanel, add-budget
/// FAB, GlassProgressBar component contract.
///
/// **Seeded behavioural states** (the second group, Stage D.2): with a
/// real FFI-backed [AppState] this exercises the three colour zones the
/// production screen draws (under-budget at 25 %, at-100 %, over-budget
/// at 130 %). The progress bar visually clamps at 100 % but reports the
/// raw percentage in semantics so screen readers announce 130 %.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

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

  Future<void> pumpHarness(
    WidgetTester tester, {
    AppState? appState,
    Size surface = const Size(420, 1400),
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
          home: const BudgetScreen(),
        ),
      ),
    );
  }

  testWidgets('GlassTopAppBar renders "Budgets" title with month navigator',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Budgets'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('empty state renders inside a GlassPanel when no budgets',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    // The empty-state helper-text changes with the current month name,
    // but the "No budgets for ..." prefix is stable.
    expect(
      find.textContaining('No budgets for'),
      findsOneWidget,
      reason: 'Expected empty-state heading to render before any budget '
          'is added.',
    );
    expect(
      find.text('Set spending limits for categories to track and control '
          'your expenses'),
      findsOneWidget,
    );
    expect(
      find.text('Tap here or + to create your first budget'),
      findsOneWidget,
    );

    // Empty state should be wrapped in a GlassPanel (the Luminous redesign
    // surface).
    final glassPanel = find.ancestor(
      of: find.textContaining('No budgets for'),
      matching: find.byType(GlassPanel),
    );
    expect(glassPanel, findsAtLeastNWidgets(1));
  });

  testWidgets('add-budget FAB is present and labeled',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);

    // Semantics label preserved from prior implementation.
    expect(
      tester.widget<FloatingActionButton>(fab).tooltip,
      'Add budget',
    );
  });

  testWidgets('GlassProgressBar component is exported and composes correctly',
      (tester) async {
    // Sanity check that the screen's progress primitive is available and
    // animates fill while reporting raw value in semantics. This is the
    // contract the BudgetScreen relies on for over-budget cases (115%, 130%).
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLuminousTheme(
          brightness: Brightness.light,
          appColorsExtension: AppColors.fromBrightness(Brightness.light),
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: GlassProgressBar(
              progress: 1.3,
              semanticLabel: 'Groceries over budget',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(GlassProgressBar), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(GlassProgressBar)).value,
      '130%',
    );
  });

  // -------------------------------------------------------------------------
  // Stage D.2 — seeded-data per-budget state assertions.
  //
  // The three colour zones the screen draws ride off a single mutator chain:
  //   appState.loadData() → addExpense(...) → setBudget(category, amount).
  // After that, the GlassProgressBar in the BudgetScreen carries the raw
  // percentage in its semantics value (clamped visually at 100 %).
  //
  // **Pump pattern**: AppState.loadData() kicks off a fire-and-forget
  // `_processRecurringInBackground()` (see app_state.dart:354). Calling
  // `pumpAndSettle()` waits for that pipeline to drain and never settles,
  // so we drain it inside `tester.runAsync()` before pumping the widget,
  // then `pump()` with a bounded duration (no `pumpAndSettle`).
  //
  // **Why the wider surface (800 × 1600)** — the screen's
  // `_MonthlySummaryCard` packs an Income/Expenses row that overflows
  // the default test surface (420 × 1400). The seeded tests adopt the
  // same 800 × 1600 surface the AddTransaction harness uses for the same
  // reason. A narrower surface fails with `RenderFlex overflowed` and
  // FlutterTest records that as an unhandled exception.
  //
  // **Why we filter `Icons.warning` by ancestor** — the screen also draws
  // an `Icons.warning` inside the projected-balance Row when the projected
  // end-of-month balance dips negative (income $0 – spent $50 = –$50). That
  // is independent of the per-budget colour zone we're asserting, so we
  // scope icon expectations to within the per-budget `GlassPanel` card.
  // -------------------------------------------------------------------------

  Future<AppState> seedBudgetState(
    WidgetTester tester, {
    required double budgetAmount,
    required double spentAmount,
    String category = 'Food',
  }) async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      await state.addExpense(
        Expense(
          amount: Decimal.parse(spentAmount.toString()),
          category: category,
          description: 'seed',
          date: DateTime.now(),
          accountId: state.currentAccountId,
        ),
      );
      await state.setBudget(category, budgetAmount);
      // Let the fire-and-forget recurring processor in loadData() drain
      // so subsequent `pump()` calls aren't racing against it.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    return state;
  }

  Future<void> pumpAndDrain(WidgetTester tester) async {
    // One real frame to mount, then advance enough to clear FadeInOnLoad
    // (200 ms) and BounceAnimation tickers without waiting for the
    // unsettleable recurring processor.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Finds the icon(s) inside the per-budget GlassPanel card for [category]
  /// — i.e. excluding the projected-balance and overall-summary icons.
  Finder iconsInBudgetCard(IconData icon, String category) {
    return find.descendant(
      of: find.ancestor(
        of: find.text(category.toUpperCase()),
        matching: find.byType(GlassPanel),
      ),
      matching: find.byIcon(icon),
    );
  }

  testWidgets(
    'seeded under-budget (25 %) renders green status + raw 25 % semantics',
    (tester) async {
      final state = await seedBudgetState(
        tester,
        budgetAmount: 200,
        spentAmount: 50,
      );
      await pumpHarness(
        tester,
        appState: state,
        surface: const Size(800, 1600),
      );
      await pumpAndDrain(tester);

      // Budget header should show "$50 / $200".
      expect(find.text(r'$50 / $200'), findsOneWidget);

      // GlassProgressBar present and reports 25 % raw value via semantics.
      final progress = find.byType(GlassProgressBar);
      expect(progress, findsOneWidget);
      expect(tester.getSemantics(progress).value, '25%');

      // Per-budget icon (scoped to the Food card) is the check-circle for
      // the under-budget colour zone.
      expect(iconsInBudgetCard(Icons.check_circle, 'Food'), findsOneWidget);
      expect(iconsInBudgetCard(Icons.error, 'Food'), findsNothing);
      expect(iconsInBudgetCard(Icons.warning, 'Food'), findsNothing);
    },
  );

  testWidgets(
    'seeded at-100 % budget renders error icon + 100 % semantics',
    (tester) async {
      final state = await seedBudgetState(
        tester,
        budgetAmount: 200,
        spentAmount: 200,
      );
      await pumpHarness(
        tester,
        appState: state,
        surface: const Size(800, 1600),
      );
      await pumpAndDrain(tester);

      expect(find.text(r'$200 / $200'), findsOneWidget);

      final progress = find.byType(GlassProgressBar);
      expect(progress, findsOneWidget);
      expect(tester.getSemantics(progress).value, '100%');

      // ≥ 95 % flips to the error/red status zone in the Food card.
      expect(iconsInBudgetCard(Icons.error, 'Food'), findsOneWidget);
    },
  );

  testWidgets(
    'seeded over-budget (130 %) renders error icon + raw 130 % semantics '
    'even though the visual bar clamps at 100 %',
    (tester) async {
      final state = await seedBudgetState(
        tester,
        budgetAmount: 200,
        spentAmount: 260,
      );
      await pumpHarness(
        tester,
        appState: state,
        surface: const Size(800, 1600),
      );
      await pumpAndDrain(tester);

      expect(find.text(r'$260 / $200'), findsOneWidget);

      final progress = find.byType(GlassProgressBar);
      expect(progress, findsOneWidget);
      // Raw value preserved for screen readers; visual fill clamps at 100 %.
      expect(tester.getSemantics(progress).value, '130%');

      // ≥ 95 % → error status icon in the Food card.
      expect(iconsInBudgetCard(Icons.error, 'Food'), findsOneWidget);
    },
  );

  testWidgets(
    'multiple budgets render side-by-side, one per GlassPanel card',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await state.addExpense(Expense(
          amount: Decimal.parse('50'),
          category: 'Food',
          description: 'lunch',
          date: DateTime.now(),
          accountId: state.currentAccountId,
        ));
        await state.addExpense(Expense(
          amount: Decimal.parse('120'),
          category: 'Transport',
          description: 'gas',
          date: DateTime.now(),
          accountId: state.currentAccountId,
        ));
        await state.setBudget('Food', 200);
        await state.setBudget('Transport', 100);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpHarness(
        tester,
        appState: state,
        surface: const Size(800, 1600),
      );
      await pumpAndDrain(tester);

      // Two budget cards visible (one per category).
      expect(find.text('FOOD'), findsOneWidget);
      expect(find.text('TRANSPORT'), findsOneWidget);
      expect(find.byType(GlassProgressBar), findsNWidgets(2));

      // Transport is at 120 %, Food at 25 %. Both progress bars carry their
      // raw percentage in semantics.
      final progressBars = tester.widgetList<GlassProgressBar>(
        find.byType(GlassProgressBar),
      );
      final progressValues = progressBars.map((p) => p.progress).toSet();
      // 50/200 = 0.25, 120/100 = 1.2.
      expect(progressValues, containsAll(<double>[0.25, 1.2]));

      // Per-card icon colour zones — Food check_circle, Transport error.
      expect(iconsInBudgetCard(Icons.check_circle, 'Food'), findsOneWidget);
      expect(iconsInBudgetCard(Icons.error, 'Transport'), findsOneWidget);
    },
  );
}
