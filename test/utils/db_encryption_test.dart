import 'dart:convert';
import 'dart:io';

import 'package:budget_tracker/database/db_open.dart';
import 'package:budget_tracker/utils/crash_log.dart';
import 'package:budget_tracker/utils/db_encryption.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 6.1 — at-rest DB encryption key management ([DbEncryption]).
///
/// The real cipher can't run on the Windows test runner, but the key lifecycle
/// (generate once, persist, return the same value next launch, degrade
/// gracefully when the Keystore channel throws) is pure Dart over the mocked
/// `flutter_secure_storage` channel and is fully exercised here — including the
/// rule that a stored key is never replaced: not after a failed read, and not
/// once the database file is encrypted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secureBacking;
  late TestDefaultBinaryMessenger messenger;
  late Directory tmp;
  late String dbPath;
  var failSecureWrites = false;
  var failSecureReads = false;

  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ff_db_key_test');
    dbPath = p.join(tmp.path, 'expense_tracker_v4.db');
    CrashLog.directoryOverride = tmp;
    secureBacking = <String, String>{};
    failSecureWrites = false;
    failSecureReads = false;
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(secureChannel, (call) async {
      switch (call.method) {
        case 'read':
          if (failSecureReads) {
            throw PlatformException(code: 'Exception encountered');
          }
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

  tearDown(() async {
    messenger.setMockMethodCallHandler(secureChannel, null);
    CrashLog.resetForTesting();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  /// 64 bytes without the SQLite magic: what an encrypted database looks like.
  Future<void> writeEncryptedDb() => File(dbPath)
      .writeAsBytes(List<int>.generate(64, (i) => 200 + (i % 50)));

  test('getOrCreateKey generates a 256-bit base64 key on first call', () async {
    final key = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    expect(key, isNotNull);
    expect(base64Decode(key!).length, 32);
  });

  test('getOrCreateKey returns the same persisted key across calls', () async {
    final first = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    final second = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    expect(first, isNotNull);
    expect(second, equals(first));
  });

  test('hasKey is false before generation and true afterwards', () async {
    expect(await DbEncryption.hasKey(), isFalse);
    await DbEncryption.getOrCreateKey(dbPath: dbPath);
    expect(await DbEncryption.hasKey(), isTrue);
  });

  test('a persisted key survives a simulated relaunch', () async {
    final created = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    // Fresh launch: SharedPreferences wiped, the secure store (Keystore) kept.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final reloaded = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    expect(reloaded, equals(created));
  });

  test('two freshly generated keys differ (entropy sanity)', () async {
    final a = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    secureBacking.clear();
    final b = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(a, isNot(equals(b)));
  });

  test('still produces a stable key when the Keystore write throws '
      '(SharedPreferences fallback)', () async {
    failSecureWrites = true;
    final key = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    expect(key, isNotNull, reason: 'fallback store must still persist the key');
    final again = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    expect(again, equals(key));
  });

  test('a read error before the database is encrypted returns null and '
      'writes nothing', () async {
    failSecureReads = true;
    expect(await DbEncryption.getOrCreateKey(dbPath: dbPath), isNull);
    expect(secureBacking, isEmpty, reason: 'no key may be minted on an error');
  });

  test('a still-plaintext database (upgrade from pre-5.1.0) gets a key',
      () async {
    final magic = <int>[...utf8.encode('SQLite format 3'), 0];
    await File(dbPath).writeAsBytes(<int>[...magic, ...List.filled(48, 0)]);
    final key = await DbEncryption.getOrCreateKey(dbPath: dbPath);
    expect(key, isNotNull);
    expect(secureBacking[DbEncryption.keyStorageKey], key);
  });

  group('an encrypted database never gets a new key', () {
    test('a transient read error throws and leaves the stored key alone',
        () async {
      secureBacking[DbEncryption.keyStorageKey] = 'the-real-key';
      await writeEncryptedDb();
      failSecureReads = true;

      await expectLater(
        DbEncryption.getOrCreateKey(dbPath: dbPath),
        throwsA(isA<DatabaseKeyUnavailableException>()),
      );
      expect(secureBacking[DbEncryption.keyStorageKey], 'the-real-key');

      // The Keystore recovers: the next attempt gets the original key back.
      failSecureReads = false;
      expect(
        await DbEncryption.getOrCreateKey(dbPath: dbPath),
        'the-real-key',
      );
    });

    test('a missing key throws instead of minting one', () async {
      await writeEncryptedDb();
      await expectLater(
        DbEncryption.getOrCreateKey(dbPath: dbPath),
        throwsA(isA<DatabaseKeyUnavailableException>()),
      );
      expect(secureBacking, isEmpty);
    });

    test('the stored key is returned', () async {
      secureBacking[DbEncryption.keyStorageKey] = 'the-real-key';
      await writeEncryptedDb();
      expect(
        await DbEncryption.getOrCreateKey(dbPath: dbPath),
        'the-real-key',
      );
    });

    test('a key that fell back to SharedPreferences is still used when the '
        'Keystore read fails', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{DbEncryption.keyStorageKey: 'fallback-key'},
      );
      await writeEncryptedDb();
      failSecureReads = true;
      expect(
        await DbEncryption.getOrCreateKey(dbPath: dbPath),
        'fallback-key',
      );
    });
  });
}
