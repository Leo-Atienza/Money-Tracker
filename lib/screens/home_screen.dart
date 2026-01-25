import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/expense_model.dart';
import '../utils/accessibility_helper.dart';
import '../utils/haptic_helper.dart';
import '../utils/date_helper.dart';
import '../utils/premium_animations.dart';
import '../widgets/category_tile.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'add_payment_dialog.dart';
import 'budget_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // FIX #10: Extract magic numbers to named constants for clarity
  static const double _baseExpandedHeight = 100.0; // Base height for expanded app bar
  static const double _textScaleMultiplier = 16.0; // Base font size for scaling
  static const double _textScaleFactor = 1.5; // Multiplier for text scale adjustment
  static const double _contentTopPadding = 50.0; // Top padding before status bar
  // CRITICAL FIX: Reduced from 1200.0 to 500.0 for better usability
  // 500.0 is responsive enough while still preventing accidental swipes during vertical scrolling
  static const double _swipeVelocityThreshold = 500.0; // Minimum swipe velocity to trigger navigation

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Use Selector to watch only selectedMonthName and expenses list
    final monthNameAndExpenses = context.select<AppState, (String, List<Expense>)>(
      (s) => (s.selectedMonthName, s.expenses),
    );
    final monthName = monthNameAndExpenses.$1;
    final expenses = monthNameAndExpenses.$2;

    // Calculate accessible height based on text scale
    final textScaler = MediaQuery.textScalerOf(context);
    final expandedHeight = _baseExpandedHeight + (textScaler.scale(_textScaleMultiplier) * _textScaleFactor);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      // FIX: Use Material standard dark background to prevent OLED smearing
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFFAFAFA),
      // FIX: Wrap body in GestureDetector for month swiping, but exclude horizontal scrollables
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe right = previous month, Swipe left = next month
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > _swipeVelocityThreshold) {
              HapticHelper.selectionClick();
              context.read<AppState>().goToPreviousMonth();
            } else if (details.primaryVelocity! < -_swipeVelocityThreshold) {
              HapticHelper.selectionClick();
              context.read<AppState>().goToNextMonth();
            }
          }
        },
        // FIX: Use deferToChild to allow horizontal scrollables (Quick Add) to work
        behavior: HitTestBehavior.deferToChild,
        // FIX: Add pull-to-refresh to reload data
        child: RefreshIndicator(
          onRefresh: () async {
            // Reload expenses and income for current month
            await context.read<AppState>().refreshCurrentMonthData();
          },
          child: CustomScrollView(
        slivers: [
          // App Bar with Month Navigation
          SliverAppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            pinned: true,
            // Use flexible height based on text scale factor for accessibility
            expandedHeight: expandedHeight,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: EdgeInsets.fromLTRB(24, _contentTopPadding + statusBarHeight, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Navigation
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AccessibilityHelper.semanticIconButton(
                            icon: Icons.chevron_left,
                            label: 'Previous month',
                            onPressed: () => context.read<AppState>().goToPreviousMonth(),
                          ),
                          Semantics(
                            label: 'Current month: $monthName. Tap to select a different month, long press to go to today.',
                            button: true,
                            child: InkWell(
                              onTap: () => _showMonthPicker(context),
                              onLongPress: () => context.read<AppState>().goToToday(),
                              child: Text(
                                monthName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          AccessibilityHelper.semanticIconButton(
                            icon: Icons.chevron_right,
                            label: 'Next month',
                            onPressed: () => context.read<AppState>().goToNextMonth(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Financial Summary Card
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            sliver: SliverToBoxAdapter(
              child: Semantics(
                label: 'Financial summary card',
                child: const _FinancialSummaryCard(),
              ),
            ),
          ),

          // Upcoming Bills Banner
          if (context.select<AppState, bool>((s) => s.getUpcomingBillsThisMonth().isNotEmpty))
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  label: 'Upcoming bills section',
                  container: true,
                  child: const _UpcomingBillsBanner(),
                ),
              ),
            ),

          // Quick Add Templates
          if (context.select<AppState, bool>((s) => s.quickTemplates.isNotEmpty))
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  label: 'Quick add templates section',
                  container: true,
                  child: const _QuickAddBar(),
                ),
              ),
            ),

          // Recent Transactions Header
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'RECENT TRANSACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),

          // Expenses List
          // FIX #7: Make empty state clickable to add expense
          expenses.isEmpty
              ? SliverFillRemaining(
            child: Semantics(
              label: 'No transactions this month, tap to add your first expense',
              button: true,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PremiumPageRoute(page: const AddExpenseScreen()),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No transactions this month',
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add your first expense',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
              : SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 160),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final expense = expenses[index];
                  return StaggeredListItem(
                    index: index,
                    delay: const Duration(milliseconds: 30),
                    child: _ExpenseCard(expense: expense),
                  );
                },
                childCount: expenses.length,
              ),
            ),
          ),
        ],
        ),
        ),
      ),

      // Floating Action Buttons
      floatingActionButton: const _FloatingActionButtons(),
    );
  }

  void _showMonthPicker(BuildContext context) async {
    final appState = context.read<AppState>();
    final theme = Theme.of(context);

    await showModalBottomSheet(
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
                  // Year navigation - left arrow
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      appState.goToMonth(DateTime(appState.selectedMonth.year - 1, appState.selectedMonth.month));
                    },
                    tooltip: 'Previous year',
                  ),
                  // Year display
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
                      // Year navigation - right arrow
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          appState.goToMonth(DateTime(appState.selectedMonth.year + 1, appState.selectedMonth.month));
                        },
                        tooltip: 'Next year',
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

                  return Semantics(
                    label: '${months[index]}, ${isSelected ? 'selected' : 'not selected'}${isCurrentMonth ? ', current month' : ''}',
                    button: true,
                    selected: isSelected,
                    child: InkWell(
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

class _FinancialSummaryCard extends StatefulWidget {
  const _FinancialSummaryCard();

  @override
  State<_FinancialSummaryCard> createState() => _FinancialSummaryCardState();
}

class _FinancialSummaryCardState extends State<_FinancialSummaryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Only watch the specific financial data needed
    final financialData = context.select<AppState, (double, double, double, double, double, double)>(
      (s) => (
        s.totalIncome,
        s.totalSpent,
        s.availableIncomeBalance,
        s.totalPaid,
        s.totalRemaining,
        s.currency.length.toDouble(), // Include currency for rebuilding
      ),
    );
    final totalIncome = financialData.$1;
    final totalSpent = financialData.$2;
    final availableIncomeBalance = financialData.$3;
    // totalPaid removed from display per user request
    final totalRemaining = financialData.$5;
    final appState = context.read<AppState>(); // For format methods

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Income & Expenses Row (smaller, secondary)
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Income: ${appState.formatWithCurrency(totalIncome)}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ExcludeSemantics(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'INCOME',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedCounter(
                          value: totalIncome,
                          prefix: appState.currency,
                          compact: totalIncome > 100000,
                          decimalPlaces: totalIncome > 100000 ? 1 : 2,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outline,
                ),
              ),
              Expanded(
                child: Semantics(
                  label: 'Expenses: ${appState.formatWithCurrency(totalSpent)}',
                  child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'EXPENSES',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedCounter(
                            value: totalSpent,
                            prefix: appState.currency,
                            compact: totalSpent > 100000,
                            decimalPlaces: totalSpent > 100000 ? 1 : 2,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // PRIMARY: Available Balance & Remaining - Large and prominent
          Row(
            children: [
              // Available Balance - Primary metric
              // FIX P3-18: Added liveRegion for screen reader announcements when balance changes
              Expanded(
                child: Semantics(
                  label: 'Available balance: ${appState.formatWithCurrency(availableIncomeBalance)}, calculated as income minus paid expenses',
                  liveRegion: true, // Announces balance changes to screen readers
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: availableIncomeBalance >= 0
                          ? Colors.green.withAlpha(20)
                          : Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: availableIncomeBalance >= 0
                            ? Colors.green.withAlpha(50)
                            : Colors.red.withAlpha(50),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                Icons.account_balance_wallet,
                                size: 18,
                                color: availableIncomeBalance >= 0
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AVAILABLE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedCounter(
                            value: availableIncomeBalance,
                            prefix: availableIncomeBalance < 0 ? '-${appState.currency}' : appState.currency,
                            compact: availableIncomeBalance.abs() > 100000,
                            decimalPlaces: availableIncomeBalance.abs() > 100000 ? 1 : 2,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: availableIncomeBalance >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Income - Paid',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Remaining Balance - Primary metric
              // FIX P3-18: Added liveRegion for screen reader announcements when balance changes
              Expanded(
                child: Semantics(
                  label: 'Remaining to pay: ${appState.formatWithCurrency(totalRemaining)}',
                  liveRegion: true, // Announces balance changes to screen readers
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: totalRemaining > 0
                          ? Colors.orange.withAlpha(20)
                          : Colors.green.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: totalRemaining > 0
                            ? Colors.orange.withAlpha(50)
                            : Colors.green.withAlpha(50),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                                totalRemaining > 0
                                    ? Icons.pending_actions
                                    : Icons.check_circle,
                                size: 18,
                                color: totalRemaining > 0
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'REMAINING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedCounter(
                            value: totalRemaining,
                            prefix: appState.currency,
                            compact: totalRemaining > 100000,
                            decimalPlaces: totalRemaining > 100000 ? 1 : 2,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: totalRemaining > 0
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalRemaining > 0 ? 'To pay' : 'All paid!',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _UpcomingBillsBanner extends StatelessWidget {
  const _UpcomingBillsBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Only watch currency and bills list, read appState for methods
    final billsAndCurrency = context.select<AppState, (List<Map<String, dynamic>>, String)>(
      (s) => (s.getUpcomingBillsThisMonth(), s.currency),
    );
    final bills = billsAndCurrency.$1;
    final appState = context.read<AppState>();

    if (bills.isEmpty) return const SizedBox.shrink();

    // Calculate total upcoming bills
    final totalDue = bills.fold<double>(0, (sum, bill) => sum + (bill['amount'] as double));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                size: 18,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'UPCOMING BILLS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.orange.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${appState.currency}${totalDue.toStringAsFixed(0)} due',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Show up to 3 upcoming bills
          ...bills.take(3).map((bill) {
            final dueDate = bill['dueDate'] as DateTime;
            final daysUntilDue = bill['daysUntilDue'] as int?;

            String dueText;
            if (daysUntilDue != null) {
              if (daysUntilDue == 0) {
                dueText = 'Due today';
              } else if (daysUntilDue == 1) {
                dueText = 'Due tomorrow';
              } else if (daysUntilDue < 0) {
                dueText = 'Overdue';
              } else {
                dueText = 'Due in $daysUntilDue days';
              }
            } else {
              dueText = 'Due ${dueDate.day}/${dueDate.month}';
            }

            return Semantics(
              label: '${bill['description']}, ${appState.currency}${(bill['amount'] as double).toStringAsFixed(0)}, $dueText',
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: daysUntilDue != null && daysUntilDue <= 2
                              ? Colors.orange
                              : theme.colorScheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bill['description'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${appState.currency}${(bill['amount'] as double).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: daysUntilDue != null && daysUntilDue <= 2
                            ? Colors.orange.withAlpha(30)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dueText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: daysUntilDue != null && daysUntilDue <= 2
                              ? Colors.orange.shade700
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (bills.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${bills.length - 3} more bills',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Only watch quickTemplates list and currency, read for methods
    final templatesAndCurrency = context.select<AppState, (List<dynamic>, String)>(
      (s) => (s.quickTemplates, s.currency),
    );
    final templates = templatesAndCurrency.$1;
    final currency = templatesAndCurrency.$2;
    final appState = context.read<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ADD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        // FIX: Wrap in GestureDetector to prevent month swipe when scrolling templates
        GestureDetector(
          onHorizontalDragStart: (_) {}, // Absorb horizontal gestures
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              itemBuilder: (context, index) {
              final template = templates[index];
              final isIncome = template.type == 'income';

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  label: '${template.name}, $currency${template.amount.toStringAsFixed(0)}, ${isIncome ? 'income' : 'expense'}',
                  button: true,
                  child: InkWell(
                    onTap: () async {
                      await appState.useTemplate(template);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${template.name} added!'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isIncome
                            ? Colors.green.withAlpha((255 * 0.1).round())
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isIncome ? Colors.green : theme.colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            template.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isIncome ? Colors.green : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$currency${template.amount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isIncome ? Colors.green : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Expense expense;

  const _ExpenseCard({required this.expense});

  Color _getStatusColor() {
    if (expense.isPaid) return Colors.green;
    if (expense.amountPaid > 0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();

    final statusText = expense.isPaid
        ? 'Paid'
        : expense.amountPaid > 0
            ? 'Partially paid'
            : 'Unpaid';

    // Get category for icon styling
    final category = appState.categories
        .where((c) => c.name == expense.category && c.type == 'expense')
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        label: '${expense.description}, ${expense.category}, ${appState.currency}${expense.amount.toStringAsFixed(2)}, $statusText',
        button: true,
        child: AnimatedPressCard(
          onTap: () {
            // Consistent with History screen: tap to pay
            showDialog(
              context: context,
              builder: (BuildContext context) => AddPaymentDialog(expense: expense),
            );
          },
          onLongPress: () {
            // Long press to edit details
            Navigator.push(
              context,
              PremiumPageRoute(page: AddExpenseScreen(expense: expense)),
            );
          },
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.outline.withAlpha(30)
                : theme.colorScheme.outline.withAlpha(50),
            width: 1,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Premium category tile
                    CategoryTile(
                      categoryName: expense.category,
                      categoryType: 'expense',
                      color: category?.color,
                      icon: category?.icon,
                    ),
                    const SizedBox(width: 14),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.description.isEmpty
                                ? '${expense.category} expense'
                                : expense.description,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                expense.category,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              // Show relative time
                              Builder(
                                builder: (context) {
                                  final relativeTime = DateHelper.getRelativeTime(expense.date);
                                  if (relativeTime.isNotEmpty) {
                                    return Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          child: Text(
                                            '•',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          relativeTime,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Amount and status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${appState.currency}${expense.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFFF87171) // Softer red for dark mode
                                : const Color(0xFFDC2626), // Tailwind red-600
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (!expense.isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              expense.amountPaid > 0
                                  ? '${appState.currency}${expense.remainingAmount.toStringAsFixed(2)} left'
                                  : 'UNPAID',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.orange,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.withAlpha(60), width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 10, color: Colors.green.shade700),
                                const SizedBox(width: 3),
                                Text(
                                  'PAID',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (expense.amountPaid > 0 && !expense.isPaid) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    label: AccessibilityHelper.getPaymentProgressLabel(
                      expense.amountPaid,
                      expense.amount,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        // FIX: Prevent division by zero if expense amount is zero
                        value: expense.amount > 0 ? expense.amountPaid / expense.amount : 0.0,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: _getStatusColor(),
                        minHeight: 4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingActionButtons extends StatefulWidget {
  const _FloatingActionButtons();

  @override
  State<_FloatingActionButtons> createState() => _FloatingActionButtonsState();
}

class _FloatingActionButtonsState extends State<_FloatingActionButtons>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // FIX #25: Add extra bottom padding for accessibility (text scaling) and bottom nav
    final textScaler = MediaQuery.textScalerOf(context);
    final extraBottomPadding = textScaler.scale(8.0) * 2; // Scale with text size

    return Padding(
      padding: EdgeInsets.only(bottom: extraBottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expandable buttons
          ScaleTransition(
            scale: _expandAnimation,
            child: FadeTransition(
              opacity: _expandAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Add Income Button
                  Semantics(
                    label: 'Add income',
                    button: true,
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        _toggle();
                        Navigator.push(
                          context,
                          PremiumPageRoute(page: const AddIncomeScreen()),
                        );
                      },
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('Income'),
                      heroTag: 'income',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Add Budget Button
                  Semantics(
                    label: 'Add budget',
                    button: true,
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        _toggle();
                        BudgetScreen.showAddBudget(context);
                      },
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.account_balance_wallet),
                      label: const Text('Budget'),
                      heroTag: 'budget',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Add Expense Button
                  Semantics(
                    label: 'Add expense',
                    button: true,
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        _toggle();
                        Navigator.push(
                          context,
                          PremiumPageRoute(page: const AddExpenseScreen()),
                        );
                      },
                      backgroundColor: theme.colorScheme.onSurface,
                      foregroundColor: theme.colorScheme.surface,
                      icon: const Icon(Icons.add),
                      label: const Text('Expense'),
                      heroTag: 'expense',
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Main toggle button
          Semantics(
            label: _isExpanded ? 'Close quick actions' : 'Open quick actions',
            button: true,
            child: FloatingActionButton(
              onPressed: _toggle,
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              heroTag: 'home_main_fab',
              child: AnimatedRotation(
                turns: _isExpanded ? 0.125 : 0, // 45 degrees rotation when expanded
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
