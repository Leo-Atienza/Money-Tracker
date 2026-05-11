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
  })  : _carryoverFromPrevious = carryoverFromPrevious,
        _overallBudget = overallBudget;

  /// The amount carried over from the previous month (can be negative for deficits)
  double get carryoverFromPrevious =>
      DecimalHelper.toDouble(_carryoverFromPrevious);

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
      // Phase 4.8: store as YYYY-MM (the month *key*) rather than the
      // YYYY-MM-DD of the first-of-month. The previous full-date version
      // led to silent duplicate rows when callers truncated to YYYY-MM
      // for lookup but the writer left YYYY-MM-DD on disk. Migration v19
      // normalises existing rows via `UPDATE ... SET month = substr(month, 1, 7)`.
      'month': DateHelper.toMonthString(month),
    };
  }

  factory MonthlyBalance.fromMap(Map<String, dynamic> map) {
    final monthValue = map['month'];
    DateTime? parsedMonth;

    if (monthValue == null) {
      parsedMonth = DateHelper.startOfMonth(DateHelper.today());
    } else if (monthValue is String) {
      // Phase 4.8: rows written post-v19 use YYYY-MM. Expand to YYYY-MM-01
      // before delegating to `parseDate`, which only accepts full dates.
      // Pre-v19 rows in YYYY-MM-DD form are accepted unchanged.
      final value = monthValue.length == 7 && monthValue.contains('-')
          ? '$monthValue-01'
          : monthValue;
      parsedMonth = DateHelper.parseDate(value);
    } else if (monthValue is int) {
      parsedMonth = DateHelper.normalize(
        DateTime.fromMillisecondsSinceEpoch(monthValue),
      );
    } else {
      parsedMonth = DateHelper.startOfMonth(DateHelper.today());
    }

    // Parse overall budget (can be null)
    final overallBudgetValue = map['overall_budget'];
    Decimal? overallBudget;
    if (overallBudgetValue != null) {
      overallBudget = DecimalHelper.fromDoubleSafe(
        (overallBudgetValue as num?)?.toDouble(),
      );
      // Treat zero as null (no budget set)
      if (overallBudget == Decimal.zero) {
        overallBudget = null;
      }
    }

    // Phase 4.11: snake_case only. The `accountId` fallback to `0` would
    // attach orphan rows to the no-such-account id; reject upfront instead.
    final accountId = map['account_id'];
    if (accountId == null) {
      throw ArgumentError('MonthlyBalance account_id is required');
    }

    return MonthlyBalance(
      id: map['id'],
      carryoverFromPrevious: DecimalHelper.fromDoubleSafe(
        (map['carryover_from_previous'] as num?)?.toDouble(),
      ),
      overallBudget: overallBudget,
      accountId: accountId as int,
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
          : (overallBudget != null
              ? DecimalHelper.fromDouble(overallBudget)
              : _overallBudget),
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
      overallBudget:
          clearOverallBudget ? null : (overallBudget ?? _overallBudget),
      accountId: accountId ?? this.accountId,
      month: month ?? this.month,
    );
  }
}
