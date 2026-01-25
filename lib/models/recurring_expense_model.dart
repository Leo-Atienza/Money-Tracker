import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import '../utils/decimal_helper.dart';
import '../utils/date_helper.dart';

/// Frequency types for recurring expenses (matches recurring income)
enum RecurringExpenseFrequency {
  monthly,   // On a specific day of the month (1-31)
  biweekly,  // Every two weeks on a specific day of the week
  weekly,    // Every week on a specific day of the week
}

class RecurringExpense {
  final int? id;
  final String description;
  final Decimal _amount;
  final String category;
  final int dayOfMonth;  // For monthly: 1-31, For weekly/biweekly: 0-6 (Mon-Sun)
  final bool isActive;
  final DateTime? lastCreated;
  final int accountId;
  final String paymentMethod;
  final DateTime? endDate; // FIX: Optional end date for recurring transactions
  final int? maxOccurrences; // FIX: Optional max number of occurrences
  final int occurrenceCount; // FIX: Track how many times it has occurred
  final RecurringExpenseFrequency frequency; // FIX: Support weekly/biweekly frequencies
  final DateTime? startDate; // FIX: Reference date for bi-weekly calculations

  RecurringExpense({
    this.id,
    required this.description,
    required Decimal amount,
    required this.category,
    required this.dayOfMonth,
    this.isActive = true,
    this.lastCreated,
    required this.accountId,
    this.paymentMethod = 'Cash',
    this.endDate,
    this.maxOccurrences,
    this.occurrenceCount = 0,
    this.frequency = RecurringExpenseFrequency.monthly,
    this.startDate,
  }) : _amount = amount;

  // Public getter that returns double for backward compatibility
  double get amount => DecimalHelper.toDouble(_amount);

  // Internal Decimal getter for precise calculations
  Decimal get amountDecimal => _amount;

  /// Get the day name for weekly/biweekly frequencies
  String get dayName {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    if (frequency == RecurringExpenseFrequency.monthly) {
      return 'Day $dayOfMonth';
    }
    return days[dayOfMonth.clamp(0, 6)];
  }

  /// Get a human-readable frequency description
  String get frequencyDescription {
    switch (frequency) {
      case RecurringExpenseFrequency.monthly:
        return 'Monthly on day $dayOfMonth';
      case RecurringExpenseFrequency.biweekly:
        return 'Every 2 weeks on $dayName';
      case RecurringExpenseFrequency.weekly:
        return 'Weekly on $dayName';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': DecimalHelper.toDouble(_amount),  // Convert to double for database
      'category': category,
      'dayOfMonth': dayOfMonth,
      'isActive': isActive ? 1 : 0,
      'lastCreated': lastCreated != null ? DateHelper.toDateString(lastCreated!) : null,
      'account_id': accountId,
      'paymentMethod': paymentMethod,
      'endDate': endDate != null ? DateHelper.toDateString(endDate!) : null,
      'maxOccurrences': maxOccurrences,
      'occurrenceCount': occurrenceCount,
      'frequency': frequency.index,
      'startDate': startDate != null ? DateHelper.toDateString(startDate!) : null,
    };
  }

  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    // CRITICAL FIX: Use DateHelper for consistent normalization and error handling
    DateTime? parseDateTime(dynamic value, String fieldName) {
      if (value == null) return null;
      final parsed = DateHelper.parseDate(value.toString());
      if (parsed == null && kDebugMode) {
        debugPrint('RecurringExpense ID ${map['id']}: Invalid $fieldName date "$value"');
      }
      return parsed;
    }

    // FIX P0-3: Validate frequency index to prevent RangeError on corrupted data
    final frequencyIndex = map['frequency'] as int? ?? 0;
    final safeFrequencyIndex = frequencyIndex.clamp(0, RecurringExpenseFrequency.values.length - 1);
    if (frequencyIndex != safeFrequencyIndex && kDebugMode) {
      debugPrint('RecurringExpense ID ${map['id']}: Invalid frequency index $frequencyIndex, using $safeFrequencyIndex');
    }

    return RecurringExpense(
      id: map['id'],
      description: map['description'],
      amount: DecimalHelper.fromDoubleSafe(map['amount'] as double?),  // Convert from database double
      category: map['category'],
      dayOfMonth: map['dayOfMonth'],
      isActive: map['isActive'] == 1,
      lastCreated: parseDateTime(map['lastCreated'], 'lastCreated'),
      accountId: map['account_id'],
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      endDate: parseDateTime(map['endDate'], 'endDate'),
      maxOccurrences: map['maxOccurrences'] as int?,
      occurrenceCount: map['occurrenceCount'] as int? ?? 0,
      frequency: RecurringExpenseFrequency.values[safeFrequencyIndex],
      startDate: parseDateTime(map['startDate'], 'startDate'),
    );
  }

  /// Copy with updated values. Use clear* flags to explicitly set optional fields to null.
  /// FIX P0-2: Added clear flags to allow explicitly clearing optional fields.
  RecurringExpense copyWith({
    int? id,
    String? description,
    double? amount,
    String? category,
    int? dayOfMonth,
    bool? isActive,
    DateTime? lastCreated,
    bool clearLastCreated = false,
    int? accountId,
    String? paymentMethod,
    DateTime? endDate,
    bool clearEndDate = false,
    int? maxOccurrences,
    bool clearMaxOccurrences = false,
    int? occurrenceCount,
    RecurringExpenseFrequency? frequency,
    DateTime? startDate,
    bool clearStartDate = false,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount != null ? DecimalHelper.fromDouble(amount) : _amount,
      category: category ?? this.category,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      isActive: isActive ?? this.isActive,
      lastCreated: clearLastCreated ? null : (lastCreated ?? this.lastCreated),
      accountId: accountId ?? this.accountId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      maxOccurrences: clearMaxOccurrences ? null : (maxOccurrences ?? this.maxOccurrences),
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      frequency: frequency ?? this.frequency,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
    );
  }

  /// Copy with Decimal values. Use clear* flags to explicitly set optional fields to null.
  /// FIX P0-2: Added clear flags to allow explicitly clearing optional fields.
  RecurringExpense copyWithDecimal({
    int? id,
    String? description,
    Decimal? amount,
    String? category,
    int? dayOfMonth,
    bool? isActive,
    DateTime? lastCreated,
    bool clearLastCreated = false,
    int? accountId,
    String? paymentMethod,
    DateTime? endDate,
    bool clearEndDate = false,
    int? maxOccurrences,
    bool clearMaxOccurrences = false,
    int? occurrenceCount,
    RecurringExpenseFrequency? frequency,
    DateTime? startDate,
    bool clearStartDate = false,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? _amount,
      category: category ?? this.category,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      isActive: isActive ?? this.isActive,
      lastCreated: clearLastCreated ? null : (lastCreated ?? this.lastCreated),
      accountId: accountId ?? this.accountId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      maxOccurrences: clearMaxOccurrences ? null : (maxOccurrences ?? this.maxOccurrences),
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      frequency: frequency ?? this.frequency,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
    );
  }

  /// Check if this recurring expense should still be active
  bool get shouldBeActive {
    if (!isActive) return false;

    // Check if end date has passed (use normalized dates for comparison)
    if (endDate != null && DateHelper.isPast(endDate!)) {
      return false;
    }

    // Check if max occurrences reached
    if (maxOccurrences != null && occurrenceCount >= maxOccurrences!) {
      return false;
    }

    return true;
  }
}