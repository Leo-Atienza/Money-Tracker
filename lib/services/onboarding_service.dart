import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _firstLaunchKey = 'first_launch';

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

  /// Reset onboarding (for testing)
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, false);
    await prefs.setBool(_firstLaunchKey, true);
  }
}
