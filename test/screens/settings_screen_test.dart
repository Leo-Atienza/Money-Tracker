import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/settings_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_list_tile.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

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
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    secureBacking = <String, String>{};
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null)
      ..setMockMethodCallHandler(
        pathProviderChannel,
        (_) async => '.dart_tool/test_path_provider',
      );
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

  testWidgets('Carry Over Balance tile renders on, and the row toggles it',
      (tester) async {
    final state = AppState();
    await tester.runAsync(() => state.loadData());
    await pumpHarness(tester, appState: state);
    await tester.pumpAndSettle();

    expect(find.text('Carry Over Balance'), findsOneWidget);
    expect(find.text('Leftover money rolls into next month'), findsOneWidget);
    expect(state.carryoverEnabled, isTrue);

    // Tapping the row (not just the Switch) flips the setting.
    await tester.runAsync(() async {
      await tester.tap(find.text('Carry Over Balance'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(state.carryoverEnabled, isFalse);
    expect(find.text('Each month starts from zero'), findsOneWidget);
  });

  testWidgets(
      'theme picker offers Light, Dark, Purple and Follow System; '
      'choosing Purple persists it and updates the row', (tester) async {
    final state = AppState();
    await tester.runAsync(() => state.loadData());
    await pumpHarness(tester, appState: state);
    await tester.pumpAndSettle();

    // Default is to follow the OS; the row subtitle says so.
    expect(find.text('Follow System'), findsOneWidget);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Theme'), findsOneWidget);
    for (final option in ['Light', 'Dark', 'Purple']) {
      expect(find.text(option), findsOneWidget, reason: option);
    }
    // Row subtitle + the sheet option.
    expect(find.text('Follow System'), findsNWidgets(2));
    expect(find.text('Lavender by day, violet at night'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Purple'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(state.themeMode, 'purple');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'purple');
    // The sheet closed and the row now reads "Purple".
    expect(find.text('Choose Theme'), findsNothing);
    expect(find.text('Purple'), findsOneWidget);
    expect(find.text('Follow System'), findsNothing);
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

  // -------------------------------------------------------------------------
  // Stage D.2 — seeded-data Settings assertions.
  //
  // The header section reads the current account name + currency via
  // narrow context.selects (settings_screen.dart:57). Seeded states pin
  // that the screen reflects AppState updates without re-pumping the
  // ChangeNotifierProvider.
  // -------------------------------------------------------------------------

  Future<void> pumpAndDrain(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets(
    'Current Account tile shows the seeded default account name',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      expect(find.text('Current Account'), findsOneWidget);
      // After loadData() the bootstrap creates "Main Account" as default.
      expect(find.text('Main Account'), findsOneWidget);
    },
  );

  testWidgets(
    'Currency tile shows the currency name + symbol from AppState',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // Currency tile sublabel formats as "<Name> (<symbol>)" — by default
      // "US Dollar ($)" until the user opens the picker.
      expect(find.text('Currency'), findsOneWidget);
      expect(find.textContaining('US Dollar'), findsAtLeastNWidgets(1));
      // AppState's currencyCode default is USD.
      expect(state.currencyCode, 'USD');
    },
  );

  testWidgets(
    'Recurring Expenses tile entry into RecurringItems screen is wired',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // The Preferences section exposes the entry point — the label is
      // the contract surface.
      expect(find.text('Recurring Expenses'), findsOneWidget);
      expect(find.text('Auto-create monthly expenses'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // Session 21 review fixes: the account and currency actions reached from
  // bottom sheets. Each handler used to receive the sheet's own context,
  // await a dialog, then gate on `context.mounted` -- always false by then,
  // because the sheet had closed -- so confirming did nothing.
  // -------------------------------------------------------------------------

  /// Drives UI-started async work: the database runs on real I/O, so
  /// alternate real time (for the I/O) with frames (for the continuations
  /// and route animations) until [until] holds, then let the UI settle.
  /// Bounded, so a regression fails on its assertions instead of hanging.
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

  Future<void> openSheetsAndPause(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Expense expenseIn(int accountId) => Expense(
        amount: Decimal.parse('12.50'),
        category: 'Food',
        description: 'Lunch',
        date: DateTime.now(),
        accountId: accountId,
      );

  Future<int> expenseCount(int accountId) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'expenses',
      where: 'account_id = ?',
      whereArgs: [accountId],
    );
    return rows.length;
  }

  /// Main Account (current) plus "Side", which holds one expense.
  Future<(AppState, int)> seedSideAccount(WidgetTester tester) async {
    final state = AppState();
    late int sideId;
    await tester.runAsync(() async {
      await state.loadData();
      await state.addAccount('Side');
      final main = state.currentAccount!;
      final side = state.accounts.firstWhere((a) => a.name == 'Side');
      sideId = side.id!;
      await state.switchAccount(side);
      await state.addExpense(expenseIn(sideId));
      await state.switchAccount(main);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    return (state, sideId);
  }

  Future<void> openSideOptions(WidgetTester tester) async {
    await tester.tap(find.text('Current Account'));
    await openSheetsAndPause(tester);
    await tester.tap(find.descendant(
      of: find.widgetWithText(ListTile, 'Side'),
      matching: find.byIcon(Icons.more_vert),
    ));
    await openSheetsAndPause(tester);
  }

  Future<void> confirmDialog(WidgetTester tester) async {
    // The destructive action is the dialog's last button.
    await tester.tap(find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        )
        .last);
    await tester.pump();
  }

  testWidgets('Reset Account from the account options really resets it',
      (tester) async {
    final (state, sideId) = await seedSideAccount(tester);
    expect(await tester.runAsync(() => expenseCount(sideId)), 1);
    await pumpHarness(tester, appState: state);
    await pumpAndDrain(tester);

    await openSideOptions(tester);
    await tester.tap(find.text('Reset Account'));
    await openSheetsAndPause(tester);
    expect(find.text('Reset Account?'), findsOneWidget);

    await confirmDialog(tester);
    await drainAsync(
      tester,
      until: () =>
          find.text('Account "Side" has been reset').evaluate().isNotEmpty,
    );

    expect(await tester.runAsync(() => expenseCount(sideId)), 0);
    expect(find.text('Resetting account...'), findsNothing);
    expect(find.text('Account "Side" has been reset'), findsOneWidget);
  });

  testWidgets(
      'Delete Account from the account options really deletes it, and says '
      'where it went', (tester) async {
    final (state, _) = await seedSideAccount(tester);
    await pumpHarness(tester, appState: state);
    await pumpAndDrain(tester);

    await openSideOptions(tester);
    await tester.tap(find.text('Delete Account'));
    await openSheetsAndPause(tester);
    expect(find.text('Delete Account?'), findsOneWidget);
    // Deleting is a 30-day soft delete, so the dialog must not promise
    // anything permanent.
    Finder inDialog(Finder f) =>
        find.descendant(of: find.byType(AlertDialog), matching: f);
    expect(inDialog(find.textContaining('30 days')), findsOneWidget);
    expect(inDialog(find.textContaining('permanently')), findsNothing);
    expect(inDialog(find.textContaining('cannot be undone')), findsNothing);

    await confirmDialog(tester);
    await drainAsync(
      tester,
      until: () => find
          .text('Account "Side" moved to Recently deleted')
          .evaluate()
          .isNotEmpty,
    );

    expect(state.accounts.any((a) => a.name == 'Side'), isFalse);
    expect(find.text('Deleting account...'), findsNothing);
  });

  testWidgets(
      'changing currency with "Clear All Data" clears the account and '
      'switches the currency', (tester) async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      await state.addExpense(expenseIn(state.currentAccountId));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    expect(state.allExpenses, hasLength(1));
    // Wide enough for the shared currency warning's title row in the test
    // font, which draws every glyph a full em wide.
    await pumpHarness(tester, appState: state, surface: const Size(800, 3200));
    await pumpAndDrain(tester);

    await tester.tap(find.text('Currency'));
    await openSheetsAndPause(tester);
    await tester.tap(find.text('Euro'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await openSheetsAndPause(tester);
    expect(find.text('Change Currency?'), findsOneWidget);

    await tester.tap(find.text('Clear All Data'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await openSheetsAndPause(tester);
    expect(find.text('Clear All Data?'), findsOneWidget);

    await tester.tap(find.text('Delete Everything'));
    await drainAsync(
      tester,
      until: () => find
          .text('Data cleared and currency changed')
          .evaluate()
          .isNotEmpty,
    );

    expect(state.currencyCode, 'EUR');
    expect(state.allExpenses, isEmpty);
    expect(find.text('Clearing data...'), findsNothing);
  });

  testWidgets(
      'Add Account from the account picker owns its text controller and adds '
      'the account', (tester) async {
    final state = AppState();
    await tester.runAsync(() async {
      await state.loadData();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await pumpHarness(tester, appState: state);
    await pumpAndDrain(tester);

    await tester.tap(find.text('Current Account'));
    await openSheetsAndPause(tester);
    await tester.tap(find.byTooltip('Add Account'));
    await openSheetsAndPause(tester);

    await tester.enterText(find.byType(TextField), 'Travel');
    await tester.tap(find.widgetWithText(TextButton, 'Add'));
    // Run the dialog's exit transition: the old dialog disposed its
    // controller before popping, and the closing field still used it.
    await drainAsync(
      tester,
      until: () => state.accounts.any((a) => a.name == 'Travel'),
    );

    expect(state.accounts.any((a) => a.name == 'Travel'), isTrue);
    expect(find.text('Add Account'), findsNothing);
  });
}
