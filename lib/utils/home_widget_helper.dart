import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../providers/app_state.dart';
import 'clock.dart';
import 'currency_helper.dart';
import 'pin_security_helper.dart';
import 'widget_payload.dart';

/// Keeps the Android home-screen widget (`BudgetWidgetProvider`) in sync with
/// the database, and decodes the launches its buttons start.
class HomeWidgetHelper {
  static const String _androidWidgetName = 'BudgetWidgetProvider';
  static const String _iOSWidgetName = 'BudgetWidget';
  static const String _appGroupId = 'group.com.budgettracker.widget';

  /// The quick-add buttons launch `financeflow://add?type=expense|income`.
  /// Must match `BudgetWidgetProvider.quickAddUri` on the native side.
  static const String _quickAddScheme = 'financeflow';
  static const String _quickAddHost = 'add';

  /// MainActivity's hand-off for widget taps (see [takeQuickAdd]).
  static const MethodChannel _launchChannel =
      MethodChannel('budget_tracker/widget_launch');

  /// Initialize home widget.
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidget initialization error: $e');
    }
  }

  /// Update widget with current data from AppState
  /// Always uses the actual current month data, not the user's selected month.
  ///
  /// FIX Bug #4: Reads totals directly from the database via
  /// [DatabaseHelper.calculateMonthBalance] instead of
  /// appState.getExpensesForMonth, which only scans the in-memory
  /// `_expenses` list. The in-memory list is subject to
  /// `_pruneDistantMonths` — after the user browses history and the app
  /// is backgrounded, the current month can be evicted from memory, and
  /// the widget would render `0.00` even though the DB has the data.
  ///
  /// Next month's figures are published too. The database only changes while
  /// the app runs, and every change re-publishes, so they stay exact; they
  /// let the widget turn the page at midnight on the 1st by itself instead of
  /// showing last month's numbers until the app is next opened.
  static Future<void> updateWidget(AppState appState) async {
    try {
      final now = Clock.instance.now();
      final thisMonth = DateTime(now.year, now.month);
      final nextMonth = DateTime(now.year, now.month + 1);
      final db = DatabaseHelper();
      final accountId = appState.currentAccountId;
      final currencyCode = appState.currencyCode;
      final symbol = appState.currency;

      final thisTotals = await db.calculateMonthBalance(
        accountId,
        thisMonth.year,
        thisMonth.month,
      );
      final nextTotals = await db.calculateMonthBalance(
        accountId,
        nextMonth.year,
        nextMonth.month,
      );
      final thisPaid = await db.calculateMonthPaid(
        accountId,
        thisMonth.year,
        thisMonth.month,
      );
      final nextPaid = await db.calculateMonthPaid(
        accountId,
        nextMonth.year,
        nextMonth.month,
      );
      // Mirror Home's "Total Balance" exactly (AppState.totalAvailableCash):
      // income + whatever was carried in - what has been PAID so far. With
      // Carry Over Balance on, everything carried into a month (all prior
      // income minus all prior expenses) is part of it; next month carries
      // this month's net on top.
      var carriedIntoThis = 0.0;
      var carriedIntoNext = 0.0;
      if (appState.carryoverEnabled) {
        final prior = await db.calculateNetBalanceBefore(
          accountId,
          DateTime.utc(thisMonth.year, thisMonth.month, 1),
        );
        carriedIntoThis = prior.income - prior.expenses;
        carriedIntoNext =
            carriedIntoThis + thisTotals.income - thisTotals.expenses;
      }

      // Phase 6.4: redact every monetary field when PIN protection is
      // enabled. The launcher widget renders even on the lock screen,
      // so unredacted data here would defeat the PIN gate entirely.
      // An unreadable secure store redacts too (fail closed).
      final pinEnabled = await PinSecurityHelper.isPinEnabled()
          .catchError((Object _) => true);
      WidgetData figures(
        DateTime month,
        ({double income, double expenses}) totals,
        double paid,
        double carriedIn,
      ) {
        return WidgetPayload.redactIfLocked(
          WidgetData(
            monthKey: monthKey(month),
            monthName: DateFormat.MMMM().format(month),
            balance: formatBalance(
              totals.income + carriedIn - paid,
              symbol,
              currencyCode,
            ),
            income: CurrencyHelper.formatWithSymbol(
              totals.income,
              symbol,
              currencyCode,
            ),
            expenses: CurrencyHelper.formatWithSymbol(
              totals.expenses,
              symbol,
              currencyCode,
            ),
          ),
          pinEnabled: pinEnabled,
        );
      }

      final fields = {
        ...figures(thisMonth, thisTotals, thisPaid, carriedIntoThis)
            .toWidgetFields(),
        ...figures(nextMonth, nextTotals, nextPaid, carriedIntoNext)
            .toWidgetFields(prefix: 'next_'),
        // BudgetWidgetProvider draws Purple's violet tile for 'purple'.
        'theme_mode': appState.themeMode,
      };
      for (final field in fields.entries) {
        await HomeWidget.saveWidgetData<String>(field.key, field.value);
      }

      // Update the widget using qualifiedAndroidName for reliable class resolution
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.moneytracker.app.$_androidWidgetName',
        iOSName: _iOSWidgetName,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('HomeWidget update error: $e');
    }
  }

  /// `yyyy-MM`, the form the native widget compares against the clock.
  @visibleForTesting
  static String monthKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

  /// The balance as Home prints it: `-$12.00` when negative, `$12.00`
  /// otherwise. Anything that rounds to zero prints as zero, never `-$0.00`.
  @visibleForTesting
  static String formatBalance(
    double balance,
    String symbol,
    String currencyCode,
  ) {
    final formatted =
        CurrencyHelper.formatWithSymbol(balance.abs(), symbol, currencyCode);
    return balance <= -0.005 ? '-$formatted' : formatted;
  }

  /// The transaction type a widget quick-add button asked for —
  /// `'expense'` or `'income'` — or null for any other launch (the widget
  /// body, or a launch that did not come from the widget at all).
  static String? quickAddType(Uri? uri) {
    if (uri == null ||
        uri.scheme != _quickAddScheme ||
        uri.host != _quickAddHost) {
      return null;
    }
    final type = uri.queryParameters['type'];
    return type == 'expense' || type == 'income' ? type : null;
  }

  /// Takes the widget quick-add tap MainActivity is holding, if any —
  /// `'expense'` or `'income'`. Each tap is handed out exactly once, so the
  /// startup, resume and nudge paths can all call this without double-opening
  /// the form.
  ///
  /// MainActivity holds the tap rather than relying on home_widget's launch
  /// stream: when Android has killed the backgrounded process, the tap
  /// arrives before Flutter is listening and the plugin drops it.
  static Future<String?> takeQuickAdd() async {
    try {
      final launch = await _launchChannel.invokeMethod<String>('takeLaunch');
      return quickAddType(launch == null ? null : Uri.tryParse(launch));
    } catch (e) {
      // No host activity (tests, desktop): there is never a pending tap.
      if (kDebugMode) debugPrint('Widget launch read error: $e');
      return null;
    }
  }

  /// Calls [onLaunch] whenever a widget tap arrives while the app is running
  /// (MainActivity nudges; the tap itself is then read with [takeQuickAdd]).
  /// Pass null to stop listening.
  static void listenForQuickAdds(VoidCallback? onLaunch) {
    _launchChannel.setMethodCallHandler(
      onLaunch == null
          ? null
          : (call) async {
              if (call.method == 'launched') onLaunch();
            },
    );
  }
}
