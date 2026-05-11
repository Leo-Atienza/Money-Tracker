/// Phase 6.4 — Home widget payload + redaction.
///
/// Pure-function layer between `HomeWidgetHelper` and the native widget
/// surface. When PIN protection is enabled, the launcher's widget keeps
/// rendering even on the lock screen — so we must NOT leak balances /
/// transaction descriptions there. `redactIfLocked` swaps every monetary
/// value for `'•••'` and every description for `'Locked'`.
///
/// Kept separate from `HomeWidgetHelper` so it stays trivially testable
/// without a live `HomeWidget` channel.
library;

/// Immutable shape of the data we push to the home widget.
class WidgetData {
  final String monthName;
  final String expenses;
  final String income;
  final String balance;
  final bool isPositive;
  final String currency;

  const WidgetData({
    required this.monthName,
    required this.expenses,
    required this.income,
    required this.balance,
    required this.isPositive,
    required this.currency,
  });

  WidgetData copyWith({
    String? monthName,
    String? expenses,
    String? income,
    String? balance,
    bool? isPositive,
    String? currency,
  }) {
    return WidgetData(
      monthName: monthName ?? this.monthName,
      expenses: expenses ?? this.expenses,
      income: income ?? this.income,
      balance: balance ?? this.balance,
      isPositive: isPositive ?? this.isPositive,
      currency: currency ?? this.currency,
    );
  }
}

class WidgetPayload {
  WidgetPayload._();

  /// Token used in place of every monetary value when PIN is enabled.
  static const String redactedAmount = '•••';

  /// Token used in place of human-readable strings when PIN is enabled.
  static const String redactedLabel = 'Locked';

  /// Returns a redacted copy of [data] when [pinEnabled] is true; the
  /// original otherwise. Currency code is preserved so the widget's
  /// layout doesn't shift when the user toggles PIN.
  static WidgetData redactIfLocked(
    WidgetData data, {
    required bool pinEnabled,
  }) {
    if (!pinEnabled) return data;
    return data.copyWith(
      monthName: redactedLabel,
      expenses: redactedAmount,
      income: redactedAmount,
      balance: redactedAmount,
      // isPositive stays as-is so the widget's accent color is stable;
      // the value itself is masked.
    );
  }
}
