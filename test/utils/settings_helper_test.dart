import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/utils/settings_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  // ==========================================================================
  // Theme mode (tri-state + legacy bool migration)
  // ==========================================================================
  group('theme mode', () {
    test('defaults to system when nothing persisted', () async {
      expect(await SettingsHelper.getThemeMode(), 'system');
    });

    test('setThemeMode persists and getThemeMode returns it', () async {
      await SettingsHelper.setThemeMode('dark');
      expect(await SettingsHelper.getThemeMode(), 'dark');
    });

    test('purple round-trips like the other modes', () async {
      await SettingsHelper.setThemeMode('purple');
      expect(await SettingsHelper.getThemeMode(), 'purple');
    });

    test('migrates legacy dark_mode=true to themeMode=dark', () async {
      SharedPreferences.setMockInitialValues({'dark_mode': true});
      expect(await SettingsHelper.getThemeMode(), 'dark');
      // Migration must persist the new key so subsequent calls are fast-path.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('migrates legacy dark_mode=false to themeMode=light', () async {
      SharedPreferences.setMockInitialValues({'dark_mode': false});
      expect(await SettingsHelper.getThemeMode(), 'light');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'light');
    });

    test('themeMode key wins over legacy dark_mode key when both present',
        () async {
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'system',
        'dark_mode': true,
      });
      expect(await SettingsHelper.getThemeMode(), 'system');
    });
  });

  // ==========================================================================
  // Legacy dark mode getter (kept for backward compat)
  // ==========================================================================
  group('legacy dark mode', () {
    test('getDarkMode defaults to false', () async {
      expect(await SettingsHelper.getDarkMode(), false);
    });

    test('setDarkMode persists', () async {
      await SettingsHelper.setDarkMode(true);
      expect(await SettingsHelper.getDarkMode(), true);
    });
  });

  // ==========================================================================
  // Currency / notifications / reminder time
  // ==========================================================================
  group('currency', () {
    test('defaults to USD', () async {
      expect(await SettingsHelper.getCurrencyCode(), 'USD');
    });

    test('persists arbitrary ISO code', () async {
      await SettingsHelper.setCurrencyCode('JPY');
      expect(await SettingsHelper.getCurrencyCode(), 'JPY');
    });
  });

  group('notification toggles default ON', () {
    test('bill reminders default true', () async {
      expect(await SettingsHelper.getBillReminders(), true);
    });

    test('budget alerts default true', () async {
      expect(await SettingsHelper.getBudgetAlerts(), true);
    });

    test('monthly summary default true', () async {
      expect(await SettingsHelper.getMonthlySummary(), true);
    });

    test('toggles persist as false', () async {
      await SettingsHelper.setBillReminders(false);
      await SettingsHelper.setBudgetAlerts(false);
      await SettingsHelper.setMonthlySummary(false);
      expect(await SettingsHelper.getBillReminders(), false);
      expect(await SettingsHelper.getBudgetAlerts(), false);
      expect(await SettingsHelper.getMonthlySummary(), false);
    });
  });

  group('reminder time', () {
    test('defaults to 09:00', () async {
      expect(await SettingsHelper.getReminderHour(), 9);
      expect(await SettingsHelper.getReminderMinute(), 0);
    });

    test('persists arbitrary hour/minute', () async {
      await SettingsHelper.setReminderHour(18);
      await SettingsHelper.setReminderMinute(45);
      expect(await SettingsHelper.getReminderHour(), 18);
      expect(await SettingsHelper.getReminderMinute(), 45);
    });
  });

  // ==========================================================================
  // CSV separator
  // ==========================================================================
  group('csv separator', () {
    test('defaults to comma', () async {
      expect(await SettingsHelper.getCsvSeparator(), 'comma');
    });

    test('persists semicolon', () async {
      await SettingsHelper.setCsvSeparator('semicolon');
      expect(await SettingsHelper.getCsvSeparator(), 'semicolon');
    });
  });

  // ==========================================================================
  // Clamped settings — the interesting cases
  // ==========================================================================
  group('budget warning threshold (clamped to 0..1)', () {
    test('defaults to 0.75', () async {
      expect(await SettingsHelper.getBudgetWarningThreshold(), 0.75);
    });

    test('clamps negative values up to 0.0', () async {
      await SettingsHelper.setBudgetWarningThreshold(-5.0);
      expect(await SettingsHelper.getBudgetWarningThreshold(), 0.0);
    });

    test('clamps values > 1.0 down to 1.0', () async {
      await SettingsHelper.setBudgetWarningThreshold(9.9);
      expect(await SettingsHelper.getBudgetWarningThreshold(), 1.0);
    });

    test('in-range values pass through', () async {
      await SettingsHelper.setBudgetWarningThreshold(0.42);
      expect(await SettingsHelper.getBudgetWarningThreshold(), 0.42);
    });
  });

  group('search debounce (clamped to 0..2000ms)', () {
    test('defaults to 300ms', () async {
      expect(await SettingsHelper.getSearchDebounce(), 300);
    });

    test('clamps negative values to 0', () async {
      await SettingsHelper.setSearchDebounce(-100);
      expect(await SettingsHelper.getSearchDebounce(), 0);
    });

    test('clamps values > 2000 down to 2000', () async {
      await SettingsHelper.setSearchDebounce(5000);
      expect(await SettingsHelper.getSearchDebounce(), 2000);
    });
  });

  group('pagination limit (clamped to 10..200)', () {
    test('defaults to 50', () async {
      expect(await SettingsHelper.getPaginationLimit(), 50);
    });

    test('clamps low values up to 10', () async {
      await SettingsHelper.setPaginationLimit(1);
      expect(await SettingsHelper.getPaginationLimit(), 10);
    });

    test('clamps high values down to 200', () async {
      await SettingsHelper.setPaginationLimit(9999);
      expect(await SettingsHelper.getPaginationLimit(), 200);
    });

    test('in-range value persists as-is', () async {
      await SettingsHelper.setPaginationLimit(75);
      expect(await SettingsHelper.getPaginationLimit(), 75);
    });
  });

  // ==========================================================================
  // Transaction color toggles
  // ==========================================================================
  group('transaction colors', () {
    test('showTransactionColors defaults to false', () async {
      expect(await SettingsHelper.getShowTransactionColors(), false);
    });

    test('showTransactionColors persists true', () async {
      await SettingsHelper.setShowTransactionColors(true);
      expect(await SettingsHelper.getShowTransactionColors(), true);
    });

    test('transactionColorIntensity defaults to 0.5', () async {
      expect(await SettingsHelper.getTransactionColorIntensity(), 0.5);
    });

    test('transactionColorIntensity clamps to 0..1', () async {
      await SettingsHelper.setTransactionColorIntensity(-0.3);
      expect(await SettingsHelper.getTransactionColorIntensity(), 0.0);

      await SettingsHelper.setTransactionColorIntensity(1.5);
      expect(await SettingsHelper.getTransactionColorIntensity(), 1.0);
    });
  });

  // ==========================================================================
  // clearAll
  // ==========================================================================
  group('clearAll', () {
    test('removes every persisted setting', () async {
      await SettingsHelper.setThemeMode('dark');
      await SettingsHelper.setCurrencyCode('EUR');
      await SettingsHelper.setBillReminders(false);
      await SettingsHelper.setPaginationLimit(100);

      await SettingsHelper.clearAll();

      expect(await SettingsHelper.getThemeMode(), 'system');
      expect(await SettingsHelper.getCurrencyCode(), 'USD');
      expect(await SettingsHelper.getBillReminders(), true);
      expect(await SettingsHelper.getPaginationLimit(), 50);
    });
  });

  // ==========================================================================
  // Backup round-trip (S22): the real keys, validated one by one
  // ==========================================================================
  group('settings in a backup', () {
    test('every exported setting comes back on restore', () async {
      await SettingsHelper.setThemeMode('purple');
      await SettingsHelper.setBillReminders(false);
      await SettingsHelper.setBudgetAlerts(false);
      await SettingsHelper.setMonthlySummary(false);
      await SettingsHelper.setReminderHour(21);
      await SettingsHelper.setReminderMinute(45);
      await SettingsHelper.setCsvSeparator('semicolon');
      await SettingsHelper.setBudgetWarningThreshold(0.9);
      await SettingsHelper.setShowTransactionColors(true);
      await SettingsHelper.setTransactionColorIntensity(0.25);
      await SettingsHelper.setCarryoverEnabled(false);
      // Through JSON, as a backup file carries it.
      final exported = jsonDecode(
        jsonEncode(await SettingsHelper.exportForBackup()),
      ) as Map<String, dynamic>;

      SharedPreferences.setMockInitialValues({}); // a fresh install
      expect(await SettingsHelper.restoreFromBackup(exported), 11);

      expect(await SettingsHelper.getThemeMode(), 'purple');
      expect(await SettingsHelper.getBillReminders(), isFalse);
      expect(await SettingsHelper.getBudgetAlerts(), isFalse);
      expect(await SettingsHelper.getMonthlySummary(), isFalse);
      expect(await SettingsHelper.getReminderHour(), 21);
      expect(await SettingsHelper.getReminderMinute(), 45);
      expect(await SettingsHelper.getCsvSeparator(), 'semicolon');
      expect(await SettingsHelper.getBudgetWarningThreshold(), 0.9);
      expect(await SettingsHelper.getShowTransactionColors(), isTrue);
      expect(await SettingsHelper.getTransactionColorIntensity(), 0.25);
      expect(await SettingsHelper.getCarryoverEnabled(), isFalse);
    });

    test('a damaged value is skipped, never thrown, and the rest applies',
        () async {
      await SettingsHelper.setReminderHour(8);

      final applied = await SettingsHelper.restoreFromBackup({
        'theme_mode': 'sepia', // unknown
        'reminder_hour': 'nine', // wrong type
        'reminder_minute': 75, // out of range
        'budget_warning_threshold': 1, // JSON int for a double: fine
        'bill_reminders': false,
      });

      expect(applied, 2);
      expect(await SettingsHelper.getThemeMode(), 'system');
      expect(await SettingsHelper.getReminderHour(), 8);
      expect(await SettingsHelper.getReminderMinute(), 0);
      expect(await SettingsHelper.getBudgetWarningThreshold(), 1.0);
      expect(await SettingsHelper.getBillReminders(), isFalse);
    });

    test('a pre-S22 camelCase block (defaults only) changes nothing',
        () async {
      await SettingsHelper.setThemeMode('dark');

      final applied = await SettingsHelper.restoreFromBackup({
        'darkMode': false,
        'currencyCode': 'USD',
        'billReminders': true,
        'reminderHour': 9,
      });

      expect(applied, 0);
      expect(await SettingsHelper.getThemeMode(), 'dark');
    });
  });
}
