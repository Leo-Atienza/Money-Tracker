import 'package:budget_tracker/services/onboarding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 7.3 — real OnboardingService coverage.
///
/// Replaces the compile-time stubs in `services_test.dart` (which only
/// asserted that the methods existed) with behaviour tests that exercise
/// the SharedPreferences-backed state machine end-to-end.
void main() {
  setUp(() async {
    // Each test sees a fresh in-memory SharedPreferences store. Without
    // this the boolean flags would leak between tests via the platform
    // channel mock.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('OnboardingService.isOnboardingComplete', () {
    test('returns false on a fresh install', () async {
      expect(await OnboardingService().isOnboardingComplete(), isFalse);
    });

    test('returns true after completeOnboarding', () async {
      final service = OnboardingService();
      await service.completeOnboarding();
      expect(await service.isOnboardingComplete(), isTrue);
    });

    test('persists across SharedPreferences.getInstance() calls', () async {
      // Mark via one instance; read via another. The persistence layer is
      // SharedPreferences which is a singleton across instances within
      // a process — pin that contract.
      await OnboardingService().completeOnboarding();
      expect(await OnboardingService().isOnboardingComplete(), isTrue);
    });

    test('returns false after resetOnboarding', () async {
      final service = OnboardingService();
      await service.completeOnboarding();
      await service.resetOnboarding();
      expect(await service.isOnboardingComplete(), isFalse);
    });
  });

  group('OnboardingService.isFirstLaunch', () {
    test('returns true on the very first call', () async {
      expect(await OnboardingService().isFirstLaunch(), isTrue);
    });

    test('returns false on subsequent calls (self-extinguishing flag)', () async {
      final service = OnboardingService();
      expect(await service.isFirstLaunch(), isTrue);
      expect(await service.isFirstLaunch(), isFalse);
      expect(await service.isFirstLaunch(), isFalse);
    });

    test('resetOnboarding makes the next isFirstLaunch return true again', () async {
      final service = OnboardingService();
      await service.isFirstLaunch(); // consume
      expect(await service.isFirstLaunch(), isFalse);
      await service.resetOnboarding();
      expect(await service.isFirstLaunch(), isTrue);
    });
  });

  group('OnboardingService.completeOnboarding', () {
    test('is idempotent — calling twice still yields isOnboardingComplete=true', () async {
      final service = OnboardingService();
      await service.completeOnboarding();
      await service.completeOnboarding();
      expect(await service.isOnboardingComplete(), isTrue);
    });
  });
}
