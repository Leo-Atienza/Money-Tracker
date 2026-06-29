import 'dart:convert';

import 'package:budget_tracker/utils/db_encryption.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 6.1 — at-rest DB encryption key management ([DbEncryption]).
///
/// The real cipher can't run on the Windows test runner, but the key lifecycle
/// (generate once, persist, return the same value next launch, degrade
/// gracefully when the Keystore channel throws) is pure Dart over the mocked
/// `flutter_secure_storage` channel and is fully exercised here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureBacking;
  late TestDefaultBinaryMessenger messenger;
  var failSecureWrites = false;

  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    secureBacking = <String, String>{};
    failSecureWrites = false;
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      switch (call.method) {
        case 'read':
          return secureBacking[(call.arguments as Map)['key'] as String];
        case 'write':
          if (failSecureWrites) {
            throw PlatformException(code: 'Keystore', message: 'unavailable');
          }
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
          secureBacking.remove((call.arguments as Map)['key'] as String);
          return null;
        case 'readAll':
          return Map<String, String>.from(secureBacking);
        case 'deleteAll':
          secureBacking.clear();
          return null;
        case 'containsKey':
          return secureBacking
              .containsKey((call.arguments as Map)['key'] as String);
      }
      return null;
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(secureChannel, null);
  });

  test('getOrCreateKey generates a 256-bit base64 key on first call', () async {
    final key = await DbEncryption.getOrCreateKey();
    expect(key, isNotNull);
    expect(base64Decode(key!).length, 32);
  });

  test('getOrCreateKey returns the same persisted key across calls', () async {
    final first = await DbEncryption.getOrCreateKey();
    final second = await DbEncryption.getOrCreateKey();
    expect(first, isNotNull);
    expect(second, equals(first));
  });

  test('hasKey is false before generation and true afterwards', () async {
    expect(await DbEncryption.hasKey(), isFalse);
    await DbEncryption.getOrCreateKey();
    expect(await DbEncryption.hasKey(), isTrue);
  });

  test('a persisted key survives a simulated relaunch', () async {
    final created = await DbEncryption.getOrCreateKey();
    // Fresh launch: SharedPreferences wiped, the secure store (Keystore) kept.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final reloaded = await DbEncryption.getOrCreateKey();
    expect(reloaded, equals(created));
  });

  test('two freshly generated keys differ (entropy sanity)', () async {
    final a = await DbEncryption.getOrCreateKey();
    secureBacking.clear();
    final b = await DbEncryption.getOrCreateKey();
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(a, isNot(equals(b)));
  });

  test('still produces a stable key when the Keystore write throws '
      '(SharedPreferences fallback)', () async {
    failSecureWrites = true;
    final key = await DbEncryption.getOrCreateKey();
    expect(key, isNotNull, reason: 'fallback store must still persist the key');
    final again = await DbEncryption.getOrCreateKey();
    expect(again, equals(key));
  });
}
