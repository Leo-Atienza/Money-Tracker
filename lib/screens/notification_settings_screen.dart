import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_settings/app_settings.dart';
import '../providers/app_state.dart';
import '../utils/notification_helper.dart';
import '../theme/app_colors.dart';
import '../theme/luminous_tokens.dart';
import '../widgets/luminous/glass_list_section.dart';
import '../widgets/luminous/glass_list_tile.dart';
import '../widgets/luminous/glass_panel.dart';
import '../widgets/luminous/glass_top_app_bar.dart';

/// Phase 5.9j — Notification Settings Luminous redesign.
///
/// Composition:
///   * [GlassTopAppBar] header ("Notifications") with BackButton leading.
///   * Permission warning + info banners wrapped in [GlassPanel].
///   * Toggles grouped into a single [GlassListSection] ("Alerts").
///   * Reminder Time + Test action in their own [GlassListSection]s.
///   * Example notifications shown as plain [GlassPanel]s with the same
///     inner content as before (icon · title · body · progress).
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

  /// Phase 2.7: resolve the helper once via `AppState` so tests can swap in a
  /// fake AppState with a mock helper.
  late final NotificationHelper _helper =
      context.read<AppState>().notificationHelper;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  Future<void> _checkPermissionStatus() async {
    final granted = await _helper.areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
        _checkingPermission = false;
      });
    }
  }

  Future<void> _handleNotificationToggle(
    bool value,
    Future<void> Function(bool) toggle,
  ) async {
    if (value && !_permissionGranted) {
      final granted = await _helper.requestPermissions();

      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Notification permission is required'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
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
    final appColors = theme.extension<AppColors>()!;

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
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTopAppBar(
            leading: BackButton(color: theme.colorScheme.onSurface),
            title: 'Notifications',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                LuminousTokens.containerPadding,
                LuminousTokens.stackGap,
                LuminousTokens.containerPadding,
                LuminousTokens.sectionMargin,
              ),
              children: [
                if (!_checkingPermission && !_permissionGranted) ...[
                  GlassPanel(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: appColors.warningOrange),
                        const SizedBox(width: 16),
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
                              const SizedBox(height: 4),
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
                            final granted = await _helper.requestPermissions();
                            if (granted) {
                              if (mounted) {
                                setState(() => _permissionGranted = true);
                              }
                            } else {
                              AppSettings.openAppSettings(
                                type: AppSettingsType.notification,
                              );
                            }
                          },
                          child: const Text('Enable'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Info banner
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: appColors.infoBlue),
                      const SizedBox(width: 16),
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
                ),
                const SizedBox(height: LuminousTokens.sectionMargin),

                // Alerts
                GlassListSection(
                  title: 'Alerts',
                  children: [
                    GlassListTile(
                      icon: Icons.notifications_outlined,
                      label: 'Bill Reminders',
                      sublabel:
                          'Get notified 1 day before recurring bills are due',
                      trailing: Switch(
                        value: billRemindersEnabled,
                        onChanged: (v) => _handleNotificationToggle(
                            v, appState.toggleBillReminders),
                      ),
                    ),
                    GlassListTile(
                      icon: Icons.warning_amber_outlined,
                      label: 'Budget Alerts',
                      sublabel:
                          'Notifications at 80%, 90%, and 100% of budget',
                      trailing: Switch(
                        value: budgetAlertsEnabled,
                        onChanged: (v) => _handleNotificationToggle(
                            v, appState.toggleBudgetAlerts),
                      ),
                    ),
                    GlassListTile(
                      icon: Icons.bar_chart_outlined,
                      label: 'Monthly Summary',
                      sublabel:
                          'Get a spending summary on the 1st of each month',
                      trailing: Switch(
                        value: monthlySummaryEnabled,
                        onChanged: (v) => _handleNotificationToggle(
                            v, appState.toggleMonthlySummary),
                      ),
                    ),
                  ],
                ),

                // Reminder time
                GlassListSection(
                  title: 'Reminder Time',
                  children: [
                    GlassListTile(
                      icon: Icons.access_time,
                      label: 'Default reminder time',
                      value: reminderTime.format(context),
                      chevron: true,
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
                  ],
                ),

                // Test
                GlassListSection(
                  title: 'Test',
                  children: [
                    GlassListTile(
                      icon: Icons.notifications_active_outlined,
                      iconColor: appColors.infoBlue,
                      label: 'Send Test Notification',
                      sublabel: 'Verify notifications are working',
                      trailing: Icon(
                        Icons.send_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onTap: () async {
                        try {
                          await _helper.showMonthlySummary(1234.56, 1500.00);
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
                            final errorAppColors =
                                Theme.of(context).extension<AppColors>()!;
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
                  ],
                ),

                // Examples header
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'EXAMPLES',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _ExampleNotification(
                  icon: Icons.notifications,
                  title: '💡 Bill Reminder',
                  message: 'Netflix (\$15.99) due tomorrow',
                  time: reminderTime.format(context),
                ),
                const SizedBox(height: 8),
                _ExampleNotification(
                  icon: Icons.warning_amber,
                  title: '⚠️ Budget Alert',
                  message: 'Food budget at 92%\n\$40 left for month',
                  time: 'When limit reached',
                  progress: 0.92,
                  progressColor: appColors.warningOrange,
                ),
                const SizedBox(height: 8),
                const _ExampleNotification(
                  icon: Icons.bar_chart,
                  title: '📊 Monthly Summary',
                  message: 'November spending: \$4,250',
                  time: '1st of month at 9:00 AM',
                ),
              ],
            ),
          ),
        ],
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

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
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
