import 'package:decimal/decimal.dart';
import '../utils/decimal_helper.dart';
import '../utils/date_helper.dart';

class Expense {
  final int? id;
  final Decimal _amount;
  final String category;
  final String description;
  final DateTime date;
  final int accountId;
  final Decimal _amountPaid;
  final String paymentMethod;

  Expense({
    this.id,
    required Decimal amount,
    required this.category,
    required this.description,
    required this.date,
    required this.accountId,
    Decimal? amountPaid,
    this.paymentMethod = 'Cash',
  })  : _amount = amount,
        _amountPaid = amountPaid ?? Decimal.zero;

  // Public getters that return double for backward compatibility
  double get amount => DecimalHelper.toDouble(_amount);
  double get amountPaid => DecimalHelper.toDouble(_amountPaid);

  // Internal Decimal getters for precise calculations
  Decimal get amountDecimal => _amount;
  Decimal get amountPaidDecimal => _amountPaid;

  // Automatically determine if paid based on amount paid
  // CRITICAL FIX: Use Decimal comparison with proper rounding to avoid precision issues
  // Decimal package handles precision correctly, but we normalize to 2 decimal places
  // to match currency display (prevents 99.999999 vs 100.00 edge cases)
  bool get isPaid {
    // Round both values to 2 decimal places for comparison (currency precision)
    final amountRounded = DecimalHelper.fromDouble(DecimalHelper.toDouble(_amount));
    final paidRounded = DecimalHelper.fromDouble(DecimalHelper.toDouble(_amountPaid));
    return paidRounded >= amountRounded;
  }

  // Get remaining amount to pay
  double get remainingAmount => DecimalHelper.toDouble(_amount - _amountPaid);

  // Get remaining amount as Decimal
  Decimal get remainingAmountDecimal => _amount - _amountPaid;

  // Get payment progress (0.0 to 1.0)
  double get paymentProgress {
    // Check if amount is zero or very close to zero to prevent division by zero
    if (_amount <= Decimal.parse('0.01')) return 0.0;
    final progress = (_amountPaid / _amount).toDecimal();
    final one = Decimal.one;
    final clamped = progress < Decimal.zero ? Decimal.zero : (progress > one ? one : progress);
    return DecimalHelper.toDouble(clamped);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': DecimalHelper.toDouble(_amount),  // Convert to double for database
      'category': category,
      'description': description,
      'date': DateHelper.toDateString(date),  // Normalize to ISO 8601 date string
      'account_id': accountId,
      'amountPaid': DecimalHelper.toDouble(_amountPaid),  // Convert to double for database
      'paymentMethod': paymentMethod,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      amount: DecimalHelper.fromDoubleSafe(map['amount'] as double?),  // Convert from database double
      category: map['category'],
      description: map['description'] ?? '',
      date: DateHelper.parseDate(map['date']) ?? DateHelper.today(),  // Normalize date from database
      accountId: map['account_id'],
      amountPaid: DecimalHelper.fromDoubleSafe(map['amountPaid'] as double?),  // Convert from database double
      paymentMethod: map['paymentMethod'] ?? 'Cash',
    );
  }

  Expense copyWith({
    int? id,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    int? accountId,
    double? amountPaid,
    String? paymentMethod,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount != null ? DecimalHelper.fromDouble(amount) : _amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      amountPaid: amountPaid != null ? DecimalHelper.fromDouble(amountPaid) : _amountPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  // Additional copyWith for Decimal values
  Expense copyWithDecimal({
    int? id,
    Decimal? amount,
    String? category,
    String? description,
    DateTime? date,
    int? accountId,
    Decimal? amountPaid,
    String? paymentMethod,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? _amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
      amountPaid: amountPaid ?? _amountPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}