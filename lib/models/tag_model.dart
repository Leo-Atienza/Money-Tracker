/// Tag model for labeling/categorizing transactions.
///
/// FIX P2-11: FEATURE INCOMPLETE - Tags are defined in the database schema and
/// loaded in AppState, but the UI for tag management is not yet implemented.
/// The database has a `tags` table and `transaction_tags` junction table ready.
///
/// To complete this feature:
/// 1. Add TagManagerScreen in lib/screens/ for CRUD operations on tags
/// 2. Add tag selection UI in AddExpenseScreen/AddIncomeScreen
/// 3. Add tag filtering in HistoryScreen
/// 4. Add tag-related methods to AppState (addTag, deleteTag, getTagsForTransaction, etc.)
class Tag {
  final int? id;
  final String name;
  final String? color;
  final int accountId;

  Tag({
    this.id,
    required this.name,
    this.color,
    required this.accountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'account_id': accountId,
    };
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

  Tag copyWith({
    int? id,
    String? name,
    String? color,
    int? accountId,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      accountId: accountId ?? this.accountId,
    );
  }
}
