import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/recurring_expense_model.dart';
import '../models/budget_model.dart';
import 'clock.dart';
import 'date_helper.dart';
import 'notification_payload_store.dart';

/// Default time-of-day for bill reminders when the user hasn't set one.
const TimeOfDay _defaultReminderTime = TimeOfDay(hour: 9, minute: 0);

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const MethodChannel _deviceChannel =
      MethodChannel('budget_tracker/device_info');

  /// Points `tz.local` at the phone's zone. The timezone package starts on
  /// UTC, and a repeating reminder keeps its time of day in that location:
  /// on UTC it moved an hour against the wall clock at every DST change.
  /// Stays on UTC (the old behaviour) when the zone is unavailable.
  @visibleForTesting
  static Future<void> setLocalTimeZone() async {
    try {
      final name = await _deviceChannel.invokeMethod<String>('timeZone');
      if (name != null) tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      // No channel (tests) or an id the database does not know.
      if (kDebugMode) debugPrint('Local timezone unavailable: $e');
    }
  }

  // FIX P2-9: Use separate ID ranges to prevent notification ID collisions
  // Bill reminders: 10000-19999
  // Budget alerts: 20000-29999
  // Monthly summary: 9999 (reserved)
  static const int _billReminderIdBase = 10000;
  static const int _budgetAlertIdBase = 20000;

  // FIX Bug #6: Idempotency marker for end-of-month bill reminders.
  // Key: '<prefix><recurringId>', value: epoch millis of the scheduled reminder.
  // If the recurring processor re-runs and the next reminder epoch matches the
  // stored value, scheduling is skipped.
  static const String _eomBillKeyPrefix = 'eom_bill_scheduled_';

  String _eomBillKey(int expenseId) => '$_eomBillKeyPrefix$expenseId';

  // FIX P3-17: Notification channel configuration for localization support
  // These can be overridden by calling setChannelNames() before scheduling notifications
  // Default values are in English
  static String _billRemindersChannelName = 'Bill Reminders';
  static String _billRemindersChannelDesc = 'Reminders for upcoming bills';
  static String _budgetAlertsChannelName = 'Budget Alerts';
  static String _budgetAlertsChannelDesc =
      'Alerts when approaching or exceeding budgets';
  static String _monthlyReportsChannelName = 'Monthly Reports';
  static String _monthlyReportsChannelDesc = 'Monthly spending summaries';

  /// FIX P3-17: Set localized channel names for notifications.
  /// Call this method before scheduling notifications to use localized strings.
  static void setChannelNames({
    String? billRemindersName,
    String? billRemindersDesc,
    String? budgetAlertsName,
    String? budgetAlertsDesc,
    String? monthlyReportsName,
    String? monthlyReportsDesc,
  }) {
    if (billRemindersName != null) {
      _billRemindersChannelName = billRemindersName;
    }
    if (billRemindersDesc != null) {
      _billRemindersChannelDesc = billRemindersDesc;
    }
    if (budgetAlertsName != null) {
      _budgetAlertsChannelName = budgetAlertsName;
    }
    if (budgetAlertsDesc != null) {
      _budgetAlertsChannelDesc = budgetAlertsDesc;
    }
    if (monthlyReportsName != null) {
      _monthlyReportsChannelName = monthlyReportsName;
    }
    if (monthlyReportsDesc != null) {
      _monthlyReportsChannelDesc = monthlyReportsDesc;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    await setLocalTimeZone();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // M19: wire BOTH tap callbacks so notification taps are actually routed.
    // Foreground/just-resumed taps land in `onDidReceiveNotificationResponse`;
    // taps that wake a terminated app land in the background isolate handler.
    // Both persist the payload to `NotificationPayloadStore`, which the
    // foreground drains via `_checkPendingNotification` on resume.
    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        NotificationPayloadStore.storePendingPayload(response.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    _initialized = true;

    // A tap that LAUNCHED the app (it was not running) reaches neither
    // callback above — it only shows up in the launch details. Queue it the
    // same way so the reminder still opens the bills screen (after the PIN).
    try {
      final launch = await _notifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        await NotificationPayloadStore.storePendingPayload(
          launch!.notificationResponse?.payload,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Notification launch details failed: $e');
    }
  }

  Future<bool> areNotificationsEnabled() async {
    final bool? result = await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    return result ?? true;
  }

  /// Checks if exact alarms are allowed (Android 12+ requires special permission).
  /// Returns true on other platforms or if permission is granted.
  Future<bool> canScheduleExactAlarms() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // Not on Android

    // On Android 12+ (API 31+), check if exact alarms are allowed
    final canSchedule = await android.canScheduleExactNotifications();
    return canSchedule ?? true;
  }

  /// Requests exact alarm permission on Android 12+.
  /// Opens system settings where user can grant the permission.
  Future<void> requestExactAlarmPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.requestExactAlarmsPermission();
  }

  // Request permissions (iOS and Android)
  Future<bool> requestPermissions() async {
    // iOS permissions
    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return result ?? true;
    }

    // Android notification permission (Android 13+)
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final result = await android.requestNotificationsPermission();
      return result ?? true;
    }

    return true;
  }

  // ========== BILL REMINDERS ==========

  Future<void> scheduleBillReminder(
    RecurringExpense expense, {
    String currencySymbol = '\$',
    TimeOfDay reminderTime = _defaultReminderTime,
  }) async {
    final expenseId = expense.id;
    if (expenseId == null) return;
    // Paused, past its end date, or out of occurrences: make sure nothing
    // keeps firing (repeating reminders used to outlive the bill).
    if (!expense.shouldBeActive) {
      await cancelBillReminder(expenseId);
      return;
    }

    await initialize();

    // Check if we can schedule exact alarms; fall back to inexact if not
    final canUseExact = await canScheduleExactAlarms();

    final now = Clock.instance.now();

    // The reminder goes off the day before the due date, at the user's
    // reminder time. Take the first occurrence whose reminder is still ahead,
    // comparing the full reminder TIME: comparing midnight skipped today's
    // reminder whenever the app was opened before it fired. nextDueDate is
    // frequency-aware — a weekly bill's weekday (0-6) used to be read as a
    // day of the month.
    DateTime reminderFor(DateTime due) => DateTime(
          due.year,
          due.month,
          due.day - 1,
          reminderTime.hour,
          reminderTime.minute,
        );
    var dueDate = expense.nextDueDate(now);
    if (dueDate != null && !reminderFor(dueDate).isAfter(now)) {
      dueDate = expense.nextDueDate(DateHelper.addDays(dueDate, 1));
    }
    if (dueDate == null) {
      await cancelBillReminder(expenseId);
      return;
    }
    final scheduledFor = reminderFor(dueDate);

    // FIX: Bills due on the 29th-31st can't use a repeating notification:
    // DateTimeComponents.dayOfMonthAndTime silently fails in short months.
    // Neither can a bill due on the 1st (its reminder lands on the 28th-31st
    // of the month before) or a biweekly one (no 14-day repeat exists). Those
    // are booked one occurrence at a time and re-booked after each
    // recurring-processor run (rescheduleOneShotBillReminders).
    final isOneShot = isOneShotReminder(expense);
    // FIX P3-17: Use localized channel names
    final billReminderDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'bill_reminders',
        _billRemindersChannelName,
        channelDescription: _billRemindersChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        // FIX Phase 1.10: redact body text on a secure lock screen so
        // the bill description + amount aren't shoulder-surfable.
        // On Android, `visibility: private` defers to the user's
        // system-wide lock-screen privacy setting — when "Hide
        // sensitive content" is on the OS shows a generic
        // placeholder instead of the description + amount.
        visibility: NotificationVisibility.private,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    if (isOneShot) {
      // One-time notification for next occurrence only

      // FIX Bug #6: Idempotency — skip if this exact reminder is already
      // scheduled. `rescheduleOneShotBillReminders` calls this on every
      // recurring-processor run; without the skip we would cancel+rebook the
      // same notification on every app start.
      // M20: the user's configured reminder time (in scheduledFor).
      final reminderEpoch = scheduledFor.millisecondsSinceEpoch;
      final prefs = await SharedPreferences.getInstance();
      final storedEpoch = prefs.getInt(_eomBillKey(expenseId));
      if (storedEpoch == reminderEpoch) {
        // Already booked for this occurrence — nothing to do.
        return;
      }

      // Cancel any prior schedule for this recurring (may be stale) before
      // booking the fresh one. Prevents leftover notifications from an earlier
      // due date still being delivered.
      await _notifications.cancel(id: _billReminderIdBase + expenseId);

      // FIX P2-9: Use separate ID range to prevent collision with budget alerts
      await _notifications.zonedSchedule(
        id: _billReminderIdBase + expenseId,
        title: '💡 Bill Reminder',
        body:
            '${expense.description} ($currencySymbol${expense.amount.toStringAsFixed(2)}) due tomorrow',
        scheduledDate: tz.TZDateTime.from(scheduledFor, tz.local),
        notificationDetails: billReminderDetails,
        androidScheduleMode: canUseExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        // M19: route taps to the recurring-items screen.
        payload: 'recurring_expenses',
        // NO matchDateTimeComponents - this is a one-time notification
      );

      // Persist the booked reminder epoch so the next call can skip if the
      // value is unchanged.
      await prefs.setInt(_eomBillKey(expenseId), reminderEpoch);
    } else {
      // Repeating notification: weekly bills repeat on the weekday, monthly
      // bills due on the 2nd-28th on the day of the month (their reminder
      // day, 1st-27th, exists in every month).
      // FIX P2-9: Use separate ID range to prevent collision with budget alerts
      await _notifications.zonedSchedule(
        id: _billReminderIdBase + expenseId,
        title: '💡 Bill Reminder',
        body:
            '${expense.description} ($currencySymbol${expense.amount.toStringAsFixed(2)}) due tomorrow',
        // M20: honor the user's configured reminder time instead of 09:00.
        scheduledDate: tz.TZDateTime.from(scheduledFor, tz.local),
        notificationDetails: billReminderDetails,
        androidScheduleMode: canUseExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        // M19: route taps to the recurring-items screen.
        payload: 'recurring_expenses',
        matchDateTimeComponents:
            expense.frequency == RecurringExpenseFrequency.weekly
                ? DateTimeComponents.dayOfWeekAndTime
                : DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  /// Reminders that cannot repeat natively and are booked one occurrence at
  /// a time: biweekly bills (no 14-day repeat exists) and monthly bills due
  /// on the 1st (the reminder lands on the 28th-31st of the month before) or
  /// on the 29th-31st (missing from short months).
  @visibleForTesting
  static bool isOneShotReminder(RecurringExpense expense) {
    switch (expense.frequency) {
      case RecurringExpenseFrequency.biweekly:
        return true;
      case RecurringExpenseFrequency.weekly:
        return false;
      case RecurringExpenseFrequency.monthly:
        return expense.dayOfMonth == 1 || expense.dayOfMonth >= 29;
    }
  }

  Future<void> cancelBillReminder(int expenseId) async {
    // FIX P2-9: Use the correct ID range for bill reminders
    await _notifications.cancel(id: _billReminderIdBase + expenseId);

    // FIX Bug #6: Also clear the end-of-month idempotency marker so a
    // subsequent `scheduleBillReminder` call is not short-circuited by a
    // stale stored epoch.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eomBillKey(expenseId));
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to clear EOM bill marker: $e');
    }
  }

  /// FIX Bug #6: Re-book the one-shot bill reminders ([isOneShotReminder]),
  /// and cancel the reminders of bills that have ended.
  ///
  /// One-shot reminders cover a single occurrence. Call this after
  /// `_processRecurringExpenses` completes so that once a scheduled
  /// notification has fired (and the generator created the corresponding
  /// transaction), the next occurrence's reminder is queued up. A bill past
  /// its end date or out of occurrences still reads `isActive`, so its
  /// repeating reminder is cancelled here — it used to fire forever.
  ///
  /// Idempotent: if `scheduleBillReminder` sees the same reminder epoch
  /// already stored in SharedPreferences, it no-ops. So calling this on
  /// every recurring-processor run is safe and cheap.
  Future<void> rescheduleOneShotBillReminders(
    List<RecurringExpense> recurringExpenses, {
    String currencySymbol = '\$',
    TimeOfDay reminderTime = _defaultReminderTime,
  }) async {
    if (recurringExpenses.isEmpty) return;
    await initialize();
    for (final recurring in recurringExpenses) {
      try {
        final id = recurring.id;
        if (id == null) continue;
        if (!recurring.shouldBeActive) {
          await cancelBillReminder(id);
          continue;
        }
        if (!isOneShotReminder(recurring)) continue;
        await scheduleBillReminder(
          recurring,
          currencySymbol: currencySymbol,
          reminderTime: reminderTime,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Failed to reschedule EOM reminder for recurring ${recurring.id}: $e',
          );
        }
      }
    }
  }

  // ========== BUDGET ALERTS ==========

  Future<void> showBudgetAlert(
    Budget budget,
    double spent,
    double percentage, {
    String currencySymbol = '\$',
  }) async {
    await initialize();

    String title;
    String body;
    // FIX P2-9: Use separate ID range to prevent collision with bill reminders
    int notificationId = _budgetAlertIdBase + (budget.id ?? 0);

    if (percentage >= 1.0) {
      title = '🚨 Budget Exceeded!';
      body =
          '${budget.category} budget exceeded! Spent: $currencySymbol${spent.toStringAsFixed(2)} of $currencySymbol${budget.amount.toStringAsFixed(2)}';
    } else if (percentage >= 0.9) {
      title = '⚠️ Budget Alert';
      body =
          '${budget.category} at ${(percentage * 100).toInt()}%! Only $currencySymbol${(budget.amount - spent).toStringAsFixed(2)} left';
    } else if (percentage >= 0.8) {
      title = '💡 Budget Warning';
      body =
          '${budget.category} at ${(percentage * 100).toInt()}%. $currencySymbol${(budget.amount - spent).toStringAsFixed(2)} remaining';
    } else {
      return; // Don't notify if under 80%
    }

    // FIX P3-17: Use localized channel names
    await _notifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alerts',
          _budgetAlertsChannelName,
          channelDescription: _budgetAlertsChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          // FIX Phase 1.10: see billReminderDetails — redacts the
          // "spent $X of $Y" body on a secure lock screen.
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // M19: route taps to the budgets view.
      payload: 'budget_alert:${budget.id ?? 0}',
    );
  }

  // ========== MONTHLY SUMMARY ==========

  Future<void> scheduleMonthlyReports() async {
    await initialize();

    // Check if we can schedule exact alarms
    final canUseExact = await canScheduleExactAlarms();

    // Schedule for 1st of next month at 9 AM
    final now = Clock.instance.now();
    var scheduledDate = DateTime(now.year, now.month + 1, 1, 9, 0);

    // If for some reason that calculation resulted in a past time (unlikely given +1 month), fix it
    if (scheduledDate.isBefore(now)) {
      scheduledDate = DateTime(now.year, now.month + 2, 1, 9, 0);
    }

    // FIX P3-17: Use localized channel names
    await _notifications.zonedSchedule(
      id: 9999, // Unique ID for monthly reports
      title: '📊 Monthly Summary',
      body: 'Your spending report is ready!',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'monthly_reports',
          _monthlyReportsChannelName,
          channelDescription: _monthlyReportsChannelDesc,
          importance: Importance.defaultImportance,
          // FIX Phase 1.10: monthly report scheduling carries no
          // numbers in the body ("Your spending report is ready!")
          // but redact for consistency in case the body changes.
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Use exact alarms if permitted, otherwise fall back to inexact
      androidScheduleMode: canUseExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> cancelMonthlyReports() async {
    await _notifications.cancel(id: 9999);
  }

  Future<void> showMonthlySummary(double totalSpent, double budget, {String currencySymbol = '\$'}) async {
    await initialize();

    final percentage = budget > 0 ? (totalSpent / budget * 100).toInt() : 0;
    final status = totalSpent <= budget ? '✅' : '⚠️';

    // FIX P3-17: Use localized channel names
    await _notifications.show(
      id: 9999,
      title: '📊 Monthly Summary',
      body:
          '$status Spent $currencySymbol${totalSpent.toStringAsFixed(2)} ($percentage% of budget)',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'monthly_reports',
          _monthlyReportsChannelName,
          channelDescription: _monthlyReportsChannelDesc,
          importance: Importance.defaultImportance,
          // FIX Phase 1.10: this body has the exact spend + budget
          // dollar values — strict candidate for lock-screen redaction.
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ========== UTILITY ==========

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
