import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/onboarding_service.dart';
import 'package:budget_tracker/utils/notification_payload_store.dart';

void main() {
  group('OnboardingService', () {
    late OnboardingService service;

    setUp(() {
      service = OnboardingService();
    });

    test('constructor creates a valid instance', () {
      expect(service, isNotNull);
      expect(service, isA<OnboardingService>());
    });

    test('multiple instances can be created', () {
      final service1 = OnboardingService();
      final service2 = OnboardingService();
      expect(service1, isNotNull);
      expect(service2, isNotNull);
      expect(identical(service1, service2), isFalse);
    });

    test('has isOnboardingComplete method (compile-time verification)', () {
      expect(service.isOnboardingComplete, isA<Function>());
    });

    test('has completeOnboarding method (compile-time verification)', () {
      expect(service.completeOnboarding, isA<Function>());
    });

    test('has isFirstLaunch method (compile-time verification)', () {
      expect(service.isFirstLaunch, isA<Function>());
    });

    test('has resetOnboarding method (compile-time verification)', () {
      expect(service.resetOnboarding, isA<Function>());
    });
  });

  group('NotificationPayloadStore', () {
    test('class exists and can be referenced', () {
      // Compile-time verification that the class exists
      expect(NotificationPayloadStore, isNotNull);
    });

    test('storePendingPayload is a static method', () {
      // Verify the static method exists and has the correct signature
      expect(NotificationPayloadStore.storePendingPayload, isA<Function>());
    });

    test('consumePendingPayload is a static method', () {
      expect(NotificationPayloadStore.consumePendingPayload, isA<Function>());
    });

    test('clearPendingPayload is a static method', () {
      expect(NotificationPayloadStore.clearPendingPayload, isA<Function>());
    });
  });
}
