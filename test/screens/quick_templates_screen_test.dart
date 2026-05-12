import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/quick_templates_screen.dart';
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
}
