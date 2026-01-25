import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/account_model.dart';
import '../utils/progress_indicator_helper.dart';

class AccountManagerScreen extends StatelessWidget {
  const AccountManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              'Accounts',
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
                const _AccountList(),
                const SizedBox(height: 24),
                const _DeletedAccountsSection(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccount(context),
        backgroundColor: theme.colorScheme.onSurface,
        child: Icon(Icons.add, color: theme.colorScheme.surface),
      ),
    );
  }

  void _showAddAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _AddAccountDialog(),
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return Column(
      children: accounts.map((account) {
        final isCurrent = account.id == currentAccountId;

        return Semantics(
          label: '${account.name}${account.isDefault ? ', default account' : ''}${isCurrent ? ', currently active' : ', tap to view options'}',
          button: !isCurrent,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrent
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outline,
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: ExcludeSemantics(
              child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCurrent
                    ? theme.colorScheme.onSurface.withAlpha((255 * 0.1).round())
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
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: account.isDefault
                ? Text(
              'Default Account',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
                : null,
            trailing: isCurrent
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.surface,
                ),
              ),
            )
                : PopupMenuButton(
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
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
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
                        style: TextStyle(color: theme.colorScheme.onSurface),
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
                              color: Colors.blue.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withAlpha(100)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'You\'ll see transactions and budgets for this account.',
                                    style: TextStyle(
                                      fontSize: 12,
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

                  // Show loading indicator during account switch
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
                    Navigator.pop(context); // Close account manager
                  }
                } else if (value == 'setDefault') {
                  await appState.setDefaultAccount(account.id!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${account.name} is now the default account'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else if (value == 'delete') {
                  _confirmDelete(context, account.id!);
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
                    style: TextStyle(color: theme.colorScheme.onSurface),
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
                          color: Colors.blue.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withAlpha(100)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'You\'ll see transactions and budgets for this account.',
                                style: TextStyle(
                                  fontSize: 12,
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

              // Show loading indicator during account switch
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
                Navigator.pop(context); // Close account manager
              }
            },
          ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
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
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first account',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();

    // FIX #1: Get transaction count before showing dialog
    final account = appState.accounts.firstWhere((a) => a.id == id);

    showDialog(
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
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_forever, color: Colors.red, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All transactions, budgets, and data in this account will be permanently deleted.',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
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
              // Close the confirmation dialog
              Navigator.pop(context);

              // Show loading indicator during delete
              if (!context.mounted) return;
              ProgressIndicatorHelper.show(context, message: 'Deleting account...');

              try {
                await appState.deleteAccount(id);
                if (!context.mounted) return;
                ProgressIndicatorHelper.hide(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Account "${account.name}" moved to trash'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ProgressIndicatorHelper.hide(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot delete default account'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}

class _AddAccountDialog extends StatefulWidget {
  const _AddAccountDialog();

  @override
  State<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<_AddAccountDialog> {
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
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
      _showError('Account name cannot contain special characters like < > " \\ /');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }
}

class _DeletedAccountsSection extends StatefulWidget {
  const _DeletedAccountsSection();

  @override
  State<_DeletedAccountsSection> createState() => _DeletedAccountsSectionState();
}

class _DeletedAccountsSectionState extends State<_DeletedAccountsSection> {
  List<Map<String, dynamic>> _deletedAccounts = [];
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadDeletedAccounts();
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_deletedAccounts.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...(_deletedAccounts.map((account) {
            final deletedAt = DateTime.parse(account['deletedAt'] as String);
            final daysRemaining = 30 - DateTime.now().difference(deletedAt).inDays;

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
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$daysRemaining days remaining',
                          style: TextStyle(
                            fontSize: 12,
                            color: daysRemaining <= 7
                                ? Colors.orange
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
      ProgressIndicatorHelper.hide(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account restored successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
      await _loadDeletedAccounts();
    } catch (e) {
      if (!mounted) return;
      ProgressIndicatorHelper.hide(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore account: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}