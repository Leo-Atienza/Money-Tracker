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
}
