import 'package:shared_preferences/shared_preferences.dart';

class SettingsHelper {
  // Keys for SharedPreferences
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyThemeMode =
      'theme_mode'; // FIX: New tri-state theme mode
  static const String _keyCurrencyCode = 'currency_code';
  static const String _keyBillReminders = 'bill_reminders';
  static const String _keyBudgetAlerts = 'budget_alerts';
  static const String _keyMonthlySummary = 'monthly_summary';
  static const String _keyReminderHour = 'reminder_hour';
  static const String _keyReminderMinute = 'reminder_minute';
  static const String _keyCsvSeparator = 'csv_separator';
  // FIX #12: Configurable budget warning threshold (default 75%)
  static const String _keyBudgetWarningThreshold = 'budget_warning_threshold';
  // FIX #18: Configurable search debounce (default 300ms)
  static const String _keySearchDebounce = 'search_debounce';
  // FIX #19: Configurable pagination limit (default 50)
  static const String _keyPaginationLimit = 'pagination_limit';
  // Transaction background colors toggle (default false for clean UI)
  // When enabled, shows transparent category color as background on transaction cards
  static const String _keyShowTransactionColors = 'show_transaction_colors';
  static const String _keyCarryoverEnabled = 'carryover_enabled';
  // Transaction color intensity (0.0 - 1.0, default 0.5 = medium)
  static const String _keyTransactionColorIntensity =
      'transaction_color_intensity';

  /// The user's settings as a backup carries them, under the keys the app
  /// actually reads. (Backups before S22 wrote camelCase keys nothing read,
  /// so they only ever held defaults; `restoreFromBackup` never sees them.)
  static Future<Map<String, Object>> exportForBackup() async {
    return {
      _keyThemeMode: await getThemeMode(),
      _keyBillReminders: await getBillReminders(),
      _keyBudgetAlerts: await getBudgetAlerts(),
      _keyMonthlySummary: await getMonthlySummary(),
      _keyReminderHour: await getReminderHour(),
      _keyReminderMinute: await getReminderMinute(),
      _keyCsvSeparator: await getCsvSeparator(),
      _keyBudgetWarningThreshold: await getBudgetWarningThreshold(),
      _keyShowTransactionColors: await getShowTransactionColors(),
      _keyTransactionColorIntensity: await getTransactionColorIntensity(),
      _keyCarryoverEnabled: await getCarryoverEnabled(),
    };
  }

  /// Applies the settings of a restored backup. Each value is checked on its
  /// own: one of the wrong type or out of range is skipped and the current
  /// setting kept, so a damaged settings block can never fail the restore of
  /// a good database. Returns how many settings were applied.
  static Future<int> restoreFromBackup(Map<String, dynamic> raw) async {
    var applied = 0;
    Future<void> apply<T>(String key, Future<void> Function(T) set,
        {bool Function(T)? valid}) async {
      final value = raw[key];
      final T typed;
      if (value is T) {
        typed = value;
      } else if (T == double && value is num) {
        // JSON writes 1.0 as 1.
        typed = value.toDouble() as T;
      } else {
        return;
      }
      if (valid != null && !valid(typed)) return;
      await set(typed);
      applied++;
    }

    await apply<String>(_keyThemeMode, setThemeMode,
        valid: const {'light', 'dark', 'purple', 'system'}.contains);
    await apply<bool>(_keyBillReminders, setBillReminders);
    await apply<bool>(_keyBudgetAlerts, setBudgetAlerts);
    await apply<bool>(_keyMonthlySummary, setMonthlySummary);
    await apply<int>(_keyReminderHour, setReminderHour,
        valid: (h) => h >= 0 && h <= 23);
    await apply<int>(_keyReminderMinute, setReminderMinute,
        valid: (m) => m >= 0 && m <= 59);
    await apply<String>(_keyCsvSeparator, setCsvSeparator,
        valid: const {'comma', 'semicolon'}.contains);
    await apply<double>(_keyBudgetWarningThreshold, setBudgetWarningThreshold,
        valid: (v) => v >= 0 && v <= 1);
    await apply<bool>(_keyShowTransactionColors, setShowTransactionColors);
    await apply<double>(
        _keyTransactionColorIntensity, setTransactionColorIntensity,
        valid: (v) => v >= 0 && v <= 1);
    await apply<bool>(_keyCarryoverEnabled, setCarryoverEnabled);
    return applied;
  }

  // Dark Mode (deprecated - kept for migration)
  static Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  // Theme Mode: 'light', 'dark', 'purple' (lavender by day, violet at night,
  // following the phone) or 'system'. Anything else is treated as 'system' by
  // the theme resolver.
  static Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();

