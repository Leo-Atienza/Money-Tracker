import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/settings_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_list_tile.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 5.1 — Settings & Security widget tests.
///
/// Covers the spec acceptance criteria for B.1:
///   * Top app bar title is "Settings & Security".
///   * All eight Luminous list sections render (Accounts, Appearance,
///     Security, Preferences, Insights, Data & Backup, Notifications,
///     Advanced).
///   * PIN tile reflects current PIN state (enabled vs. disabled).
///   * "FinanceFlow / Made by Leo Atienza" footer renders.
///
/// The dialog/modal helpers (theme picker, currency picker, account picker,
/// reset/delete dialogs) are exercised in their own helper tests; here we
/// only verify the screen composition + the integration with the redesigned
/// PIN section. A tall surface size keeps every sliver in the viewport so
/// off-screen content is part of the widget tree, not lazily skipped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureBacking;
  late TestDefaultBinaryMessenger messenger;

  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    secureBacking = <String, String>{};
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      switch (call.method) {
        case 'read':
          final args = call.arguments as Map;
          return secureBacking[args['key'] as String];
        case 'write':
          final args = call.arguments as Map;
          final key = args['key'] as String;
          final value = args['value'] as String?;
          if (value == null) {
            secureBacking.remove(key);
          } else {
            secureBacking[key] = value;
          }
          return null;
        case 'delete':
          final args = call.arguments as Map;
          secureBacking.remove(args['key'] as String);
          return null;
        case 'readAll':
          return Map<String, String>.from(secureBacking);
        case 'deleteAll':
          secureBacking.clear();
          return null;
        case 'containsKey':
          final args = call.arguments as Map;
          return secureBacking.containsKey(args['key'] as String);
      }
      return null;
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    AppState? appState,
    Size surface = const Size(420, 3200),
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
          home: const SettingsScreen(),
        ),
      ),
    );
  }

  testWidgets('GlassTopAppBar renders "Settings & Security" title',
      (tester) async {
    await pumpHarness(tester);
    // First frame paints the screen and kicks off the async PIN load.
    await tester.pump();

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Settings & Security'), findsOneWidget);
  });

  testWidgets('all eight Luminous sections render with correct headings',
      (tester) async {
    await pumpHarness(tester);
    // Let the async PIN load complete so the Security section flips out
    // of its loading state.
    await tester.pumpAndSettle();

    for (final heading in const [
      'ACCOUNTS',
      'APPEARANCE',
      'SECURITY',
      'PREFERENCES',
      'INSIGHTS',
      'DATA & BACKUP',
      'NOTIFICATIONS',
      'ADVANCED',
    ]) {
      expect(
        find.text(heading),
        findsOneWidget,
        reason: 'Expected section heading "$heading" to render exactly once.',
      );
    }
  });

  testWidgets('PIN section shows "Lock app with PIN" when disabled',
      (tester) async {
    // Empty secureBacking ⇒ PinSecurityHelper.isPinEnabled() resolves false.
    await pumpHarness(tester);
    await tester.pumpAndSettle();

    // Find the App PIN Lock tile and confirm its sublabel.
    expect(find.text('App PIN Lock'), findsOneWidget);
    expect(find.text('Lock app with PIN'), findsOneWidget);

    // No "Change PIN" tile when disabled.
    expect(find.text('Change PIN'), findsNothing);
    expect(
      find.text('App locks after 3 minutes of inactivity'),
      findsNothing,
    );

    // Switch inside the PIN tile should be off. Scope the finder to the
    // App PIN Lock tile so it doesn't collide with the Transaction Colors
    // switch in the Appearance section.
    final pinTile = find.ancestor(
      of: find.text('App PIN Lock'),
      matching: find.byType(GlassListTile),
    );
    expect(pinTile, findsOneWidget);
    final pinSwitch = find.descendant(of: pinTile, matching: find.byType(Switch));
    expect(pinSwitch, findsOneWidget);
    expect(tester.widget<Switch>(pinSwitch).value, isFalse);
  });

  testWidgets('PIN section shows "Enabled (4 digits)" when PIN already set',
      (tester) async {
    // Seed secure storage so isPinEnabled() returns true.
    secureBacking['app_pin_hash'] = 'fake-hash';
    secureBacking['app_pin_salt'] = 'fake-salt';
    secureBacking['pin_enabled'] = 'true';
    secureBacking['pin_length'] = '4';

    await pumpHarness(tester);
    await tester.pumpAndSettle();

    expect(find.text('App PIN Lock'), findsOneWidget);
    expect(find.text('Enabled (4 digits)'), findsOneWidget);
    expect(find.text('Change PIN'), findsOneWidget);
    expect(
      find.text('App locks after 3 minutes of inactivity'),
      findsOneWidget,
    );

    // PIN switch should be on.
    final pinTile = find.ancestor(
      of: find.text('App PIN Lock'),
      matching: find.byType(GlassListTile),
    );
    final pinSwitch = find.descendant(of: pinTile, matching: find.byType(Switch));
    expect(tester.widget<Switch>(pinSwitch).value, isTrue);
  });

  testWidgets('renders "FinanceFlow / Made by Leo Atienza" footer',
      (tester) async {
    await pumpHarness(tester);
    await tester.pumpAndSettle();

    expect(find.text('FinanceFlow'), findsOneWidget);
    expect(find.text('Made by Leo Atienza'), findsOneWidget);
  });
}
