import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/category_manager_screen.dart';
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
}
