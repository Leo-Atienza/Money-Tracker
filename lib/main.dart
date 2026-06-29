import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'providers/app_state.dart';
import 'theme/app_colors.dart';
import 'utils/crash_log.dart';
import 'screens/home_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/recurring_items_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/pin_unlock_screen.dart';
import 'services/onboarding_service.dart';
import 'utils/notification_helper.dart';
import 'utils/notification_payload_store.dart';
import 'utils/home_widget_helper.dart';
import 'theme/luminous_app_theme.dart';
import 'utils/premium_animations.dart';

/// Resolves the current app version from the native bundle so it stays in
/// sync with `pubspec.yaml` → `version:`. Falls back to `'unknown'` only when
/// `PackageInfo` itself throws — every recorded crash should still be tagged
/// with *something*, even if package_info_plus is broken.
///
/// Phase 2.6: replaces the hardcoded `_appVersion` constant.
Future<String> _resolveAppVersion() async {
  try {
    final pkg = await PackageInfo.fromPlatform();
    return '${pkg.version}+${pkg.buildNumber}';
  } catch (e, st) {
    if (kDebugMode) debugPrint('PackageInfo.fromPlatform failed: $e');
    // Note: CrashLog isn't initialised yet at this call site. The caller is
    // expected to record the failure once init() succeeds.
    debugPrintStack(stackTrace: st, label: 'package_info_plus');
    return 'unknown';
  }
}

// The background notification-tap handler `notificationTapBackground` lives in
// `utils/notification_payload_store.dart` so `NotificationHelper` can wire it
// without importing this entrypoint. It is imported above and used by both.

