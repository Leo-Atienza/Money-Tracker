import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'clock.dart';
import 'secure_prefs.dart';

/// The secure store holding the PIN could not be read. Callers must fail
/// closed: an unreadable store is not "no PIN" (taking it for one let the app
/// open without its PIN), and a PIN that could not be checked is not a wrong
/// PIN (counting it would lock the user out for a storage fault).
class PinStorageUnavailableException implements Exception {
  const PinStorageUnavailableException(this.cause);

  final Object cause;

  @override
  String toString() => 'PinStorageUnavailableException: $cause';
}

/// Helper class for PIN-based app security.
///
/// PINs are stored as a salted **PBKDF2-HMAC-SHA256** hash (100k iterations)
/// so the on-disk secret resists offline brute force even though the PIN is
/// only 4–6 digits (≤ 10^6 candidates). A single round of SHA-256 over
/// `salt+pin` (the pre-H2 scheme) fell to a GPU in well under a second; the
/// PBKDF2 work factor — the same one [BackupCrypto] already uses — raises a
/// full sweep from milliseconds to days.
///
/// Stored hashes are **self-describing**: the modern form is
/// `pbkdf2_sha256$<iterations>$<base64-key>`. Legacy forms (plain 64-char
/// SHA-256 hex, salted or un-salted) are detected by the absence of that
/// prefix and **transparently upgraded to PBKDF2 on the next successful
/// verify** — the only point where the plaintext PIN is available without
/// forcing the user to re-set it.
///
/// Phase 6.2: hash + salt + counters live in Keystore (via [SecurePrefs])
/// instead of plain-text `SharedPreferences`. Existing prefs entries are
/// migrated transparently on first read.
///
/// A PIN is written as ONE value (S22): `pbkdf2_sha256$<iters>$<salt>$<key>$<len>`.
/// The salt and the length used to be separate keys, so a process killed
/// between writes could pair a new hash with an old salt (the PIN never
/// verifies again) or an old length (the unlock pad submits at the wrong
/// digit). Earlier forms still verify and are rewritten on the next unlock.
class PinSecurityHelper {
  static const String _pinHashKey = 'app_pin_hash';
  static const String _pinEnabledKey = 'pin_enabled';
  // Legacy (pre-S22): read when the record does not carry them.
  static const String _pinLengthKey = 'pin_length';
  static const String _pinSaltKey = 'app_pin_salt';

  // FIX P1-7: Rate limiting keys and constants
  static const String _failedAttemptsKey = 'pin_failed_attempts';
  static const String _lockoutUntilKey = 'pin_lockout_until';
  // The lockout's end on the device's monotonic clock (ms since boot), so
  // moving the system clock forward does not end it.
  static const String _lockoutUntilElapsedKey = 'pin_lockout_until_elapsed';
  static const int _maxFailedAttempts = 5; // Lock after 5 failed attempts
  static const int _lockoutDurationMinutes = 5; // 5 minute lockout

  /// Milliseconds since boot (Android `SystemClock.elapsedRealtime`), or null
  /// where unavailable (the test runner, a missing plugin). Tests replace it.
  @visibleForTesting
  static Future<int?> Function() elapsedRealtimeMs = _nativeElapsedRealtime;

  static const MethodChannel _clockChannel =
      MethodChannel('budget_tracker/secure_window');

