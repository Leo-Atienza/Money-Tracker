import 'package:flutter/material.dart';

import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../utils/premium_animations.dart';
import 'history_grouping.dart' as grouping;

/// Builder signatures kept narrow so the parent can plug its existing
/// tile builders in without forcing a tile extraction.
typedef ExpenseTileBuilder = Widget Function(
    BuildContext context, Expense expense);
typedef IncomeTileBuilder = Widget Function(
    BuildContext context, Income income);
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

  /// M8: only the first N tiles per list/group get the staggered entrance
  /// animation. Beyond this, tiles render plain so opening a busy month (or
  /// the category-sort/all-time path with up to 1000 rows) doesn't spawn
  /// hundreds of AnimationControllers + pending timers in a single frame.
  static const int _staggerCap = 12;

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

    // M7: flatten groups into a single index space so the outer ListView.builder
    // lazily builds each header and each tile. Pre-fix the builder virtualized
    // only at the group-header level — a category-sort bucketing up to 1000
    // items into a few giant Columns built them all eagerly, defeating
    // virtualization. Each flat row is a header or an item tagged with its
    // position in the group (for the M8 stagger cap).
    final rows = <_HistoryRow>[];
    for (final groupKey in sortedKeys) {
      final String headerText;
      if (_isCategorySort) {
        headerText = groupKey.toUpperCase();
      } else {
        final date = DateTime.parse(groupKey);
        headerText = showMonth
            ? grouping.formatDateHeaderWithMonth(date)
            : grouping.formatDateHeader(date);
      }
      rows.add(_HistoryRow.header(headerText));
      final groupItems = grouped[groupKey]!;
      for (var i = 0; i < groupItems.length; i++) {
        rows.add(_HistoryRow.item(groupItems[i], i));
      }
    }

    final hasSpinner = isLoadingMore && showMonth;
    final itemCount =
        rows.length + (hasSpinner ? 1 : 0) + (_showLimitMessage ? 1 : 0);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: showMonth ? scrollController : null,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= rows.length) {
            // Trailing rows, in order: loading spinner then limit message.
            if (hasSpinner && index == rows.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _limitReachedTile(theme);
          }

          final row = rows[index];
          if (row.isHeader) {
            return Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 14),
              child: Text(
                row.header!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                  letterSpacing: 1.0,
                ),
              ),
            );
          }

          final item = row.item!;
          final tile = item is Expense
              ? expenseTileBuilder(context, item)
              : incomeTileBuilder(context, item as Income);
          // M8: stagger only the first N tiles per group.
          if (row.indexInGroup < _staggerCap) {
            return StaggeredListItem(
              index: row.indexInGroup,
              delay: const Duration(milliseconds: 25),
              child: tile,
            );
          }
          return tile;
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
          final tile = item is Expense
              ? datedExpenseTileBuilder(context, item, showMonth: showMonth)
              : datedIncomeTileBuilder(context, item as Income,
                  showMonth: showMonth);
          // M8: stagger only the first N tiles; the rest render plain.
          if (index < _staggerCap) {
            return StaggeredListItem(
              index: index,
              delay: const Duration(milliseconds: 25),
              child: tile,
            );
          }
          return tile;
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

/// A single flattened row in the grouped history list: either a section
/// header or a transaction item tagged with its position within its group
/// (used to cap the staggered entrance animation — see [HistoryList]).
class _HistoryRow {
  final String? header;
  final dynamic item; // Expense | Income
  final int indexInGroup;

  const _HistoryRow.header(this.header)
      : item = null,
        indexInGroup = -1;
  const _HistoryRow.item(this.item, this.indexInGroup) : header = null;

  bool get isHeader => header != null;
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
                color: theme.colorScheme.surfaceContainerHighest,
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
