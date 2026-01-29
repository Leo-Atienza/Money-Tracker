import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/app_state.dart';
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

// Top-level function for notification tap handling
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // FIX: Handle notification taps when app is in background
  // Store the payload so we can navigate when the app resumes
  NotificationPayloadStore.storePendingPayload(notificationResponse.payload);
  if (kDebugMode) debugPrint('Notification tapped in background: ${notificationResponse.payload}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Firebase initialization failed: $e');
  }

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
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MyApp(),
    ),
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
    final appState = context.watch<AppState>();

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
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E1E1E),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      themeMode: appState.themeMode == 'light'
          ? ThemeMode.light
          : appState.themeMode == 'dark'
              ? ThemeMode.dark
              : ThemeMode.system,
      home: FutureBuilder<bool>(
        future: _onboardingFuture,
        builder: (context, snapshot) {
          // Show loading while checking onboarding status
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
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

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
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
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
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
    final appState = context.watch<AppState>();

    // FIX #8: Check if account was switched and reset navigation to home
    if (appState.accountJustSwitched) {
      appState.clearAccountSwitchFlag();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      });
    }

    if (!_hasShownRecurringSnackbar && appState.lastAutoCreatedCount > 0) {
      _hasShownRecurringSnackbar = true;
      final count = appState.lastAutoCreatedCount;
      appState.clearAutoCreatedCount();

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
          child: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
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
            indicatorColor: theme.colorScheme.onSurface.withAlpha(isDark ? 50 : 30),
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
