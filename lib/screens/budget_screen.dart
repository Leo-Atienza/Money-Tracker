import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../utils/currency_helper.dart';
import '../utils/accessibility_helper.dart';
import '../utils/dialog_helpers.dart';
import '../utils/haptic_helper.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  // FIX #10: Extract magic numbers to named constants for clarity
  static const double _baseToolbarHeight = 56.0;  // Material default toolbar height
  static const double _textScaleMultiplier = 14.0; // Base font size for scaling calculation
  static const double _textScaleFactor = 2.0; // Extra height per scaled text unit

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Only watch the selected month name for display
    final selectedMonthName = context.select<AppState, String>((s) => s.selectedMonthName);
    final appState = context.read<AppState>(); // Read for one-time access in callbacks

    // Calculate accessible toolbar height based on text scale
    final textScaler = MediaQuery.textScalerOf(context);
    final toolbarHeight = _baseToolbarHeight + (textScaler.scale(_textScaleMultiplier) * _textScaleFactor);

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
            toolbarHeight: toolbarHeight,
            title: Text(
              'Budgets',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: theme.colorScheme.onSurface,
              ),
            ),
            actions: [
              // Month navigation directly in the app bar
              AccessibilityHelper.semanticIconButton(
                icon: Icons.chevron_left,
                label: 'Previous month',
                onPressed: appState.goToPreviousMonth,
              ),
              Semantics(
                label: 'Current month: $selectedMonthName. Tap to select month, long press for today.',
                button: true,
                child: GestureDetector(
                  onTap: () => _showMonthPicker(context, appState, theme),
                  onLongPress: () => context.read<AppState>().goToToday(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      selectedMonthName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              AccessibilityHelper.semanticIconButton(
                icon: Icons.chevron_right,
                label: 'Next month',
                onPressed: appState.goToNextMonth,
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _MonthlySummaryCard(),
                const SizedBox(height: 16),
                const _BudgetList(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: Semantics(
        label: 'Add budget',
        button: true,
        child: FloatingActionButton(
          onPressed: () => showAddBudget(context),
          backgroundColor: theme.colorScheme.onSurface,
          tooltip: 'Add budget',
          heroTag: 'budget_fab',
          child: Icon(Icons.add, color: theme.colorScheme.surface),
        ),
      ),
    );
  }

  static void showAddBudget(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _AddBudgetDialog(),
    );
  }

  void _showMonthPicker(BuildContext context, AppState appState, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      appState.goToMonth(DateTime(appState.selectedMonth.year - 1, appState.selectedMonth.month));
                    },
                  ),
                  Text(
                    '${appState.selectedMonth.year}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          appState.goToMonth(DateTime(appState.selectedMonth.year + 1, appState.selectedMonth.month));
                        },
                      ),
                      TextButton(
                        onPressed: () {
                          appState.goToToday();
                          Navigator.pop(context);
                        },
                        child: const Text('Today'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = DateTime(appState.selectedMonth.year, index + 1);
                  final isSelected = month.month == appState.selectedMonth.month;
                  // FIX #13: Indicate current month
                  final now = DateTime.now();
                  final isCurrentMonth = month.year == now.year && month.month == now.month;
                  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

                  return InkWell(
                    onTap: () {
                      appState.goToMonth(month);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        // FIX #13: Add border for current month
                        border: isCurrentMonth && !isSelected
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // FIX #13: Show dot indicator for current month
                            if (isCurrentMonth && !isSelected) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              months[index],
                              style: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : isCurrentMonth
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                fontWeight: isSelected || isCurrentMonth ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary card showing total budget, carryover, and overall spending status
class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive padding: reduce on smaller screens
    final cardPadding = screenWidth < 360 ? 16.0 : 20.0;

    final currency = appState.currency;
    final totalBudget = appState.totalMonthlyBudget;
    final totalSpent = appState.totalExpensesThisMonth;
    final totalIncome = appState.totalIncomeThisMonth;
    final carryover = appState.carryoverForSelectedMonth;
    final hasCarryover = appState.hasCarryover;
    final projectedBalance = appState.projectedEndOfMonthBalance;
    final hasOverallBudget = appState.hasOverallMonthlyBudget;
    final categoryBudgetTotal = appState.totalCategoryBudget;

    // Calculate budget progress
    final budgetProgress = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.5) : 0.0;
    final budgetPercentage = (budgetProgress * 100).clamp(0.0, 150.0);

    // Determine status color based on budget usage
    Color budgetStatusColor = Colors.green;
    IconData budgetStatusIcon = Icons.check_circle;
    if (budgetPercentage >= 95) {
      budgetStatusColor = Colors.red;
      budgetStatusIcon = Icons.error;
    } else if (budgetPercentage >= 85) {
      budgetStatusColor = Colors.orange;
      budgetStatusIcon = Icons.warning;
    } else if (budgetPercentage >= 75) {
      budgetStatusColor = Colors.amber;
      budgetStatusIcon = Icons.info;
    }

    return Container(
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and status icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MONTHLY OVERVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (totalBudget > 0)
                Row(
                  children: [
                    Icon(budgetStatusIcon, size: 18, color: budgetStatusColor),
                    const SizedBox(width: 4),
                    Text(
                      '${budgetPercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: budgetStatusColor,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Income + Carryover row
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Income',
                  value: '$currency${appState.formatAmount(totalIncome, decimalDigits: 0)}',
                  valueColor: Colors.green,
                  icon: Icons.arrow_downward,
                ),
              ),
              if (hasCarryover) ...[
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _SummaryItem(
                    label: 'Carryover',
                    value: '${carryover >= 0 ? '+' : ''}$currency${appState.formatAmount(carryover, decimalDigits: 0)}',
                    valueColor: carryover >= 0 ? Colors.blue : Colors.red,
                    icon: carryover >= 0 ? Icons.trending_up : Icons.trending_down,
                  ),
                ),
              ],
            ],
          ),

          if (hasCarryover) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (carryover >= 0 ? Colors.blue : Colors.red).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 16,
                    color: carryover >= 0 ? Colors.blue : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total Available: $currency${appState.formatAmount(totalIncome + carryover, decimalDigits: 0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 16),

          // Overall Monthly Budget Section
          _buildOverallBudgetSection(context, theme, appState, currency, hasOverallBudget, totalBudget, categoryBudgetTotal),

          const SizedBox(height: 16),

          // Budget vs Spent
          if (totalBudget > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Spent',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$currency${appState.formatAmount(totalSpent, decimalDigits: 0)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: budgetStatusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress bar for total budget
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: budgetProgress.clamp(0.0, 1.0),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(budgetStatusColor),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),

            // Remaining budget
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalBudget - totalSpent >= 0 ? 'Remaining' : 'Over Budget',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$currency${appState.formatAmount((totalBudget - totalSpent).abs(), decimalDigits: 0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: totalBudget - totalSpent >= 0
                        ? theme.colorScheme.onSurfaceVariant
                        : Colors.red,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 16),

          // Projected end of month balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 3,
                child: Row(
                  children: [
                    Icon(
                      projectedBalance >= 0 ? Icons.savings : Icons.warning,
                      size: 18,
                      color: projectedBalance >= 0 ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Projected Balance',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  '${projectedBalance >= 0 ? '+' : ''}$currency${appState.formatAmount(projectedBalance, decimalDigits: 0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: projectedBalance >= 0 ? Colors.green : Colors.red,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            projectedBalance >= 0
                ? 'Will carry over to next month'
                : 'Deficit will reduce next month\'s budget',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }

  Widget _buildOverallBudgetSection(
    BuildContext context,
    ThemeData theme,
    AppState appState,
    String currency,
    bool hasOverallBudget,
    double totalBudget,
    double categoryBudgetTotal,
  ) {
    if (hasOverallBudget) {
      // Show overall budget with edit/remove options
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Monthly Budget',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$currency${appState.formatAmount(totalBudget, decimalDigits: 0)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _showSetOverallBudgetDialog(context, appState.overallMonthlyBudget),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _confirmRemoveOverallBudget(context),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (categoryBudgetTotal > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Category budgets total: $currency${appState.formatAmount(categoryBudgetTotal, decimalDigits: 0)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    } else if (categoryBudgetTotal > 0) {
      // Show category budget total with option to set overall budget
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Budget (from categories)',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$currency${appState.formatAmount(categoryBudgetTotal, decimalDigits: 0)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showSetOverallBudgetDialog(context, null),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Set overall monthly budget',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      // No budgets at all - show prompt to set overall budget
      return InkWell(
        onTap: () => _showSetOverallBudgetDialog(context, null),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 32,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Set a monthly budget',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Limit your total spending for ${appState.selectedMonthName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to set budget',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showSetOverallBudgetDialog(BuildContext context, double? currentBudget) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _SetOverallBudgetDialog(currentBudget: currentBudget),
    );
  }

  void _confirmRemoveOverallBudget(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Monthly Budget?'),
        content: const Text(
          'This will remove the overall monthly budget limit. '
          'Category budgets will still be tracked individually.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AppState>().removeOverallMonthlyBudget();
    }
  }
}

/// Dialog to set the overall monthly budget
class _SetOverallBudgetDialog extends StatefulWidget {
  final double? currentBudget;

  const _SetOverallBudgetDialog({this.currentBudget});

  @override
  State<_SetOverallBudgetDialog> createState() => _SetOverallBudgetDialogState();
}

class _SetOverallBudgetDialogState extends State<_SetOverallBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.currentBudget?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();
    final currency = appState.currency;
    final selectedMonthName = appState.selectedMonthName;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.currentBudget != null ? 'Edit Monthly Budget' : 'Set Monthly Budget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For $selectedMonthName',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This sets a total spending limit for the entire month, regardless of categories.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [CurrencyHelper.decimalInputFormatter()],
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Monthly Budget Amount',
                  prefixText: '$currency ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final amount = CurrencyHelper.parseDecimal(value!);
                  if (amount == null) return 'Invalid number';
                  if (amount <= 0) return 'Budget must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBudget,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface,
                    foregroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = CurrencyHelper.parseDecimal(_amountController.text);
    if (amount == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await context.read<AppState>().setOverallMonthlyBudget(amount);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save budget: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

/// Helper widget for summary items
class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: valueColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetList extends StatelessWidget {
  const _BudgetList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Select only budgets and currency, read appState for methods
    final budgetsAndCurrency = context.select<AppState, (List<dynamic>, String)>(
      (s) => (s.currentMonthBudgets, s.currency),
    );
    final budgets = budgetsAndCurrency.$1;
    final currency = budgetsAndCurrency.$2;
    final appState = context.read<AppState>(); // For getBudgetSpentBreakdown

    if (budgets.isEmpty) {
      return _buildEmptyState(theme, appState.selectedMonthName, context);
    }

    return Column(
      children: budgets.map((budget) {
        // FIX: Get breakdown of actual vs projected spending
        final breakdown = appState.getBudgetSpentBreakdown(budget.category);
        final actualSpent = breakdown['actual']!;
        final projectedSpent = breakdown['projected']!;
        final spent = breakdown['total']!;

        // CRITICAL FIX: Add null check and zero division protection
        final budgetAmount = budget.amount;
        final percentage = (budgetAmount != null && budgetAmount > 0)
            ? (spent / budgetAmount * 100).clamp(0.0, 150.0)
            : 0.0;
        final remaining = (budgetAmount ?? 0.0) - spent;

        // FIX: Change red threshold from 100% to 95% for earlier warning
        Color statusColor = Colors.green;
        IconData statusIcon = Icons.check_circle;
        if (percentage >= 95) {
          statusColor = Colors.red;
          statusIcon = Icons.error; // CRITICAL FIX: Add icon for color-blind users
        } else if (percentage >= 85) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning; // CRITICAL FIX: Add icon for color-blind users
        } else if (percentage >= 75) {
          statusColor = Colors.amber;
          statusIcon = Icons.info; // CRITICAL FIX: Add icon for color-blind users
        }

        final statusLabel = AccessibilityHelper.getBudgetStatusLabel(percentage, budget.category);

        return Semantics(
          label: statusLabel,
          container: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      budget.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Row(
                      children: [
                        // CRITICAL FIX: Add status icon for color-blind accessibility
                        ExcludeSemantics(
                          child: Icon(statusIcon, size: 18, color: statusColor),
                        ),
                        const SizedBox(width: 12),
                        AccessibilityHelper.semanticIconButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit ${budget.category} budget',
                          onPressed: () => _showEditBudget(context, budget.category, budget.amount),
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        AccessibilityHelper.semanticIconButton(
                          icon: Icons.delete_outline,
                          label: 'Delete ${budget.category} budget',
                          onPressed: () => _confirmDelete(context, budget.id!),
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$currency${spent.toStringAsFixed(0)} / $currency${budget.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                // FIX: Stacked progress bar showing actual (solid) and projected (lighter)
                Semantics(
                  label: AccessibilityHelper.getBudgetStatusLabel(percentage, budget.category),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Stack(
                        children: [
                          // Background
                          Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          // Projected (total) - lighter/semi-transparent
                          if (projectedSpent > 0)
                            FractionallySizedBox(
                              widthFactor: (spent / budget.amount).clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.3),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.5),
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          // Actual - solid color
                          FractionallySizedBox(
                            widthFactor: (actualSpent / budget.amount).clamp(0.0, 1.0),
                            child: Container(
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // FIX: Show breakdown of actual vs projected
                if (projectedSpent > 0)
                  Semantics(
                    label: 'Breakdown: Actual spending $currency${actualSpent.toStringAsFixed(0)}, Projected spending $currency${projectedSpent.toStringAsFixed(0)}',
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Actual: $currency${actualSpent.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ExcludeSemantics(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.3),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Projected: $currency${projectedSpent.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Semantics(
                  label: '${percentage.toStringAsFixed(0)}% used, ${remaining >= 0 ? '${appState.currency}${remaining.toStringAsFixed(0)} remaining' : '${appState.currency}${(-remaining).toStringAsFixed(0)} over budget'}',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${percentage.toStringAsFixed(0)}% used',
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        remaining >= 0
                            ? '${appState.currency}${remaining.toStringAsFixed(0)} left'
                            : '${appState.currency}${(-remaining).toStringAsFixed(0)} over',
                        style: TextStyle(
                          fontSize: 13,
                          color: remaining >= 0
                              ? theme.colorScheme.onSurfaceVariant
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String monthName, BuildContext context) {
    return GestureDetector(
      onTap: () => BudgetScreen.showAddBudget(context),
      child: Container(
        padding: const EdgeInsets.all(32),
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
              'No budgets for $monthName',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            // FIX #5: Add descriptive explanation of what budgets are and how they help
            Text(
              'Set spending limits for categories to track and control your expenses',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            // FIX #5: Example use case to help users understand
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Example',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set Food: \$500 to limit dining expenses',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap here or + to create your first budget',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBudget(BuildContext context, String category, double amount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AddBudgetDialog(
        initialCategory: category,
        initialAmount: amount.toString(),
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) async {
    final appState = context.read<AppState>();

    // Find the budget to show details in the warning
    final budgetIndex = appState.currentMonthBudgets.indexWhere((b) => b.id == id);
    if (budgetIndex == -1) return; // Budget not found
    final budget = appState.currentMonthBudgets[budgetIndex];
    final breakdown = appState.getBudgetSpentBreakdown(budget.category);
    final spent = breakdown['total']!;

    // FIX #9: Show detailed deletion warning with current spending info
    final confirmed = await DialogHelpers.showBudgetDeletionWarning(
      context,
      categoryName: budget.category,
      currentSpending: spent,
      budgetAmount: budget.amount,
      currency: appState.currency,
    );

    if (confirmed && context.mounted) {
      await appState.deleteBudget(id);
      await HapticHelper.itemDeleted();

      // FIX #22: Show undo option after deletion
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Budget deleted'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                await appState.undoBudgetDeletion();
              },
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _AddBudgetDialog extends StatefulWidget {
  final String? initialCategory;
  final String? initialAmount;

  const _AddBudgetDialog({
    this.initialCategory,
    this.initialAmount,
  });

  @override
  State<_AddBudgetDialog> createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<_AddBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  String? _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.initialAmount);
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Select only categoryNames and currency, read appState for other methods
    final categoryNamesAndCurrency = context.select<AppState, (List<String>, String, String)>(
      (s) => (s.categoryNames, s.currency, s.selectedMonthName),
    );
    final categories = categoryNamesAndCurrency.$1;
    final currency = categoryNamesAndCurrency.$2;
    final selectedMonthName = categoryNamesAndCurrency.$3;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialCategory != null ? 'Edit Budget' : 'Set Budget',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For $selectedMonthName',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              // Fixed dropdown using InputDecorator pattern to avoid deprecation
              InputDecorator(
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isDense: true,
                  isExpanded: true,
                  hint: const Text('Select category'),
                  items: categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: widget.initialCategory == null
                      ? (value) => setState(() => _selectedCategory = value)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [CurrencyHelper.decimalInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Monthly Budget',
                prefixText: '$currency ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                final amount = CurrencyHelper.parseDecimal(value!);
                if (amount == null) return 'Invalid number';
                // FIX #46: Validate budget amount must be greater than 0
                if (amount <= 0) return 'Budget must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveBudget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.onSurface,
                  foregroundColor: theme.colorScheme.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Save'),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBudget() async {
    // FIX #46: Validate form with validator (checks amount > 0)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      _showError('Please select a category');
      return;
    }

    final amount = CurrencyHelper.parseDecimal(_amountController.text);
    if (amount == null) {
      return; // Should not happen due to validator
    }

    setState(() => _isSaving = true);

    try {
      await context.read<AppState>().setBudget(_selectedCategory!, amount);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showError('Failed to save budget');
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