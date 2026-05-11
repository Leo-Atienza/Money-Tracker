import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/providers/app_state.dart';

import '_test_helpers.dart';

/// FIX Phase 1.5 — `loadData()` must coalesce concurrent calls.
///
/// **Bug.** `main.dart` triggers `loadData()` from three places that
/// can fire within milliseconds of each other on a typical app launch:
/// - `_MyAppState.initState` post-frame callback
/// - The `resumed` lifecycle event (e.g. after PIN unlock)
/// - `completeOnboarding()`'s downstream listeners
///
/// Each one used to spawn its own end-to-end pass: DB reads, `Future.wait`
/// over nine loaders, `_safeNotify`. The races produced duplicate work
/// and occasionally let a stale notification win — users saw the home
/// screen flicker between "empty" and "loaded".
///
/// **Fix.** `loadData()` stores its in-flight Future and returns the
/// same one to every caller until it resolves, then clears it via
/// `whenComplete`. Behavioural contract: N concurrent callers ⇒ ONE
/// internal pass.
void main() {
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  test('three concurrent loadData() calls share one underlying pass',
      () async {
    final appState = AppState();
    expect(appState.loadDataInternalRunCount, 0);

    await Future.wait([
      appState.loadData(),
      appState.loadData(),
      appState.loadData(),
    ]);

    expect(
      appState.loadDataInternalRunCount,
      1,
      reason: 'loadData must coalesce: three concurrent calls should '
          'resolve from a single internal pass. Pre-fix this was 3.',
    );

    appState.dispose();
  });

  test('subsequent loadData() after completion runs again', () async {
    final appState = AppState();
    await appState.loadData();
    expect(appState.loadDataInternalRunCount, 1);

    // After the in-flight future resolves, `_loadingFuture` is cleared
    // via `whenComplete`. The next call must trigger a fresh pass.
    await appState.loadData();
    expect(
      appState.loadDataInternalRunCount,
      2,
      reason: 'Coalescing should NOT permanently cache the result — the '
          'second call (after completion) should run a fresh pass.',
    );

    appState.dispose();
  });
}
