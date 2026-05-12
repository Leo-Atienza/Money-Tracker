import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../utils/date_helper.dart';
import '../utils/premium_animations.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/luminous/glass_panel.dart';
import '../widgets/luminous/glass_segmented_control.dart';
import '../widgets/luminous/glass_top_app_bar.dart';
import '../theme/app_colors.dart';
import '../theme/luminous_tokens.dart';

/// Phase 5.9f — Trash Luminous redesign.
///
/// Composition:
///   * [GlassTopAppBar] header ("Trash") + delete-forever action when non-empty
///   * Info banner wrapped in a [GlassPanel]
///   * [GlassSegmentedControl] replaces the old `TabBar` for Expense / Income
///   * Each deleted item rendered as a [GlassPanel] card with restore + permanent-delete actions
///
/// Behaviour is unchanged from the v4 implementation: items are kept for 30 days
/// and the "Empty Trash" action still requires typing `DELETE` to confirm.
enum _TrashTab { expenses, income }

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  _TrashTab _selectedTab = _TrashTab.expenses;
  List<Map<String, dynamic>> _deletedExpenses = [];
  List<Map<String, dynamic>> _deletedIncome = [];
  bool _isLoading = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadDeletedItems();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _loadDeletedItems() async {
    if (_isDisposed || !mounted) return;
    setState(() => _isLoading = true);

    final appState = context.read<AppState>();
    _deletedExpenses = await appState.getDeletedExpenses();
    _deletedIncome = await appState.getDeletedIncome();

    if (_isDisposed || !mounted) return;
    setState(() => _isLoading = false);
  }

  int _getDaysRemaining(String deletedAt) {
    final deletedDate = DateTime.parse(deletedAt);
    final expiryDate = deletedDate.add(const Duration(days: 30));
    final today = DateHelper.today();
    final remaining = expiryDate.difference(today).inDays;
    return remaining > 0 ? remaining : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.select<AppState, String>((s) => s.currency);
    final appState = context.read<AppState>();
    final appColors = theme.extension<AppColors>()!;

    final hasItems = _deletedExpenses.isNotEmpty || _deletedIncome.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTopAppBar(
            leading: BackButton(color: theme.colorScheme.onSurface),
            title: 'Trash',
            actions: [
              if (hasItems)
                IconButton(
                  onPressed: () => _showEmptyTrashDialog(context),
                  tooltip: 'Empty Trash',
                  icon: Icon(Icons.delete_forever, color: appColors.expenseRed),
                ),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const TransactionListSkeleton()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      LuminousTokens.containerPadding,
                      LuminousTokens.stackGap,
                      LuminousTokens.containerPadding,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Items are permanently deleted after 30 days',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassSegmentedControl<_TrashTab>(
                          values: const [_TrashTab.expenses, _TrashTab.income],
                          labels: [
                            'Expenses (${_deletedExpenses.length})',
                            'Income (${_deletedIncome.length})',
                          ],
                          selected: _selectedTab,
                          onChanged: (tab) =>
                              setState(() => _selectedTab = tab),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: _selectedTab == _TrashTab.expenses
                              ? (_deletedExpenses.isEmpty
                                  ? _buildEmptyState(theme, 'No deleted expenses')
                                  : _buildExpensesList(theme, appState, currency))
                              : (_deletedIncome.isEmpty
                                  ? _buildEmptyState(theme, 'No deleted income')
                                  : _buildIncomeList(theme, appState, currency)),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LuminousTokens.sectionMargin),
        child: GlassPanel(
          padding: const EdgeInsets.all(LuminousTokens.glassPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesList(
    ThemeData theme,
    AppState appState,
    String currency,
  ) {
    final appColors = theme.extension<AppColors>()!;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: _deletedExpenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _deletedExpenses[index];
        final daysRemaining = _getDaysRemaining(item['deletedAt'] as String);

        return StaggeredListItem(
          index: index,
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['description'] as String? ?? 'Expense',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['category']} • ${DateFormat('MMM d, yyyy').format(DateTime.parse(item['date'] as String))}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$daysRemaining days until permanent deletion',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: daysRemaining <= 7
                              ? appColors.expenseRed
                              : theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currency${(item['amount'] as double).toStringAsFixed(2)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            icon: const Icon(Icons.restore, size: 20),
                            onPressed: () => _restoreExpense(item['id'] as int),
                            tooltip: 'Restore',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_forever,
                              size: 20,
                              color: appColors.expenseRed,
                            ),
                            onPressed: () =>
                                _permanentlyDeleteExpense(item['id'] as int),
                            tooltip: 'Delete permanently',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIncomeList(ThemeData theme, AppState appState, String currency) {
    final appColors = theme.extension<AppColors>()!;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: _deletedIncome.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _deletedIncome[index];
        final daysRemaining = _getDaysRemaining(item['deletedAt'] as String);

        return StaggeredListItem(
          index: index,
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['description'] as String? ?? 'Income',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['category']} • ${DateFormat('MMM d, yyyy').format(DateTime.parse(item['date'] as String))}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$daysRemaining days until permanent deletion',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: daysRemaining <= 7
                              ? appColors.expenseRed
                              : theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currency${(item['amount'] as double).toStringAsFixed(2)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: appColors.incomeGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            icon: const Icon(Icons.restore, size: 20),
                            onPressed: () => _restoreIncome(item['id'] as int),
                            tooltip: 'Restore',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_forever,
                              size: 20,
                              color: appColors.expenseRed,
                            ),
                            onPressed: () =>
                                _permanentlyDeleteIncome(item['id'] as int),
                            tooltip: 'Delete permanently',
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _restoreExpense(int id) async {
    if (_isDisposed || !mounted) return;
    final appState = context.read<AppState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await appState.restoreDeletedExpense(id);

    if (_isDisposed || !mounted) return;
    await _loadDeletedItems();

    if (_isDisposed || !mounted) return;
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Expense restored'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restoreIncome(int id) async {
    if (_isDisposed || !mounted) return;
    final appState = context.read<AppState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    await appState.restoreDeletedIncome(id);

    if (_isDisposed || !mounted) return;
    await _loadDeletedItems();

    if (_isDisposed || !mounted) return;
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Income restored'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _permanentlyDeleteExpense(int id) async {
    if (_isDisposed || !mounted) return;
    final appState = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).extension<AppColors>()!.expenseRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (_isDisposed || !mounted) return;
    if (confirmed == true) {
      await appState.permanentlyDeleteExpense(id);
      if (_isDisposed || !mounted) return;
      await _loadDeletedItems();
    }
  }

  Future<void> _permanentlyDeleteIncome(int id) async {
    if (_isDisposed || !mounted) return;
    final appState = context.read<AppState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).extension<AppColors>()!.expenseRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (_isDisposed || !mounted) return;
    if (confirmed == true) {
      await appState.permanentlyDeleteIncome(id);
      if (_isDisposed || !mounted) return;
      await _loadDeletedItems();
    }
  }

  Future<void> _showEmptyTrashDialog(BuildContext context) async {
    final appState = context.read<AppState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).extension<AppColors>()!.expenseRed;

    final totalItems = _deletedExpenses.length + _deletedIncome.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          _EmptyTrashConfirmDialog(totalItems: totalItems),
    );

    if (!mounted || _isDisposed) return;

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        await appState.emptyTrash();

        if (!mounted || _isDisposed) return;

        _deletedExpenses = [];
        _deletedIncome = [];

        setState(() => _isLoading = false);

        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Trash emptied'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted || _isDisposed) return;
        setState(() => _isLoading = false);

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error emptying trash: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }
}

/// Separate StatefulWidget for the dialog to properly manage the TextEditingController lifecycle
class _EmptyTrashConfirmDialog extends StatefulWidget {
  final int totalItems;

  const _EmptyTrashConfirmDialog({required this.totalItems});

  @override
  State<_EmptyTrashConfirmDialog> createState() =>
      _EmptyTrashConfirmDialogState();
}

class _EmptyTrashConfirmDialogState extends State<_EmptyTrashConfirmDialog> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<AppColors>()!;

    return AlertDialog(
      title: const Text('Empty Trash?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will permanently delete ${widget.totalItems} item${widget.totalItems == 1 ? '' : 's'}.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('This action cannot be undone.'),
          const SizedBox(height: 16),
          const Text('Type DELETE to confirm:'),
          const SizedBox(height: 8),
          TextField(
            controller: _textController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'DELETE',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder(
          valueListenable: _textController,
          builder: (context, value, child) {
            final isValid = value.text.trim().toUpperCase() == 'DELETE';
            return TextButton(
              onPressed: isValid ? () => Navigator.pop(context, true) : null,
              style: TextButton.styleFrom(
                foregroundColor: appColors.expenseRed,
              ),
              child: const Text('Empty Trash'),
            );
          },
        ),
      ],
    );
  }
}
