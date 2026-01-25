import 'package:shared_preferences/shared_preferences.dart';

class SettingsHelper {
  // Keys for SharedPreferences
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyThemeMode = 'theme_mode'; // FIX: New tri-state theme mode
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
  // Transaction color intensity (0.0 - 1.0, default 0.5 = medium)
  static const String _keyTransactionColorIntensity = 'transaction_color_intensity';

  // Dark Mode (deprecated - kept for migration)
  static Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkMode) ?? false;
  }

  static Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }

  // FIX: Theme Mode - tri-state (light, dark, system)
  // Returns 'light', 'dark', or 'system'
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

  // Clear all settings (useful for testing or reset)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}