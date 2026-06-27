import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'clock.dart';
import 'secure_prefs.dart';

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
class PinSecurityHelper {
  static const String _pinHashKey = 'app_pin_hash';
  static const String _pinEnabledKey = 'pin_enabled';
  static const String _pinLengthKey = 'pin_length';
  static const String _pinSaltKey = 'app_pin_salt';

  // FIX P1-7: Rate limiting keys and constants
  static const String _failedAttemptsKey = 'pin_failed_attempts';
  static const String _lockoutUntilKey = 'pin_lockout_until';
  static const int _maxFailedAttempts = 5; // Lock after 5 failed attempts
  static const int _lockoutDurationMinutes = 5; // 5 minute lockout

  /// H2: PBKDF2 parameters for the modern PIN hash. 100k iterations matches
  /// [BackupCrypto.pbkdf2Iterations] and is the OWASP SHA-256 floor for
  /// mobile. The derived key is 256 bits.
  static const String _pbkdf2Prefix = 'pbkdf2_sha256';
  static const int _pinPbkdf2Iterations = 100000;
  static const int _derivedKeyBits = 256;

  /// Check if PIN protection is enabled
  static Future<bool> isPinEnabled() async {
    return await SecurePrefs.readBool(_pinEnabledKey) ?? false;
  }

  /// Get the configured PIN length (4-6 digits)
  static Future<int> getPinLength() async {
    return await SecurePrefs.readInt(_pinLengthKey) ?? 4;
  }

  /// Set up a new PIN
  /// Returns true if successful, false otherwise
  static Future<bool> setPin(String pin) async {
    if (!_isValidPin(pin)) {
      return false;
    }

    final salt = _generateSalt();
    final hashedPin = await _hashPinWithSalt(pin, salt);

    await SecurePrefs.writeString(_pinHashKey, hashedPin);
    await SecurePrefs.writeString(_pinSaltKey, salt);
    await SecurePrefs.writeBool(_pinEnabledKey, true);
    await SecurePrefs.writeInt(_pinLengthKey, pin.length);

    return true;
  }

  /// Check if the account is currently locked out due to too many failed attempts
  /// FIX P1-7: Added rate limiting
  static Future<bool> isLockedOut() async {
    final lockoutUntil = await SecurePrefs.readInt(_lockoutUntilKey);

    if (lockoutUntil == null) return false;

    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutUntil);
    if (Clock.instance.now().isBefore(lockoutTime)) {
      return true;
    }

    // Lockout expired, clear the data
    await _clearLockoutData();
    return false;
  }

  /// Get remaining lockout time in seconds (0 if not locked)
  /// FIX P1-7: Added rate limiting
  static Future<int> getRemainingLockoutSeconds() async {
    final lockoutUntil = await SecurePrefs.readInt(_lockoutUntilKey);

    if (lockoutUntil == null) return 0;

    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutUntil);
    final remaining = lockoutTime.difference(Clock.instance.now()).inSeconds;

    return remaining > 0 ? remaining : 0;
  }

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
  static Future<bool> verifyPin(String pin) async {
    // FIX P1-7: Check for lockout first
    if (await isLockedOut()) {
      return false;
    }

    final storedHash = await SecurePrefs.readString(_pinHashKey);
    final storedSalt = await SecurePrefs.readString(_pinSaltKey);

    if (storedHash == null) {
      return false;
    }

    // FIX Bug #10: Use a constant-time comparison so an attacker with
    // precise timing access cannot learn the stored hash byte-by-byte.
    //
    // Three stored formats are possible:
    //   1. Modern PBKDF2  — `pbkdf2_sha256$<iters>$<base64key>` (+ salt).
    //   2. Legacy salted SHA-256 — 64-hex-char hash + a salt.
    //   3. Legacy un-salted SHA-256 — 64-hex-char hash, no salt.
    // Formats 2 and 3 are weak; on a successful verify they are re-derived
    // as PBKDF2 and re-persisted (the H2 migrate-on-verify path).
    final bool isValid;
    var needsUpgrade = false;

    if (storedHash.startsWith('$_pbkdf2Prefix\$')) {
      if (storedSalt == null) {
        // Malformed: a PBKDF2 hash with no salt cannot be re-derived.
        isValid = false;
      } else {
        final iterations = _parsePbkdf2Iterations(storedHash);
        final inputHash =
            await _hashPinWithSalt(pin, storedSalt, iterations: iterations);
        isValid = _constantTimeEquals(inputHash, storedHash);
        // Future-proofing: upgrade if a stored hash predates an iteration bump.
        needsUpgrade = isValid && iterations < _pinPbkdf2Iterations;
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
          .add(Duration(minutes: _lockoutDurationMinutes))
          .millisecondsSinceEpoch;
      await SecurePrefs.writeInt(_lockoutUntilKey, lockoutUntil);
    }
  }

  /// Clear lockout data after successful login or lockout expiry
  /// FIX P1-7: Added rate limiting
  static Future<void> _clearLockoutData() async {
    await SecurePrefs.remove(_failedAttemptsKey);
    await SecurePrefs.remove(_lockoutUntilKey);
  }

  /// Change the PIN (requires old PIN for verification)
  static Future<bool> changePin(String oldPin, String newPin) async {
    final isOldPinValid = await verifyPin(oldPin);

    if (!isOldPinValid) {
      return false;
    }

    return await setPin(newPin);
  }

  /// Disable PIN protection
  static Future<void> disablePin() async {
    await SecurePrefs.remove(_pinHashKey);
    await SecurePrefs.remove(_pinSaltKey);
    await SecurePrefs.writeBool(_pinEnabledKey, false);
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

  /// H2: Hash the PIN with [salt] using PBKDF2-HMAC-SHA256.
  ///
  /// The base64-encoded [salt] is decoded to raw bytes and used as the
  /// PBKDF2 nonce; the derived 256-bit key is base64-encoded into a
  /// self-describing `pbkdf2_sha256$<iterations>$<base64key>` string so
  /// the iteration count travels with the hash and old hashes still verify
  /// after a future iteration bump.
  static Future<String> _hashPinWithSalt(
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
    final keyBytes = await derived.extractBytes();
    return '$_pbkdf2Prefix\$$iterations\$${base64Encode(keyBytes)}';
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
    await SecurePrefs.remove(_failedAttemptsKey);
    await SecurePrefs.remove(_lockoutUntilKey);
  }
}
