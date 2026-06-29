import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../theme/luminous_app_theme.dart';
import '../providers/app_state.dart';
import '../models/expense_model.dart';
import '../utils/accessibility_helper.dart';
import '../utils/haptic_helper.dart';
import '../utils/date_helper.dart';
import '../utils/premium_animations.dart'
    show PremiumPageRoute, AnimatedCounter;
import '../widgets/category_tile.dart';
import '../widgets/luminous/glass_surface.dart';
import 'add_transaction_screen.dart';
import 'add_payment_dialog.dart';
import 'history/history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // CRITICAL FIX: Reduced from 1200.0 to 500.0 for better usability
  // 500.0 is responsive enough while still preventing accidental swipes during vertical scrolling
  static const double _swipeVelocityThreshold =
      500.0; // Minimum swipe velocity to trigger navigation

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optimize: Use Selector to watch only selectedMonthName and expenses list
    final monthNameAndExpenses =
        context.select<AppState, (String, List<Expense>)>(
      (s) => (s.selectedMonthName, s.expenses),
    );
    final monthName = monthNameAndExpenses.$1;
    final expenses = monthNameAndExpenses.$2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: GlassHeaderStrip(
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LuminousTokens.containerPadding,
                  ),
                  child: Row(
                    children: [
                      Semantics(
                        label: 'Open settings',
                        button: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              Navigator.push(
                                context,
                                PremiumPageRoute(page: const SettingsScreen()),
                              );
                            },
                            child: Ink(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  // De-glass: solid hairline ring from the
                                  // colorScheme (was a translucent white edge).
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainer,
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'FinanceFlow',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 26,
                            height: 1.1,
                          ),
                        ),
                      ),
                      AccessibilityHelper.semanticIconButton(
                        icon: Icons.search_rounded,
                        label: 'Open transaction history',
                        color: theme.colorScheme.primary,
                        onPressed: () {
                          Navigator.push(
                            context,
                            PremiumPageRoute(page: const HistoryScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! > _swipeVelocityThreshold) {
                    HapticHelper.selectionClick();
                    context.read<AppState>().goToPreviousMonth();
                  } else if (details.primaryVelocity! <
                      -_swipeVelocityThreshold) {
                    HapticHelper.selectionClick();
                    context.read<AppState>().goToNextMonth();
                  }
                }
              },
              behavior: HitTestBehavior.deferToChild,
              child: RefreshIndicator(
                onRefresh: () async {
                  await context.read<AppState>().refreshCurrentMonthData();
                },
                child: CustomScrollView(
                  slivers: [
                    // Month navigation (glass redesign strip)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        LuminousTokens.containerPadding,
                        16,
                        LuminousTokens.containerPadding,
                        8,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // M13: labeled + >=48dp target (was a bare 40x40
                            // unlabeled InkWell). Matches budget_screen.dart.
                            AccessibilityHelper.semanticIconButton(
                              icon: Icons.chevron_left,
                              label: 'Previous month',
                              color: theme.colorScheme.onSurfaceVariant,
                              onPressed: () =>
                                  context.read<AppState>().goToPreviousMonth(),
                            ),
                            Semantics(
                              label:
                                  'Current month: $monthName. Tap to pick a month, long press for today.',
                              button: true,
                              child: InkWell(
                                onTap: () => _showMonthPicker(context),
                                onLongPress: () =>
                                    context.read<AppState>().goToToday(),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    monthName,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // M13: labeled + >=48dp target (was a bare 40x40
                            // unlabeled InkWell).
                            AccessibilityHelper.semanticIconButton(
                              icon: Icons.chevron_right,
                              label: 'Next month',
                              color: theme.colorScheme.onSurfaceVariant,
                              onPressed: () =>
                                  context.read<AppState>().goToNextMonth(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Financial Summary Card
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                          LuminousTokens.containerPadding,
                          0,
                          LuminousTokens.containerPadding,
                          0),
                      sliver: SliverToBoxAdapter(
                        child: Semantics(
                          label: 'Financial summary card',
                          child: const _FinancialSummaryCard(),
                        ),
                      ),
                    ),

                    // Upcoming Bills Banner
                    if (context.select<AppState, bool>(
                      (s) => s.getUpcomingBillsThisMonth().isNotEmpty,
                    ))
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Semantics(
                            label: 'Upcoming bills section',
                            container: true,
                            child: const _UpcomingBillsBanner(),
                          ),
                        ),
                      ),

                    // Quick Add Templates
                    if (context.select<AppState, bool>(
                      (s) => s.quickTemplates.isNotEmpty,
                    ))
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Semantics(
                            label: 'Quick add templates section',
                            container: true,
                            child: const _QuickAddBar(),
                          ),
                        ),
                      ),

                    // Recent Transactions
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        LuminousTokens.containerPadding,
                        LuminousTokens.sectionMargin,
                        LuminousTokens.containerPadding,
                        LuminousTokens.stackGap,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Recent Transactions',
                                style: theme.textTheme.headlineMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PremiumPageRoute(page: const HistoryScreen()),
                                );
                              },
                              child: Text(
                                'SEE ALL',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expenses list (inside single glass sheet like stitch mock)
                    expenses.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Semantics(
                              label:
                                  'No transactions this month, tap to add your first expense',
                              button: true,
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PremiumPageRoute(
                                      page: const AddTransactionScreen(
                                        initialType: TransactionType.expense,
                                      ),
                                    ),
                                  );
                                },
                                behavior: HitTestBehavior.opaque,
                                // De-glass: the standard bottom NavigationBar
                                // insets the body above it, so the empty state
                                // only needs a modest bottom margin now.
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.receipt_long_outlined,
                                          size: 64,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No transactions this month',
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap to add',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                              LuminousTokens.containerPadding,
                              0,
                              LuminousTokens.containerPadding,
                              24,
                            ),
                            sliver: SliverToBoxAdapter(
                              // Isolate the transactions panel under a
                              // RepaintBoundary so unrelated header refreshes
                              // don't repaint the whole list.
                              child: RepaintBoundary(
                                child: GlassPanel(
                                  padding: EdgeInsets.zero,
                                  child: Column(
                                    children: [
                                      for (var i = 0;
                                          i < expenses.length;
                                          i++) ...[
                                        if (i > 0)
                                          Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: Colors.white
                                                .withValues(alpha: 0.35),
                                          ),
                                        _GlassHomeExpenseTile(
                                            expense: expenses[i]),
                                      ],
                                    ],
                                  ),
                                ),
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
    );
  }

  void _showMonthPicker(BuildContext context) async {
    final appState = context.read<AppState>();
    final theme = Theme.of(context);

    var displayYear = appState.selectedMonth.year;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                        setModalState(() => displayYear--);
                      },
                      tooltip: 'Previous year',
                    ),
                    // Year display
                    Text(
                      '$displayYear',
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
                            setModalState(() => displayYear++);
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
                    final month = DateTime(
                      displayYear,
                      index + 1,
                    );
                    final isSelected =
                        month.year == appState.selectedMonth.year &&
                            month.month == appState.selectedMonth.month;
                    // FIX #13: Indicate current month
                    final now = DateTime.now();
                    final isCurrentMonth =
                        month.year == now.year && month.month == now.month;
                    const months = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec',
                    ];

                    return Semantics(
                      label:
                          '${months[index]}, ${isSelected ? 'selected' : 'not selected'}${isCurrentMonth ? ', current month' : ''}',
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
                                    fontWeight: isSelected || isCurrentMonth
                                        ? FontWeight.w600
                                        : FontWeight.normal,
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
    final financialData =
        context.select<AppState, (double, double, double, double)>(
      (s) => (
        s.totalIncome,
        s.totalSpent,
        s.availableIncomeBalance,
        s.currency.length.toDouble(),
      ),
    );
    final totalIncome = financialData.$1;
    final totalSpent = financialData.$2;
    final totalBalance = financialData.$3;
    final appState = context.read<AppState>();

    // De-glass: the Income/Expenses tiles nested in the balance card are solid
    // surfaces drawn from the colorScheme so they read as distinct cards in
    // both light and dark mode (was a translucent white wash).
    BoxDecoration insetTile(BuildContext ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GlassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label:
                  'Total balance ${appState.formatWithCurrency(totalBalance)}',
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedCounter(
                      value: totalBalance,
                      prefix: totalBalance < 0
                          ? '-${appState.currency}'
                          : appState.currency,
                      compact: totalBalance.abs() > 100000,
                      decimalPlaces: totalBalance.abs() > 100000 ? 1 : 2,
                      style: theme.textTheme.displayLarge
                          ?.copyWith(fontSize: 34, height: 41 / 34),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LuminousTokens.stackGap),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Income ${appState.formatWithCurrency(totalIncome)}',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: insetTile(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_downward_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Income',
                                style: theme.textTheme.bodyMedium?.copyWith(
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
                              value: totalIncome,
                              prefix: appState.currency,
                              compact: totalIncome > 100000,
                              decimalPlaces: totalIncome > 100000 ? 1 : 2,
                              style: theme.textTheme.headlineMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: LuminousTokens.stackGap),
                Expanded(
                  child: Semantics(
                    label:
                        'Expenses ${appState.formatWithCurrency(totalSpent)}',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: insetTile(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.arrow_upward_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Expenses',
                                style: theme.textTheme.bodyMedium?.copyWith(
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
                              value: totalSpent,
                              prefix: appState.currency,
                              compact: totalSpent > 100000,
                              decimalPlaces: totalSpent > 100000 ? 1 : 2,
                              style: theme.textTheme.headlineMedium,
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

class _GlassHomeExpenseTile extends StatelessWidget {
  final Expense expense;

  const _GlassHomeExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = context.read<AppState>();

    final category = appState.categories
        .where((c) => c.name == expense.category && c.type == 'expense')
        .firstOrNull;

    final statusText = expense.isPaid
        ? 'Paid'
        : expense.amountPaid > 0
            ? 'Partial'
            : 'Unpaid';

    return Semantics(
      label:
          '${expense.description}, ${expense.category}, ${appState.formatWithCurrency(expense.amount)}, $statusText',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (BuildContext context) =>
                  AddPaymentDialog(expense: expense),
            );
          },
          onLongPress: () {
            Navigator.push(
              context,
              PremiumPageRoute(
                page: AddTransactionScreen(
                  initialType: TransactionType.expense,
                  expense: expense,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CategoryTile(
                  categoryName: expense.category,
                  categoryType: 'expense',
                  color: category?.color,
                  icon: category?.icon,
                  size: 48,
                  borderRadius: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description.isEmpty
                            ? '${expense.category} expense'
                            : expense.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          expense.category,
                          DateHelper.getRelativeTime(expense.date),
                        ].where((e) => e.isNotEmpty).join(' • '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  // M16: locale-aware grouping ($1,234.00) to match the a11y label.
                  '-${appState.formatWithCurrency(expense.amount)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
    final appColors = theme.extension<AppColors>()!;
    // Optimize: Only watch currency and bills list, read appState for methods
    final billsAndCurrency =
        context.select<AppState, (List<Map<String, dynamic>>, String)>(
      (s) => (s.getUpcomingBillsThisMonth(), s.currency),
    );
    final bills = billsAndCurrency.$1;
    final appState = context.read<AppState>();

    if (bills.isEmpty) return const SizedBox.shrink();

    // Calculate total upcoming bills
    final totalDue = bills.fold<double>(
      0,
      (sum, bill) => sum + (bill['amount'] as double),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appColors.warningOrange.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appColors.warningOrange.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                size: 18,
                color: appColors.warningOrange,
              ),
              const SizedBox(width: 8),
              Text(
                'UPCOMING BILLS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: appColors.warningOrange,
                ),
              ),
              const Spacer(),
              Text(
                // M16: grouped, zero-decimal ($1,234 due).
                '${appState.formatWithCurrency(totalDue, decimalDigits: 0)} due',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: appColors.warningOrange,
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
              label:
                  '${bill['description']}, ${appState.formatWithCurrency(bill['amount'] as double, decimalDigits: 0)}, $dueText',
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
                              ? appColors.warningOrange
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
                      // M16: grouped, zero-decimal.
                      appState.formatWithCurrency(bill['amount'] as double,
                          decimalDigits: 0),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: daysUntilDue != null && daysUntilDue <= 2
                            ? appColors.warningOrange.withAlpha(30)
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dueText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: daysUntilDue != null && daysUntilDue <= 2
                              ? appColors.warningOrange
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
    final appColors = theme.extension<AppColors>()!;
    // Optimize: Only watch quickTemplates list and currency, read for methods
    final templatesAndCurrency =
        context.select<AppState, (List<dynamic>, String)>(
      (s) => (s.quickTemplates, s.currency),
    );
    final templates = templatesAndCurrency.$1;
    // currency stays in the select tuple so the bar rebuilds when it changes;
    // amounts below render via appState.formatWithCurrency (M16 grouping).
    final appState = context.read<AppState>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ADD',
          style: theme.textTheme.labelSmall?.copyWith(
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
                    label:
                        '${template.name}, ${appState.formatWithCurrency(template.amount, decimalDigits: 0)}, ${isIncome ? 'income' : 'expense'}',
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
                              ? appColors.incomeGreen
                                  .withAlpha((255 * 0.1).round())
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isIncome
                                ? appColors.incomeGreen
                                : theme.colorScheme.outline,
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
                                color: isIncome
                                    ? appColors.incomeGreen
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              appState.formatWithCurrency(template.amount,
                                  decimalDigits: 0),
                              style: TextStyle(
                                fontSize: 13,
                                color: isIncome
                                    ? appColors.incomeGreen
                                    : theme.colorScheme.onSurfaceVariant,
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
