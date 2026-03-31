import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import '../providers/app_state.dart';
import '../utils/notification_helper.dart';
import '../constants/spacing.dart';
import '../main.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _permissionGranted = true;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    // Register observer to detect when user returns from system settings
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    // Unregister observer to prevent memory leaks
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app resumes (user returns from Settings or another app),
    // re-check notification permission status to update the UI
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  Future<void> _checkPermissionStatus() async {
    final granted = await NotificationHelper().areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
        _checkingPermission = false;
      });
    }
  }

  // FIX #2: Request notification permission when enabling any notification
  Future<void> _handleNotificationToggle(
    bool value,
    Future<void> Function(bool) toggle,
  ) async {
    if (value && !_permissionGranted) {
      // Request permission first
      final granted = await NotificationHelper().requestPermissions();

      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notification permission is required'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  // Open app notification settings directly
                  AppSettings.openAppSettings(
                    type: AppSettingsType.notification,
                  );
                },
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _permissionGranted = true);
      }
    }

    await toggle(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Select only the notification fields rendered in this build method
    final (
      billRemindersEnabled,
      budgetAlertsEnabled,
      monthlySummaryEnabled,
      reminderTime,
    ) = context.select<AppState, (bool, bool, bool, TimeOfDay)>(
      (s) => (
        s.billRemindersEnabled,
        s.budgetAlertsEnabled,
        s.monthlySummaryEnabled,
        s.reminderTime,
      ),
    );
    final appState = context.read<AppState>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.screenPadding),
        children: [
          // Permission Warning Card (if not granted)
          if (!_checkingPermission && !_permissionGranted) ...[
            Builder(
              builder: (context) {
                final appColors = Theme.of(context).extension<AppColors>()!;
                return Container(
                  padding: const EdgeInsets.all(Spacing.md),
                  decoration: BoxDecoration(
                    color: appColors.warningOrange.withAlpha(30),
                    borderRadius: BorderRadius.circular(Spacing.radiusLarge),
                    border: Border.all(color: appColors.warningOrange.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: appColors.warningOrange),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications Disabled',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: Spacing.xxs),
                            Text(
                              'Enable notifications to receive alerts',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          // First try to request permission via the system dialog
                          final granted =
                              await NotificationHelper().requestPermissions();
                          if (granted) {
                            if (mounted) {
                              setState(() => _permissionGranted = true);
                            }
                          } else {
                            // If denied, open app settings directly
                            AppSettings.openAppSettings(
                              type: AppSettingsType.notification,
                            );
                          }
                        },
                        child: const Text('Enable'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: Spacing.md),
          ],

          // Info Card
          Builder(
            builder: (context) {
              final appColors = Theme.of(context).extension<AppColors>()!;
              return Container(
                padding: const EdgeInsets.all(Spacing.cardPadding),
                decoration: BoxDecoration(
                  color: appColors.infoBlue.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(Spacing.radiusLarge),
                  border: Border.all(
                    color: appColors.infoBlue.withAlpha((255 * 0.3).round()),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: appColors.infoBlue),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Text(
                        'All notifications are local and work offline',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: Spacing.screenPadding),

          // Bill Reminders
          _NotificationCard(
            icon: Icons.notifications_outlined,
            title: 'Bill Reminders',
            subtitle: 'Get notified 1 day before recurring bills are due',
            value: billRemindersEnabled,
            onChanged: (value) =>
                _handleNotificationToggle(value, appState.toggleBillReminders),
          ),

          const SizedBox(height: Spacing.sm),

          // Budget Alerts
          _NotificationCard(
            icon: Icons.warning_amber_outlined,
            title: 'Budget Alerts',
            subtitle: 'Notifications at 80%, 90%, and 100% of budget',
            value: budgetAlertsEnabled,
            onChanged: (value) =>
                _handleNotificationToggle(value, appState.toggleBudgetAlerts),
          ),

          const SizedBox(height: 12),

          // Monthly Summary
          _NotificationCard(
            icon: Icons.bar_chart_outlined,
            title: 'Monthly Summary',
            subtitle: 'Get a spending summary on the 1st of each month',
            value: monthlySummaryEnabled,
            onChanged: (value) =>
                _handleNotificationToggle(value, appState.toggleMonthlySummary),
          ),

          const SizedBox(height: Spacing.screenPadding),

          // Reminder Time
          Text(
            'REMINDER TIME',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),

          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(Spacing.radiusLarge),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: ListTile(
              leading: Icon(
                Icons.access_time,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('Default reminder time'),
              subtitle: Text(
                reminderTime.format(context),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: reminderTime,
                );
                if (time != null) {
                  await appState.setReminderTime(time);
                }
              },
            ),
          ),

          const SizedBox(height: Spacing.screenPadding),

          // Test Notification Button
          Text(
            'TEST',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),

          Builder(
            builder: (context) {
              final appColors = Theme.of(context).extension<AppColors>()!;
              return Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Spacing.radiusLarge),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(Spacing.xs),
                    decoration: BoxDecoration(
                      color: appColors.infoBlue.withAlpha((255 * 0.1).round()),
                      borderRadius: BorderRadius.circular(Spacing.radiusSmall),
                    ),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      color: appColors.infoBlue,
                    ),
                  ),
                  title: const Text('Send Test Notification'),
                  subtitle: const Text('Verify notifications are working'),
                  trailing: const Icon(Icons.send_outlined),
                  onTap: () async {
                    // Send a test notification
                    try {
                      await NotificationHelper().showMonthlySummary(
                        1234.56,
                        1500.00,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Test notification sent! Check your notification shade.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        final errorAppColors = Theme.of(context).extension<AppColors>()!;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to send notification: $e'),
                            backgroundColor: errorAppColors.expenseRed,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                ),
              );
            },
          ),

          const SizedBox(height: Spacing.screenPadding),

          // Examples Section
          Text(
            'EXAMPLES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),

          _ExampleNotification(
            icon: Icons.notifications,
            title: '💡 Bill Reminder',
            message: 'Netflix (\$15.99) due tomorrow',
            time: appState.reminderTime.format(context),
          ),

          const SizedBox(height: Spacing.xs),

          Builder(
            builder: (context) {
              final appColors = Theme.of(context).extension<AppColors>()!;
              return _ExampleNotification(
                icon: Icons.warning_amber,
                title: '⚠️ Budget Alert',
                message: 'Food budget at 92%\n\$40 left for month',
                time: 'When limit reached',
                progress: 0.92,
                progressColor: appColors.warningOrange,
              );
            },
          ),

          const SizedBox(height: Spacing.xs),

          const _ExampleNotification(
            icon: Icons.bar_chart,
            title: '📊 Monthly Summary',
            message: 'November spending: \$4,250',
            time: '1st of month at 9:00 AM',
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Spacing.radiusLarge),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(Spacing.xs),
          decoration: BoxDecoration(
            color: value
                ? theme.colorScheme.primary.withAlpha((255 * 0.1).round())
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(Spacing.radiusSmall),
          ),
          child: Icon(
            icon,
            color: value
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeTrackColor: theme.colorScheme.primary,
      ),
    );
  }
}

class _ExampleNotification extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String time;
  final double? progress;
  final Color? progressColor;

  const _ExampleNotification({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    this.progress,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Spacing.radiusMedium),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: Spacing.xs),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xxs),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: Spacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: progressColor ?? theme.colorScheme.primary,
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
