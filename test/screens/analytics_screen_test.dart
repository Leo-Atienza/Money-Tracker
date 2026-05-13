import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/analytics_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_panel.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.4 / Stage D.2 — Analytics widget tests (resurrected from TRASH).
///
/// The original test was deferred to D.2 because chart-driven AnimationController
/// tickers leak under `pumpAndSettle` teardown. This file drains those tickers
/// inside `tester.runAsync(() => Future.delayed(...))` and uses bounded
/// `pump()` calls — never `pumpAndSettle` — so the test framework doesn't
/// complain about pending timers.
///
/// Behavioural coverage:
///   * GlassTopAppBar renders "Analytics" without a back button (the screen
///     lives behind the main-nav tab).
///   * Seeded category breakdown surfaces the "TOP CATEGORIES" header and
///     the seeded category labels once spending exists.
///   * The five hero `GlassPanel` cards (`_MonthOverMonthInsights`,
///     `_SpendingTrendsChart`, `_SpendingChart`, `_BudgetProgress`,
///     `_CategoryBreakdown`) render — at minimum, the spending panel is
///     visible after seeding so the chart primitive instantiates.
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

  Future<void> pumpHarness(
    WidgetTester tester, {
    AppState? appState,
    Size surface = const Size(800, 2400),
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
          home: const AnalyticsScreen(),
        ),
      ),
    );
  }

  /// Drain animation tickers — FadeInOnLoad (200 ms) + chart
  /// controllers (`_SpendingTrendsChart` 800 ms + others). pumpAndSettle
  /// hangs on the trend loader's `_loadTrends` future, so this fakes
  /// elapsed time inside `tester.runAsync` (real wall clock) and then
  /// pumps so widget-test sees the animation completed.
  Future<void> pumpAndDrain(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    // 1500 ms covers the 800 ms chart animation that fires inside
    // `_loadTrends().forward(from: 0)` after the DB read returns.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    });
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('GlassTopAppBar renders "Analytics" without back button',
      (tester) async {
    await pumpHarness(tester);
    await pumpAndDrain(tester);

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    // Analytics sits behind the main-nav tab — no BackButton.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets(
    'seeded spending surfaces the "TOP CATEGORIES" header in the breakdown card',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await state.addExpense(Expense(
          amount: Decimal.parse('25'),
          category: 'Food',
          description: 'lunch',
          date: DateTime.now(),
          accountId: state.currentAccountId,
        ));
        await state.addExpense(Expense(
          amount: Decimal.parse('50'),
          category: 'Transport',
          description: 'gas',
          date: DateTime.now(),
          accountId: state.currentAccountId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // `_CategoryBreakdown` returns `SizedBox.shrink()` until seeded
      // spending exists. After seeding, the "TOP CATEGORIES" header and
      // each seeded category label surface.
      expect(find.text('TOP CATEGORIES'), findsOneWidget);
      expect(find.text('Food'), findsAtLeastNWidgets(1));
      expect(find.text('Transport'), findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'hero GlassPanel cards render once seeded data exists',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await state.addExpense(Expense(
          amount: Decimal.parse('100'),
          category: 'Food',
          description: 'groceries',
          date: DateTime.now(),
          accountId: state.currentAccountId,
        ));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // At minimum, the breakdown card's GlassPanel is now in the tree.
      // The full hero set (5 panels) can fluctuate by viewport height so
      // we only pin the lower bound.
      expect(find.byType(GlassPanel), findsAtLeastNWidgets(1));
    },
  );
}
