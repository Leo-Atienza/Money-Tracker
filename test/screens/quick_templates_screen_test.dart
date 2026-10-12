import 'package:budget_tracker/models/quick_template_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/quick_templates_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_panel.dart';
import 'package:budget_tracker/utils/premium_animations.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.9i — Quick Templates widget smoke tests.
///
/// Covers the Luminous-redesign composition contract:
///   * [GlassTopAppBar] renders "Quick Templates" with a back button.
///   * The Add-Template FAB is present and labeled.
///   * Empty state renders inside a [GlassPanel] on a fresh AppState.
///
/// Behavioural flows (use/edit/delete a template) are exercised at the
/// AppState + DatabaseHelper level by integration tests; per-state widget
/// coverage (under-budget, populated lists) is deferred to D.6.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (_) async => null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    Size surface = const Size(420, 1400),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: const QuickTemplatesScreen(),
        ),
      ),
    );
  }

  testWidgets('GlassTopAppBar renders "Quick Templates" with back button',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Quick Templates'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('add-template FAB is present and labeled',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    expect(find.text('Add Template'), findsOneWidget);
  });

  testWidgets('empty state renders inside a GlassPanel on a fresh AppState',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.text('No templates yet'), findsOneWidget);
    final panel = find.ancestor(
      of: find.text('No templates yet'),
      matching: find.byType(GlassPanel),
    );
    expect(panel, findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Session 21 review fixes.
  // -------------------------------------------------------------------------

  /// Drives UI-started async work (the database runs on real I/O) until
  /// [until] holds, bounded, then lets the UI settle.
  Future<void> drainAsync(
    WidgetTester tester, {
    required bool Function() until,
  }) async {
    Future<void> round() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    for (var i = 0; i < 1000 && !until(); i++) {
      await round();
    }
    for (var i = 0; i < 30; i++) {
      await round();
    }
  }

  Future<AppState> seeded(WidgetTester tester, Map<String, String> templates)
      async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      for (final t in templates.entries) {
        await state.addTemplate(QuickTemplate(
          name: t.key,
          amount: Decimal.parse('4.50'),
          category: t.value == 'income' ? 'Salary' : 'Food',
          type: t.value,
          accountId: state.currentAccountId,
        ));
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    return state;
  }

  /// Pushes the screen over a base route, as Settings does, so a stray
  /// extra pop shows up as the screen disappearing.
  Future<void> pumpPushed(
    WidgetTester tester,
    AppState state, {
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: const Scaffold(body: Text('Base route')),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: padding),
          child: const QuickTemplatesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('the template list starts flush under a status-bar inset',
      (tester) async {
    final state = await seeded(tester, {'Coffee': 'expense'});
    await pumpPushed(tester, state, padding: const EdgeInsets.only(top: 48));

    final list = find.byType(ListView);
    final firstCard = find.byType(StaggeredListItem).first;
    expect(
      tester.getTopLeft(firstCard).dy - tester.getTopLeft(list).dy,
      lessThan(1),
    );
  });

  testWidgets('template arrows follow Home: income up, expense down',
      (tester) async {
    final state =
        await seeded(tester, {'Coffee': 'expense', 'Allowance': 'income'});
    await pumpPushed(tester, state);

    Finder iconOf(String name, IconData icon) => find.descendant(
          of: find.ancestor(
            of: find.text(name),
            matching: find.byType(AnimatedPressCard),
          ),
          matching: find.byIcon(icon),
        );
    expect(iconOf('Allowance', Icons.arrow_upward), findsOneWidget);
    expect(iconOf('Coffee', Icons.arrow_downward), findsOneWidget);

    // The type switch in the Add dialog: the selected segment shows a check,
    // the other one its own arrow.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final segments = find.byType(SegmentedButton<String>);
    expect(
      find.descendant(of: segments, matching: find.byIcon(Icons.arrow_upward)),
      findsOneWidget,
      reason: 'Expense selected: the Income segment points up',
    );
    await tester.tap(find.text('Income'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: segments,
        matching: find.byIcon(Icons.arrow_downward),
      ),
      findsOneWidget,
      reason: 'Income selected: the Expense segment points down',
    );
  });

  testWidgets('a double tap on Add saves the template once', (tester) async {
    final state = await seeded(tester, const {});
    await pumpPushed(tester, state);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Morning Coffee',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '3.50',
    );
    final add = find.widgetWithText(TextButton, 'Add');
    await tester.tap(add);
    await tester.tap(add, warnIfMissed: false);
    await drainAsync(tester, until: () => state.quickTemplates.isNotEmpty);

    expect(
      state.quickTemplates.where((t) => t.name == 'Morning Coffee'),
      hasLength(1),
    );
    expect(find.byType(QuickTemplatesScreen), findsOneWidget);
    expect(find.text('Add Template'), findsOneWidget); // the FAB, not a dialog
  });
}
