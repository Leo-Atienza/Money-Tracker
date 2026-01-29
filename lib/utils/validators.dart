import 'currency_helper.dart';

/// Comprehensive validation utilities for the app
class Validators {
  // Maximum allowed amount to prevent UI issues
  static const double maxAmount = 999999999.99;

  // Maximum text lengths (must match database schema constraints)
  static const int maxDescriptionLength = 200;
  static const int maxCategoryNameLength = 50;
  static const int maxTagNameLength = 50; // CRITICAL FIX: Changed from 30 to 50 to match category length

  /// Validate amount input
  static String? validateAmount(String? value, {bool allowZero = false}) {
    if (value == null || value.isEmpty) {
      return 'Please enter an amount';
    }

    final parsed = CurrencyHelper.parseDecimal(value);
    if (parsed == null) {
      return 'Please enter a valid number';
    }

    if (!allowZero && parsed <= 0) {
      return 'Amount must be greater than 0';
    }

    if (parsed < 0) {
      return 'Amount cannot be negative';
    }

    if (parsed > maxAmount) {
      return 'Amount is too large (max 999,999,999.99)';
    }

    return null;
  }

  /// Validate amount paid doesn't exceed total.
  /// FIX: Uses Decimal comparison to avoid floating-point precision issues
  /// (e.g., 99.999999 vs 100.00 edge cases).
  static String? validateAmountPaid(String? value, double totalAmount) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final amountPaid = CurrencyHelper.parseDecimal(value);
    if (amountPaid == null) {
      return 'Please enter a valid number';
    }

    if (amountPaid < 0) {
      return 'Amount paid cannot be negative';
    }

    // Compare in integer cents to avoid floating-point precision issues
    final totalCents = (totalAmount * 100).round();
    final paidCents = (amountPaid * 100).round();
    if (paidCents > totalCents) {
      return 'Amount paid cannot exceed total amount';
    }

    return null;
  }

  /// Validate description length
  /// FIX: Properly check for empty strings when required=true
  static String? validateDescription(String? value, {bool required = false}) {
    // FIX: Check for null, empty, and whitespace-only strings when required
    if (required) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter a description';
      }
    }

    // Check length if value is provided
    if (value != null && value.isNotEmpty && value.length > maxDescriptionLength) {
      return 'Description is too long (max $maxDescriptionLength characters)';
    }

    return null;
  }

  /// Validate category name
  static String? validateCategoryName(String? value, List<String> existingCategories, {String? originalName}) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a category name';
    }

    final trimmed = value.trim();

    if (trimmed.length > maxCategoryNameLength) {
      return 'Category name is too long (max $maxCategoryNameLength characters)';
    }

    // Check for duplicates (case-insensitive)
    final lowerCaseName = trimmed.toLowerCase();
    final isDuplicate = existingCategories.any((cat) =>
      cat.toLowerCase() == lowerCaseName && cat != originalName
    );

    if (isDuplicate) {
      return 'A category with this name already exists';
    }

    // FIX: Enhanced special character validation for security and UI stability
    // Blocks: angle brackets, braces, brackets, backslash, backticks, pipe, null char
    if (trimmed.contains(RegExp(r'[<>{}[\]\\`|]')) || trimmed.contains('\x00')) {
      return 'Category name contains invalid characters';
    }

    return null;
  }

  /// Validate tag name
  static String? validateTagName(String? value, List<String> existingTags) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a tag name';
    }

    final trimmed = value.trim();

    if (trimmed.length > maxTagNameLength) {
      return 'Tag name is too long (max $maxTagNameLength characters)';
    }

    // Check for duplicates (case-insensitive)
    final lowerCaseName = trimmed.toLowerCase();
    final isDuplicate = existingTags.any((tag) =>
      tag.toLowerCase() == lowerCaseName
    );

    if (isDuplicate) {
      return 'A tag with this name already exists';
    }

    return null;
  }

  /// Validate budget amount
  /// FIX #8: Prevent negative budget values during creation/editing
  static String? validateBudgetAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a budget amount';
    }

    final parsed = CurrencyHelper.parseDecimal(value);
    if (parsed == null) {
      return 'Please enter a valid number';
    }

    // FIX #8: Explicit check for negative values
    if (parsed < 0) {
      return 'Budget cannot be negative';
    }

    if (parsed <= 0) {
      return 'Budget must be greater than 0';
    }

    if (parsed > maxAmount) {
      return 'Budget is too large (max 999,999,999.99)';
    }

    return null;
  }

  /// Check if date is in valid range (5 years past to 1 year future)
  static bool isDateInValidRange(DateTime date) {
    final now = DateTime.now();
    final fiveYearsAgo = DateTime(now.year - 5, now.month, now.day);
    final oneYearFuture = DateTime(now.year + 1, now.month, now.day);

    return !date.isBefore(fiveYearsAgo) && !date.isAfter(oneYearFuture);
  }

  // CRITICAL FIX: Centralized date range helpers for consistent date picker constraints

  /// Get the earliest allowed date for transaction entry (5 years ago)
  static DateTime getTransactionMinDate() {
    final now = DateTime.now();
    return DateTime(now.year - 5, now.month, now.day);
  }

  /// Get the latest allowed date for transaction entry (1 year future)
  static DateTime getTransactionMaxDate() {
    final now = DateTime.now();
    return DateTime(now.year + 1, now.month, now.day);
  }

  /// Get the earliest allowed date for filtering/history (same as transaction min)
  static DateTime getFilterMinDate() => getTransactionMinDate();

  /// Get the latest allowed date for filtering/history (today)
  static DateTime getFilterMaxDate() => DateTime.now();

  /// Get the earliest allowed date for recurring transaction end dates (today)
  static DateTime getRecurringEndMinDate() => DateTime.now();

  /// Get the latest allowed date for recurring transaction end dates (10 years future)
  static DateTime getRecurringEndMaxDate() {
    return DateTime.now().add(const Duration(days: 3650));
  }

  /// Check if date is in the future
  static bool isFutureDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    return dateOnly.isAfter(today);
  }

  /// Sanitize text input to prevent issues
  static String sanitizeText(String input, {int maxLength = 200}) {
    String sanitized = input.trim();

    // Remove control characters and other potentially dangerous characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    // Limit length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  /// Get character count display for text fields
  static String getCharacterCount(String text, int maxLength) {
    return '${text.length}/$maxLength';
  }

  /// Check if text will be truncated
  static bool willBeTruncated(String text, int maxLength) {
    return text.length > maxLength;
  }

  /// FIX #49: Validate date range (end date must be after start date)
  static String? validateDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) {
      return null; // Both must be set to validate
    }

    if (endDate.isBefore(startDate)) {
      return 'End date must be after start date';
    }

    return null;
  }

  /// Validate recurring expense occurrence count
  /// FIX #48: Ensure max occurrences is valid when set
  static String? validateMaxOccurrences(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final parsed = int.tryParse(value);
    if (parsed == null) {
      return 'Please enter a valid number';
    }

    if (parsed < 1) {
      return 'Must be at least 1 occurrence';
    }

    if (parsed > 1000) {
      return 'Maximum 1000 occurrences allowed';
    }

    return null;
  }
}
