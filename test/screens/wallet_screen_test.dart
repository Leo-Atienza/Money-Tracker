import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/wallet_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.2 — Wallet widget smoke tests.
///
/// Covers the Luminous-redesign composition contract:
///   * [GlassTopAppBar] renders "Wallet" (no back button — this screen
///     lives behind the main-nav "Wallet" tab).
///   * Add-account [FloatingActionButton] is present.
///
/// Account-card per-state coverage (current vs other, default vs custom)
/// is exercised by the AppState/DatabaseHelper integration tests; here
/// we only verify the Luminous composition.
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
          home: const WalletScreen(),
        ),
      ),
    );
  }

  testWidgets('GlassTopAppBar renders "Wallet" without back button',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);
    // Wallet sits behind the main-nav "Wallet" tab — no BackButton.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('Add-account FAB is present', (tester) async {
    await pumpHarness(tester);
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
