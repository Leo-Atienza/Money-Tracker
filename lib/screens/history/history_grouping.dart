import 'package:intl/intl.dart';

import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../utils/date_helper.dart';

/// Pure functions for History-screen transaction grouping + header formatting.
///
/// Extracted from `history_screen.dart` so the logic is unit-testable without
/// pumping the screen. No widget code lives here — these helpers take raw
/// transaction lists and return maps / strings.

/// Returns the date that a transaction is anchored to.
///
/// Accepts [Expense] or [Income]; throws on anything else.
DateTime itemDate(dynamic item) {
  if (item is Expense) return item.date;
  if (item is Income) return item.date;
  throw ArgumentError('itemDate: unsupported type ${item.runtimeType}');
}

/// Returns the category of a transaction.
String itemCategory(dynamic item) {
  if (item is Expense) return item.category;
  if (item is Income) return item.category;
  throw ArgumentError('itemCategory: unsupported type ${item.runtimeType}');
}

/// Groups [items] by their date, formatted as `yyyy-MM-dd`.
///
/// Time-of-day is discarded — two items on the same calendar day land in
/// the same bucket regardless of hour. Insertion order within a bucket is
/// preserved.
Map<String, List<dynamic>> groupByDay(List<dynamic> items) {
  final result = <String, List<dynamic>>{};
  for (final item in items) {
    final key = DateFormat('yyyy-MM-dd').format(itemDate(item));
    result.putIfAbsent(key, () => []).add(item);
  }
  return result;
}

/// Groups [items] by category string (case-sensitive, raw stored value).
Map<String, List<dynamic>> groupByCategory(List<dynamic> items) {
  final result = <String, List<dynamic>>{};
  for (final item in items) {
    final key = itemCategory(item);
    result.putIfAbsent(key, () => []).add(item);
  }
  return result;
}

/// Sort mode for grouped keys.
enum GroupSortOrder {
  /// Newest day first (descending lexicographic on `yyyy-MM-dd` works because
  /// the format is zero-padded).
  newestFirst,

  /// Oldest day first.
  oldestFirst,

  /// Alphabetical (used for category groups).
  alphabetical,
}

/// Returns [keys] sorted according to [order].
///
/// Returns a new list — does not mutate the input.
List<String> sortGroupKeys(Iterable<String> keys, GroupSortOrder order) {
  final sorted = keys.toList();
  switch (order) {
    case GroupSortOrder.newestFirst:
      sorted.sort((a, b) => b.compareTo(a));
    case GroupSortOrder.oldestFirst:
      sorted.sort();
    case GroupSortOrder.alphabetical:
      sorted.sort();
  }
  return sorted;
}

/// Formats a grouping date as a section header without the month/year.
///
/// Returns `TODAY`, `YESTERDAY`, or the localized `EEEE, MMM d` in all caps.
String formatDateHeader(DateTime date) {
  final today = DateHelper.today();
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateHelper.normalize(date);

  if (DateHelper.isSameDay(dateOnly, today)) {
    return 'TODAY';
  }
  if (DateHelper.isSameDay(dateOnly, yesterday)) {
    return 'YESTERDAY';
  }
  return DateFormat('EEEE, MMM d').format(date).toUpperCase();
}

/// Formats a grouping date as a section header for all-time mode.
///
/// Same `TODAY`/`YESTERDAY` rule as [formatDateHeader], but older dates
/// include the year when not in the current year.
String formatDateHeaderWithMonth(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateHelper.today();
  final yesterday = today.subtract(const Duration(days: 1));
  final dateOnly = DateHelper.normalize(date);

  if (DateHelper.isSameDay(dateOnly, today)) {
    return 'TODAY';
  }
  if (DateHelper.isSameDay(dateOnly, yesterday)) {
    return 'YESTERDAY';
  }
  if (date.year == reference.year) {
    return DateFormat('EEEE, MMM d').format(date).toUpperCase();
  }
  return DateFormat('MMM d, yyyy').format(date).toUpperCase();
}
