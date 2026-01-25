import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/currency_helper.dart';
import '../utils/dialog_helpers.dart';
import '../utils/progress_indicator_helper.dart';
import '../utils/premium_animations.dart';
import 'recurring_expenses_screen.dart';
import 'recurring_income_screen.dart';
import 'category_manager_screen.dart';
import 'quick_templates_screen.dart';
import 'trash_screen.dart';
import 'notification_settings_screen.dart';
import 'analytics_screen.dart';
import 'backup_restore_screen.dart';
import 'budget_screen.dart';
import 'pin_setup_screen.dart';
import 'export_data_screen.dart';
import '../utils/pin_security_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            pinned: true,
            title: Text(
              'Settings',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ACCOUNTS
                const _SectionHeader(title: 'ACCOUNTS'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      title: 'Current Account',
                      subtitle: appState.currentAccount?.name ?? 'Main Account',
                      icon: Icons.account_balance_wallet_outlined,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showAccountPicker(context),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // APPEARANCE
                const _SectionHeader(title: 'APPEARANCE'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    // FIX: Theme mode picker with tri-state (Light, Dark, System)
                    _SettingsTile(
                      title: 'Theme',
                      subtitle: appState.themeMode == 'light'
                          ? 'Light'
                          : appState.themeMode == 'dark'
                              ? 'Dark'
                              : 'Follow System',
                      icon: appState.themeMode == 'light'
                          ? Icons.light_mode
                          : appState.themeMode == 'dark'
                              ? Icons.dark_mode
                              : Icons.brightness_auto,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showThemePicker(context),
                    ),
                    const _Divider(),
                    _SettingsTile(
                      title: 'Transaction Colors',
                      subtitle: appState.showTransactionColors
                          ? 'Category colors shown on cards'
                          : 'Clean white/dark cards',
                      icon: Icons.palette_outlined,
                      trailing: Switch(
                        value: appState.showTransactionColors,
                        onChanged: (value) => appState.toggleShowTransactionColors(value),
                      ),
                    ),
                    // Show intensity slider when transaction colors are enabled
                    if (appState.showTransactionColors) ...[
                      const _Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.opacity,
                                  size: 20,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Color Intensity',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(appState.transactionColorIntensity * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                              ),
                              child: Slider(
                                value: appState.transactionColorIntensity,
                                min: 0.1,
                                max: 1.0,
                                divisions: 9,
                                onChanged: (value) => appState.setTransactionColorIntensity(value),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Subtle',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  'Vivid',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 32),

                // SECURITY
                const _SectionHeader(title: 'SECURITY'),
                const SizedBox(height: 12),
                _PinSecurityCard(),

                const SizedBox(height: 32),

                // PREFERENCES
                const _SectionHeader(title: 'PREFERENCES'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      title: 'Currency',
                      subtitle: '${CurrencyHelper.getName(appState.currencyCode)} (${appState.currency})',
                      icon: Icons.attach_money,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showCurrencyPicker(context),
                    ),
                    const _Divider(),
                    _SettingsTile(
                      title: 'Recurring Expenses',
                      subtitle: 'Auto-create monthly expenses',
                      icon: Icons.repeat,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const RecurringExpensesScreen(),
                          ),
                        );
                      },
                    ),
                    const _Divider(),
                    _SettingsTile(
                      title: 'Recurring Income',
                      subtitle: 'Auto-create monthly income',
                      icon: Icons.repeat,
                      iconColor: Colors.green,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const RecurringIncomeScreen(),
                          ),
                        );
                      },
                    ),
                    const _Divider(),
                    _SettingsTile(
                      title: 'Categories',
                      subtitle: 'Manage expense categories',
                      icon: Icons.category_outlined,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const CategoryManagerScreen(),
                          ),
                        );
                      },
                    ),
                    const _Divider(),
                    _SettingsTile(
                      title: 'Quick Templates',
                      subtitle: '1-tap expense adding',
                      icon: Icons.flash_on_outlined,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const QuickTemplatesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // INSIGHTS
                const _SectionHeader(title: 'INSIGHTS'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      title: 'Budgets',
                      subtitle: 'Set spending limits by category',
                      icon: Icons.account_balance_wallet_outlined,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const BudgetScreen(),
                          ),
                        );
                      },
                    ),
                    const _Divider(),
                    _SettingsTile(
                      title: 'Analytics',
                      subtitle: 'View charts and spending patterns',
                      icon: Icons.bar_chart,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const AnalyticsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // DATA & BACKUP
                const _SectionHeader(title: 'DATA & BACKUP'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      title: 'Trash',
                      subtitle: 'Restore deleted items (30 days)',
                      icon: Icons.delete_outline,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const TrashScreen(),
                          ),
                        );
                      },
                    ),
                    const _Divider(),
                    _SettingsTile(
                      title: 'Backup & Restore',
                      subtitle: 'Export and import your data',
                      icon: Icons.backup_outlined,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const BackupRestoreScreen(),
                          ),
                        );
                      },
                    ),
                    const _Divider(),
                    _SettingsTile(
                      title: 'Export Data',
                      subtitle: 'Export transactions to CSV',
                      icon: Icons.file_download_outlined,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const ExportDataScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // NOTIFICATIONS
                const _SectionHeader(title: 'NOTIFICATIONS'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      title: 'Notification Settings',
                      subtitle: 'Bill reminders, budget alerts',
                      icon: Icons.notifications_outlined,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          PremiumPageRoute(
                            page: const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // APP INFO
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Money Tracker',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Made by Leo Atienza',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha((255 * 0.6).round()),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // FIX #32: Build theme option with preview card
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.blue : theme.colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Colors.blue : theme.colorScheme.onSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (previewColors != null) ...[
                const SizedBox(width: 12),
                // Preview card showing theme colors
                Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    color: previewColors['surface'],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.colorScheme.outline.withAlpha(50)),
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
                const Icon(Icons.check_circle, color: Colors.blue),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // FIX: Theme picker with tri-state options
  void _showThemePicker(BuildContext context) {
    final theme = Theme.of(context);
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            // FIX #32: Theme option with preview card
            _buildThemeOption(
              context,
              icon: Icons.light_mode,
              title: 'Light',
              isSelected: appState.themeMode == 'light',
              previewColors: {
                'surface': const Color(0xFFFAFAFA),
                'onSurface': const Color(0xFF000000),
                'primary': Colors.blue,
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
                'primary': Colors.blue,
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
              previewColors: null, // No preview for system mode
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
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Currency',
                      style: TextStyle(
                        fontSize: 20,
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
            // Currency List
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
                    onTap: isSelected ? null : () async {
                      Navigator.pop(context);
                      // FIX #5: Show currency change warning
                      await _showCurrencyChangeWarning(context, code, name, symbol);
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

  // FIX #50: Enhanced currency change warning with data clearing option
  Future<void> _showCurrencyChangeWarning(
      BuildContext context,
      String newCode,
      String newName,
      String newSymbol,
      ) async {
    final appState = context.read<AppState>();

    // Show comprehensive warning with clear data option
    final transactionCount = appState.getExpensesForSelectedMonth().length +
        appState.incomes.length;

    final action = await DialogHelpers.showCurrencyChangeWarning(
      context,
      oldCurrency: appState.currencyCode,
      newCurrency: newCode,
      transactionCount: transactionCount,
    );

    if (action == 'keep') {
      // Just change currency symbol, keep all data
      await appState.changeCurrency(newCode);
    } else if (action == 'clear') {
      if (!mounted) return;
      if (!context.mounted) return;

      // Show final confirmation before clearing all data
      final confirmed = await DialogHelpers.showConfirmation(
        context,
        title: 'Clear All Data?',
        message: 'This will permanently delete all transactions, budgets, and categories. This cannot be undone.',
        confirmText: 'Delete Everything',
        isDangerous: true,
      );

      if (confirmed) {
        // Note: clearAllData functionality would need to be implemented in AppState
        // For now, just change currency
        await appState.changeCurrency(newCode);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Currency changed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

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
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Account',
                      style: TextStyle(
                        fontSize: 20,
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
            // Account List
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
                              Navigator.pop(context); // Close account picker
                              _showAccountOptionsMenu(context, account);
                            },
                          ),
                    onTap: isSelected
                        ? null
                        : () async {
                            // FIX #17: Add haptic feedback
                            HapticFeedback.mediumImpact();

                            // FIX: Show loading indicator during account switch
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                            await appState.switchAccount(account);
                            if (context.mounted) {
                              Navigator.pop(context); // Close loading dialog
                              Navigator.pop(context); // Close account selector
                              // FIX #15: Show confirmation feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Switched to ${account.name}'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
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
      // Ensure controller is disposed even if dialog is dismissed by tapping outside
      disposeController();
    });
  }

  void _showAccountOptionsMenu(BuildContext context, account) {
    final theme = Theme.of(context);

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
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      account.name,
                      style: TextStyle(
                        fontSize: 20,
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

            // Reset Account Option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh, color: Colors.orange),
              ),
              title: const Text('Reset Account'),
              subtitle: const Text('Delete all data but keep account'),
              onTap: () async {
                Navigator.pop(context);
                _showResetAccountDialog(context, account);
              },
            ),

            // Delete Account Option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_forever, color: Colors.red),
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

  void _showResetAccountDialog(BuildContext context, account) async {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withAlpha(100)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This will delete:', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('• All transactions (expenses & income)'),
                  Text('• All budgets'),
                  Text('• All recurring transactions'),
                  Text('• All custom categories'),
                  Text('• All templates and tags'),
                  SizedBox(height: 8),
                  Text('The account itself will remain.', style: TextStyle(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Reset Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      ProgressIndicatorHelper.show(context, message: 'Resetting account...');

      try {
        await appState.resetAccount(account.id);
        if (!context.mounted) return;
        ProgressIndicatorHelper.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account "${account.name}" has been reset'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ProgressIndicatorHelper.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting account: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteAccountDialog(BuildContext context, account) async {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
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
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(100)),
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
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      ProgressIndicatorHelper.show(context, message: 'Deleting account...');

      try {
        await appState.deleteAccount(account.id);
        if (!context.mounted) return;
        ProgressIndicatorHelper.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account "${account.name}" has been deleted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ProgressIndicatorHelper.hide(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap, // Can be null
      borderRadius: BorderRadius.circular(16), // Match container radius for ripples
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor ?? theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 16),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 64, // Align with text start
      color: Theme.of(context).colorScheme.outline.withAlpha(50),
    );
  }
}

/// PIN Security settings card
class _PinSecurityCard extends StatefulWidget {
  @override
  State<_PinSecurityCard> createState() => _PinSecurityCardState();
}

class _PinSecurityCardState extends State<_PinSecurityCard> {
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
      MaterialPageRoute(
        builder: (context) => const PinSetupScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadPinSettings();
      if (!mounted) return;

      // Store appState reference before async gap
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
    // First verify current PIN
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
        MaterialPageRoute(
          builder: (context) => PinSetupScreen(
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
        const SnackBar(
          content: Text('Incorrect PIN'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    currentPinController.dispose();
  }

  Future<void> _disablePin() async {
    // First verify current PIN
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

      // Store appState reference before async gap
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
        const SnackBar(
          content: Text('Incorrect PIN'),
          backgroundColor: Colors.red,
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
      return _SettingsCard(
        children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    return _SettingsCard(
      children: [
        _SettingsTile(
          title: 'App PIN Lock',
          subtitle: _isPinEnabled
              ? 'Enabled ($_pinLength digits)'
              : 'Lock app with PIN',
          icon: _isPinEnabled ? Icons.lock : Icons.lock_open,
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
          const _Divider(),
          _SettingsTile(
            title: 'Change PIN',
            subtitle: 'Update your security PIN',
            icon: Icons.edit_outlined,
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePin,
          ),
          const _Divider(),
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
                    style: TextStyle(
                      fontSize: 12,
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