import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/home_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 5.8 — Home dashboard polish widget tests.
///
/// The Phase 1.7 perf-gate test at test/lint/glass_blur_perf_test.dart
/// already pins the RepaintBoundary placement structurally (via source-
/// scanning). These widget-level tests complement that:
///   * Confirms the "FinanceFlow" brand label renders in the header strip.
///   * Confirms no [FloatingActionButton] is present (the bottom-nav Add
///     tab is now the entry point per Phase 5).
///   * Confirms the empty-state messaging is shown when no expenses exist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const accessibilityChannel = MethodChannel('flutter/accessibility');
  const homeWidgetChannel = MethodChannel('home_widget');

  setUp(() {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (_) async => null);
    messenger.setMockMethodCallHandler(accessibilityChannel, (_) async => null);
    messenger.setMockMethodCallHandler(homeWidgetChannel, (_) async => null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
    messenger.setMockMethodCallHandler(accessibilityChannel, null);
    messenger.setMockMethodCallHandler(homeWidgetChannel, null);
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
}
