import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/providers/app_state.dart';

import '_test_helpers.dart';

/// FIX Phase 3c — Regression tests for Bug #5 and Bug #7.
///
/// **Bug #5** — Every mutation on `AppState` does DB work inside
/// `_writeMutex.synchronized` before calling `notifyListeners()`. If
/// the surrounding widget tree is torn down during that await (e.g.
/// hot restart, user signs out, test teardown), the plain
/// `notifyListeners()` call would throw
/// `A ChangeNotifier was used after being disposed`. The fix
/// introduced `_safeNotify()` which early-returns when `_isDisposed`
/// is set by `dispose()`.
///
/// **Bug #7** — `_lastAutoCreatedCount` accumulated across runs of
/// `_processRecurringInBackground` because the counter was never
/// reset; subsequent foreground/background cycles kept increasing the
/// number. The fix resets the counter to `0` at the top of every run.
///
/// These tests drive a real `AppState` + `sqflite_common_ffi` DB.
/// `home_widget` and `flutter_local_notifications` are mocked at the
/// MethodChannel layer so the pipeline can run without a real device.
void main() {
  const homeWidgetChannel = MethodChannel('home_widget');
  const notifChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Swallow platform-channel calls during the recurring pipeline.
    // `_processRecurringInBackground` ends with `_initializeNotifications`
    // which touches `flutter_local_notifications`, and `HomeWidgetHelper`
    // touches `home_widget`. Both have try/catch but returning `null`
    // keeps the logs clean.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, (_) async => true)
      ..setMockMethodCallHandler(notifChannel, (_) async => null);

    await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(homeWidgetChannel, null)
      ..setMockMethodCallHandler(notifChannel, null);
    await DatabaseHelper.resetForTesting();
  });

  /// Seed a monthly recurring expense due today — dayOfMonth matches
  /// `DateTime.now().day` so the scheduler generates one instance on
  /// the first processing run.
  Future<void> seedRecurringDueToday(Database db, {String description = 'rent'}) async {
    final today = DateTime.now();
    await db.insert('recurring_expenses', {
      'description': description,
      'amount': 100.0,
      'category': 'Bills',
      'dayOfMonth': today.day,
      'isActive': 1,
      'lastCreated': null,
      'account_id': 1,
      'paymentMethod': 'Cash',
      'occurrenceCount': 0,
      'frequency': 0, // monthly
    });
  }

  group('Bug #7 — lastAutoCreatedCount resets each run', () {
    test('counter reflects only the latest run, not accumulated', () async {
      final db = await DatabaseHelper().database;
      await seedRecurringDueToday(db);

      final appState = AppState();

      // First run generates one instance for today's recurring expense.
      await appState.runRecurringProcessingForTesting();
      expect(appState.lastAutoCreatedCount, 1);

      // Second run happens on the same day — the recurring now has
      // `lastCreated = today`, so the scheduler skips it. In the
      // PRE-FIX code the counter would remain at 1 (1 + 0). In the
      // FIXED code it resets to 0 before re-running, proving the reset.
      await appState.runRecurringProcessingForTesting();
      expect(appState.lastAutoCreatedCount, 0);

      appState.dispose();
    });

    test('counter reports only new items added by the latest run', () async {
      final db = await DatabaseHelper().database;
      // Seed two recurring rows due today — first run creates both.
      await seedRecurringDueToday(db, description: 'rent');
      await seedRecurringDueToday(db, description: 'internet');

      final appState = AppState();

      await appState.runRecurringProcessingForTesting();
      expect(appState.lastAutoCreatedCount, 2);

      // Add a THIRD recurring item due today and run again. Fixed
      // behavior: counter resets to 0 then increments by 1 (only the
      // new item is processed — the other two are skipped via
      // isSameDay). Pre-fix behavior: counter would be 2 + 1 = 3.
      await seedRecurringDueToday(db, description: 'gym');
      await appState.runRecurringProcessingForTesting();
      expect(appState.lastAutoCreatedCount, 1);

      appState.dispose();
    });

    test('clearAutoCreatedCount zeroes the counter explicitly', () async {
      final db = await DatabaseHelper().database;
      await seedRecurringDueToday(db);

      final appState = AppState();
      await appState.runRecurringProcessingForTesting();
      expect(appState.lastAutoCreatedCount, 1);

      appState.clearAutoCreatedCount();
      expect(appState.lastAutoCreatedCount, 0);

      appState.dispose();
    });
  });

  group('Bug #5 — _safeNotify short-circuits after dispose', () {
    test('safeNotify after dispose does not throw', () {
      final appState = AppState();
      // Before disposal: safeNotify is safe to call even with no listeners.
      expect(() => appState.safeNotifyForTesting(), returnsNormally);

      appState.dispose();

      // After disposal: the pre-fix code would have thrown
      // "A ChangeNotifier was used after being disposed". The fixed
      // `_safeNotify` short-circuits on `_isDisposed` and is a no-op.
      expect(() => appState.safeNotifyForTesting(), returnsNormally);
    });

    test('recurring processing followed by dispose does not throw', () async {
      final db = await DatabaseHelper().database;
      await seedRecurringDueToday(db);

      final appState = AppState();
      // Drive the full background pipeline (DB writes + _safeNotify).
      await appState.runRecurringProcessingForTesting();

      // Dispose immediately — any lingering `_safeNotify()` call
      // from a late async completion must not surface an exception.
      expect(() => appState.dispose(), returnsNormally);

      // Post-dispose notify is still a no-op.
      expect(() => appState.safeNotifyForTesting(), returnsNormally);
    });
  });
}
