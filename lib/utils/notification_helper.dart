import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/recurring_expense_model.dart';
import '../models/budget_model.dart';

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // FIX P2-9: Use separate ID ranges to prevent notification ID collisions
  // Bill reminders: 10000-19999
  // Budget alerts: 20000-29999
  // Monthly summary: 9999 (reserved)
  static const int _billReminderIdBase = 10000;
  static const int _budgetAlertIdBase = 20000;

  // FIX P3-17: Notification channel configuration for localization support
  // These can be overridden by calling setChannelNames() before scheduling notifications
  // Default values are in English
  static String _billRemindersChannelName = 'Bill Reminders';
  static String _billRemindersChannelDesc = 'Reminders for upcoming bills';
  static String _budgetAlertsChannelName = 'Budget Alerts';
  static String _budgetAlertsChannelDesc = 'Alerts when approaching or exceeding budgets';
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
    if (billRemindersName != null) _billRemindersChannelName = billRemindersName;
    if (billRemindersDesc != null) _billRemindersChannelDesc = billRemindersDesc;
    if (budgetAlertsName != null) _budgetAlertsChannelName = budgetAlertsName;
    if (budgetAlertsDesc != null) _budgetAlertsChannelDesc = budgetAlertsDesc;
    if (monthlyReportsName != null) _monthlyReportsChannelName = monthlyReportsName;
    if (monthlyReportsDesc != null) _monthlyReportsChannelDesc = monthlyReportsDesc;
  }

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _initialized = true;
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
    final ios = _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final result = await ios.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? true;
    }

    // Android notification permission (Android 13+)
    final android = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final result = await android.requestNotificationsPermission();
      return result ?? true;
    }

    return true;
  }

  // ========== BILL REMINDERS ==========

  Future<void> scheduleBillReminder(RecurringExpense expense) async {
    if (!expense.isActive || expense.id == null) return;

    await initialize();

    // Check if we can schedule exact alarms; fall back to inexact if not
    final canUseExact = await canScheduleExactAlarms();

    final now = DateTime.now();

    // FIX: For bills on 29th-31st, don't use repeating notifications
    // because DateTimeComponents.dayOfMonthAndTime will silently fail in short months
    // Instead, schedule only for the next occurrence
    final isEndOfMonthBill = expense.dayOfMonth >= 29;

    // Calculate due date for current month
    // Handle days that don't exist in current month (e.g. 31st in Feb)
    int day = expense.dayOfMonth;
    int maxDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    if (day > maxDaysInMonth) day = maxDaysInMonth;

    var dueDate = DateTime(now.year, now.month, day);
    var reminderDate = dueDate.subtract(const Duration(days: 1));

    // If reminder time has passed for this month, move to next month
    if (reminderDate.isBefore(now)) {
      // Calculate for next month
      int nextMonth = now.month + 1;
      int year = now.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        year++;
      }

      int maxDaysInNextMonth = DateTime(year, nextMonth + 1, 0).day;
      int nextMonthDay = expense.dayOfMonth;
      if (nextMonthDay > maxDaysInNextMonth) nextMonthDay = maxDaysInNextMonth;

      dueDate = DateTime(year, nextMonth, nextMonthDay);
      reminderDate = dueDate.subtract(const Duration(days: 1));
    }

    // FIX: For end-of-month bills, use one-time notification (no repeat)
    // For regular bills, use monthly repeat
    // FIX P3-17: Use localized channel names
    final billReminderDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'bill_reminders',
        _billRemindersChannelName,
        channelDescription: _billRemindersChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    if (isEndOfMonthBill) {
      // One-time notification for next occurrence only
      final expenseId = expense.id;
      if (expenseId == null) return; // Cannot schedule without ID
      // FIX P2-9: Use separate ID range to prevent collision with budget alerts
      await _notifications.zonedSchedule(
        _billReminderIdBase + expenseId,
        '💡 Bill Reminder',
        '${expense.description} (\$${expense.amount.toStringAsFixed(2)}) due tomorrow',
        tz.TZDateTime.from(reminderDate.copyWith(hour: 9, minute: 0), tz.local),
        billReminderDetails,
        androidScheduleMode: canUseExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        // NO matchDateTimeComponents - this is a one-time notification
      );

      // NOTE: For recurring end-of-month bills, the notification will need to be
      // rescheduled after each occurrence. This can be done when the app processes
      // recurring transactions monthly.
    } else {
      // Regular monthly repeating notification (safe for days 1-28)
      final expenseId = expense.id;
      if (expenseId == null) return; // Cannot schedule without ID
      // FIX P2-9: Use separate ID range to prevent collision with budget alerts
      await _notifications.zonedSchedule(
        _billReminderIdBase + expenseId,
        '💡 Bill Reminder',
        '${expense.description} (\$${expense.amount.toStringAsFixed(2)}) due tomorrow',
        tz.TZDateTime.from(reminderDate.copyWith(hour: 9, minute: 0), tz.local),
        billReminderDetails,
        androidScheduleMode: canUseExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  Future<void> cancelBillReminder(int expenseId) async {
    // FIX P2-9: Use the correct ID range for bill reminders
    await _notifications.cancel(_billReminderIdBase + expenseId);
  }

  // ========== BUDGET ALERTS ==========

  Future<void> showBudgetAlert(Budget budget, double spent, double percentage) async {
    await initialize();

    String title;
    String body;
    // FIX P2-9: Use separate ID range to prevent collision with bill reminders
    int notificationId = _budgetAlertIdBase + (budget.id ?? 0);

    if (percentage >= 1.0) {
      title = '🚨 Budget Exceeded!';
      body = '${budget.category} budget exceeded! Spent: \$${spent.toStringAsFixed(2)} of \$${budget.amount.toStringAsFixed(2)}';
    } else if (percentage >= 0.9) {
      title = '⚠️ Budget Alert';
      body = '${budget.category} at ${(percentage * 100).toInt()}%! Only \$${(budget.amount - spent).toStringAsFixed(2)} left';
    } else if (percentage >= 0.8) {
      title = '💡 Budget Warning';
      body = '${budget.category} at ${(percentage * 100).toInt()}%. \$${(budget.amount - spent).toStringAsFixed(2)} remaining';
    } else {
      return; // Don't notify if under 80%
    }

    // FIX P3-17: Use localized channel names
    await _notifications.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'budget_alerts',
          _budgetAlertsChannelName,
          channelDescription: _budgetAlertsChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ========== MONTHLY SUMMARY ==========

  Future<void> scheduleMonthlyReports() async {
    await initialize();

    // Check if we can schedule exact alarms
    final canUseExact = await canScheduleExactAlarms();

    // Schedule for 1st of next month at 9 AM
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month + 1, 1, 9, 0);
    
    // If for some reason that calculation resulted in a past time (unlikely given +1 month), fix it
    if (scheduledDate.isBefore(now)) {
       scheduledDate = DateTime(now.year, now.month + 2, 1, 9, 0);
    }

    // FIX P3-17: Use localized channel names
    await _notifications.zonedSchedule(
      9999, // Unique ID for monthly reports
      '📊 Monthly Summary',
      'Your spending report is ready!',
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'monthly_reports',
          _monthlyReportsChannelName,
          channelDescription: _monthlyReportsChannelDesc,
          importance: Importance.defaultImportance,
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
    await _notifications.cancel(9999);
  }

  Future<void> showMonthlySummary(double totalSpent, double budget) async {
    await initialize();

    final percentage = budget > 0 ? (totalSpent / budget * 100).toInt() : 0;
    final status = totalSpent <= budget ? '✅' : '⚠️';

    // FIX P3-17: Use localized channel names
    await _notifications.show(
      9999,
      '📊 Monthly Summary',
      '$status Spent \$${totalSpent.toStringAsFixed(2)} ($percentage% of budget)',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'monthly_reports',
          _monthlyReportsChannelName,
          channelDescription: _monthlyReportsChannelDesc,
          importance: Importance.defaultImportance,
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
