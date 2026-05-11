import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_tracker/utils/secure_prefs.dart';

/// Phase 6.2: unit tests for [SecurePrefs].
///
/// The class is a thin wrapper around `flutter_secure_storage` with a
/// lazy migration path from `SharedPreferences`. We mock both layers so
/// each test runs deterministically on the host platform.
///
/// `flutter_secure_storage` 9.x talks to native code via the
/// `plugins.it_nomads.com/flutter_secure_storage` channel. The mock
/// handler below implements `read` / `write` / `delete` (the three
/// methods this app actually uses) backed by an in-memory map. Any new
/// secure-store method this app needs in the future should be added to
/// both the handler and the assertions in this file.
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

  test('writeString persists to the secure store', () async {
    await SecurePrefs.writeString('greeting', 'hello');
    expect(secureBacking['greeting'], equals('hello'));
    expect(await SecurePrefs.readString('greeting'), equals('hello'));
  });

  test('writeString scrubs any legacy prefs entry on the same key', () async {
    SharedPreferences.setMockInitialValues({'greeting': 'legacy'});
    await SecurePrefs.writeString('greeting', 'fresh');
    expect(secureBacking['greeting'], equals('fresh'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('greeting'), isNull);
  });

  test('readString migrates a string legacy value on first read', () async {
    SharedPreferences.setMockInitialValues({'token': 'abc123'});
    expect(secureBacking.containsKey('token'), isFalse);

    final v1 = await SecurePrefs.readString('token');
    expect(v1, equals('abc123'));
    expect(secureBacking['token'], equals('abc123'),
        reason: 'migration must populate the secure store');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('token'), isNull,
        reason: 'migration must scrub legacy after secure write');

    // Second read comes straight from the secure store — no fallback hit.
    final v2 = await SecurePrefs.readString('token');
    expect(v2, equals('abc123'));
  });

  test('readBool migrates a legacy bool value', () async {
    SharedPreferences.setMockInitialValues({'pin_enabled': true});
    final v = await SecurePrefs.readBool('pin_enabled');
    expect(v, isTrue);
    expect(secureBacking['pin_enabled'], equals('true'));
  });

  test('readInt migrates a legacy int value', () async {
    SharedPreferences.setMockInitialValues({'pin_length': 6});
    final v = await SecurePrefs.readInt('pin_length');
    expect(v, equals(6));
    expect(secureBacking['pin_length'], equals('6'));
  });

  test('readString returns null when both stores are empty', () async {
    expect(await SecurePrefs.readString('missing'), isNull);
  });

  test('remove deletes from both stores', () async {
    secureBacking['k'] = 'v';
    SharedPreferences.setMockInitialValues({'k': 'legacy'});

    await SecurePrefs.remove('k');

    expect(secureBacking.containsKey('k'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('k'), isNull);
  });

  test('writeBool round-trips', () async {
    await SecurePrefs.writeBool('flag', true);
    expect(await SecurePrefs.readBool('flag'), isTrue);
    await SecurePrefs.writeBool('flag', false);
    expect(await SecurePrefs.readBool('flag'), isFalse);
  });

  test('writeInt round-trips', () async {
    await SecurePrefs.writeInt('n', 42);
    expect(await SecurePrefs.readInt('n'), equals(42));
  });

  test('migration tolerates a flaky secure write (keeps legacy intact)',
      () async {
    // Replace handler with one that throws on `write` so the migration
    // fails. Reads should still work and the legacy entry should survive.
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'read':
          final args = call.arguments as Map;
          return secureBacking[args['key'] as String];
        case 'write':
          throw PlatformException(
            code: 'KEYSTORE',
            message: 'simulated flake',
          );
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({'legacy_only': 'still-here'});

    final v = await SecurePrefs.readString('legacy_only');
    expect(v, equals('still-here'),
        reason: 'caller still sees the value even if migration failed');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('legacy_only'), equals('still-here'),
        reason:
            'legacy entry must NOT be deleted unless the secure write succeeded');
  });
}
