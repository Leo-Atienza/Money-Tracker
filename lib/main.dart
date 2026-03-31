import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'providers/app_state.dart';
import 'utils/color_contrast_helper.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/recurring_expenses_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/pin_unlock_screen.dart';
import 'services/onboarding_service.dart';
import 'utils/notification_helper.dart';
import 'utils/notification_payload_store.dart';
import 'utils/home_widget_helper.dart';

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

TextTheme _buildTextTheme(Brightness brightness) {
  final baseColor =
      brightness == Brightness.dark ? Colors.white : Colors.black;
  return TextTheme(
    displayLarge: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w300,
      color: baseColor,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w300,
      color: baseColor,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: baseColor,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: baseColor,
    ),
    titleSmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: baseColor,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: baseColor,
    ),
    bodyMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: baseColor,
    ),
    bodySmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      color: baseColor,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: baseColor,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: baseColor,
    ),
  );
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize notifications with error handling
  try {
    await NotificationHelper().initialize();
  } catch (e) {
    if (kDebugMode) debugPrint('Notification initialization failed: $e');
    // App will continue without notifications
  }

  // Initialize home screen widget
  try {
    await HomeWidgetHelper.initialize();
  } catch (e) {
    if (kDebugMode) debugPrint('Home widget initialization failed: $e');
    // App will continue without widget support
  }

  // Initialize date formatting
  await initializeDateFormatting();

  runApp(
    ChangeNotifierProvider(create: (_) => AppState(), child: const MyApp()),
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
      // App going to background - lock if PIN is enabled
      if (mounted && context.mounted) {
        final appState = context.read<AppState>();
        appState.lock();
        // Update home widget so it shows current data on the home screen
        HomeWidgetHelper.updateWidget(appState);
      }
      // Good time to run cleanup
      _performBackgroundMaintenance();
    } else if (state == AppLifecycleState.detached) {
      // App being terminated - close database safely
      _closeDatabaseSafely();
    } else if (state == AppLifecycleState.resumed) {
      // Refresh data when app resumes (e.g. date change)
      if (mounted && context.mounted) {
        context.read<AppState>().loadData();
      }
    }
  }

  Future<void> _performBackgroundMaintenance() async {
    try {
      if (mounted && context.mounted) {
        final appState = context.read<AppState>();
        // Perform maintenance operations asynchronously
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
      title: 'Money Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E1E1E),
          brightness: Brightness.light,
        ),
        textTheme: _buildTextTheme(Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        extensions: <ThemeExtension<dynamic>>[
          AppColors.fromBrightness(Brightness.light),
        ],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E1E1E),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
        textTheme: _buildTextTheme(Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        extensions: <ThemeExtension<dynamic>>[
          AppColors.fromBrightness(Brightness.dark),
        ],
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const RecurringExpensesScreen(),
    const SettingsScreen(),
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
      setState(() => _currentIndex = 2);
    } else if (payload.startsWith('budget_alert:')) {
      setState(() => _currentIndex = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(isDark ? 50 : 30),
                  width: 1,
                ),
              ),
              color: theme.colorScheme.surface,
            ),
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                if (index == _currentIndex) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else {
                  // Animate tab transition
                  _fadeController.reverse().then((_) {
                    setState(() => _currentIndex = index);
                    _fadeController.forward();
                  });
                  HapticFeedback.selectionClick();
                }
              },
              backgroundColor: Colors.transparent,
              indicatorColor: theme.colorScheme.onSurface.withAlpha(
                isDark ? 50 : 30,
              ),
              height: 65,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.repeat),
                  selectedIcon: Icon(Icons.repeat_on_outlined),
                  label: 'Recurring',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
