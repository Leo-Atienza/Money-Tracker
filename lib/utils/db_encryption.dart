import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../database/db_open.dart';
import 'crash_log.dart';
import 'secure_prefs.dart';

/// Phase 6.1: at-rest database encryption key management.
///
/// The SQLCipher passphrase is a 256-bit key generated once with
/// [Random.secure] and persisted, base64-encoded, in the Android Keystore
/// (Keychain on iOS) via [SecurePrefs]. The key never leaves the device and
/// is deliberately **not** derived from the user PIN — disabling or changing
/// the PIN must never strand the database.
///
/// **Safety contract.** [getOrCreateKey] returns `null` rather than handing
/// back a key it could not durably persist. Encrypting the live database with
/// a key that vanishes on the next launch would be permanent data loss, so the
/// caller treats a `null` here as "stay on the plaintext path this launch and
/// retry next time".
///
/// It never replaces a stored key either. A Keystore read *error* is not a miss
/// ([SecurePrefs.readStringStrict]), and once the database file is encrypted a
/// missing or unreadable key throws [DatabaseKeyUnavailableException]: a new
/// key could never open that file.
class DbEncryption {
  DbEncryption._();

  /// SecurePrefs key under which the base64 DB passphrase is stored.
  @visibleForTesting
  static const String keyStorageKey = 'db_encryption_key';

  /// Key length in bytes. 32 bytes = 256 bits of entropy, fed to SQLCipher's
  /// PBKDF2 key-derivation as a high-entropy passphrase.
  static const int _keyLengthBytes = 32;

  /// Returns the persisted passphrase, generating and storing one on first
  /// call. [dbPath] is the database it keys, which decides the no-key cases:
  ///
  /// - The file is already encrypted: throws [DatabaseKeyUnavailableException]
  ///   whether the key is missing or unreadable. Never a new key.
  /// - Otherwise (absent, or still plaintext): a genuine miss generates a key,
  ///   but a read *error* returns `null` without writing, since the real key
  ///   may still be there.
  ///
  /// `null` (also returned when a new key could not be durably persisted)
  /// means the caller MUST fall back to a plaintext open this launch.
  static Future<String?> getOrCreateKey({required String dbPath}) async {
    String? existing;
    try {
      existing = await SecurePrefs.readStringStrict(keyStorageKey);
    } catch (e, st) {
      await CrashLog.record(e, stack: st, context: 'db_encryption_key');
      if (await isEncryptedDatabaseFile(dbPath)) {
        throw const DatabaseKeyUnavailableException(
          'the database is encrypted and its key could not be read',
        );
      }
      return null;
    }
    if (existing != null && existing.isNotEmpty) return existing;

    if (await isEncryptedDatabaseFile(dbPath)) {
      throw const DatabaseKeyUnavailableException(
        'the database is encrypted but its key is missing',
      );
    }

    try {
      final key = _generateKey();
      await SecurePrefs.writeString(keyStorageKey, key);

      // Read back to confirm the key actually persisted. SecurePrefs falls
      // back to SharedPreferences when the Keystore write throws, so a
      // successful read-back here means the key is retrievable next launch
      // (somewhere). If it comes back wrong/empty, refuse to encrypt.
      final readBack = await SecurePrefs.readStringStrict(keyStorageKey);
      if (readBack != key) {
        await CrashLog.record(
          'DB encryption key did not persist (read-back mismatch)',
          context: 'db_encryption_key',
        );
        return null;
      }
      return key;
    } catch (e, st) {
      await CrashLog.record(e, stack: st, context: 'db_encryption_key');
      return null;
    }
  }

  /// True once a key has been persisted — i.e. the database is (or is about to
  /// be) encrypted. Lets callers decide whether a plaintext copy is needed for
  /// a portable backup. Never throws.
  static Future<bool> hasKey() async {
    try {
      final existing = await SecurePrefs.readString(keyStorageKey);
      return existing != null && existing.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _generateKey() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(_keyLengthBytes, (_) => rnd.nextInt(256));
    return base64Encode(bytes);
  }
}
