import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'providers/app_state.dart';
import 'utils/color_contrast_helper.dart';
import 'utils/crash_log.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/recurring_expenses_screen.dart';
import 'screens/add_hub_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/account_manager_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/pin_unlock_screen.dart';
import 'services/onboarding_service.dart';
import 'utils/notification_helper.dart';
import 'utils/notification_payload_store.dart';
import 'utils/home_widget_helper.dart';
import 'theme/luminous_app_theme.dart';
import 'widgets/luminous/floating_glass_nav_bar.dart';
import 'widgets/luminous/organic_blob_background.dart';
import 'utils/premium_animations.dart';

/// Current app version. Keep in sync with `pubspec.yaml` → `version:`.
/// FIX Phase 3a: Passed to [CrashLog.init] so every crash record is tagged
/// with the build that produced it.
const String _appVersion = '4.4.0+6';

/// Semantic color extension for expense/income/warning/info colors.
/// Uses WCAG-compliant colors from ColorContrastHelper.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color expenseRed;
  final Color incomeGreen;
  final Color warningOrange;
  final Color infoBlue;

  const AppColors({
    required this.expenseRed,
    required this.incomeGreen,
    required this.warningOrange,
    required this.infoBlue,
  });

  factory AppColors.fromBrightness(Brightness brightness) {
    final status = ColorContrastHelper.getStatusColors(brightness);
    return AppColors(
      expenseRed: status.error,
      incomeGreen: status.success,
      warningOrange: status.warning,
      infoBlue: status.info,
    );
  }

  @override
  AppColors copyWith({
    Color? expenseRed,
    Color? incomeGreen,
    Color? warningOrange,
    Color? infoBlue,
  }) {
    return AppColors(
      expenseRed: expenseRed ?? this.expenseRed,
      incomeGreen: incomeGreen ?? this.incomeGreen,
      warningOrange: warningOrange ?? this.warningOrange,
      infoBlue: infoBlue ?? this.infoBlue,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      expenseRed: Color.lerp(expenseRed, other.expenseRed, t)!,
      incomeGreen: Color.lerp(incomeGreen, other.incomeGreen, t)!,
      warningOrange: Color.lerp(warningOrange, other.warningOrange, t)!,
      infoBlue: Color.lerp(infoBlue, other.infoBlue, t)!,
    );
  }
}

// Top-level function for notification tap handling
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // FIX: Handle notification taps when app is in background
  // Store the payload so we can navigate when the app resumes
  NotificationPayloadStore.storePendingPayload(notificationResponse.payload);
  if (kDebugMode) {
    debugPrint(
      'Notification tapped in background: ${notificationResponse.payload}',
    );
  }
}

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
      await CrashLog.init(appVersion: _appVersion);

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
    }
  }

  Future<void> _handlePaused() async {
    if (!mounted || !context.mounted) return;
    final appState = context.read<AppState>();
    appState.lock();
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
    // Only NOW close the DB.
    await _performBackgroundMaintenance();
  }

  Future<void> _performBackgroundMaintenance() async {
    try {
      if (mounted && context.mounted) {
        final appState = context.read<AppState>();
        await appState.closeDatabase();
      }
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
      // FIX: Dispose home widget helper to cancel stream subscription
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
      home: FutureBuilder<bool>(
        future: _onboardingFuture,
        builder: (context, snapshot) {
          // Show loading while checking onboarding status
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: LuminousTokens.background,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
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
  bool _hasShownRecurringSnackbar = false;
  bool _hasCheckedNotificationPayload = false;

  // Animation controllers for tab transitions
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const List<FloatingGlassNavDestination> _navDestinations = [
    FloatingGlassNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    FloatingGlassNavDestination(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      label: 'History',
    ),
    FloatingGlassNavDestination(
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      label: 'Add',
    ),
    FloatingGlassNavDestination(
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard,
      label: 'Analytics',
    ),
    FloatingGlassNavDestination(
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      label: 'Wallet',
    ),
  ];

  final List<Widget> _screens = [
    const HomeScreen(),
    HistoryScreen(),
    const AddHubScreen(),
    const AnalyticsScreen(),
    const AccountManagerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
      _checkPendingNotification();
      _checkPinLock();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Check if app needs to show PIN unlock screen
  Future<void> _checkPinLock() async {
    if (!mounted) return;

    final appState = context.read<AppState>();
    if (appState.isLocked) {
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

    final payload = await NotificationPayloadStore.consumePendingPayload();
    if (payload == null || !mounted) return;

    if (payload == 'recurring_expenses') {
      if (!mounted) return;
      Navigator.push(
        context,
        PremiumPageRoute(page: const RecurringExpensesScreen()),
      );
    } else if (payload.startsWith('budget_alert:')) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountJustSwitched = context.select<AppState, bool>(
      (s) => s.accountJustSwitched,
    );
    final lastAutoCreatedCount = context.select<AppState, int>(
      (s) => s.lastAutoCreatedCount,
    );

    // FIX #8: Check if account was switched and reset navigation to home
    if (accountJustSwitched) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AppState>().clearAccountSwitchFlag();
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
          }
        }
      });
    }

    if (!_hasShownRecurringSnackbar && lastAutoCreatedCount > 0) {
      _hasShownRecurringSnackbar = true;
      final count = lastAutoCreatedCount;
      context.read<AppState>().clearAutoCreatedCount();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
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
                  setState(() => _currentIndex = 1);
                },
              ),
            ),
          );
        }
      });
    }

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
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: OrganicBlobBackground()),
              FadeTransition(
                opacity: _fadeAnimation,
                child: IndexedStack(index: _currentIndex, children: _screens),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16 + MediaQuery.paddingOf(context).bottom,
                // FIX Phase 1.7: isolate the nav bar's BackdropFilter
                // behind a RepaintBoundary so the rest of the screen
                // doesn't repaint when only the nav highlight pulses.
                // Saves ~3-5ms per frame during scroll on Pixel 4a.
                child: RepaintBoundary(
                  child: FloatingGlassNavBar(
                    currentIndex: _currentIndex,
                    destinations: _navDestinations,
                    onTap: (index) {
                      if (index == _currentIndex) {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      } else {
                        _fadeController.reverse().then((_) {
                          setState(() => _currentIndex = index);
                          _fadeController.forward();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
