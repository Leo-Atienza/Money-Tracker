class Account {
  final int? id;
  final String name;
  final String? icon;
  final String? color;
  final bool isDefault;
  final String currencyCode;

  Account({
    this.id,
    required this.name,
    this.icon,
    this.color,
    this.isDefault = false,
    this.currencyCode = 'USD',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'isDefault': isDefault ? 1 : 0,
      'currencyCode': currencyCode,
    };
  }

  /// Create an Account from a database map.
  /// FIX: Validates that required fields exist to prevent null reference exceptions.
  factory Account.fromMap(Map<String, dynamic> map) {
    // FIX: Validate required field
    final name = map['name'];
    if (name == null || (name is String && name.isEmpty)) {
      throw ArgumentError('Account name is required and cannot be empty');
    }

    return Account(
      id: map['id'],
      name: name as String,
      icon: map['icon'],
      color: map['color'],
      isDefault: map['isDefault'] == 1,
      currencyCode: map['currencyCode'] as String? ?? 'USD',
    );
  }

  Account copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
    bool? isDefault,
    String? currencyCode,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}