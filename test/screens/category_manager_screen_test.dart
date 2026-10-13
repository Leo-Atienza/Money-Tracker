import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/category_manager_screen.dart';
import 'package:budget_tracker/utils/premium_animations.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_panel.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';
import '_large_text.dart';

/// Phase 5.9g — Category Manager widget smoke tests.
///
/// Covers the Luminous-redesign composition contract:
///   * [GlassTopAppBar] renders "Categories" with a back button.
///   * Empty state wraps "No categories" in a [GlassPanel].
///   * The Add-Category [FloatingActionButton] is present.
///
/// Per-category-tile state (default vs custom, expense vs income) is
/// covered by the integration tests around `AppState.categories`; the
/// widget test here verifies only screen composition.
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
    Size surface = const Size(420, 1600),
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
          home: const CategoryManagerScreen(),
        ),
      ),
    );
  }

  testWidgets('GlassTopAppBar renders "Categories" with back button',
      (tester) async {
    await pumpHarness(tester);
    // Settle the FadeInOnLoad + BounceAnimation tickers so we don't leak
    // timers when the widget tree disposes at end of test.
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('empty state wraps "No categories" in a GlassPanel',
      (tester) async {
    await pumpHarness(tester);
    // Settle the FadeInOnLoad + BounceAnimation tickers so we don't leak
    // timers when the widget tree disposes at end of test.
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('No categories'), findsOneWidget);
    final panel = find.ancestor(
      of: find.text('No categories'),
      matching: find.byType(GlassPanel),
    );
    expect(panel, findsOneWidget);
  });

  testWidgets('Add-Category FAB is present', (tester) async {
    await pumpHarness(tester);
    // Settle the FadeInOnLoad + BounceAnimation tickers so we don't leak
    // timers when the widget tree disposes at end of test.
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.byType(FloatingActionButton), findsOneWidget);
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

  Future<AppState> seeded(WidgetTester tester, {List<String> extra = const []})
      async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      for (final name in extra) {
        await state.addCategory(name, type: 'expense');
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    return state;
  }

  Future<void> pumpWith(
    WidgetTester tester,
    AppState state, {
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: padding),
              child: const CategoryManagerScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  testWidgets('both category lists start flush under a status-bar inset',
      (tester) async {
    final state = await seeded(tester);
    await pumpWith(tester, state, padding: const EdgeInsets.only(top: 48));

    // Without an explicit padding each ListView padded itself with the
    // status-bar inset: an empty band at the top of each panel.
    final lists = find.byType(ListView);
    expect(lists, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      final list = lists.at(i);
      final firstRow = find
          .descendant(of: list, matching: find.byType(StaggeredListItem))
          .first;
      expect(
        tester.getTopLeft(firstRow).dy - tester.getTopLeft(list).dy,
        lessThan(1),
      );
    }
  });

  testWidgets('deleting an unused category deletes it straight away',
      (tester) async {
    final state = await seeded(tester, extra: ['Coffee']);
    await pumpWith(tester, state);

    await tester.tap(find.byTooltip('Delete Coffee category'));
    await drainAsync(
      tester,
      until: () => find.text('Delete Category?').evaluate().isNotEmpty,
    );
    // No transactions: no delete-or-move choice, no destination picker.
    expect(find.text('Select category'), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await drainAsync(
      tester,
      until: () => !state.categories.any((c) => c.name == 'Coffee'),
    );

    expect(state.categories.any((c) => c.name == 'Coffee'), isFalse);
    expect(find.text('Delete Category?'), findsNothing);
    expect(find.text('Please select a category'), findsNothing);
  });

  // S22 device walk: on a 411x914dp phone with the keyboard up, the edit
  // dialog's content ran 22px past its bottom once the error showed.
  testWidgets('the edit dialog fits above the keyboard', (tester) async {
    await loadAppFont();
    final state = await seeded(tester, extra: ['Coffee']);
    // The emulator's frame: 1080x2400 at 420dpi, a 74px status bar and a
    // 63px gesture bar.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 2.625
      ..padding = const FakeViewPadding(top: 74, bottom: 63)
      ..viewPadding = const FakeViewPadding(top: 74, bottom: 63);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: buildLuminousTheme(
            brightness: Brightness.light,
            appColorsExtension: AppColors.fromBrightness(Brightness.light),
          ),
          home: const CategoryManagerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Edit Coffee category'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The keyboard Gboard showed on the device: 882px at 420dpi.
    tester.view
      ..viewInsets = const FakeViewPadding(bottom: 882)
      ..padding = const FakeViewPadding(top: 74);
    await tester.enterText(find.byType(TextField), 'food');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('A category with this name already exists'),
        findsOneWidget);
    // An overflow is reported through FlutterError and fails the test.
  });

  testWidgets('renaming onto another category name is refused, any case',
      (tester) async {
    final state = await seeded(tester, extra: ['Coffee']);
    await pumpWith(tester, state);

    await tester.tap(find.byTooltip('Edit Coffee category'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'food');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await drainAsync(
      tester,
      until: () => find
          .text('A category with this name already exists')
          .evaluate()
          .isNotEmpty,
    );

    // The rename would have cascaded into every Coffee transaction and left
    // two "Food" categories. The reason shows in the dialog: as a SnackBar it
    // sat behind the scrim, dimmed, and Save looked dead.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('A category with this name already exists'),
      ),
      findsOneWidget,
    );
    expect(find.text('Edit Category'), findsOneWidget);
    final names = state.categories
        .where((c) => c.type == 'expense')
        .map((c) => c.name.toLowerCase())
        .toList();
    expect(names.where((n) => n == 'food'), hasLength(1));
    expect(names, contains('coffee'));

    // Editing the name clears the complaint.
    await tester.enterText(find.byType(TextField), 'Coffee beans');
    await tester.pump();
    expect(find.text('A category with this name already exists'), findsNothing);
  });
}
