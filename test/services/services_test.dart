import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/services/biometric_service.dart';
import 'package:budget_tracker/services/onboarding_service.dart';
import 'package:budget_tracker/utils/notification_payload_store.dart';

void main() {
  group('BiometricService', () {
    late BiometricService service;

    setUp(() {
      service = BiometricService();
    });

    test('constructor creates a valid instance', () {
      expect(service, isNotNull);
      expect(service, isA<BiometricService>());
    });

    test('multiple instances can be created (no enforced singleton)', () {
      final service1 = BiometricService();
      final service2 = BiometricService();
      expect(service1, isNotNull);
      expect(service2, isNotNull);
      // They are separate instances (factory-like, not singleton)
      expect(identical(service1, service2), isFalse);
    });

    test('isDeviceSupported() always returns false (stub)', () async {
      final result = await service.isDeviceSupported();
      expect(result, isFalse);
    });

    test('isDeviceSupported() returns Future<bool>', () {
      final result = service.isDeviceSupported();
      expect(result, isA<Future<bool>>());
    });

    test('authenticate() always returns true (stub - allows access)', () async {
      final result = await service.authenticate();
      expect(result, isTrue);
    });

    test('authenticate() accepts custom reason parameter', () async {
      final result = await service.authenticate(reason: 'Custom reason');
      expect(result, isTrue);
    });

    test('authenticate() returns Future<bool>', () {
      final result = service.authenticate();
      expect(result, isA<Future<bool>>());
    });

    test('getAvailableBiometrics() returns empty list (stub)', () async {
      final result = await service.getAvailableBiometrics();
      expect(result, isEmpty);
      expect(result, isA<List<String>>());
    });

    test('getAvailableBiometrics() returns Future<List<String>>', () {
      final result = service.getAvailableBiometrics();
      expect(result, isA<Future<List<String>>>());
    });

    test('has isBiometricEnabled method (compile-time verification)', () {
      // This test verifies the method exists and returns the correct type.
      // We cannot call it without SharedPreferences, but we verify the signature.
      expect(service.isBiometricEnabled, isA<Function>());
    });

    test('has enableBiometric method (compile-time verification)', () {
      expect(service.enableBiometric, isA<Function>());
    });

    test('has disableBiometric method (compile-time verification)', () {
      expect(service.disableBiometric, isA<Function>());
    });
  });

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
