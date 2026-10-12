/// Phase 6.4 — Home widget payload + redaction.
///
/// Pure-function layer between `HomeWidgetHelper` and the native widget
/// surface. When PIN protection is enabled, the launcher's widget keeps
/// rendering even on the lock screen — so we must NOT leak balances there.
/// `redactIfLocked` swaps every monetary value for `'•••'`.
///
/// Kept separate from `HomeWidgetHelper` so it stays trivially testable
/// without a live `HomeWidget` channel.
library;

/// One month's figures as the home widget shows them.
class WidgetData {
  /// `yyyy-MM` of the month the figures belong to. The native widget compares
  /// it with the device clock to tell whether these figures are current.
  final String monthKey;
  final String monthName;

  /// Formatted with a leading `-` when negative and no sign otherwise — the
  /// same way the Home screen prints the balance.
  final String balance;
  final String income;
  final String expenses;

  const WidgetData({
    required this.monthKey,
    required this.monthName,
    required this.balance,
    required this.income,
    required this.expenses,
  });

  WidgetData copyWith({
    String? monthKey,
    String? monthName,
    String? balance,
    String? income,
    String? expenses,
  }) {
    return WidgetData(
      monthKey: monthKey ?? this.monthKey,
      monthName: monthName ?? this.monthName,
      balance: balance ?? this.balance,
      income: income ?? this.income,
      expenses: expenses ?? this.expenses,
    );
  }

  /// Key/value pairs for the widget's SharedPreferences. [prefix] namespaces
  /// a second month (`next_`) next to the current one.
  Map<String, String> toWidgetFields({String prefix = ''}) => {
        '${prefix}month_key': monthKey,
        '${prefix}month_name': monthName,
        '${prefix}balance': balance,
        '${prefix}income': income,
        '${prefix}expenses': expenses,
      };
}

class WidgetPayload {
  WidgetPayload._();

  /// Token used in place of every monetary value when PIN is enabled.
  static const String redactedAmount = '•••';

  /// Returns a redacted copy of [data] when [pinEnabled] is true; the
  /// original otherwise. Only the amounts are sensitive: the month name and
  /// key stay so the widget still labels — and rolls over — correctly. The
  /// balance's sign goes with it, since the sign alone says whether the
  /// account is overdrawn.
  static WidgetData redactIfLocked(
    WidgetData data, {
    required bool pinEnabled,
  }) {
    if (!pinEnabled) return data;
    return data.copyWith(
      balance: redactedAmount,
      income: redactedAmount,
      expenses: redactedAmount,
    );
  }
}