    // FIX: Migration from old boolean dark mode
    final themeMode = prefs.getString(_keyThemeMode);
    if (themeMode != null) {
      return themeMode;
    }

    // Migrate old boolean setting
    final oldDarkMode = prefs.getBool(_keyDarkMode);
    if (oldDarkMode != null) {
      final migratedMode = oldDarkMode ? 'dark' : 'light';
      await setThemeMode(migratedMode);
      return migratedMode;
    }

    return 'system'; // Default to system
  }

  static Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  // Currency Code
  static Future<String> getCurrencyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCurrencyCode) ?? 'USD';
  }

  static Future<void> setCurrencyCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrencyCode, code);
  }

  // Bill Reminders
  static Future<bool> getBillReminders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBillReminders) ?? true;
  }

  static Future<void> setBillReminders(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBillReminders, value);
  }

  // Budget Alerts
  static Future<bool> getBudgetAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBudgetAlerts) ?? true;
  }

  static Future<void> setBudgetAlerts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBudgetAlerts, value);
  }

  // Monthly Summary
  static Future<bool> getMonthlySummary() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMonthlySummary) ?? true;
  }

  static Future<void> setMonthlySummary(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMonthlySummary, value);
  }

  // Reminder Time
  static Future<int> getReminderHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyReminderHour) ?? 9;
  }

  static Future<void> setReminderHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderHour, hour);
  }

  static Future<int> getReminderMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyReminderMinute) ?? 0;
  }

  static Future<void> setReminderMinute(int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReminderMinute, minute);
  }

  // CSV Separator (for international Excel compatibility)
  // 'comma' for US/UK (1234.56), 'semicolon' for Europe (1234,56)
  static Future<String> getCsvSeparator() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCsvSeparator) ?? 'comma';
  }

  static Future<void> setCsvSeparator(String separator) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCsvSeparator, separator);
  }

  // FIX #12: Budget Warning Threshold (0.0 - 1.0, default 0.75 = 75%)
  static Future<double> getBudgetWarningThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyBudgetWarningThreshold) ?? 0.75;
  }

  static Future<void> setBudgetWarningThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBudgetWarningThreshold, value.clamp(0.0, 1.0));
  }

  // FIX #18: Search Debounce (milliseconds, default 300ms)
  static Future<int> getSearchDebounce() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keySearchDebounce) ?? 300;
  }

  static Future<void> setSearchDebounce(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySearchDebounce, ms.clamp(0, 2000));
  }

  // FIX #19: Pagination Limit (default 50, range 10-200)
  static Future<int> getPaginationLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPaginationLimit) ?? 50;
  }

  static Future<void> setPaginationLimit(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPaginationLimit, limit.clamp(10, 200));
  }

  // Show Transaction Background Colors (default false for clean UI)
  // When enabled, shows transparent category color as background on transaction cards
  static Future<bool> getShowTransactionColors() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShowTransactionColors) ?? false;
  }

  static Future<void> setShowTransactionColors(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTransactionColors, value);
  }

  // Transaction Color Intensity (0.0 - 1.0, default 0.5 = medium)
  // Controls how visible the category background color is on transaction cards
  static Future<double> getTransactionColorIntensity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyTransactionColorIntensity) ?? 0.5;
  }

  static Future<void> setTransactionColorIntensity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTransactionColorIntensity, value.clamp(0.0, 1.0));
  }

  // Carry Over Balance (default true): whatever is left at the end of a month
  // — surplus or deficit — rolls into the next month's balance. Off means
  // every month starts from zero.
  static Future<bool> getCarryoverEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCarryoverEnabled) ?? true;
  }

  static Future<void> setCarryoverEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCarryoverEnabled, value);
  }

  // Budget rollover marker: last month's budgets are copied into a month at
  // most once per account. The rollover runs on every load, and without the
  // marker it re-copied them whenever the month had none — so deleting all of
  // a month's budgets brought them straight back on the next resume.
  static String _budgetRolloverKey(int accountId, DateTime month) =>
      'budget_rollover_${accountId}_${month.year}-${month.month}';

  static Future<bool> isBudgetRolloverDone(int accountId, DateTime month) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_budgetRolloverKey(accountId, month)) ?? false;
  }

  static Future<void> markBudgetRolloverDone(int accountId, DateTime month) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_budgetRolloverKey(accountId, month), true);
  }

  // Clear all settings (useful for testing or reset)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
