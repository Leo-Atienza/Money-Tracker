import 'package:flutter/material.dart';

/// Stateless filter strip for HistoryScreen.
///
/// Holds the search TextField plus the horizontal-scrolling filter-chip
/// row (all-time toggle / date-range / sort / category chips / optional
/// payment-status chips).
///
/// All state lives in the parent; this widget only renders and calls
/// callbacks. The parent is responsible for any debouncing — `onSearchChanged`
/// fires on every keystroke.
class HistoryFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchTerm;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final bool searchAllTime;
  final bool isLoadingAllTime;
  final ValueChanged<bool> onAllTimeChanged;
  final DateTimeRange? dateRange;
  final String Function(DateTimeRange) formatDateRange;
  final VoidCallback onDateRangeRequested;
  final VoidCallback onDateRangeCleared;
  final String sortOrder;
  final String Function(String) sortLabelFor;
  final IconData Function(String) sortIconFor;
  final VoidCallback onShowSortOptions;
  final List<Widget> categoryChips;
  final List<Widget>? paymentFilterChips;

  const HistoryFilterBar({
    super.key,
    required this.searchController,
    required this.searchTerm,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.searchAllTime,
    required this.isLoadingAllTime,
    required this.onAllTimeChanged,
    required this.dateRange,
    required this.formatDateRange,
    required this.onDateRangeRequested,
    required this.onDateRangeCleared,
    required this.sortOrder,
    required this.sortLabelFor,
    required this.sortIconFor,
    required this.onShowSortOptions,
    required this.categoryChips,
    this.paymentFilterChips,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Semantics(
            label: 'Search transactions by name, category, or amount',
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.outline.withAlpha(50),
                ),
              ),
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  suffixIcon: searchTerm.isNotEmpty
                      ? Semantics(
                          label: 'Clear search',
                          button: true,
                          child: IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                            onPressed: onSearchCleared,
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _allTimeChip(theme),
              const SizedBox(width: 8),
              _dateRangeChip(theme),
              const SizedBox(width: 8),
              _sortChip(theme),
              const SizedBox(width: 8),
              ...categoryChips,
              if (paymentFilterChips != null) ...[
                const SizedBox(width: 8),
                ...paymentFilterChips!,
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _allTimeChip(ThemeData theme) {
    return Semantics(
      label: searchAllTime
          ? 'All time search enabled'
          : 'All time search disabled',
      hint: 'Search across all months',
      button: true,
      child: FilterChip(
        selected: searchAllTime,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 16),
            const SizedBox(width: 4),
            const Text('All time'),
            if (isLoadingAllTime) ...[
              const SizedBox(width: 4),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        onSelected: onAllTimeChanged,
        labelStyle: const TextStyle(fontSize: 13),
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primary.withAlpha(30),
        checkmarkColor: theme.colorScheme.primary,
        side: BorderSide(
          color: searchAllTime
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withAlpha(80),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _dateRangeChip(ThemeData theme) {
    final hasRange = dateRange != null;
    return Semantics(
      label: hasRange
          ? 'Date range: ${formatDateRange(dateRange!)}'
          : 'Select date range',
      button: true,
      child: FilterChip(
        selected: hasRange,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range, size: 16),
            const SizedBox(width: 4),
            Text(hasRange ? formatDateRange(dateRange!) : 'Date range'),
          ],
        ),
        onSelected: (_) => onDateRangeRequested(),
        onDeleted: hasRange ? onDateRangeCleared : null,
        deleteIcon: hasRange ? const Icon(Icons.close, size: 16) : null,
        labelStyle: const TextStyle(fontSize: 13),
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primary.withAlpha(30),
        checkmarkColor: theme.colorScheme.primary,
        side: BorderSide(
          color: hasRange
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withAlpha(80),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _sortChip(ThemeData theme) {
    final notDefault = sortOrder != 'newest';
    return Semantics(
      label: 'Sort by: ${sortLabelFor(sortOrder)}',
      hint: 'Change sort order',
      button: true,
      child: FilterChip(
        selected: notDefault,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sortIconFor(sortOrder), size: 16),
            const SizedBox(width: 4),
            Text(sortLabelFor(sortOrder)),
          ],
        ),
        onSelected: (_) => onShowSortOptions(),
        labelStyle: const TextStyle(fontSize: 13),
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primary.withAlpha(30),
        checkmarkColor: theme.colorScheme.primary,
        side: BorderSide(
          color: notDefault
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withAlpha(80),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
