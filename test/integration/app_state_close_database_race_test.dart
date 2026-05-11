import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/models/expense_model.dart';
import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/date_helper.dart';

import '_test_helpers.dart';

/// FIX Phase 1.4 — `closeDatabase` must not race in-flight writes.
///
/// **Bug.** `MyApp.didChangeAppLifecycleState(paused)` fired
/// `HomeWidgetHelper.updateWidget(appState)` without awaiting it, then
/// kicked off `_performBackgroundMaintenance` which closed the DB.
/// `closeDatabase` itself only spun on `_processingRecurring` —
/// nothing protected against an ordinary `addExpense` / `updateExpense`
/// or the widget-update query still being in flight. Result:
/// intermittent `DatabaseException(error database_closed)` in crash
/// logs whenever the user backgrounded the app during a write.
///
/// **Fix.** `AppState.closeDatabase` now wraps `_db.closeDatabase()` in
/// `_writeMutex.synchronized(...)`, so it queues behind every other
/// mutex-using write (addExpense/addIncome/addBudget/...). And
/// `MyApp.didChangeAppLifecycleState` routes `paused` through an
/// async helper that awaits the widget update before maintenance.
///
/// This test exercises only the AppState contract — the lifecycle
/// helper is covered indirectly by the analyzer (it now awaits
/// `HomeWidgetHelper.updateWidget`).
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

  test('closeDatabase queues behind concurrent writes via _writeMutex',
      () async {
    final appState = AppState();
    await appState.loadData();

    // Pile up several concurrent writes alongside the closeDatabase.
    // Pre-fix, closeDatabase did not acquire `_writeMutex`, so under
    // load any write that hadn't yet flushed could surface as
    // `DatabaseException(error database_closed)`. With the fix, the
    // mutex serializes them — every write either completes before
    // close runs, or closeDatabase waits for every write to flush.
    final errors = <Object>[];
    final futures = <Future<void>>[];
    for (var i = 0; i < 5; i++) {
      futures.add(
        appState
            .addExpense(
              Expense(
                amount: Decimal.parse('1.00'),
                category: 'Food',
                description: 'race_$i',
                date: DateHelper.today(),
                accountId: appState.currentAccountId,
                amountPaid: Decimal.zero,
              ),
            )
            .catchError((Object e) => errors.add(e)),
      );
    }
    // closeDatabase interleaved with the writes.
    futures.add(
      appState.closeDatabase().catchError((Object e) => errors.add(e)),
    );

    await Future.wait(futures);

    expect(
      errors,
      isEmpty,
      reason: 'closeDatabase raced one of the addExpense calls. '
          'The mutex around `_db.closeDatabase()` (Phase 1.4) should '
          'serialize them. Errors observed: $errors',
    );

    // The mutex ordering means writes either finished BEFORE close, or
    // are silently dropped (none in our scheduling). The exact count
    // depends on event-loop scheduling, but every completed write must
    // have actually persisted — no `DatabaseClosed` exceptions.
    appState.dispose();
  });

  // STRUCTURAL guard: the race itself is timing-dependent and hard to
  // reproduce in FFI tests (microsecond writes), so the behavioural
  // test above is best-effort. This test reads the source of
  // `closeDatabase` and asserts the Phase 1.4 mutex line is still in
  // place. If a future refactor drops the mutex, this fails and forces
  // a deliberate decision.
  test('closeDatabase source still contains the _writeMutex guard',
      () {
    final src = File('lib/providers/app_state.dart').readAsStringSync();
    // Find the closeDatabase function body and assert _writeMutex is
    // referenced inside it. A simple substring containment after the
    // declaration line is sufficient — full-text Dart parsing is
    // overkill for a one-line guard.
    final closeIdx = src.indexOf('Future<void> closeDatabase()');
    expect(closeIdx, isNonNegative,
        reason: 'closeDatabase moved or was renamed — update this test.');
    // Look at the next ~2000 chars (function body — the multi-line
    // comment + body easily exceeds 800 chars).
    final body = src.substring(closeIdx, (closeIdx + 2000).clamp(0, src.length));
    expect(
      body.contains('_writeMutex.synchronized'),
      isTrue,
      reason: 'closeDatabase must serialize through _writeMutex so it '
          'cannot close the DB while another write holds the mutex. '
          'Phase 1.4 introduced this guard against the paused-lifecycle '
          'race. Function body sampled:\n$body',
    );
  });
}
