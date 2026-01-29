import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import '../providers/app_state.dart';
import 'currency_helper.dart';

/// Helper class for managing the home screen widget
/// Updates the widget with current month's financial summary
class HomeWidgetHelper {
  static const String _androidWidgetName = 'BudgetWidgetProvider';
  static const String _iOSWidgetName = 'BudgetWidget';
  static const String _appGroupId = 'group.com.budgettracker.widget';

  /// Stores the widget click subscription so it can be cancelled
  static StreamSubscription<Uri?>? _widgetClickSubscription;

  /// Initialize home widget
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidget initialization error: $e');
    }
  }

  /// Update widget with current data from AppState
  /// Always uses the actual current month data, not the user's selected month
  static Future<void> updateWidget(AppState appState) async {
    try {
      // Get the current month data specifically for the widget
      // Use getCurrentMonthExpenses/Income instead of totalExpensesThisMonth
      // which is based on _selectedMonth and may not be the current month
      final now = DateTime.now();
      final totalExpenses = appState.getExpensesForMonth(now);
      final totalIncome = appState.getIncomeForMonth(now);
      final balance = totalIncome - totalExpenses;
      final currency = appState.currency;

      // Format the values
      final expensesFormatted = CurrencyHelper.formatAmount(totalExpenses, currency);
      final incomeFormatted = CurrencyHelper.formatAmount(totalIncome, currency);
      final balanceFormatted = CurrencyHelper.formatAmount(balance.abs(), currency);
      final isPositiveBalance = balance >= 0;

      // Get current month name
      final monthNames = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final monthName = monthNames[now.month - 1];

      // Save data to widget storage
      await HomeWidget.saveWidgetData<String>('month_name', monthName);
      await HomeWidget.saveWidgetData<String>('expenses', expensesFormatted);
      await HomeWidget.saveWidgetData<String>('income', incomeFormatted);
      await HomeWidget.saveWidgetData<String>('balance', '${isPositiveBalance ? '+' : '-'}$balanceFormatted');
      await HomeWidget.saveWidgetData<bool>('is_positive', isPositiveBalance);
      await HomeWidget.saveWidgetData<String>('currency', currency);

      // Update the widget using qualifiedAndroidName for reliable class resolution
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.moneytracker.app.$_androidWidgetName',
        iOSName: _iOSWidgetName,
      );

      if (kDebugMode) debugPrint('HomeWidget updated: Expenses=$expensesFormatted, Income=$incomeFormatted, Balance=$balanceFormatted');
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidget update error: $e');
    }
  }

  /// Clear widget data
  /// FIX: Accept optional currency parameter instead of hardcoding USD
  static Future<void> clearWidget({String currency = '\$'}) async {
    try {
      await HomeWidget.saveWidgetData<String>('month_name', '');
      await HomeWidget.saveWidgetData<String>('expenses', '${currency}0.00');
      await HomeWidget.saveWidgetData<String>('income', '${currency}0.00');
      await HomeWidget.saveWidgetData<String>('balance', '${currency}0.00');
      await HomeWidget.saveWidgetData<bool>('is_positive', true);
      await HomeWidget.saveWidgetData<String>('currency', currency);

      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.moneytracker.app.$_androidWidgetName',
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidget clear error: $e');
    }
  }

  /// Register callback for widget clicks (opens the app)
  /// Returns a subscription that should be cancelled when no longer needed
  static Future<void> registerInteractivityCallback(Function(Uri?) callback) async {
    try {
      // Cancel any existing subscription to prevent memory leaks
      await _widgetClickSubscription?.cancel();
      _widgetClickSubscription = HomeWidget.widgetClicked.listen(callback);
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidget callback registration error: $e');
    }
  }

  /// Cancel the widget click subscription to prevent memory leaks
  static Future<void> dispose() async {
    await _widgetClickSubscription?.cancel();
    _widgetClickSubscription = null;
  }
}
