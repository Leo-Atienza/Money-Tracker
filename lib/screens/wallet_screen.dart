import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/account_model.dart';
import '../utils/progress_indicator_helper.dart';
import '../utils/premium_animations.dart';
import '../theme/app_colors.dart';
import '../theme/luminous_tokens.dart';
import '../widgets/luminous/glass_panel.dart';
import '../widgets/luminous/glass_top_app_bar.dart';

/// Phase 5.2 — Wallet & Accounts (renamed from `AccountManagerScreen`).
///
/// Composition:
///   * [GlassTopAppBar] header ("Wallet") — no leading BackButton since
///     this screen lives behind the main-nav "Wallet" tab.
///   * `_AccountList` cards wrapped in `GlassPanel`.
///   * `_DeletedAccountsSection` retained as-is for the v5.1 trash flow.
///   * Empty state in a `GlassPanel`.
///
/// Class renamed `AccountManagerScreen` → `WalletScreen`. `main.dart`
/// import + reference updated; old file moved to `TRASH/` for history.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // M15: the add-account action lives in the header. It was a
          // default-positioned FAB that the bottom navigation bar occluded
          // on most phones.
          GlassTopAppBar(
            title: 'Wallet',
            actions: [
              IconButton(
                tooltip: 'Add account',
                icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
                onPressed: () => _showAddAccount(context),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                LuminousTokens.containerPadding,
                LuminousTokens.stackGap,
                LuminousTokens.containerPadding,
                100,
              ),
              child: const Column(
                children: [
                  _AccountList(),
                  SizedBox(height: 24),
                  _DeletedAccountsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddAccountDialog(),
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    // Optimize: Watch specific data, read for methods
    final accountsData = context.select<AppState, (List<Account>, int?)>(
      (s) => (s.accounts, s.currentAccount?.id),
    );
    final accounts = accountsData.$1;
    final currentAccountId = accountsData.$2;
    final appState = context.read<AppState>(); // For method calls

    if (accounts.isEmpty) {
      return _buildEmptyState(theme);
    }

    return ListView.builder(
      // Explicit: with no padding a ListView pads itself with the status-bar
      // inset, an empty band above the first account.
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        final isCurrent = account.id == currentAccountId;

        // The tile carries its own semantics: TalkBack reaches the row's tap
        // (switch) and the options menu (switch, make default, delete) as
        // separate actions, and reads "Default Account" / "Active" as state.
        return StaggeredListItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: GlassPanel(
              padding: EdgeInsets.zero,
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? theme.colorScheme.onSurface.withAlpha(
                            (255 * 0.1).round(),
                          )
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: isCurrent
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  account.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: account.isDefault
                    ? Text(
                        'Default Account',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : null,
                trailing: isCurrent
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Active',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : PopupMenuButton(
                        tooltip: 'Options for ${account.name}',
                        icon: Icon(
                          Icons.more_vert,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'switch',
                            child: Row(
                              children: [
                                Icon(Icons.check_circle),
                                SizedBox(width: 12),
                                Text('Switch to this'),
                              ],
                            ),
                          ),
                          if (!account.isDefault)
                            const PopupMenuItem(
                              value: 'setDefault',
                              child: Row(
                                children: [
                                  Icon(Icons.star_outline),
                                  SizedBox(width: 12),
                                  Text('Make Default'),
                                ],
                              ),
                            ),
                          if (!account.isDefault)
                            PopupMenuItem(
                              value: 'delete',
                              child: Builder(
                                builder: (context) {
                                  final appColors = Theme.of(context).extension<AppColors>()!;
                                  return Row(
                                    children: [
                                      Icon(Icons.delete, color: appColors.expenseRed),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Delete',
                                        style: TextStyle(color: appColors.expenseRed),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                        ],
                        onSelected: (value) async {
                          if (value == 'switch') {
                            // FIX #1: Show confirmation dialog before switching accounts
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: theme.colorScheme.surface,
                                title: Text(
                                  'Switch Account?',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Switch to "${account.name}"?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: appColors.infoBlue.withAlpha(20),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: appColors.infoBlue.withAlpha(100),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: appColors.infoBlue,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'You\'ll see transactions and budgets for this account.',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Switch'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true || !context.mounted) return;
                            await _switchAccount(context, appState, account);
                          } else if (value == 'setDefault') {
                            final id = account.id;
                            if (id == null) return;
                            await appState.setDefaultAccount(id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${account.name} is now the default account',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else if (value == 'delete') {
                            final id = account.id;
                            if (id == null) return;
                            _confirmDelete(context, id);
                          }
                        },
                      ),
                onTap: isCurrent
                    ? null
                    : () async {
                        // FIX #1: Show confirmation dialog before switching accounts
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: theme.colorScheme.surface,
                            title: Text(
                              'Switch Account?',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Switch to "${account.name}"?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final appColors = Theme.of(context).extension<AppColors>()!;
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: appColors.infoBlue.withAlpha(20),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: appColors.infoBlue.withAlpha(100),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: appColors.infoBlue,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'You\'ll see transactions and budgets for this account.',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
                                child: const Text('Switch'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true || !context.mounted) return;
                        await _switchAccount(context, appState, account);
                      },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Switches to [account] behind a progress dialog.
  ///
  /// Wallet is a tab of the navigation shell, not a pushed route, so the
  /// progress dialog is the only route to close: a second pop removed the
  /// shell itself and left a blank app. `switchAccount` sends the shell back
  /// to Home on its own (`onAccountSwitch`).
  Future<void> _switchAccount(
    BuildContext context,
    AppState appState,
    Account account,
  ) async {
    final closeProgress = _showProgressDialog(context, 'Switching account...');
    try {
      await appState.switchAccount(account);
    } finally {
      closeProgress();
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return GlassPanel(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No accounts',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first account',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;
    final appState = context.read<AppState>();

    // FIX #1: Get transaction count before showing dialog
    final accountIndex = appState.accounts.indexWhere((a) => a.id == id);
    if (accountIndex == -1) return;
    final account = appState.accounts[accountIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: appColors.expenseRed.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: appColors.expenseRed.withAlpha(100)),
              ),
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: appColors.expenseRed, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The account and all its transactions, budgets and data move to Recently deleted, where you can restore them for 30 days.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // This dialog's context is unmounted long before the delete
              // ends, so take what the outcome needs now and close the
              // progress dialog through its own route.
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final closeProgress =
                  _showProgressDialog(context, 'Deleting account...');

              try {
                await appState.deleteAccount(id);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Account "${account.name}" moved to Recently deleted',
                    ),
                    backgroundColor: appColors.incomeGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Cannot delete default account'),
                    backgroundColor: appColors.expenseRed,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } finally {
                closeProgress();
              }
            },
            style: TextButton.styleFrom(foregroundColor: appColors.expenseRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// The Add Account dialog, shared by Wallet and Settings.
///
/// It owns its text controller, so the controller is disposed with the
/// dialog, after the route's exit transition — never while the closing field
/// still uses it.
class AddAccountDialog extends StatefulWidget {
  const AddAccountDialog({super.key});

  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  late TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      title: Text(
        'Add Account',
        style: TextStyle(color: theme.colorScheme.onSurface),
      ),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Account Name',
          hintText: 'e.g., Personal, Business, Savings',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final accountName = _nameController.text.trim();
    if (accountName.isEmpty) {
      _showError('Please enter an account name');
      return;
    }

    // Validate account name length
    if (accountName.length > 50) {
      _showError('Account name must be 50 characters or less');
      return;
    }

    // Validate account name doesn't contain problematic characters
    if (accountName.contains(RegExp(r'[<>"\\/]'))) {
      _showError(
        'Account name cannot contain special characters like < > " \\ /',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<AppState>().addAccount(accountName);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Failed to add account');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: appColors.expenseRed,
      ),
    );
  }
}

class _DeletedAccountsSection extends StatefulWidget {
  const _DeletedAccountsSection();

  @override
  State<_DeletedAccountsSection> createState() =>
      _DeletedAccountsSectionState();
}

class _DeletedAccountsSectionState extends State<_DeletedAccountsSection> {
  List<Map<String, dynamic>> _deletedAccounts = [];
  bool _isLoading = true;
  bool _isExpanded = false;
  late final AppState _appState;
  late List<Account> _seenAccounts;

  @override
  void initState() {
    super.initState();
    // Wallet is a persistent tab, so this State lives for the whole session:
    // reload whenever the account list changes (a delete or restore, here or
    // from Settings), or a just-deleted account never shows up.
    _appState = context.read<AppState>();
    _seenAccounts = _appState.accounts;
    _appState.addListener(_onAppStateChanged);
    _loadDeletedAccounts();
  }

  void _onAppStateChanged() {
    if (identical(_appState.accounts, _seenAccounts)) return;
    _seenAccounts = _appState.accounts;
    _loadDeletedAccounts();
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  Future<void> _loadDeletedAccounts() async {
    final appState = context.read<AppState>();
    final deleted = await appState.getDeletedAccounts();
    if (mounted) {
      setState(() {
        _deletedAccounts = deleted;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_deletedAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'RECENTLY DELETED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_deletedAccounts.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          Text(
            'Accounts can be restored within 30 days of deletion.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...(_deletedAccounts.map((account) {
            final deletedAt = DateTime.parse(account['deletedAt'] as String);
            final daysRemaining =
                30 - DateTime.now().difference(deletedAt).inDays;

            final appColors = theme.extension<AppColors>()!;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account['name'] as String,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$daysRemaining days remaining',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: daysRemaining <= 7
                                ? appColors.warningOrange
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _restoreAccount(account['id'] as int),
                    child: const Text('Restore'),
                  ),
                ],
              ),
            );
          })),
        ],
      ],
    );
  }

  Future<void> _restoreAccount(int deletedId) async {
    final appState = context.read<AppState>();

    // Show loading indicator during restore
    if (!mounted) return;
    ProgressIndicatorHelper.show(context, message: 'Restoring account...');

    try {
      await appState.restoreDeletedAccount(deletedId);
      if (!mounted) return;
      final appColors = Theme.of(context).extension<AppColors>()!;
      ProgressIndicatorHelper.hide(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account restored successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: appColors.incomeGreen,
        ),
      );
      await _loadDeletedAccounts();
    } catch (e) {
      if (!mounted) return;
      final appColors = Theme.of(context).extension<AppColors>()!;
      ProgressIndicatorHelper.hide(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore account: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: appColors.expenseRed,
        ),
      );
    }
  }
}

/// Shows a progress dialog that blocks the screen and returns a callback that
/// closes exactly that dialog.
///
/// It closes by route rather than by popping whatever is on top: the context
/// that opened it can be gone by the time the work ends, and one pop too many
/// takes down the navigation shell that hosts the Wallet tab.
VoidCallback _showProgressDialog(BuildContext context, String message) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    ),
  );
  navigator.push(route);
  return () {
    if (!route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  };
}
