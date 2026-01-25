import 'package:decimal/decimal.dart';
import '../utils/decimal_helper.dart';
import '../utils/date_helper.dart';

class Income {
  final int? id;
  final Decimal _amount;
  final String category;
  final String description;
  final DateTime date;
  final int accountId;

  Income({
    this.id,
    required Decimal amount,
    required this.category,
    required this.description,
    required this.date,
    required this.accountId,
  }) : _amount = amount;

  // Public getter that returns double for backward compatibility
  double get amount => DecimalHelper.toDouble(_amount);

  // Internal Decimal getter for precise calculations
  Decimal get amountDecimal => _amount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': DecimalHelper.toDouble(_amount),  // Convert to double for database
      'category': category,
      'description': description,
      'date': DateHelper.toDateString(date),  // Normalize to ISO 8601 date string
      'account_id': accountId,
    };
  }

  /// Create an Income from a database map.
  /// FIX: Validates that required fields exist to prevent null reference exceptions.
  factory Income.fromMap(Map<String, dynamic> map) {
    // FIX: Validate required fields
    final category = map['category'];
    if (category == null || (category is String && category.isEmpty)) {
      throw ArgumentError('Income category is required');
    }

    final accountId = map['account_id'];
    if (accountId == null) {
      throw ArgumentError('Income account_id is required');
    }

    return Income(
      id: map['id'],
      amount: DecimalHelper.fromDoubleSafe(map['amount'] as double?),  // Convert from database double
      category: category as String,
      description: map['description'] ?? '',
      date: DateHelper.parseDate(map['date']) ?? DateHelper.today(),  // Normalize date from database
      accountId: accountId as int,
    );
  }

  Income copyWith({
    int? id,
    double? amount,
    String? category,
    String? description,
    DateTime? date,
    int? accountId,
  }) {
    return Income(
      id: id ?? this.id,
      amount: amount != null ? DecimalHelper.fromDouble(amount) : _amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
    );
  }

  // Additional copyWith for Decimal values
  Income copyWithDecimal({
    int? id,
    Decimal? amount,
    String? category,
    String? description,
    DateTime? date,
    int? accountId,
  }) {
    return Income(
      id: id ?? this.id,
      amount: amount ?? _amount,
      category: category ?? this.category,
      description: description ?? this.description,
      date: date ?? this.date,
      accountId: accountId ?? this.accountId,
    );
  }
}
