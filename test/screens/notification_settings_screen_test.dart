import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/screens/notification_settings_screen.dart';
import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/widgets/luminous/glass_top_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration/_test_helpers.dart';

/// Phase 5.9j / Stage D.2 — Notification Settings widget tests (resurrected).
///
/// The original test was deferred into
/// `TRASH/notification_settings_screen_test.dart_skipped` because
/// `FlutterLocalNotificationsPlatform.instance` is a `late final` static
/// and explodes with `LateInitializationError` the first time the screen
/// tries to query notification permissions during `initState`. This
/// resurrection registers a `_FakeNotificationsPlatform` via
/// `MockPlatformInterfaceMixin` so the static is populated before the
/// screen pumps, and stubs every method the screen exercises (including
/// `cancelAll`, `pendingNotificationRequests`, etc.) so other tests in
/// the suite don't trip over the same late initialisation.
///
/// Behavioural coverage:
///   * GlassTopAppBar renders "Notifications" with a back button.
///   * Section headings (ALERTS / REMINDER TIME / TEST / EXAMPLES).
///   * Toggle labels (Bill Reminders / Budget Alerts / Monthly Summary).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Populate the late static once for the whole test process. Tests are
  // tolerant of re-registration because `MockPlatformInterfaceMixin`
  // skips the token verification.
  FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();

  late TestDefaultBinaryMessenger messenger;
  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const notificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const homeWidgetChannel = MethodChannel('home_widget');
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (_) async => null);
    messenger.setMockMethodCallHandler(notificationsChannel, (_) async => true);
    messenger.setMockMethodCallHandler(homeWidgetChannel, (_) async => true);
    messenger.setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => '.dart_tool/test_path_provider',
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
    messenger.setMockMethodCallHandler(notificationsChannel, null);
    messenger.setMockMethodCallHandler(homeWidgetChannel, null);
    messenger.setMockMethodCallHandler(pathProviderChannel, null);
  });

  Future<void> pumpHarness(
    WidgetTester tester, {
    Size surface = const Size(800, 2400),
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
          home: const NotificationSettingsScreen(),
        ),
      ),
    );
  }

  Future<void> pumpAndDrain(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('GlassTopAppBar renders "Notifications" with back button',
      (tester) async {
    await pumpHarness(tester);
    await pumpAndDrain(tester);

    expect(find.byType(GlassTopAppBar), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('renders ALERTS / REMINDER TIME / TEST / EXAMPLES headings',
      (tester) async {
    await pumpHarness(tester);
    await pumpAndDrain(tester);

    for (final heading in const [
      'ALERTS',
      'REMINDER TIME',
      'TEST',
      'EXAMPLES',
    ]) {
      expect(
        find.text(heading),
        findsOneWidget,
        reason: 'Section heading "$heading" should render exactly once.',
      );
    }
  });

  testWidgets('Bill / Budget / Monthly toggle labels render',
      (tester) async {
    await pumpHarness(tester);
    await pumpAndDrain(tester);

    expect(find.text('Bill Reminders'), findsOneWidget);
    expect(find.text('Budget Alerts'), findsOneWidget);
    expect(find.text('Monthly Summary'), findsOneWidget);
  });
}

/// Test-only no-op platform for [FlutterLocalNotificationsPlatform].
///
/// Uses [MockPlatformInterfaceMixin] so the platform-interface token
/// verification (which the production setter normally enforces) is
/// skipped. Every override is a no-op or returns a benign default.
class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancel(int id, {String? tag}) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async {
    return null;
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return const [];
  }

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async {
    return const [];
  }

  @override
  Future<void> periodicallyShow(
    int id,
    String? title,
    String? body,
    RepeatInterval repeatInterval, {
    String? payload,
  }) async {}

  @override
  Future<void> periodicallyShowWithDuration(
    int id,
    String? title,
    String? body,
    Duration repeatDurationInterval, {
    String? payload,
  }) async {}

  @override
  Future<void> show(
    int id,
    String? title,
    String? body, {
    String? payload,
  }) async {}
}
