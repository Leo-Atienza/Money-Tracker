import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 6.2: Keystore-backed key/value store with lazy migration from
/// the legacy `SharedPreferences` store.
///
/// Today this wraps `flutter_secure_storage` (Keystore on Android,
/// Keychain on iOS, `encryptedSharedPreferences` as a soft fallback on
/// older API levels). It is intentionally narrow — only typed
/// `read/writeString|Bool|Int` plus `remove` — because the only caller
/// at the moment is [PinSecurityHelper], which needs the PIN hash, salt,
/// length, enabled flag and rate-limit counters out of plain-text
/// `prefs.xml`.
///
/// **Migration semantics.** Every read first asks the secure store. On a
/// miss, the wrapper consults `SharedPreferences`; if it finds a value,
/// it copies it into the secure store, then deletes the legacy entry.
/// The caller never observes the difference — the same value is returned
/// either way. If the secure write fails mid-migration the legacy entry
/// is left in place so the app keeps working until the next attempt.
///
/// **Write semantics.** Writes go to the secure store and then scrub any
/// legacy copy. If the secure store write throws (rare — broken
/// Keystore on a tampered device), the value falls back to
/// `SharedPreferences` so the user never loses their PIN.
class SecurePrefs {
  SecurePrefs._();

  /// Test seam — swapped for an in-memory implementation by
  /// `secure_prefs_test.dart`. Production code never touches this.
  @visibleForTesting
  static FlutterSecureStorage storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      // `encryptedSharedPreferences: true` lets the plugin store under
      // Jetpack EncryptedSharedPreferences on devices where the Keystore
      // wrap-and-unwrap dance is unreliable. The wrapper itself is still
      // backed by an AES key from Keystore.
      encryptedSharedPreferences: true,
    ),
  );

  /// Read a string from the secure store. On a miss, lazily migrates from
  /// `SharedPreferences` and returns the legacy value.
  static Future<String?> readString(String key) async {
    String? secure;
    try {
      secure = await storage.read(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('SecurePrefs.readString secure error: $e');
      secure = null;
    }
    if (secure != null) return secure;
    return _migrateString(key);
  }

  static Future<bool?> readBool(String key) async {
    final str = await readString(key);
    if (str == null) return null;
    return str == 'true';
  }

  static Future<int?> readInt(String key) async {
    final str = await readString(key);
    if (str == null) return null;
    return int.tryParse(str);
  }

  /// Write a string. Scrubs the legacy copy on success.
  static Future<void> writeString(String key, String value) async {
    try {
      await storage.write(key: key, value: value);
    } catch (e) {
      // Secure write failed — fall back to legacy so the caller never
      // loses data. The migration will retry on the next read.
      if (kDebugMode) debugPrint('SecurePrefs.writeString fell back: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      return;
    }
    // Secure write succeeded — drop any legacy copy.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> writeBool(String key, bool value) {
    return writeString(key, value ? 'true' : 'false');
  }

  static Future<void> writeInt(String key, int value) {
    return writeString(key, value.toString());
  }

  /// Remove the value from both stores so a re-read can't resurface a
  /// stale legacy entry.
  static Future<void> remove(String key) async {
    try {
      await storage.delete(key: key);
    } catch (e) {
      if (kDebugMode) debugPrint('SecurePrefs.remove secure error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Pull a value from `SharedPreferences` and copy it into the secure
  /// store. Tolerates string, bool, int, and double legacy types because
  /// `PinSecurityHelper` historically stored a mix (`pin_enabled` bool,
  /// `pin_length` int, hash/salt string).
  ///
  /// `prefs.getString` throws a `TypeError` when the underlying value is
  /// not a string, so we go through the untyped `prefs.get` accessor and
  /// stringify the result. `Object.toString()` is well-defined for every
  /// type SharedPreferences supports.
  static Future<String?> _migrateString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.get(key);
    if (raw == null) return null;
    final legacy = raw.toString();

    try {
      await storage.write(key: key, value: legacy);
      // Only drop the legacy copy after the secure write succeeded —
      // otherwise a flaky Keystore could lose the value entirely.
      await prefs.remove(key);
    } catch (e) {
      if (kDebugMode) debugPrint('SecurePrefs migration failed: $e');
      // Leave legacy intact for the next attempt.
    }
    return legacy;
  }
}