void main() {
  // FIX Phase 3a: Wrap the entire startup in `runZonedGuarded` so any async
  // error that escapes the Flutter framework is caught and written to the
  // local crash log. Without this, a rejected Future in (say) the recurring
  // processor would print to the debug console and vanish in release.
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize the crash log and install global error handlers BEFORE
      // anything else that might throw, so those errors are captured too.
      // Version comes from the native bundle (Phase 2.6) so we never drift
      // from `pubspec.yaml`.
      final appVersion = await _resolveAppVersion();
      await CrashLog.init(appVersion: appVersion);

      // Set preferred orientation
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Initialize notifications with error handling
      try {
        await NotificationHelper().initialize();
      } catch (e, st) {
        if (kDebugMode) debugPrint('Notification initialization failed: $e');
        CrashLog.record(e, stack: st, context: 'notification_init');
        // App will continue without notifications
      }

      // Initialize home screen widget
      try {
        await HomeWidgetHelper.initialize();
      } catch (e, st) {
        if (kDebugMode) debugPrint('Home widget initialization failed: $e');
        CrashLog.record(e, stack: st, context: 'home_widget_init');
        // App will continue without widget support
      }

      // Initialize date formatting
      await initializeDateFormatting();

      runApp(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      // Last-resort handler for anything the framework's own handlers
      // didn't catch. Never throws — CrashLog.record swallows failures.
      CrashLog.record(error, stack: stack, context: 'zone');
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final OnboardingService _onboardingService = OnboardingService();
  // CRITICAL FIX: Cache the onboarding future to prevent re-triggering the FutureBuilder
  // and losing app state (like navigation) every time AppState notifies a change.
  late Future<bool> _onboardingFuture;

  @override
  void initState() {
    super.initState();
    _onboardingFuture = _onboardingService.isOnboardingComplete();
    WidgetsBinding.instance.addObserver(this);
    // Load initial data and PIN lock state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().loadData();
        context.read<AppState>().initializeLockState();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // FIX Phase 1.4: route the paused work through an async helper so
      // HomeWidget.updateWidget completes BEFORE _performBackgroundMaintenance
      // closes the DB. The previous version fired updateWidget without
      // awaiting it and started maintenance immediately, causing
      // intermittent `DatabaseException(error database_closed)` during
      // widget rendering.
      unawaited(_handlePaused());
    } else if (state == AppLifecycleState.detached) {
      _closeDatabaseSafely();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted && context.mounted) {
        context.read<AppState>().loadData();
      }
      // Phase 3.1: the navigation screen has its own observer that picks up
      // resume and re-checks the notification queue.
    }
  }

  Future<void> _handlePaused() async {
    if (!mounted || !context.mounted) return;
    final appState = context.read<AppState>();
    // Only arm the lock gate when a PIN is actually configured. `_isLocked`
    // is the single source of truth the resume handler re-presents against,
    // so locking without a PIN would trap the user on an unlock screen they
    // can't pass. `initializeLockState` and the inactivity timer already gate
    // on pinEnabled — keep `_handlePaused` consistent so `isLocked == true`
    // always implies a PIN exists.
    //
    // Wrapped in try/catch so a secure-storage read failure can NEVER (a) skip
    // the DB-close / subscription-dispose maintenance below, nor (b) trap a
    // PIN-less user — on error we leave the app unlocked (fail-open for
    // usability; the resume handler is a no-op when unlocked anyway).
    try {
      if (await appState.isPinEnabled()) {
        appState.lock();
      }
    } catch (e, st) {
      if (kDebugMode) debugPrint('isPinEnabled() on paused failed: $e');
      CrashLog.record(e, stack: st, context: 'lifecycle_paused_pin_check');
    }
    try {
      // Update the home-screen widget with the latest financial summary
      // while the DB is still open. Any failure here is logged but does
      // not block maintenance — the widget falls back to stale data on
      // the user's launcher, never an exception.
      await HomeWidgetHelper.updateWidget(appState);
    } catch (e, st) {
      if (kDebugMode) debugPrint('HomeWidget update on paused failed: $e');
      CrashLog.record(e, stack: st, context: 'lifecycle_paused_widget_update');
    }
    // Phase 3.6: state could be torn down between awaits. Bail out before
    // touching context/state on every subsequent step.
    if (!mounted) return;
    // Phase 3.5: dispose the widget click subscription on `paused` instead of
    // `detached`. Android often skips `detached` entirely (e.g. when the
    // system kills the process to reclaim memory), and the leaked stream
    // subscription would otherwise survive across a hot restart and fire the
    // click callback twice on the next foreground.
    await HomeWidgetHelper.dispose();
    if (!mounted) return;
    // Only NOW close the DB.
    await _performBackgroundMaintenance();
  }

  Future<void> _performBackgroundMaintenance() async {
    try {
      // Phase 3.6: mounted check before reading context, AND immediately
      // after the await so any later `context.read` (added in the future)
      // can't latch onto a torn-down element.
      if (!mounted || !context.mounted) return;
      final appState = context.read<AppState>();
      await appState.closeDatabase();
      if (!mounted) return;
      // Nothing after the await currently — but the guard stays so adding a
      // subsequent step (cache flush, log rotate, …) is safe by default.
    } catch (e) {
      if (kDebugMode) debugPrint('Error during background maintenance: $e');
    }
  }

  void _closeDatabaseSafely() {
    try {
      if (mounted && context.mounted) {
        // Close database connection on app termination
        context.read<AppState>().closeDatabase();
      }
      // Phase 3.5: HomeWidgetHelper.dispose() was moved to `_handlePaused`
      // because Android does not reliably deliver `detached`. The call
      // remains idempotent so a `detached`-after-`paused` flow re-disposing
      // is harmless — keep it here as a belt-and-braces guard.
      HomeWidgetHelper.dispose();
    } catch (e) {
      if (kDebugMode) debugPrint('Error closing database: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, String>((s) => s.themeMode);

    return MaterialApp(
      title: 'FinanceFlow',
      debugShowCheckedModeBanner: false,
      theme: buildLuminousTheme(
        brightness: Brightness.light,
        appColorsExtension: AppColors.fromBrightness(Brightness.light),
      ),
      darkTheme: buildLuminousTheme(
        brightness: Brightness.dark,
        appColorsExtension: AppColors.fromBrightness(Brightness.dark),
      ),
      themeMode: themeMode == 'light'
          ? ThemeMode.light
          : themeMode == 'dark'
              ? ThemeMode.dark
              : ThemeMode.system,
      // The Luminous design assumes an OrganicBlobBackground behind every
      // screen. Painting it here — below the Navigator but inside the Theme
      // scope — gives EVERY route the correct light/dark backdrop. Pushed
      // routes (Settings, Budgets, Onboarding, PIN, …) use transparent
      // Scaffolds and PremiumPageRoute is opaque, so before this they fell
      // through to a black window background with low-contrast glass/text.
      // The nav-tab screens render over this too (MainNavigationScreen no
      // longer paints its own copy).
      builder: (context, child) {
        // M12: clamp system text scaling so the fixed-height bars don't clip
        // at ~2.0 accessibility font sizes.
        //
        // De-glass (2026-06-29): the global OrganicBlobBackground was removed.
        // A solid surface backstop sits behind the Navigator so any route that
        // still uses a transparent Scaffold paints on the theme surface instead
        // of falling through to the bare (black) window.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: FutureBuilder<bool>(
        future: _onboardingFuture,
        builder: (context, snapshot) {
          // Show loading while checking onboarding status
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withAlpha(100),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Show onboarding if not complete
          final isOnboardingComplete = snapshot.data ?? false;
          if (!isOnboardingComplete) {
            return const OnboardingScreen();
          }

          // Show main app
          return const MainNavigationScreen();
        },
      ),
      routes: {
        '/home': (context) => const MainNavigationScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/budgets': (context) => const BudgetScreen(),
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _hasCheckedNotificationPayload = false;

  /// Re-entrancy guard for [_checkPinLock]. Since the unlock gate is now
  /// re-presented on every resume (not just cold start), a second resume
  /// while [PinUnlockScreen] is already on the stack must not push a
  /// duplicate. Set immediately before the push, cleared in `finally`.
  bool _pinRouteActive = false;

  /// Phase 3.2: subscription to the AppState recurring-batch stream. One
  /// snackbar per emitted batch — no more "first batch wins, second batch
  /// silent" UX.
  StreamSubscription<int>? _recurringBatchSubscription;

  /// Phase 3.4: subscription to the AppState account-switch stream. Each
  /// emission resets navigation to Home — replaces the previous
  /// `accountJustSwitched` boolean + post-frame clear flag pattern.
  StreamSubscription<void>? _accountSwitchSubscription;

  // Animation controllers for tab transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  /// FIX Phase 1.8: generation token that increments on every tab tap.
  /// The `.then` callback after `_fadeController.reverse()` captures
  /// the value at tap time and bails out if a later tap has bumped it.
  /// Prevents rapid taps from racing — the last tap wins and stale
  /// callbacks become no-ops.
  int _tabSwitchGeneration = 0;

  static const List<NavigationDestination> _navDestinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'History',
    ),
    NavigationDestination(
      icon: Icon(Icons.add_circle_outline),
      selectedIcon: Icon(Icons.add_circle),
      label: 'Add',
    ),
    NavigationDestination(
      icon: Icon(Icons.leaderboard_outlined),
      selectedIcon: Icon(Icons.leaderboard),
      label: 'Analytics',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Wallet',
    ),
  ];

  final List<Widget> _screens = [
    const HomeScreen(),
    HistoryScreen(),
    const AddTransactionScreen(),
    const AnalyticsScreen(),
    const WalletScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Phase 3.3: also reset the PIN lock timer on every focus change.
    // GestureDetector only catches taps + pans on the Scaffold's surface;
    // keyboard focus moves from one TextField to another (or a soft-keyboard
    // arrow key) don't bubble through it. Without this listener, the user
    // could sit on a long form and have the lock trip mid-edit.
    FocusManager.instance.addListener(_onFocusEvent);

    // Initialize fade animation for tab transitions
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.value = 1.0; // Start fully visible

    // Check for pending notification payload after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkPendingNotification();
      _checkPinLock();
      // Phase 3.2: subscribe to recurring-batch events. The AppState fires
      // one event per completed batch; we show a snackbar per event.
      final appState = context.read<AppState>();
      _recurringBatchSubscription =
          appState.onRecurringBatch.listen(_onRecurringBatch);
      // Phase 3.4: subscribe to account-switch events. Each emission resets
      // navigation back to Home.
      _accountSwitchSubscription =
          appState.onAccountSwitch.listen(_onAccountSwitch);
    });
  }

  @override
  void dispose() {
    _recurringBatchSubscription?.cancel();
    _accountSwitchSubscription?.cancel();
    FocusManager.instance.removeListener(_onFocusEvent);
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAccountSwitch(void _) {
    if (!mounted) return;
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
    }
  }

  void _onFocusEvent() {
    if (!mounted) return;
    context.read<AppState>().resetLockTimer();
  }

  void _onRecurringBatch(int count) {
    if (!mounted) return;
    // The AppState clears the counter after each run; mirror that on the UI
    // side so the legacy `lastAutoCreatedCount` getter (still used by tests
    // for Bug #7) keeps reporting "current run" semantics.
    context.read<AppState>().clearAutoCreatedCount();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? '1 recurring transaction added'
              : '$count recurring transactions added',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            if (mounted) setState(() => _currentIndex = 1);
          },
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Phase 3.1: reset the notification-check guard on resume so payloads
    // that landed in the background get picked up. The schedule for the
    // re-check happens after the next frame so it sees the post-resume
    // BuildContext.
    if (state == AppLifecycleState.resumed) {
      _hasCheckedNotificationPayload = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkPendingNotification();
        // Re-present the PIN gate if the app locked while backgrounded or
        // while the inactivity timer tripped. Without this, auto-lock never
        // fires on the common process-alive resume path and all financial
        // data stays visible without re-entering the PIN. `_checkPinLock`
        // no-ops when the app isn't locked and is re-entrancy guarded.
        _checkPinLock();
      });
    }
  }

  /// Check if app needs to show PIN unlock screen. Invoked on cold start and
  /// on every resume, so it is guarded against re-entrant presentation.
  Future<void> _checkPinLock() async {
    if (!mounted) return;
    if (_pinRouteActive) return;

    final appState = context.read<AppState>();
    if (!appState.isLocked) return;

    _pinRouteActive = true;
    try {
      final unlocked = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PinUnlockScreen(),
          fullscreenDialog: true,
        ),
      );

      if (unlocked == true && mounted) {
        appState.unlock();
      } else if (mounted) {
        // User didn't unlock, exit the app
        SystemNavigator.pop();
      }
    } finally {
      _pinRouteActive = false;
    }
  }

  /// Reset inactivity timer on any interaction
  void _onUserInteraction() {
    if (mounted) {
      context.read<AppState>().resetLockTimer();
    }
  }

  Future<void> _checkPendingNotification() async {
    if (_hasCheckedNotificationPayload) return;
    _hasCheckedNotificationPayload = true;

    // Phase 3.1: consume the full queue. Multiple notifications can land
    // between foreground checks (e.g. bill reminder + budget alert), and
    // dropping any of them silently is the bug we're fixing here.
    final payloads = await NotificationPayloadStore.consumePendingPayloads();
    if (payloads.isEmpty) return;

    // De-duplicate by route so two `recurring_expenses` taps don't stack the
    // same screen twice. Order is preserved.
    final seen = <String>{};
    for (final payload in payloads) {
      if (!seen.add(payload)) continue;
      // Phase 3.7: re-check mounted-ness immediately before Navigator.push.
      // The pre-await guard isn't enough — `consumePendingPayloads()` returns
      // synchronously here, but a future change that adds an await inside
      // the loop body could leave a stale BuildContext live until the next
      // re-check. The `context.mounted` half catches the case where the
      // surrounding Element was detached while State.mounted was still true.
      if (!mounted || !context.mounted) return;

      if (payload == 'recurring_expenses') {
        Navigator.push(
          context,
          PremiumPageRoute(
            page: const RecurringItemsScreen(initialType: 'expense'),
          ),
        );
      } else if (payload.startsWith('budget_alert:')) {
        setState(() => _currentIndex = 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phase 3.2: recurring snackbar moved off `lastAutoCreatedCount` to the
    // `onRecurringBatch` stream — see `_onRecurringBatch` and the
    // subscription wired in `initState`.
    // Phase 3.4: account-switch navigation reset moved off the
    // `accountJustSwitched` boolean to the `onAccountSwitch` stream — see
    // `_onAccountSwitch` and the subscription wired in `initState`.

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: GestureDetector(
        onTap: _onUserInteraction,
        onPanUpdate: (_) => _onUserInteraction(),
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          // De-glass (2026-06-29): the floating glass pill was replaced with a
          // standard Material 3 NavigationBar pinned to the bottom. A 1px top
          // hairline separates it from the body (matches the app's original
          // bottom nav). The Scaffold insets the body above it automatically,
          // so screens no longer need to reserve floating-nav clearance.
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              destinations: _navDestinations,
              onDestinationSelected: (index) {
                if (index == _currentIndex) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  // FIX Phase 1.8: guard the post-await callback with (a) a
                  // generation token so rapid taps discard stale fade-in
                  // callbacks, and (b) a `mounted` check so unmounting between
                  // tap and animation completion doesn't crash.
                  final gen = ++_tabSwitchGeneration;
                  HapticFeedback.selectionClick();
                  _fadeController.reverse().then((_) {
                    if (!mounted || gen != _tabSwitchGeneration) {
                      return;
                    }
                    setState(() => _currentIndex = index);
                    _fadeController.forward();
                  });
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
