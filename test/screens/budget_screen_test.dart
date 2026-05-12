import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/budget_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_panel.dart';
import 'package:budget_tracker/widgets/luminous/glass_progress_bar.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Phase 5.3 — Budgets & Planning widget tests.
///
/// Covers the spec acceptance criteria for B.3:
///   * Top app bar renders "Budgets" via [GlassTopAppBar].
///   * Empty state is wrapped in a [GlassPanel] when no budgets exist for
///     the selected month.
///   * Add-budget [FloatingActionButton] is present.
///   * [GlassProgressBar] is the progress primitive used in the budget
///     list (verified by the screen importing + composing it — the
///     component-level visual states are already exercised in
///     test/widgets/luminous/luminous_components_smoke_test.dart).
///
/// Per-budget state tests (under/at-100/over) are deferred to D.6 hero
/// widget tests where seeded `AppState` data through FFI gives an
/// integration-shaped guarantee. Here we focus on the screen-composition
/// contract: empty state renders, GlassTopAppBar/GlassPanel show up, FAB
/// is wired.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
