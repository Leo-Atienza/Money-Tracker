import 'package:decimal/decimal.dart';
import '../utils/decimal_helper.dart';
import '../utils/date_helper.dart';

class Budget {
  final int? id;
  final String category;
  final Decimal _amount;
  final int accountId;
  final DateTime month;

  Budget({
    this.id,
    required this.category,
    required Decimal amount,
    required this.accountId,
    required this.month,
  }) : _amount = amount;

  // Public getter that returns double for backward compatibility
  double get amount => DecimalHelper.toDouble(_amount);

  // Internal Decimal getter for precise calculations
  Decimal get amountDecimal => _amount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'amount': DecimalHelper.toDouble(_amount),  // Convert to double for database
      'account_id': accountId,  // Use snake_case to match database column
      'month': DateHelper.toDateString(month),  // Normalize month to ISO 8601 date string
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    // CRITICAL FIX: Add explicit null check before type checking
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

    return Budget(
      id: map['id'],
      category: map['category'],
      amount: DecimalHelper.fromDoubleSafe(map['amount'] as double?),  // Convert from database double
      accountId: map['account_id'] ?? map['accountId'],  // Support both formats for compatibility
      month: parsedMonth ?? DateHelper.startOfMonth(DateHelper.today()),  // Normalize month and fallback to current month
    );
  }

  Budget copyWith({
    int? id,
    String? category,
    double? amount,
    int? accountId,
    DateTime? month,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount != null ? DecimalHelper.fromDouble(amount) : _amount,
      accountId: accountId ?? this.accountId,
      month: month ?? this.month,
    );
  }

  // Additional copyWith for Decimal values
  Budget copyWithDecimal({
    int? id,
    String? category,
    Decimal? amount,
    int? accountId,
    DateTime? month,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      amount: amount ?? _amount,
      accountId: accountId ?? this.accountId,
      month: month ?? this.month,
    );
  }
}
