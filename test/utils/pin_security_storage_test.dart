import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/utils/pin_security_helper.dart';

/// Phase 6.2: storage-touching tests for [PinSecurityHelper].
///
/// The existing `pin_security_helper_test.dart` only covers the pure
/// `checkPinStrength` method. This file exercises the methods that go
/// through `SecurePrefs` (and thus the mocked `flutter_secure_storage`
/// channel): `setPin`, `verifyPin`, `disablePin`, and the legacy
/// PIN migration path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureBacking;
  late TestDefaultBinaryMessenger messenger;

  const channel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  setUp(() async {
    secureBacking = <String, String>{};
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'read':
          final args = call.arguments as Map;
          return secureBacking[args['key'] as String];
        case 'write':
          final args = call.arguments as Map;
          final key = args['key'] as String;
          final value = args['value'] as String?;
          if (value == null) {
            secureBacking.remove(key);
          } else {
            secureBacking[key] = value;
          }
          return null;
        case 'delete':
          final args = call.arguments as Map;
          secureBacking.remove(args['key'] as String);
          return null;
        case 'readAll':
          return Map<String, String>.from(secureBacking);
        case 'deleteAll':
          secureBacking.clear();
          return null;
        case 'containsKey':
          final args = call.arguments as Map;
          return secureBacking.containsKey(args['key'] as String);
      }
      return null;
    });

    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('setPin → verifyPin → disablePin round-trip via secure store',
      () async {
    expect(await PinSecurityHelper.isPinEnabled(), isFalse);

    final ok = await PinSecurityHelper.setPin('9027');
    expect(ok, isTrue);
    expect(await PinSecurityHelper.isPinEnabled(), isTrue);
    expect(await PinSecurityHelper.getPinLength(), equals(4));

    // Hash + salt landed in the secure backing, NOT in legacy prefs.
    expect(secureBacking.containsKey('app_pin_hash'), isTrue);
    expect(secureBacking.containsKey('app_pin_salt'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_pin_hash'), isNull);
    expect(prefs.getString('app_pin_salt'), isNull);

    expect(await PinSecurityHelper.verifyPin('9027'), isTrue);
    expect(await PinSecurityHelper.verifyPin('0000'), isFalse);

    await PinSecurityHelper.disablePin();
    expect(await PinSecurityHelper.isPinEnabled(), isFalse);
    expect(secureBacking.containsKey('app_pin_hash'), isFalse);
    expect(secureBacking.containsKey('app_pin_salt'), isFalse);
  });

  test('rejects invalid PIN format on setPin', () async {
    expect(await PinSecurityHelper.setPin('abc'), isFalse);
    expect(await PinSecurityHelper.setPin('12'), isFalse);
    expect(await PinSecurityHelper.setPin('1234567'), isFalse);
    expect(secureBacking, isEmpty);
  });

  test('legacy salted PIN is migrated to secure store on first verify',
      () async {
    // Simulate a user upgrading from a pre-6.2 build: hash + salt live in
    // SharedPreferences instead of the secure store.
    const pin = '4829';
    const salt = 'deadbeef';
    final legacyHash = sha256.convert(utf8.encode(salt + pin)).toString();

    SharedPreferences.setMockInitialValues({
      'app_pin_hash': legacyHash,
      'app_pin_salt': salt,
      'pin_enabled': true,
      'pin_length': 4,
    });

    // Reading each property migrates that key. Walk every accessor the
    // app actually calls so we observe the full pre-6.2 → post-6.2 shift.
    expect(await PinSecurityHelper.isPinEnabled(), isTrue);
    expect(await PinSecurityHelper.getPinLength(), equals(4));
    expect(await PinSecurityHelper.verifyPin(pin), isTrue);

    expect(secureBacking['app_pin_hash'], equals(legacyHash));
    expect(secureBacking['app_pin_salt'], equals(salt));
    expect(secureBacking['pin_enabled'], equals('true'));
    expect(secureBacking['pin_length'], equals('4'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_pin_hash'), isNull);
    expect(prefs.getString('app_pin_salt'), isNull);
    expect(prefs.getBool('pin_enabled'), isNull);
    expect(prefs.getInt('pin_length'), isNull);
  });

  test('legacy un-salted PIN still verifies (pre-salt-era PINs)', () async {
    const pin = '4829';
    final legacyHash = sha256.convert(utf8.encode(pin)).toString();

    SharedPreferences.setMockInitialValues({
      'app_pin_hash': legacyHash,
      // No salt key — pre-salt-era user.
      'pin_enabled': true,
      'pin_length': 4,
    });

    expect(await PinSecurityHelper.verifyPin(pin), isTrue);
  });

  test('resetPinData wipes both stores', () async {
    await PinSecurityHelper.setPin('4829');
    SharedPreferences.setMockInitialValues({
      'app_pin_hash': 'legacy-leftover',
    });

    await PinSecurityHelper.resetPinData();

    expect(secureBacking, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_pin_hash'), isNull);
  });

  test('failed verify increments lockout counter in secure store',
      () async {
    await PinSecurityHelper.setPin('4829');

    expect(await PinSecurityHelper.getRemainingAttempts(), equals(5));

    await PinSecurityHelper.verifyPin('0000');
    expect(await PinSecurityHelper.getRemainingAttempts(), equals(4));
    expect(secureBacking.containsKey('pin_failed_attempts'), isTrue);

    // Successful verify clears the counter.
    await PinSecurityHelper.verifyPin('4829');
    expect(await PinSecurityHelper.getRemainingAttempts(), equals(5));
    expect(secureBacking.containsKey('pin_failed_attempts'), isFalse);
  });
}