  static Future<int?> _nativeElapsedRealtime() async {
    try {
      return await _clockChannel.invokeMethod<int>('elapsedRealtime');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// H2: PBKDF2 parameters for the modern PIN hash. 100k iterations matches
  /// [BackupCrypto.pbkdf2Iterations] and is the OWASP SHA-256 floor for
  /// mobile. The derived key is 256 bits.
  static const String _pbkdf2Prefix = 'pbkdf2_sha256';
  static const int _pinPbkdf2Iterations = 100000;
  static const int _derivedKeyBits = 256;

  /// Whether PIN protection is enabled.
  ///
  /// Throws [PinStorageUnavailableException] when the secure store cannot be
  /// read: the caller decides how to fail closed.
  static Future<bool> isPinEnabled() async {
    return await _readStrict(_pinEnabledKey) == 'true';
  }

  /// The configured PIN length (4-6 digits). Throws
  /// [PinStorageUnavailableException] when the secure store cannot be read.
  static Future<int> getPinLength() async {
    final record = _PinRecord.parse(await _readStrict(_pinHashKey));
    if (record != null) return record.length;
    return int.tryParse(await _readStrict(_pinLengthKey) ?? '') ?? 4;
  }

  static Future<String?> _readStrict(String key) async {
    try {
      return await SecurePrefs.readStringStrict(key);
    } catch (e) {
      throw PinStorageUnavailableException(e);
    }
  }

  /// Set up a new PIN
  /// Returns true if successful, false otherwise
  static Future<bool> setPin(String pin) async {
    if (!_isValidPin(pin)) {
      return false;
    }

    final salt = _generateSalt();
    final key = await _derivePinKey(pin, salt);

    // One write carries the hash, its salt and the length (see the class
    // doc), and the PIN is switched on only once that record is in place.
    await SecurePrefs.writeString(
      _pinHashKey,
      _PinRecord(
        iterations: _pinPbkdf2Iterations,
        salt: salt,
        key: key,
        length: pin.length,
      ).encode(),
    );
    await SecurePrefs.writeBool(_pinEnabledKey, true);
    // The record supersedes the separate keys; a leftover is ignored.
    await SecurePrefs.remove(_pinSaltKey);
    await SecurePrefs.remove(_pinLengthKey);

    return true;
  }

  /// Check if the account is currently locked out due to too many failed attempts
  /// FIX P1-7: Added rate limiting
  static Future<bool> isLockedOut() async {
    if (await _remainingLockoutMs() > 0) return true;
    // Lockout expired (or none), clear the data
    if (await SecurePrefs.readInt(_lockoutUntilKey) != null) {
      await _clearLockoutData();
    }
    return false;
  }

  /// Get remaining lockout time in seconds (0 if not locked)
  /// FIX P1-7: Added rate limiting
  static Future<int> getRemainingLockoutSeconds() async {
    return (await _remainingLockoutMs() / 1000).ceil();
  }

  /// Time left in the lockout. On the boot it started in, the monotonic clock
  /// decides, so setting the system clock forward does not end it; after a
  /// reboot that clock has restarted and only the wall clock is left.
  static Future<int> _remainingLockoutMs() async {
    final untilWall = await SecurePrefs.readInt(_lockoutUntilKey);
    if (untilWall == null) return 0;

    final untilElapsed = await SecurePrefs.readInt(_lockoutUntilElapsedKey);
    final nowElapsed = await elapsedRealtimeMs();
    if (untilElapsed != null && nowElapsed != null) {
      final startedElapsed = untilElapsed - _lockoutDuration.inMilliseconds;
      if (nowElapsed >= startedElapsed) {
        return max(0, untilElapsed - nowElapsed);
      }
    }
    final remaining =
        untilWall - Clock.instance.now().millisecondsSinceEpoch;
    // A wall clock set back must not stretch the lockout past its length.
    return remaining.clamp(0, _lockoutDuration.inMilliseconds);
  }

  static const Duration _lockoutDuration =
      Duration(minutes: _lockoutDurationMinutes);

  /// Get the number of failed attempts remaining before lockout
  /// FIX P1-7: Added rate limiting
  static Future<int> getRemainingAttempts() async {
    final failedAttempts =
        await SecurePrefs.readInt(_failedAttemptsKey) ?? 0;
    return _maxFailedAttempts - failedAttempts;
  }

  /// Verify if the provided PIN matches the stored PIN
  /// FIX P1-7: Now includes rate limiting - returns false if locked out
  /// H2: PBKDF2 verify + transparent upgrade of legacy SHA-256 hashes.
  ///
  /// Throws [PinStorageUnavailableException] when the stored PIN cannot be
  /// read; that is not a wrong PIN, so no failed attempt is counted.
  static Future<bool> verifyPin(String pin) async {
    // FIX P1-7: Check for lockout first
    if (await isLockedOut()) {
      return false;
    }

    final storedHash = await _readStrict(_pinHashKey);
    if (storedHash == null) {
      return false;
    }
    final record = _PinRecord.parse(storedHash);
    // Only the pre-S22 forms keep their salt under its own key.
    final storedSalt = record?.salt ?? await _readStrict(_pinSaltKey);

    // FIX Bug #10: Use a constant-time comparison so an attacker with
    // precise timing access cannot learn the stored hash byte-by-byte.
    //
    // Four stored formats are possible:
    //   1. PBKDF2 record — `pbkdf2_sha256$<iters>$<salt>$<key>$<len>` (S22).
    //   2. PBKDF2 — `pbkdf2_sha256$<iters>$<base64key>` + a separate salt.
    //   3. Legacy salted SHA-256 — 64-hex-char hash + a salt.
    //   4. Legacy un-salted SHA-256 — 64-hex-char hash, no salt.
    // Formats 2-4 are rewritten as 1 on a successful verify (the H2
    // migrate-on-verify path; 3 and 4 are weak hashes as well).
    final bool isValid;
    var needsUpgrade = false;

    if (record != null) {
      final key =
          await _derivePinKey(pin, record.salt, iterations: record.iterations);
      isValid = _constantTimeEquals(key, record.key);
      // Future-proofing: upgrade if a stored hash predates an iteration bump.
      needsUpgrade = isValid && record.iterations < _pinPbkdf2Iterations;
    } else if (storedHash.startsWith('$_pbkdf2Prefix\$')) {
      if (storedSalt == null) {
        // Malformed: a PBKDF2 hash with no salt cannot be re-derived.
        isValid = false;
      } else {
        final iterations = _parsePbkdf2Iterations(storedHash);
        final key =
            await _derivePinKey(pin, storedSalt, iterations: iterations);
        isValid = _constantTimeEquals(
          '$_pbkdf2Prefix\$$iterations\$$key',
          storedHash,
        );
        needsUpgrade = isValid;
      }
    } else if (storedSalt == null) {
      // Legacy un-salted SHA-256 (pre-salt era). L37: force-migrate on unlock.
      isValid = _constantTimeEquals(_legacyHashPin(pin), storedHash);
      needsUpgrade = isValid;
    } else {
      // Legacy salted SHA-256 (the v4.x deployed scheme).
      isValid = _constantTimeEquals(
        _legacyHashPinWithSalt(pin, storedSalt),
        storedHash,
      );
      needsUpgrade = isValid;
    }

    // FIX P1-7: Track failed attempts
    if (isValid) {
      // Successful login - clear failed attempts
      await _clearLockoutData();
      if (needsUpgrade) {
        // H2: re-derive and persist as PBKDF2. The plaintext PIN is only
        // available at verify time, so this is the sole upgrade point that
        // does not force the user to re-set their PIN.
        await setPin(pin);
      }
    } else {
      // Failed attempt - increment counter
      await _recordFailedAttempt();
    }

    return isValid;
  }

  /// Record a failed PIN attempt and lock out if necessary
  /// FIX P1-7: Added rate limiting
  static Future<void> _recordFailedAttempt() async {
    final failedAttempts =
        (await SecurePrefs.readInt(_failedAttemptsKey) ?? 0) + 1;
    await SecurePrefs.writeInt(_failedAttemptsKey, failedAttempts);

    if (failedAttempts >= _maxFailedAttempts) {
      // Lock out the user
      final lockoutUntil = Clock.instance.now()
          .add(_lockoutDuration)
          .millisecondsSinceEpoch;
      final nowElapsed = await elapsedRealtimeMs();
      if (nowElapsed != null) {
        await SecurePrefs.writeInt(
          _lockoutUntilElapsedKey,
          nowElapsed + _lockoutDuration.inMilliseconds,
        );
      }
      await SecurePrefs.writeInt(_lockoutUntilKey, lockoutUntil);
    }
  }

  /// Clear lockout data after successful login or lockout expiry
  /// FIX P1-7: Added rate limiting
  static Future<void> _clearLockoutData() async {
    await SecurePrefs.remove(_failedAttemptsKey);
    await SecurePrefs.remove(_lockoutUntilKey);
    await SecurePrefs.remove(_lockoutUntilElapsedKey);
  }

  /// Change the PIN (requires old PIN for verification)
  static Future<bool> changePin(String oldPin, String newPin) async {
    final isOldPinValid = await verifyPin(oldPin);

    if (!isOldPinValid) {
      return false;
    }

    return await setPin(newPin);
  }

  /// Disable PIN protection. Switched off before the hash goes, so a process
  /// killed half way leaves no PIN rather than a PIN nothing can verify.
  static Future<void> disablePin() async {
    await SecurePrefs.writeBool(_pinEnabledKey, false);
    await SecurePrefs.remove(_pinHashKey);
    await SecurePrefs.remove(_pinSaltKey);
    await SecurePrefs.remove(_pinLengthKey);
  }

  /// Check if a PIN is valid (4-6 digits only)
  static bool _isValidPin(String pin) {
    if (pin.length < 4 || pin.length > 6) {
      return false;
    }

    // Check if all characters are digits
    return RegExp(r'^\d+$').hasMatch(pin);
  }

  /// FIX: Check if PIN is weak (repeated or sequential digits)
  /// Returns a warning message if weak, null if acceptable
  static String? checkPinStrength(String pin) {
    if (!_isValidPin(pin)) {
      return 'PIN must be 4-6 digits';
    }

    // Check for all same digits (e.g., 1111, 0000)
    if (RegExp(r'^(.)\1+$').hasMatch(pin)) {
      return 'Avoid using all identical digits';
    }

    // Check for simple ascending sequence (e.g., 1234, 2345)
    bool isAscending = true;
    for (int i = 1; i < pin.length; i++) {
      if (int.parse(pin[i]) != int.parse(pin[i - 1]) + 1) {
        isAscending = false;
        break;
      }
    }
    if (isAscending) {
      return 'Avoid simple sequential patterns';
    }

    // Check for simple descending sequence (e.g., 4321, 9876)
    bool isDescending = true;
    for (int i = 1; i < pin.length; i++) {
      if (int.parse(pin[i]) != int.parse(pin[i - 1]) - 1) {
        isDescending = false;
        break;
      }
    }
    if (isDescending) {
      return 'Avoid simple sequential patterns';
    }

    return null; // PIN is acceptable
  }

  /// H2: Derive the PIN's key with PBKDF2-HMAC-SHA256, base64-encoded.
  ///
  /// The base64-encoded [salt] is decoded to raw bytes and used as the
  /// PBKDF2 nonce. The iteration count is stored with the key (see
  /// [_PinRecord]), so old hashes still verify after a future bump.
  static Future<String> _derivePinKey(
    String pin,
    String salt, {
    int iterations = _pinPbkdf2Iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: _derivedKeyBits,
    );
    final derived = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: base64Decode(salt),
    );
    return base64Encode(await derived.extractBytes());
  }

  /// Parse the iteration count out of a `pbkdf2_sha256$<iters>$<key>` hash,
  /// falling back to the current default if the field is missing/garbled.
  static int _parsePbkdf2Iterations(String storedHash) {
    final parts = storedHash.split(r'$');
    if (parts.length >= 2) {
      return int.tryParse(parts[1]) ?? _pinPbkdf2Iterations;
    }
    return _pinPbkdf2Iterations;
  }

  /// Legacy: hash the PIN using SHA-256 with no salt (pre-salt-era format).
  /// Retained only to verify (and then upgrade) pre-H2 stored hashes.
  static String _legacyHashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Legacy: hash the PIN with salt using SHA-256 (the v4.x deployed format).
  /// Retained only to verify (and then upgrade) pre-H2 stored hashes.
  static String _legacyHashPinWithSalt(String pin, String salt) {
    final bytes = utf8.encode(salt + pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// FIX Bug #10: Constant-time comparison of two hash strings.
  ///
  /// Dart's `==` on `String` short-circuits on the first differing code
  /// unit, which leaks the number of matching prefix bytes through the
  /// wall-clock time of `verifyPin`. For a local PIN check on an app
  /// binary this is a tiny risk — but the fix is cheap, so we take it.
  ///
  /// Inputs are ASCII (SHA-256 hex or the base64 PBKDF2 form), so
  /// `codeUnitAt(i)` equals the byte value and XOR/OR-accumulating is a
  /// valid byte-level compare without allocating a `Uint8List`.
  static bool _constantTimeEquals(String a, String b) {
    // Length mismatch is unexpected in practice but a defensive early-return
    // here leaks only length, which is a fixed constant per format anyway.
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Generate a cryptographically secure random salt
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// Reset all PIN data (for debugging/testing only)
  static Future<void> resetPinData() async {
    await SecurePrefs.remove(_pinHashKey);
    await SecurePrefs.remove(_pinSaltKey);
    await SecurePrefs.remove(_pinEnabledKey);
    await SecurePrefs.remove(_pinLengthKey);
    // FIX P1-7: Also clear rate limiting data
    await _clearLockoutData();
  }
}

/// The stored PIN since S22: `pbkdf2_sha256$<iterations>$<salt>$<key>$<length>`
/// in a single value, so the hash, its salt and the length can never be out
/// of step. Base64 never contains `$`.
class _PinRecord {
  const _PinRecord({
    required this.iterations,
    required this.salt,
    required this.key,
    required this.length,
  });

  final int iterations;
  final String salt;
  final String key;
  final int length;

  /// Null for anything that is not a complete record (an older form).
  static _PinRecord? parse(String? stored) {
    if (stored == null) return null;
    final parts = stored.split(r'$');
    if (parts.length != 5 || parts[0] != PinSecurityHelper._pbkdf2Prefix) {
      return null;
    }
    final iterations = int.tryParse(parts[1]);
    final length = int.tryParse(parts[4]);
    if (iterations == null ||
        length == null ||
        parts[2].isEmpty ||
        parts[3].isEmpty) {
      return null;
    }
    return _PinRecord(
      iterations: iterations,
      salt: parts[2],
      key: parts[3],
      length: length,
    );
  }

  String encode() =>
      '${PinSecurityHelper._pbkdf2Prefix}\$$iterations\$$salt\$$key\$$length';
}
