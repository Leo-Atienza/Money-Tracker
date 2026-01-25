import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../utils/date_helper.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _deletedExpenses = [];
  List<Map<String, dynamic>> _deletedIncome = [];
  bool _isLoading = true;
  bool _isDisposed = false; // FIX: Track disposal state to prevent setState after dispose

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDeletedItems();
  }

  @override
  void dispose() {
    _isDisposed = true; // FIX: Mark as disposed before calling super.dispose()
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeletedItems() async {
    if (_isDisposed || !mounted) return; // FIX: Check if widget is still active
    setState(() => _isLoading = true);

    final appState = context.read<AppState>();
    _deletedExpenses = await appState.getDeletedExpenses();
    _deletedIncome = await appState.getDeletedIncome();

    if (_isDisposed || !mounted) return; // FIX: Check again after async operation
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
    // Optimize: Only watch currency, use read for methods
    final currency = context.select<AppState, String>((s) => s.currency);
    final appState = context.read<AppState>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Trash',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          if (_deletedExpenses.isNotEmpty || _deletedIncome.isNotEmpty)
            // FIX: Use IconButton instead of TextButton to prevent accidental taps
            IconButton(
              onPressed: () => _showEmptyTrashDialog(context),
              tooltip: 'Empty Trash',
              icon: const Icon(Icons.delete_forever, color: Colors.red),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.onSurface,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.onSurface,
          tabs: [
            Tab(text: 'Expenses (${_deletedExpenses.length})'),
            Tab(text: 'Income (${_deletedIncome.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Items are permanently deleted after 30 days',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Expenses tab
                      _deletedExpenses.isEmpty
                          ? _buildEmptyState(theme, 'No deleted expenses')
                          : _buildExpensesList(theme, appState, currency),

                      // Income tab
                      _deletedIncome.isEmpty
                          ? _buildEmptyState(theme, 'No deleted income')
                          : _buildIncomeList(theme, appState, currency),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.delete_outline,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesList(ThemeData theme, AppState appState, String currency) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedExpenses.length,
      itemBuilder: (context, index) {
        final item = _deletedExpenses[index];
        final daysRemaining = _getDaysRemaining(item['deletedAt'] as String);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
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
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['category']} • ${DateFormat('MMM d, yyyy').format(DateTime.parse(item['date'] as String))}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$daysRemaining days until permanent deletion',
                        style: TextStyle(
                          fontSize: 11,
                          color: daysRemaining <= 7 ? Colors.red : theme.colorScheme.onSurfaceVariant,
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        fontSize: 14,
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
                            icon: const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                            onPressed: () => _permanentlyDeleteExpense(item['id'] as int),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _deletedIncome.length,
      itemBuilder: (context, index) {
        final item = _deletedIncome[index];
        final daysRemaining = _getDaysRemaining(item['deletedAt'] as String);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
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
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item['category']} • ${DateFormat('MMM d, yyyy').format(DateTime.parse(item['date'] as String))}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$daysRemaining days until permanent deletion',
                        style: TextStyle(
                          fontSize: 11,
                          color: daysRemaining <= 7 ? Colors.red : theme.colorScheme.onSurfaceVariant,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                        fontSize: 14,
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
                            icon: const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                            onPressed: () => _permanentlyDeleteIncome(item['id'] as int),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

    // FIX: Require typing "DELETE" to prevent accidental deletion
    final totalItems = _deletedExpenses.length + _deletedIncome.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _EmptyTrashConfirmDialog(totalItems: totalItems),
    );

    // FIX: Check mounted state after dialog closes and before any async operations
    if (!mounted || _isDisposed) return;

    if (confirmed == true) {
      // FIX: Show loading indicator during deletion
      setState(() => _isLoading = true);

      try {
        await appState.emptyTrash();

        // FIX: Check mounted state after async operation
        if (!mounted || _isDisposed) return;

        // Clear the local lists immediately to prevent stale UI
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
            backgroundColor: Colors.red,
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
  State<_EmptyTrashConfirmDialog> createState() => _EmptyTrashConfirmDialogState();
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
    return AlertDialog(
      title: const Text('Empty Trash?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This will permanently delete ${widget.totalItems} item${widget.totalItems == 1 ? '' : 's'}.',
            style: const TextStyle(fontWeight: FontWeight.bold),
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
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Empty Trash'),
            );
          },
        ),
      ],
    );
  }
}