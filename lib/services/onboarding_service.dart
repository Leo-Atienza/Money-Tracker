import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _firstLaunchKey = 'first_launch';

  /// Phase 5.5 — gates the one-time coach mark shown over the
  /// Expense/Income toggle on [AddTransactionScreen]. Mitigates R4
  /// (merged hub confuses existing users) by surfacing the new control
  /// the first time the user opens the screen.
  static const String _addTransactionTooltipKey =
      'add_transaction_tooltip_seen';

  /// Check if onboarding has been completed
  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  /// Check if this is the first launch
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool(_firstLaunchKey) ?? true;
    if (isFirst) {
      await prefs.setBool(_firstLaunchKey, false);
    }
    return isFirst;
  }

  /// Whether the Add Transaction segmented-control tooltip has been
  /// shown and dismissed. Defaults to `false` on first read so a fresh
  /// install (or post-upgrade reset) sees the coach mark once.
  Future<bool> hasSeenAddTransactionTooltip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_addTransactionTooltipKey) ?? false;
  }

  /// Persist the dismissal of the Add Transaction tooltip.
  Future<void> markAddTransactionTooltipSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_addTransactionTooltipKey, true);
  }

  /// Reset onboarding (for testing)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, false);
    await prefs.setBool(_firstLaunchKey, true);
    await prefs.setBool(_addTransactionTooltipKey, false);
  }
}
