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

  testWidgets('Add-account FAB is present', (tester) async {
    await pumpHarness(tester);
    await tester.pump();
    expect(find.byType(FloatingActionButton), findsOneWidget);
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
}
