/// Date normalization utilities for consistent date handling across the app.
///
/// CRITICAL: All dates in the app should use UTC midnight (00:00:00.000) to avoid
/// timezone-related bugs and ensure consistent date comparisons.
class DateHelper {
  /// Normalizes a DateTime to UTC midnight (00:00:00.000).
  ///
  /// This ensures all dates are stored and compared consistently regardless of
  /// local timezone or time components.
  ///
  /// Example:
  /// ```dart
  /// final date = DateTime(2024, 1, 15, 14, 30); // 2:30 PM
  /// final normalized = DateHelper.normalize(date); // 2024-01-15 00:00:00.000Z
  /// ```
  static DateTime normalize(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  /// Returns the current date normalized to UTC midnight.
  static DateTime today() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Returns the start of the month for the given date (UTC midnight on day 1).
  static DateTime startOfMonth(DateTime date) {
    return DateTime.utc(date.year, date.month, 1);
  }

  /// Returns the end of the month for the given date (UTC midnight on last day + 1).
  /// This is the exclusive end, meaning it represents 00:00:00 of the next month.
  ///
  /// Use this for range queries: `date >= startOfMonth && date < endOfMonth`
  static DateTime endOfMonth(DateTime date) {
    return DateTime.utc(date.year, date.month + 1, 1);
  }

  /// Returns the last day of the month (inclusive, UTC midnight).
  static DateTime lastDayOfMonth(DateTime date) {
    return DateTime.utc(date.year, date.month + 1, 0);
  }

  /// Checks if two dates represent the same day (ignoring time).
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Checks if a date is in the past (before today).
  static bool isPast(DateTime date) {
    return normalize(date).isBefore(today());
  }

  /// Checks if a date is in the future (after today).
  static bool isFuture(DateTime date) {
    return normalize(date).isAfter(today());
  }

  /// Checks if a date is today.
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  /// Converts a DateTime to ISO 8601 date string (YYYY-MM-DD).
  static String toDateString(DateTime date) {
    final normalized = normalize(date);
    return normalized.toIso8601String().substring(0, 10);
  }

  /// Parses an ISO 8601 date string to normalized DateTime.
  static DateTime? parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      final parsed = DateTime.parse(dateString);
      return normalize(parsed);
    } catch (e) {
      return null;
    }
  }

  /// Gets the month string in YYYY-MM format.
  static String toMonthString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Adds months to a date, preserving the day (or last day of month if needed).
  /// FIX P1-6: Properly handles day overflow (e.g., Jan 31 + 1 month = Feb 28, not Mar 3).
  static DateTime addMonths(DateTime date, int months) {
    final normalized = normalize(date);
    int newYear = normalized.year;
    int newMonth = normalized.month + months;

    // Handle year overflow/underflow
    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear--;
    }

    // Get the last day of the target month
    final lastDayOfTargetMonth = DateTime.utc(newYear, newMonth + 1, 0).day;

    // Use the original day or the last day of the target month, whichever is smaller
    final newDay = normalized.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : normalized.day;

    return DateTime.utc(newYear, newMonth, newDay);
  }

  /// Subtracts months from a date, preserving the day (or last day of month if needed).
  static DateTime subtractMonths(DateTime date, int months) {
    return addMonths(date, -months);
  }

  /// Gets the number of days between two dates (ignoring time).
  static int daysBetween(DateTime start, DateTime end) {
    final normalizedStart = normalize(start);
    final normalizedEnd = normalize(end);
    return normalizedEnd.difference(normalizedStart).inDays;
  }

  /// Returns a relative time string for the given date.
  /// Shows "Xh ago" for today, "Yesterday" for yesterday, "X days ago" for recent dates,
  /// and formatted date for older dates.
  /// FIX P2-14: Now returns formatted date for older dates instead of empty string.
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final normalizedDate = normalize(date);
    final normalizedNow = today();

    // Check if it's today
    if (isSameDay(normalizedDate, normalizedNow)) {
      final difference = now.difference(date);
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      }
      return 'Today';
    }

    // Check if it's yesterday
    final yesterday = normalizedNow.subtract(const Duration(days: 1));
    if (isSameDay(normalizedDate, yesterday)) {
      return 'Yesterday';
    }

    // Check if it's within the last week
    final daysAgo = daysBetween(normalizedDate, normalizedNow);
    if (daysAgo > 0 && daysAgo < 7) {
      return '$daysAgo days ago';
    }

    // For older dates or future dates, return a formatted date string
    // FIX P2-14: Return formatted date instead of empty string
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (normalizedDate.year == normalizedNow.year) {
      return '${months[normalizedDate.month - 1]} ${normalizedDate.day}';
    }
    return '${months[normalizedDate.month - 1]} ${normalizedDate.day}, ${normalizedDate.year}';
  }
}
