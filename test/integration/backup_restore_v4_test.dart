import 'dart:convert';

import 'package:budget_tracker/utils/backup_crypto.dart';
import 'package:budget_tracker/utils/backup_helper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 6.3 — integration of `BackupCrypto` with `BackupHelper`.
///
/// `backup_crypto_test.dart` already pins the underlying primitive.
/// These tests pin the helper-layer contract that is exercised by
/// the production save and restore flows:
///   1. `wrapBackupIfNeeded` is a no-op when the user opts out of
///      encryption (no passphrase or empty passphrase). Legacy v2/v3
///      saves keep working.
///   2. `wrapBackupIfNeeded` produces a `BackupCrypto` v4 envelope
///      when a passphrase is supplied, and the envelope shows none of
///      the inner JSON keys when read with a text editor.
///   3. `unwrapBackupIfNeeded` returns plaintext content unchanged
///      (legacy v2/v3 backups restore transparently — no callback
///      invoked, no dialog flashed).
///   4. `unwrapBackupIfNeeded` decrypts a v4 envelope with the right
///      passphrase, returns `null` on the wrong one, and `null` when
///      the caller hands in a null/empty passphrase.
///   5. Full save→restore round-trip against a representative
///      comprehensive backup payload preserves it byte-for-byte.
void main() {
  // Representative shape of what `_createBackupInIsolate` produces:
  // a base64-encoded raw SQLite database + settings + metadata. Real
  // backups embed the user's full DB here, which is exactly the
  // payload encryption is meant to hide.
  String buildComprehensiveBackupJson() => jsonEncode(<String, dynamic>{
        'version': 2,
        'schema_version': 19,
        'timestamp': '2026-05-11T12:00:00.000Z',
        'database': base64Encode(<int>[
          // SQLite magic bytes + small payload — enough to make the
          // round-trip realistic without bundling a real DB.
          0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
          0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
          0x10, 0x00, 0x01, 0x01, 0x00, 0x40, 0x20, 0x20,
        ]),
        'settings': <String, dynamic>{
          'darkMode': true,
          'currencyCode': 'USD',
          'billReminders': true,
          'budgetAlerts': true,
          'monthlySummary': true,
          'reminderHour': 9,
          'reminderMinute': 0,
        },
      });

  const passphrase = 'correct horse battery staple';

  group('BackupHelper.wrapBackupIfNeeded', () {
    test('returns plaintext unchanged when passphrase is null', () async {
      final json = buildComprehensiveBackupJson();
      final wrapped = await BackupHelper.wrapBackupIfNeeded(json, null);
      expect(wrapped, equals(json));
    });

    test('returns plaintext unchanged when passphrase is empty', () async {
      final json = buildComprehensiveBackupJson();
      final wrapped = await BackupHelper.wrapBackupIfNeeded(json, '');
      expect(wrapped, equals(json));
    });

    test('produces a v4 envelope when a passphrase is supplied', () async {
      final json = buildComprehensiveBackupJson();
      final wrapped = await BackupHelper.wrapBackupIfNeeded(json, passphrase);

      expect(BackupCrypto.isEncryptedEnvelope(wrapped), isTrue);
      final envelope = jsonDecode(wrapped) as Map<String, dynamic>;
      expect(envelope['version'], BackupCrypto.envelopeVersion);
      expect(envelope['encrypted'], isTrue);
    });

    test('hides inner backup keys from a casual reader', () async {
      final json = buildComprehensiveBackupJson();
      final wrapped = await BackupHelper.wrapBackupIfNeeded(json, passphrase);

      // The envelope should expose no field name that gives away
      // what the inner JSON looked like.
      expect(wrapped, isNot(contains('"database"')));
      expect(wrapped, isNot(contains('"settings"')));
      expect(wrapped, isNot(contains('"darkMode"')));
      expect(wrapped, isNot(contains('"schema_version"')));
    });
  });

  group('BackupHelper.unwrapBackupIfNeeded', () {
    test('plaintext (legacy v2/v3) passes through unchanged', () async {
      final json = buildComprehensiveBackupJson();
      final out = await BackupHelper.unwrapBackupIfNeeded(json, null);
      expect(out, equals(json),
          reason:
              'Plaintext backups must restore transparently without prompting.');
    });

    test('plaintext passes through even when a passphrase is supplied',
        () async {
      // Defensive: a v3 file should not require a passphrase even if
      // the UI accidentally supplies one.
      final json = buildComprehensiveBackupJson();
      final out =
          await BackupHelper.unwrapBackupIfNeeded(json, 'unused passphrase');
      expect(out, equals(json));
    });

    test('returns null on encrypted content with null passphrase', () async {
      final json = buildComprehensiveBackupJson();
      final wrapped = await BackupHelper.wrapBackupIfNeeded(json, passphrase);
      final out = await BackupHelper.unwrapBackupIfNeeded(wrapped, null);
      expect(out, isNull);
    });

    test('returns null on encrypted content with empty passphrase', () async {
      final json = buildComprehensiveBackupJson();
      final wrapped = await BackupHelper.wrapBackupIfNeeded(json, passphrase);
      final out = await BackupHelper.unwrapBackupIfNeeded(wrapped, '');
      expect(out, isNull);
    });

    test('returns null on encrypted content with wrong passphrase', () async {
      final json = buildComprehensiveBackupJson();
      final wrapped = await BackupHelper.wrapBackupIfNeeded(json, passphrase);
      final out =
          await BackupHelper.unwrapBackupIfNeeded(wrapped, 'wrong passphrase');
      expect(out, isNull,
          reason:
              'Wrong passphrase must never return a stale or empty plaintext.');
    });
  });

  group('save → restore round-trip', () {
    test('wrap + unwrap with the same passphrase recovers the JSON exactly',
        () async {
      final original = buildComprehensiveBackupJson();
      final wrapped = await BackupHelper.wrapBackupIfNeeded(original, passphrase);
      final unwrapped =
          await BackupHelper.unwrapBackupIfNeeded(wrapped, passphrase);
      expect(unwrapped, equals(original));

      // Sanity-check that the rehydrated JSON still parses to the
      // same Dart map shape — catches any UTF-8 weirdness.
      final originalMap = jsonDecode(original) as Map<String, dynamic>;
      final restoredMap = jsonDecode(unwrapped!) as Map<String, dynamic>;
      expect(restoredMap['version'], originalMap['version']);
      expect(restoredMap['schema_version'], originalMap['schema_version']);
      expect(restoredMap['database'], originalMap['database']);
      expect(restoredMap['settings'], originalMap['settings']);
    });

    test('two consecutive wraps of the same payload produce distinct envelopes',
        () async {
      // Per the BackupCrypto contract, salt + IV are freshly generated
      // each call. The integration must not introduce caching that
      // would defeat that.
      final json = buildComprehensiveBackupJson();
      final first = await BackupHelper.wrapBackupIfNeeded(json, passphrase);
      final second = await BackupHelper.wrapBackupIfNeeded(json, passphrase);
      expect(first, isNot(equals(second)));

      // Both must still decrypt back to the original.
      expect(
        await BackupHelper.unwrapBackupIfNeeded(first, passphrase),
        equals(json),
      );
      expect(
        await BackupHelper.unwrapBackupIfNeeded(second, passphrase),
        equals(json),
      );
    });
  });
}
