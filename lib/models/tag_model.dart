/// Tag model for labeling/categorizing transactions.
///
/// Tags are loaded in AppState and selectable from AddTransactionScreen
/// (Phase 5.5 merged the previous AddExpense / AddIncome forms). The
/// database stores them in `tags` + `transaction_tags`. A dedicated
/// TagManagerScreen and tag-based history filtering are still open
/// follow-ups.
class Tag {
  final int? id;
  final String name;
  final String? color;
  final int accountId;

  Tag({this.id, required this.name, this.color, required this.accountId});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'color': color, 'account_id': accountId};
  }

  /// Create a Tag from a database map.
  /// FIX: Validates that required fields exist to prevent null reference exceptions.
  factory Tag.fromMap(Map<String, dynamic> map) {
    // FIX: Validate required fields
    final name = map['name'];
    if (name == null || (name is String && name.isEmpty)) {
      throw ArgumentError('Tag name is required');
    }

    final accountId = map['account_id'];
    if (accountId == null) {
      throw ArgumentError('Tag account_id is required');
    }

    return Tag(
      id: map['id'] as int?,
      name: name as String,
      color: map['color'] as String?,
      accountId: accountId as int,
    );
  }

  Tag copyWith({int? id, String? name, String? color, int? accountId}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      accountId: accountId ?? this.accountId,
    );
  }
}
