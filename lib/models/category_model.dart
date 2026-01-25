class Category {
  final int? id;
  final String name;
  final int accountId;
  final bool isDefault;
  final String type; // 'expense' or 'income'
  final String? color; // Hex color code (e.g., '#FF5733')
  final String? icon; // Icon code point as string

  Category({
    this.id,
    required this.name,
    required this.accountId,
    this.isDefault = false,
    this.type = 'expense',
    this.color,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'account_id': accountId,
      'isDefault': isDefault ? 1 : 0,
      'type': type,
      'color': color,
      'icon': icon,
    };
  }

  /// Create a Category from a database map.
  /// FIX: Validates that required fields exist to prevent null reference exceptions.
  factory Category.fromMap(Map<String, dynamic> map) {
    // FIX: Validate required fields exist
    final name = map['name'];
    if (name == null || (name is String && name.isEmpty)) {
      throw ArgumentError('Category name is required and cannot be empty');
    }

    final accountId = map['account_id'];
    if (accountId == null) {
      throw ArgumentError('Category account_id is required');
    }

    return Category(
      id: map['id'],
      name: name as String,
      accountId: accountId as int,
      isDefault: map['isDefault'] == 1,
      type: map['type'] ?? 'expense',
      color: map['color'],
      icon: map['icon'],
    );
  }

  Category copyWith({
    int? id,
    String? name,
    int? accountId,
    bool? isDefault,
    String? type,
    String? color,
    String? icon,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      accountId: accountId ?? this.accountId,
      isDefault: isDefault ?? this.isDefault,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }
}