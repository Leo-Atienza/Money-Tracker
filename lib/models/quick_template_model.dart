import 'package:decimal/decimal.dart';
import '../utils/decimal_helper.dart';

class QuickTemplate {
  final int? id;
  final String name;
  final Decimal _amount;
  final String category;
  final String paymentMethod;
  final String type; // 'expense' or 'income'
  final int accountId;
  final int sortOrder;

  QuickTemplate({
    this.id,
    required this.name,
    required Decimal amount,
    required this.category,
    this.paymentMethod = 'Cash',
    this.type = 'expense',
    required this.accountId,
    this.sortOrder = 0,
  }) : _amount = amount;

  // Public getter that returns double for backward compatibility
  double get amount => DecimalHelper.toDouble(_amount);

  // Internal Decimal getter for precise calculations
  Decimal get amountDecimal => _amount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': DecimalHelper.toDouble(_amount),  // Convert to double for database
      'category': category,
      'paymentMethod': paymentMethod,
      'type': type,
      'account_id': accountId,
      'sortOrder': sortOrder,
    };
  }

  /// Create a QuickTemplate from a database map.
  /// FIX: Validates that required fields exist to prevent null reference exceptions.
  factory QuickTemplate.fromMap(Map<String, dynamic> map) {
    // FIX: Validate required fields
    final name = map['name'];
    if (name == null || (name is String && name.isEmpty)) {
      throw ArgumentError('QuickTemplate name is required');
    }

    final category = map['category'];
    if (category == null || (category is String && category.isEmpty)) {
      throw ArgumentError('QuickTemplate category is required');
    }

    final accountId = map['account_id'];
    if (accountId == null) {
      throw ArgumentError('QuickTemplate account_id is required');
    }

    return QuickTemplate(
      id: map['id'],
      name: name as String,
      amount: DecimalHelper.fromDoubleSafe(map['amount'] as double?),  // Convert from database double
      category: category as String,
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      type: map['type'] ?? 'expense',
      accountId: accountId as int,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  QuickTemplate copyWith({
    int? id,
    String? name,
    double? amount,
    String? category,
    String? paymentMethod,
    String? type,
    int? accountId,
    int? sortOrder,
  }) {
    return QuickTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount != null ? DecimalHelper.fromDouble(amount) : _amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  // Additional copyWith for Decimal values
  QuickTemplate copyWithDecimal({
    int? id,
    String? name,
    Decimal? amount,
    String? category,
    String? paymentMethod,
    String? type,
    int? accountId,
    int? sortOrder,
  }) {
    return QuickTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? _amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      type: type ?? this.type,
      accountId: accountId ?? this.accountId,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
