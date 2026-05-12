import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/account_model.dart';
import '../utils/currency_helper.dart';
import '../utils/dialog_helpers.dart';
import '../utils/progress_indicator_helper.dart';
import '../utils/premium_animations.dart';
import 'recurring_items_screen.dart';
import 'category_manager_screen.dart';
import 'quick_templates_screen.dart';
import 'trash_screen.dart';
import 'notification_settings_screen.dart';
import 'analytics_screen.dart';
import 'backup_restore_screen.dart';
import 'budget_screen.dart';
import 'pin_setup_screen.dart';
import 'export_data_screen.dart';
import 'crash_log_screen.dart';
import '../utils/pin_security_helper.dart';
import '../theme/app_colors.dart';
import '../theme/luminous_tokens.dart';
import '../widgets/luminous/glass_list_section.dart';
import '../widgets/luminous/glass_list_tile.dart';
import '../widgets/luminous/glass_panel.dart';
import '../widgets/luminous/glass_top_app_bar.dart';

/// Settings & Security — Luminous redesign (Phase 5.1).
///
/// Composition:
///   * [GlassTopAppBar] header ("Settings & Security")
///   * [GlassListSection] per logical group (Accounts, Appearance, Security,
///     Preferences, Insights, Data & Backup, Notifications, Advanced)
///   * [GlassListTile] for every settings row
///
/// The dialog/modal helpers (theme picker, currency picker, account picker,
/// account-options menu, reset/delete confirmation) are kept intact —
/// `AlertDialog` + `showModalBottomSheet` shells inherit Luminous styling from
/// the global theme; reskinning them belongs to a follow-up if needed.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    // Select only the fields rendered in this build to avoid unnecessary
    // rebuilds when unrelated AppState fields change.
    final (
      currentAccountName,
      themeMode,
      showTransactionColors,
      transactionColorIntensity,
      currencyCode,
      currency,
    ) =
        context.select<AppState, (String, String, bool, double, String, String)>(
      (s) => (
        s.currentAccount?.name ?? 'Main Account',
        s.themeMode,
        s.showTransactionColors,
        s.transactionColorIntensity,
        s.currencyCode,
        s.currency,
      ),
    );
    final appState = context.read<AppState>();

    final themeSubtitle = themeMode == 'light'
        ? 'Light'
        : themeMode == 'dark'
            ? 'Dark'
            : 'Follow System';
    final themeIcon = themeMode == 'light'
        ? Icons.light_mode
        : themeMode == 'dark'
            ? Icons.dark_mode
            : Icons.brightness_auto;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GlassTopAppBar(title: 'Settings & Security'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    LuminousTokens.containerPadding,
                    LuminousTokens.stackGap,
                    LuminousTokens.containerPadding,
                    100,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ACCOUNTS
                      GlassListSection(
                        title: 'Accounts',
                        children: [
                          GlassListTile(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Current Account',
                            sublabel: currentAccountName,
                            chevron: true,
                            onTap: () => _showAccountPicker(context),
                          ),
                        ],
                      ),

                      // APPEARANCE
                      GlassListSection(
                        title: 'Appearance',
                        children: [
                          GlassListTile(
                            icon: themeIcon,
                            label: 'Theme',
                            sublabel: themeSubtitle,
                            chevron: true,
                            onTap: () => _showThemePicker(context),
                          ),
                          GlassListTile(
                            icon: Icons.palette_outlined,
                            label: 'Transaction Colors',
                            sublabel: showTransactionColors
                                ? 'Category colors shown on cards'
                                : 'Clean white/dark cards',
                            trailing: Switch(
                              value: showTransactionColors,
                              onChanged: (value) =>
                                  appState.toggleShowTransactionColors(value),
                            ),
                          ),
                          if (showTransactionColors)
                            _ColorIntensityTile(
                              value: transactionColorIntensity,
                              onChanged:
                                  appState.setTransactionColorIntensity,
                            ),
                        ],
                      ),

                      // SECURITY
                      const _PinSecuritySection(),

                      // PREFERENCES
                      GlassListSection(
                        title: 'Preferences',
                        children: [
                          GlassListTile(
                            icon: Icons.attach_money,
                            label: 'Currency',
                            sublabel:
                                '${CurrencyHelper.getName(currencyCode)} ($currency)',
                            chevron: true,
                            onTap: () => _showCurrencyPicker(context),
                          ),
                          GlassListTile(
                            icon: Icons.repeat,
                            label: 'Recurring Expenses',
                            sublabel: 'Auto-create monthly expenses',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(
                                page: const RecurringItemsScreen(
                                  initialType: 'expense',
                                ),
                              ),
                            ),
                          ),
                          GlassListTile(
                            icon: Icons.repeat,
                            iconColor: appColors.incomeGreen,
                            label: 'Recurring Income',
                            sublabel: 'Auto-create monthly income',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(
                                page: const RecurringItemsScreen(
                                  initialType: 'income',
                                ),
                              ),
                            ),
                          ),
                          GlassListTile(
                            icon: Icons.category_outlined,
                            label: 'Categories',
                            sublabel: 'Manage expense categories',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(
                                page: const CategoryManagerScreen(),
                              ),
                            ),
                          ),
                          GlassListTile(
                            icon: Icons.flash_on_outlined,
                            label: 'Quick Templates',
                            sublabel: '1-tap expense adding',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(
                                page: const QuickTemplatesScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // INSIGHTS
                      GlassListSection(
                        title: 'Insights',
                        children: [
                          GlassListTile(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Budgets',
                            sublabel: 'Set spending limits by category',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(page: const BudgetScreen()),
                            ),
                          ),
                          GlassListTile(
                            icon: Icons.bar_chart,
                            label: 'Analytics',
                            sublabel: 'View charts and spending patterns',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(page: const AnalyticsScreen()),
                            ),
                          ),
                        ],
                      ),

                      // DATA & BACKUP
                      GlassListSection(
                        title: 'Data & Backup',
                        children: [
                          GlassListTile(
                            icon: Icons.delete_outline,
                            label: 'Trash',
                            sublabel: 'Restore deleted items (30 days)',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(page: const TrashScreen()),
                            ),
                          ),
                          GlassListTile(
                            icon: Icons.backup_outlined,
                            label: 'Backup & Restore',
                            sublabel: 'Export and import your data',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(
                                page: const BackupRestoreScreen(),
                              ),
                            ),
                          ),
                          GlassListTile(
                            icon: Icons.file_download_outlined,
                            label: 'Export Data',
                            sublabel: 'Export transactions to CSV',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(
                                page: const ExportDataScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // NOTIFICATIONS
                      GlassListSection(
                        title: 'Notifications',
                        children: [
                          GlassListTile(
                            icon: Icons.notifications_outlined,
                            label: 'Notification Settings',
                            sublabel: 'Bill reminders, budget alerts',
                            chevron: true,
                            onTap: () => Navigator.push(
                              context,
                              PremiumPageRoute(
                                page: const NotificationSettingsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ADVANCED
                      GlassListSection(
                        title: 'Advanced',
                        children: [
                          GlassListTile(
                            icon: Icons.bug_report_outlined,
                            iconColor: appColors.warningOrange,
                            label: 'Crash Log',
                            sublabel:
                                'View recorded errors and share with the developer',
                            chevron: true,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              Navigator.push(
                                context,
                                PremiumPageRoute(
                                  page: const CrashLogScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      Center(
                        child: Column(
                          children: [
                            Text(
                              'FinanceFlow',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Made by Leo Atienza',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withAlpha((255 * 0.6).round()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Theme picker ───────────────────────────────────────────────────────

  Widget _buildThemeOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isSelected,
    required Map<String, Color>? previewColors,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? appColors.infoBlue : theme.colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? appColors.infoBlue : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (previewColors != null) ...[
                const SizedBox(width: 12),
                Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    color: previewColors['surface'],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(50),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: previewColors['onSurface'],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: 4,
                        decoration: BoxDecoration(
                          color: previewColors['primary'],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isSelected) ...[
                const SizedBox(width: 12),
                Icon(Icons.check_circle, color: appColors.infoBlue),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final appState = context.read<AppState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Choose Theme',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildThemeOption(
              context,
              icon: Icons.light_mode,
              title: 'Light',
              isSelected: appState.themeMode == 'light',
              previewColors: {
                'surface': const Color(0xFFFAFAFA),
                'onSurface': const Color(0xFF000000),
                'primary': appColors.infoBlue,
              },
              onTap: () {
                appState.setThemeMode('light');
                Navigator.pop(context);
              },
            ),
            _buildThemeOption(
              context,
              icon: Icons.dark_mode,
              title: 'Dark',
              isSelected: appState.themeMode == 'dark',
              previewColors: {
                'surface': const Color(0xFF121212),
                'onSurface': const Color(0xFFFFFFFF),
                'primary': appColors.infoBlue,
              },
              onTap: () {
                appState.setThemeMode('dark');
                Navigator.pop(context);
              },
            ),
            _buildThemeOption(
              context,
              icon: Icons.brightness_auto,
              title: 'Follow System',
              subtitle: 'Automatically switch based on system settings',
              isSelected: appState.themeMode == 'system',
              previewColors: null,
              onTap: () {
                appState.setThemeMode('system');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── Currency picker ────────────────────────────────────────────────────

  void _showCurrencyPicker(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Currency',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: CurrencyHelper.currencyList.length,
                itemBuilder: (context, index) {
                  final code = CurrencyHelper.currencyList[index];
                  final symbol = CurrencyHelper.getSymbol(code);
                  final name = CurrencyHelper.getName(code);
                  final isSelected = appState.currencyCode == code;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          symbol,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(code),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.onSurface,
                          )
                        : null,
                    onTap: isSelected
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await _showCurrencyChangeWarning(
                              context,
                              code,
                              name,
                              symbol,
                            );
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCurrencyChangeWarning(
    BuildContext context,
    String newCode,
    String newName,
    String newSymbol,
  ) async {
    final appState = context.read<AppState>();

    final transactionCount =
        appState.allExpenses.length + appState.incomes.length;

    final action = await DialogHelpers.showCurrencyChangeWarning(
      context,
      oldCurrency: appState.currencyCode,
      newCurrency: newCode,
      transactionCount: transactionCount,
    );

    if (action == 'keep') {
      await appState.changeCurrency(newCode);
    } else if (action == 'clear') {
      if (!mounted) return;
      if (!context.mounted) return;

      final confirmed = await DialogHelpers.showConfirmation(
        context,
        title: 'Clear All Data?',
        message:
            'This will permanently delete all transactions, budgets, and categories. This cannot be undone.',
        confirmText: 'Delete Everything',
        isDangerous: true,
      );

      if (confirmed) {
        await appState.changeCurrency(newCode);

        if (context.mounted) {
          final appColors = Theme.of(context).extension<AppColors>()!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Currency changed'),
              backgroundColor: appColors.incomeGreen,
            ),
          );
        }
      }
    }
  }

  // ─── Account picker / options ───────────────────────────────────────────

  void _showAccountPicker(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Account',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddAccountDialog(context);
                    },
                    tooltip: 'Add Account',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: appState.accounts.length,
                itemBuilder: (context, index) {
                  final account = appState.accounts[index];
                  final isSelected = appState.currentAccount?.id == account.id;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.account_balance_wallet,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    title: Text(account.name),
                    subtitle: account.isDefault ? const Text('Default') : null,
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.onSurface,
                          )
                        : IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () {
                              Navigator.pop(context);
                              _showAccountOptionsMenu(context, account);
                            },
                          ),
                    onTap: isSelected
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                            try {
                              await appState.switchAccount(account);
                              if (context.mounted) {
                                Navigator.pop(context);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Switched to ${account.name}'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Failed to switch account: $e'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();
    final controller = TextEditingController();
    var isDisposed = false;

    void disposeController() {
      if (!isDisposed) {
        isDisposed = true;
        controller.dispose();
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Account'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Account Name',
            hintText: 'e.g., Personal, Business',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () {
              disposeController();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                appState.addAccount(name);
                disposeController();
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      disposeController();
    });
  }

  void _showAccountOptionsMenu(BuildContext context, Account account) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      account.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appColors.warningOrange.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.refresh, color: appColors.warningOrange),
              ),
              title: const Text('Reset Account'),
              subtitle: const Text('Delete all data but keep account'),
              onTap: () async {
                Navigator.pop(context);
                _showResetAccountDialog(context, account);
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appColors.expenseRed.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.delete_forever, color: appColors.expenseRed),
              ),
              title: const Text('Delete Account'),
              subtitle: const Text('Permanently delete account and all data'),
              onTap: () async {
                Navigator.pop(context);
                _showDeleteAccountDialog(context, account);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showResetAccountDialog(BuildContext context, Account account) async {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final appState = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: appColors.warningOrange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Reset Account?',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reset "${account.name}"?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appColors.warningOrange.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: appColors.warningOrange.withAlpha(100)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will delete:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('• All transactions (expenses & income)'),
                  Text('• All budgets'),
                  Text('• All recurring transactions'),
                  Text('• All custom categories'),
                  Text('• All templates and tags'),
                  SizedBox(height: 8),
                  Text(
                    'The account itself will remain.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                  color: appColors.expenseRed, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: appColors.warningOrange),
            child: const Text('Reset Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final id = account.id;
      if (id == null || !context.mounted) return;
      ProgressIndicatorHelper.show(context, message: 'Resetting account...');

      try {
        await appState.resetAccount(id);
        if (!context.mounted) return;
        ProgressIndicatorHelper.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account "${account.name}" has been reset'),
            backgroundColor:
                Theme.of(context).extension<AppColors>()!.incomeGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ProgressIndicatorHelper.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting account: $e'),
            backgroundColor:
                Theme.of(context).extension<AppColors>()!.expenseRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context, Account account) async {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final appState = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: appColors.expenseRed,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Account?',
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete "${account.name}"?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: appColors.expenseRed.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: appColors.expenseRed.withAlpha(100)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently delete:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text('• The account'),
                  Text('• All transactions'),
                  Text('• All budgets'),
                  Text('• All recurring transactions'),
                  Text('• All categories and templates'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                  color: appColors.expenseRed, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: appColors.expenseRed),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final id = account.id;
      if (id == null || !context.mounted) return;
      ProgressIndicatorHelper.show(context, message: 'Deleting account...');

      try {
        await appState.deleteAccount(id);
        if (!context.mounted) return;
        ProgressIndicatorHelper.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account "${account.name}" has been deleted'),
            backgroundColor: appColors.incomeGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ProgressIndicatorHelper.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: appColors.expenseRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Custom tile for the transaction-color intensity slider. Rendered inside the
/// Appearance [GlassListSection] when transaction colors are enabled.
class _ColorIntensityTile extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _ColorIntensityTile({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.opacity, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Color Intensity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtle',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Vivid',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// PIN-security section. Loads the PIN state asynchronously; renders a Luminous
/// [GlassListSection] with a Switch tile for enable/disable, plus an optional
/// "Change PIN" row and a footer card when enabled.
class _PinSecuritySection extends StatefulWidget {
  const _PinSecuritySection();

  @override
  State<_PinSecuritySection> createState() => _PinSecuritySectionState();
}

class _PinSecuritySectionState extends State<_PinSecuritySection> {
  bool _isPinEnabled = false;
  int _pinLength = 4;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPinSettings();
  }

  Future<void> _loadPinSettings() async {
    final enabled = await PinSecurityHelper.isPinEnabled();
    final length = await PinSecurityHelper.getPinLength();

    if (mounted) {
      setState(() {
        _isPinEnabled = enabled;
        _pinLength = length;
        _isLoading = false;
      });
    }
  }

  Future<void> _setupPin() async {
    final result = await Navigator.push<bool>(
      context,
      PremiumPageRoute(page: const PinSetupScreen()),
    );

    if (result == true && mounted) {
      await _loadPinSettings();
      if (!mounted) return;

      final appState = context.read<AppState>();
      await appState.initializeLockState();

      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN enabled successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _changePin() async {
    final currentPinController = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Current PIN'),
        content: TextField(
          controller: currentPinController,
          keyboardType: TextInputType.number,
          maxLength: _pinLength,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Enter current PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final isValid = await PinSecurityHelper.verifyPin(
                currentPinController.text,
              );
              if (context.mounted) {
                Navigator.pop(context, isValid);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (verified == true && mounted) {
      final result = await Navigator.push<bool>(
        context,
        PremiumPageRoute(
          page: PinSetupScreen(
            isChangingPin: true,
            oldPin: currentPinController.text,
          ),
        ),
      );

      if (result == true && mounted) {
        await _loadPinSettings();
        if (!mounted) return;

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN changed successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else if (verified == false && mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Incorrect PIN'),
          backgroundColor: Theme.of(context).extension<AppColors>()!.expenseRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    currentPinController.dispose();
  }

  Future<void> _disablePin() async {
    final pinController = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your PIN to disable app lock.'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: _pinLength,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final isValid = await PinSecurityHelper.verifyPin(
                pinController.text,
              );
              if (context.mounted) {
                Navigator.pop(context, isValid);
              }
            },
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (verified == true) {
      await PinSecurityHelper.disablePin();
      await _loadPinSettings();

      if (!mounted) return;

      final appState = context.read<AppState>();
      await appState.initializeLockState();

      if (!mounted) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN disabled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (verified == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Incorrect PIN'),
          backgroundColor: Theme.of(context).extension<AppColors>()!.expenseRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    pinController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: LuminousTokens.sectionMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'SECURITY',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const GlassPanel(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    return GlassListSection(
      title: 'Security',
      children: [
        GlassListTile(
          icon: _isPinEnabled ? Icons.lock : Icons.lock_open,
          label: 'App PIN Lock',
          sublabel: _isPinEnabled
              ? 'Enabled ($_pinLength digits)'
              : 'Lock app with PIN',
          trailing: Switch(
            value: _isPinEnabled,
            onChanged: (value) {
              if (value) {
                _setupPin();
              } else {
                _disablePin();
              }
            },
          ),
        ),
        if (_isPinEnabled) ...[
          GlassListTile(
            icon: Icons.edit_outlined,
            label: 'Change PIN',
            sublabel: 'Update your security PIN',
            chevron: true,
            onTap: _changePin,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'App locks after 3 minutes of inactivity',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
