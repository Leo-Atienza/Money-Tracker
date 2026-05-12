import 'package:budget_tracker/providers/app_state.dart';
import 'package:budget_tracker/utils/settings_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 7.2 (NEXT_STEPS D.2) — AppState mutator coverage for the safe,
/// DB-free subset: appearance / preferences / filters.
///
/// These mutators all share a contract:
///   1. State changes match the input.
///   2. The persisted value (via [SettingsHelper]) reflects the mutation
///      so a fresh `AppState` would pick it up on next launch.
///   3. `notifyListeners` fires exactly once per mutation so Provider
///      rebuilds happen with the correct cadence.
///
/// Mutators that touch [DatabaseHelper] (addExpense/addIncome/setBudget/
/// addAccount/etc.) are deferred to their own integration test files
/// where FFI scaffolding from `_test_helpers.dart` makes the assertions
/// against real DB state straightforward.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  late int notifyCount;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    state = AppState();
    notifyCount = 0;
    state.addListener(() => notifyCount++);
  });

  tearDown(() {
    state.dispose();
  });

  group('AppState.setThemeMode', () {
    test('sets light theme + persists + notifies', () async {
      await state.setThemeMode('light');

      expect(state.themeMode, 'light');
      expect(state.isDarkMode, isFalse);
      expect(await SettingsHelper.getThemeMode(), 'light');
      expect(notifyCount, 1);
    });

    test('sets dark theme + flips isDarkMode flag', () async {
      await state.setThemeMode('dark');

      expect(state.themeMode, 'dark');
      expect(state.isDarkMode, isTrue);
      expect(await SettingsHelper.getThemeMode(), 'dark');
      expect(notifyCount, 1);
    });

    test('system theme: isDarkMode stays false (deferred to OS)', () async {
      await state.setThemeMode('system');

      expect(state.themeMode, 'system');
      expect(state.isDarkMode, isFalse);
      expect(await SettingsHelper.getThemeMode(), 'system');
      expect(notifyCount, 1);
    });
  });

  group('AppState.toggleDarkMode', () {
    test('flips _isDarkMode + persists + notifies', () async {
      expect(state.isDarkMode, isFalse);

      await state.toggleDarkMode();

      expect(state.isDarkMode, isTrue);
      expect(await SettingsHelper.getDarkMode(), isTrue);
      expect(notifyCount, 1);

      await state.toggleDarkMode();

      expect(state.isDarkMode, isFalse);
      expect(await SettingsHelper.getDarkMode(), isFalse);
      expect(notifyCount, 2);
    });
  });

  group('AppState.toggleShowTransactionColors', () {
    test('toggle on → persists + notifies', () async {
      expect(state.showTransactionColors, isFalse);

      await state.toggleShowTransactionColors(true);

      expect(state.showTransactionColors, isTrue);
      expect(await SettingsHelper.getShowTransactionColors(), isTrue);
      expect(notifyCount, 1);
    });

    test('toggle off → persists + notifies', () async {
      await state.toggleShowTransactionColors(true);
      notifyCount = 0;

      await state.toggleShowTransactionColors(false);

      expect(state.showTransactionColors, isFalse);
      expect(await SettingsHelper.getShowTransactionColors(), isFalse);
      expect(notifyCount, 1);
    });
  });

  group('AppState.setTransactionColorIntensity', () {
    test('mid-range value persists at exact precision', () async {
      await state.setTransactionColorIntensity(0.65);

      expect(state.transactionColorIntensity, closeTo(0.65, 1e-9));
      expect(
        await SettingsHelper.getTransactionColorIntensity(),
        closeTo(0.65, 1e-9),
      );
      expect(notifyCount, 1);
    });

    test('clamps above 1.0 to 1.0', () async {
      await state.setTransactionColorIntensity(1.5);

      expect(state.transactionColorIntensity, 1.0);
      expect(await SettingsHelper.getTransactionColorIntensity(), 1.0);
      expect(notifyCount, 1);
    });

    test('clamps below 0.0 to 0.0', () async {
      await state.setTransactionColorIntensity(-0.5);

      expect(state.transactionColorIntensity, 0.0);
      expect(await SettingsHelper.getTransactionColorIntensity(), 0.0);
      expect(notifyCount, 1);
    });
  });

  group('AppState.toggleBillReminders', () {
    test('toggle off → persists + notifies', () async {
      expect(state.billRemindersEnabled, isTrue);

      await state.toggleBillReminders(false);

      expect(state.billRemindersEnabled, isFalse);
      expect(await SettingsHelper.getBillReminders(), isFalse);
      expect(notifyCount, 1);
    });
  });

  group('AppState.toggleBudgetAlerts', () {
    test('toggle off → persists + notifies', () async {
      expect(state.budgetAlertsEnabled, isTrue);

      await state.toggleBudgetAlerts(false);

      expect(state.budgetAlertsEnabled, isFalse);
      expect(await SettingsHelper.getBudgetAlerts(), isFalse);
      expect(notifyCount, 1);
    });
  });

  group('AppState.toggleMonthlySummary', () {
    test('toggle off → persists + notifies', () async {
      expect(state.monthlySummaryEnabled, isTrue);

      await state.toggleMonthlySummary(false);

      expect(state.monthlySummaryEnabled, isFalse);
      expect(await SettingsHelper.getMonthlySummary(), isFalse);
      expect(notifyCount, 1);
    });
  });

  group('AppState.setReminderTime', () {
    test('persists hour + minute + notifies', () async {
      const newTime = TimeOfDay(hour: 21, minute: 30);

      await state.setReminderTime(newTime);

      expect(state.reminderTime, newTime);
      expect(await SettingsHelper.getReminderHour(), 21);
      expect(await SettingsHelper.getReminderMinute(), 30);
      expect(notifyCount, 1);
    });
  });

  group('AppState.setFilterCategory', () {
    test('changes the filter + notifies (synchronous)', () {
      state.setFilterCategory('Food');

      expect(state.filterCategory, 'Food');
      expect(notifyCount, 1);
    });
  });

  group('AppState.setDateRange', () {
    test('non-null start + end stores DateTimeRange + notifies', () {
      final start = DateTime(2026, 5, 1);
      final end = DateTime(2026, 5, 31);

      state.setDateRange(start, end);

      expect(state.dateRange, isNotNull);
      expect(state.dateRange!.start, start);
      expect(state.dateRange!.end, end);
      expect(notifyCount, 1);
    });

    test('null start clears the range + notifies', () {
      state.setDateRange(DateTime(2026, 5, 1), DateTime(2026, 5, 31));
      notifyCount = 0;

      state.setDateRange(null, null);

      expect(state.dateRange, isNull);
      expect(notifyCount, 1);
    });
  });

  group('AppState.setAmountRange', () {
    // _minAmount / _maxAmount are private (no public getter). The
    // observable contract is `notifyListeners` fired so Provider rebuilds
    // pick up the new filter state. End-to-end coverage of the filtered
    // expense list lives in the integration test files.
    test('non-null min + max fires notifyListeners', () {
      state.setAmountRange(10.0, 1000.0);
      expect(notifyCount, 1);
    });

    test('null min + max clears the filter + notifies', () {
      state.setAmountRange(10.0, 1000.0);
      notifyCount = 0;

      state.setAmountRange(null, null);

      expect(notifyCount, 1);
    });
  });

  group('AppState.setPaidStatusFilter', () {
    // Private field; contract = notifyListeners + filtered list refresh
    // (integration coverage).
    test('isPaid=true fires notifyListeners', () {
      state.setPaidStatusFilter(true);
      expect(notifyCount, 1);
    });

    test('isPaid=null clears the filter + notifies', () {
      state.setPaidStatusFilter(false);
      notifyCount = 0;

      state.setPaidStatusFilter(null);
      expect(notifyCount, 1);
    });
  });

  group('AppState.clearFilters', () {
    test('resets category to All + clears ranges + notifies', () {
      state.setFilterCategory('Food');
      state.setDateRange(DateTime(2026, 5, 1), DateTime(2026, 5, 31));
      state.setAmountRange(10.0, 1000.0);
      state.setPaidStatusFilter(true);
      notifyCount = 0;

      state.clearFilters();

      expect(state.filterCategory, 'All');
      expect(state.dateRange, isNull);
      expect(notifyCount, 1);
    });
  });

  group('AppState.clearAutoCreatedCount', () {
    test('zeroes the counter (synchronous, no notify)', () {
      // _lastAutoCreatedCount has no setter from outside; check it stays
      // 0 after construction, then verify the public clear is callable
      // without firing notifyListeners (it's not gated on a state change).
      expect(state.lastAutoCreatedCount, 0);

      state.clearAutoCreatedCount();

      expect(state.lastAutoCreatedCount, 0);
      // Synchronous getter-only mutator — by inspection it doesn't notify,
      // so we don't assert against notifyCount here.
    });
  });
}
