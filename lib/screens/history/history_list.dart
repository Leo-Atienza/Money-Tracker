import 'package:flutter/material.dart';

import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../utils/premium_animations.dart';
import 'history_grouping.dart' as grouping;

/// Builder signatures kept narrow so the parent can plug its existing
/// tile builders in without forcing a tile extraction.
typedef ExpenseTileBuilder = Widget Function(BuildContext context, Expense expense);
typedef IncomeTileBuilder = Widget Function(BuildContext context, Income income);
typedef DatedExpenseTileBuilder = Widget Function(
  BuildContext context,
  Expense expense, {
  bool showMonth,
});
typedef DatedIncomeTileBuilder = Widget Function(
  BuildContext context,
  Income income, {
  bool showMonth,
});

/// Stateless list shell for HistoryScreen.
///
/// Owns the RefreshIndicator + ListView.builder layout plus the grouping /
/// flat-list dispatch. Tile rendering itself is delegated back to the parent
/// via builder callbacks — extracting those tiles would balloon this commit
/// and is left as future work.
class HistoryList extends StatelessWidget {
  final List<dynamic> items;

  /// Sort order passed through from HistoryScreen. Values: `newest`, `oldest`,
  /// `highest`, `lowest`, `category`. Drives grouping vs flat rendering.
  final String sortOrder;

  /// True when this list is the all-time view (shows month in headers,
  /// hosts the scroll controller, may render the "result limit" message).
  final bool showMonth;
  final ScrollController? scrollController;
  final bool isLoadingMore;
  final bool hasMoreData;
  final int maxTotalResults;
  final int totalLoaded;
  final Future<void> Function() onRefresh;
  final ExpenseTileBuilder expenseTileBuilder;
  final IncomeTileBuilder incomeTileBuilder;
  final DatedExpenseTileBuilder datedExpenseTileBuilder;
  final DatedIncomeTileBuilder datedIncomeTileBuilder;

  const HistoryList({
    super.key,
    required this.items,
    required this.sortOrder,
    required this.showMonth,
    required this.scrollController,
    required this.isLoadingMore,
    required this.hasMoreData,
    required this.maxTotalResults,
    required this.totalLoaded,
    required this.onRefresh,
    required this.expenseTileBuilder,
    required this.incomeTileBuilder,
    required this.datedExpenseTileBuilder,
    required this.datedIncomeTileBuilder,
  });

  bool get _isAmountSort => sortOrder == 'highest' || sortOrder == 'lowest';
  bool get _isCategorySort => sortOrder == 'category';

  bool get _showLimitMessage =>
      showMonth && !hasMoreData && totalLoaded >= maxTotalResults;

  @override
  Widget build(BuildContext context) {
    if (_isAmountSort) {
      return _buildFlat(context);
    }
    return _buildGrouped(context);
  }

  Widget _buildGrouped(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = _isCategorySort
        ? grouping.groupByCategory(items)
        : grouping.groupByDay(items);

    final grouping.GroupSortOrder order;
    if (_isCategorySort) {
      order = grouping.GroupSortOrder.alphabetical;
    } else if (sortOrder == 'oldest') {
      order = grouping.GroupSortOrder.oldestFirst;
    } else {
      order = grouping.GroupSortOrder.newestFirst;
    }
    final sortedKeys = grouping.sortGroupKeys(grouped.keys, order);

    final itemCount = sortedKeys.length +
        (isLoadingMore && showMonth ? 1 : 0) +
        (_showLimitMessage ? 1 : 0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: showMonth ? scrollController : null,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (isLoadingMore && index == sortedKeys.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_showLimitMessage && index == sortedKeys.length) {
            return _limitReachedTile(theme);
          }

          final groupKey = sortedKeys[index];
          final groupItems = grouped[groupKey]!;

          final String headerText;
          if (_isCategorySort) {
            headerText = groupKey.toUpperCase();
          } else {
            final date = DateTime.parse(groupKey);
            headerText = showMonth
                ? grouping.formatDateHeaderWithMonth(date)
                : grouping.formatDateHeader(date);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 14),
                child: Text(
                  headerText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              ...groupItems.asMap().entries.map((entry) {
                final itemIndex = entry.key;
                final item = entry.value;
                if (item is Expense) {
                  return StaggeredListItem(
                    index: itemIndex,
                    delay: const Duration(milliseconds: 25),
                    child: expenseTileBuilder(context, item),
                  );
                }
                return StaggeredListItem(
                  index: itemIndex,
                  delay: const Duration(milliseconds: 25),
                  child: incomeTileBuilder(context, item as Income),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFlat(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = items.length +
        (isLoadingMore && showMonth ? 1 : 0) +
        (_showLimitMessage ? 1 : 0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: showMonth ? scrollController : null,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (isLoadingMore && index == items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_showLimitMessage && index == items.length) {
            return _limitReachedTile(theme);
          }

          final item = items[index];
          if (item is Expense) {
            return StaggeredListItem(
              index: index,
              delay: const Duration(milliseconds: 25),
              child: datedExpenseTileBuilder(
                context,
                item,
                showMonth: showMonth,
              ),
            );
          }
          return StaggeredListItem(
            index: index,
            delay: const Duration(milliseconds: 25),
            child: datedIncomeTileBuilder(
              context,
              item as Income,
              showMonth: showMonth,
            ),
          );
        },
      ),
    );
  }

  Widget _limitReachedTile(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: theme.colorScheme.onSurfaceVariant,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Result limit reached',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Showing first $maxTotalResults results. Refine your search to see more specific items.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state widget shown when no transactions match the current filters.
///
/// Pure UI — the parent controls the filter-aware messaging and supplies
/// callbacks for the "Add Expense" / "Add Income" buttons.
class HistoryEmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onAddExpense;
  final VoidCallback onAddIncome;

  const HistoryEmptyState({
    super.key,
    required this.hasFilters,
    required this.onAddExpense,
    required this.onAddIncome,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No transactions found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try adjusting your search or filters'
                  : 'Get started by adding your first transaction',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasFilters) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: onAddExpense,
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Add Expense'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onAddIncome,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Income'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
