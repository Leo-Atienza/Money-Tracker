import 'package:decimal/decimal.dart';
import '../utils/decimal_helper.dart';
import '../utils/date_helper.dart';

/// Represents the financial balance for a specific month.
///
/// Tracks:
/// - carryoverFromPrevious: Amount carried over from the previous month (can be negative)
/// - overallBudget: Optional manual overall budget limit for the month (null = not set)
/// - month: The month this balance belongs to
/// - accountId: The account this balance is associated with
///
/// The carryover is calculated as: previous month's (income - expenses + carryover)
class MonthlyBalance {
  final int? id;
  final Decimal _carryoverFromPrevious;
  final Decimal? _overallBudget; // Optional manual overall budget for the month
  final int accountId;
  final DateTime month;

  MonthlyBalance({
    this.id,
    required Decimal carryoverFromPrevious,
    Decimal? overallBudget,
    required this.accountId,
    required this.month,
  }) : _carryoverFromPrevious = carryoverFromPrevious,
       _overallBudget = overallBudget;

  /// The amount carried over from the previous month (can be negative for deficits)
  double get carryoverFromPrevious => DecimalHelper.toDouble(_carryoverFromPrevious);

  /// Internal Decimal getter for precise calculations
  Decimal get carryoverFromPreviousDecimal => _carryoverFromPrevious;

  /// The overall budget limit for this month (null if not set)
  double? get overallBudget {
    final budget = _overallBudget;
    if (budget == null) return null;
    return DecimalHelper.toDouble(budget);
  }

  /// Internal Decimal getter for precise calculations
  Decimal? get overallBudgetDecimal => _overallBudget;

  /// Check if an overall budget is set for this month
  bool get hasOverallBudget {
    final budget = _overallBudget;
    if (budget == null) return false;
    return budget > Decimal.zero;
  }

  Map<String, dynamic> toMap() {
    final budget = _overallBudget;
    return {
      'id': id,
      'carryover_from_previous': DecimalHelper.toDouble(_carryoverFromPrevious),
      'overall_budget': budget != null ? DecimalHelper.toDouble(budget) : null,
      'account_id': accountId,
      'month': DateHelper.toDateString(month),
    };
  }

  factory MonthlyBalance.fromMap(Map<String, dynamic> map) {
    final monthValue = map['month'];
    DateTime? parsedMonth;

    if (monthValue == null) {
      parsedMonth = DateHelper.startOfMonth(DateHelper.today());
    } else if (monthValue is String) {
      parsedMonth = DateHelper.parseDate(monthValue);
    } else if (monthValue is int) {
      parsedMonth = DateHelper.normalize(DateTime.fromMillisecondsSinceEpoch(monthValue));
    } else {
      parsedMonth = DateHelper.startOfMonth(DateHelper.today());
    }

    // Parse overall budget (can be null)
    final overallBudgetValue = map['overall_budget'];
    Decimal? overallBudget;
    if (overallBudgetValue != null) {
      overallBudget = DecimalHelper.fromDoubleSafe(overallBudgetValue as double?);
      // Treat zero as null (no budget set)
      if (overallBudget == Decimal.zero) {
        overallBudget = null;
      }
    }

    return MonthlyBalance(
      id: map['id'],
      carryoverFromPrevious: DecimalHelper.fromDoubleSafe(map['carryover_from_previous'] as double?),
      overallBudget: overallBudget,
      accountId: map['account_id'] ?? map['accountId'],
      month: parsedMonth ?? DateHelper.startOfMonth(DateHelper.today()),
    );
  }

  MonthlyBalance copyWith({
    int? id,
    double? carryoverFromPrevious,
    double? overallBudget,
    bool clearOverallBudget = false,
    int? accountId,
    DateTime? month,
  }) {
    return MonthlyBalance(
      id: id ?? this.id,
      carryoverFromPrevious: carryoverFromPrevious != null
          ? DecimalHelper.fromDouble(carryoverFromPrevious)
          : _carryoverFromPrevious,
      overallBudget: clearOverallBudget
          ? null
          : (overallBudget != null ? DecimalHelper.fromDouble(overallBudget) : _overallBudget),
      accountId: accountId ?? this.accountId,
      month: month ?? this.month,
    );
  }

  MonthlyBalance copyWithDecimal({
    int? id,
    Decimal? carryoverFromPrevious,
    Decimal? overallBudget,
    bool clearOverallBudget = false,
    int? accountId,
    DateTime? month,
  }) {
    return MonthlyBalance(
      id: id ?? this.id,
      carryoverFromPrevious: carryoverFromPrevious ?? _carryoverFromPrevious,
      overallBudget: clearOverallBudget ? null : (overallBudget ?? _overallBudget),
      accountId: accountId ?? this.accountId,
      month: month ?? this.month,
    );
  }
}
