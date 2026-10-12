import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/wallet_screen.dart';
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

/// Phase 5.2 — Wallet widget tests.
///
/// **Composition smoke** (first group): GlassTopAppBar "Wallet" with no
/// back button (Wallet sits behind the main-nav tab); add-account FAB
/// present.
///
/// **Seeded behavioural states** (Stage D.2): multi-account list and
/// soft-deleted-account section render correctly when [AppState] is
/// pre-populated via `addAccount` + `deleteAccount`. The "Active" badge,
/// the default-account subtitle, and the deleted-accounts trash section
/// are the contract surfaces.
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
    messenger.setMockMethodCallHandler(homeWidgetChannel, (_) async => null);
    messenger.setMockMethodCallHandler(notifChannel, (_) async => null);
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => '.dart_tool/test_path_provider',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(secureChannel, null);
    messenger.setMockMethodCallHandler(homeWidgetChannel, null);
    messenger.setMockMethodCallHandler(notifChannel, null);
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
    // Intentional: do NOT call `DatabaseHelper.resetForTesting()` here.
    // _DeletedAccountsSection kicks off `getDeletedAccounts()` in initState
    // (wallet_screen.dart:714) and the await outlives the widget dispose.
    // Closing the DB in tearDown wins the race and throws
    // `database_closed`. `makeFreshDb()` in the next setUp picks a fresh
    // unique database name, so leaving the previous DB open is safe.
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
          home: const WalletScreen(),
        ),
      ),
    );
  }

  Future<void> pumpAndDrain(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 700));
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

  testWidgets('M15: add-account action lives in the header, not a FAB',
      (tester) async {
    await pumpHarness(tester);
    await tester.pump();
    // M15: the FAB was occluded by the global nav bar, so the action moved
    // into the GlassTopAppBar trailing slot (a tooltipped IconButton).
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.widgetWithIcon(IconButton, Icons.add),
      findsOneWidget,
      reason: 'add-account IconButton should be in the header',
    );
  });

  // -------------------------------------------------------------------------
  // Stage D.2 — seeded-data Wallet assertions.
  // -------------------------------------------------------------------------

  testWidgets(
    'multiple accounts render and the active one shows the "Active" badge',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await state.addAccount('Savings');
        await state.addAccount('Travel');
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // Three accounts now: Main Account (default + active) + 2 new.
      expect(find.text('Main Account'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);

      // Default-account subtitle is visible on the default account row.
      expect(find.text('Default Account'), findsOneWidget);

      // Exactly one "Active" badge — the currently selected account.
      expect(find.text('Active'), findsOneWidget);
    },
  );

  testWidgets(
    'each account row is wrapped in a GlassPanel',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await state.addAccount('Savings');
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // Main Account + Savings → at minimum 2 GlassPanels in the list.
      // The screen may stack additional GlassPanels for the deleted
      // section header / empty state, so assert at-least-N instead of
      // exact count.
      final savingsPanel = find.ancestor(
        of: find.text('Savings'),
        matching: find.byType(GlassPanel),
      );
      expect(savingsPanel, findsAtLeastNWidgets(1));
    },
  );

  testWidgets(
    'a soft-deleted account does not appear in the active list',
    (tester) async {
      final state = AppState();
      await tester.runAsync(() async {
        await state.loadData();
        await state.addAccount('Vacation');
        // Find the just-added account id, then soft-delete it.
        final vacation = state.accounts.firstWhere(
          (a) => a.name == 'Vacation',
        );
        await state.deleteAccount(vacation.id!);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });

      await pumpHarness(tester, appState: state);
      await pumpAndDrain(tester);

      // The deleted account name should NOT appear in the active list.
      // (Whether the deleted-accounts trash section surfaces it depends
      // on the StatefulWidget's auto-load behaviour; we only pin the
      // active-list invariant here, which is the user-visible contract.)
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('Vacation'),
        ),
        findsNothing,
      );

      // Main Account is still active and visible.
      expect(find.text('Main Account'), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // Session 21 review fixes.
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

  Future<AppState> seededState(List<String> extraAccounts) async {
    final state = AppState();
    await state.loadData();
    for (final name in extraAccounts) {
      await state.addAccount(name);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return state;
  }

  testWidgets('the account list starts flush under a status-bar inset',
      (tester) async {
    final state = (await tester.runAsync(() => seededState(const [])))!;
    await tester.binding.setSurfaceSize(const Size(800, 1600));
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
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 48),
              ),
              child: const WalletScreen(),
            ),
          ),
        ),
      ),
    );
    await pumpAndDrain(tester);

    // Without an explicit padding the ListView padded itself with the
    // status-bar inset: an empty 48dp band above the first account.
    final listTop = tester.getTopLeft(find.byType(ListView)).dy;
    final firstRowTop = tester
        .getTopLeft(find.ancestor(
          of: find.text('Main Account'),
          matching: find.byType(GlassPanel),
        ))
        .dy;
    expect(firstRowTop - listTop, lessThan(1));
  });

  testWidgets(
      'switching account closes only its progress dialog, '
      'never the navigation shell under the Wallet tab', (tester) async {
    final state = (await tester.runAsync(() => seededState(['Savings'])))!;
    await pumpHarness(tester, appState: state);
    await pumpAndDrain(tester);

    await tester.tap(find.text('Savings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Switch Account?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Switch'));
    await drainAsync(
      tester,
      until: () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
    );

    expect(state.currentAccount?.name, 'Savings');
    // Wallet is a tab of the shell (here: the home route). The old code
    // popped twice and took that route with it, leaving a blank app.
    expect(find.byType(WalletScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets(
      'the delete confirmation tells the truth: the account goes to a '
      '30-day Recently deleted, not away for good', (tester) async {
    final state = (await tester.runAsync(() => seededState(['Vacation'])))!;
    await pumpHarness(tester, appState: state);
    await pumpAndDrain(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Delete Account?'), findsOneWidget);
    expect(find.textContaining('30 days'), findsOneWidget);
    expect(find.textContaining('permanently'), findsNothing);
    expect(find.textContaining('cannot be undone'), findsNothing);
    expect(find.text('Delete Permanently'), findsNothing);
  });

  testWidgets(
      'deleting an account closes its progress dialog after the '
      'confirmation is gone, and lists it under Recently deleted',
      (tester) async {
    final state = (await tester.runAsync(() => seededState(['Vacation'])))!;
    await pumpHarness(tester, appState: state);
    await pumpAndDrain(tester);
    expect(find.text('RECENTLY DELETED'), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The destructive action is the dialog's last button.
    await tester.tap(find
        .descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        )
        .last);
    // Let the confirmation finish closing before the delete lands: its
    // context is unmounted from here on, which is what stranded the old
    // spinner behind a barrier nobody could dismiss.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await drainAsync(
      tester,
      until: () => find.text('RECENTLY DELETED').evaluate().isNotEmpty,
    );

    expect(state.accounts.any((a) => a.name == 'Vacation'), isFalse);
    expect(find.text('Deleting account...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // Wallet is a persistent tab: the section must pick the deletion up
    // without a restart.
    expect(find.text('RECENTLY DELETED'), findsOneWidget);
  });

  testWidgets(
      'account rows expose the switch tap and the options menu to '
      'TalkBack', (tester) async {
    final handle = tester.ensureSemantics();
    final state = (await tester.runAsync(() => seededState(['Savings'])))!;
    await pumpHarness(tester, appState: state);
    await pumpAndDrain(tester);

    expect(
      tester.getSemantics(find.widgetWithText(ListTile, 'Savings')),
      isSemantics(hasTapAction: true),
    );
    // The options menu is its own button, named for the account.
    expect(
      tester.getSemantics(find.byIcon(Icons.more_vert)),
      isSemantics(tooltip: 'Options for Savings', hasTapAction: true),
    );
    handle.dispose();
  });
}
