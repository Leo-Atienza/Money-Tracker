import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class for PIN-based app security
/// Stores PIN as a salted hash (SHA-256) for security
/// Salt prevents rainbow table attacks
/// FIX P1-7: Added rate limiting to prevent brute-force attacks
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

  /// Check if PIN protection is enabled
  static Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pinEnabledKey) ?? false;
  }

  /// Get the configured PIN length (4-6 digits)
  static Future<int> getPinLength() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pinLengthKey) ?? 4;
  }

  /// Set up a new PIN
  /// Returns true if successful, false otherwise
  static Future<bool> setPin(String pin) async {
    if (!_isValidPin(pin)) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final hashedPin = _hashPinWithSalt(pin, salt);

    await prefs.setString(_pinHashKey, hashedPin);
    await prefs.setString(_pinSaltKey, salt);
    await prefs.setBool(_pinEnabledKey, true);
    await prefs.setInt(_pinLengthKey, pin.length);

    return true;
  }

  /// Check if the account is currently locked out due to too many failed attempts
  /// FIX P1-7: Added rate limiting
  static Future<bool> isLockedOut() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntil = prefs.getInt(_lockoutUntilKey);

    if (lockoutUntil == null) return false;

    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutUntil);
    if (DateTime.now().isBefore(lockoutTime)) {
      return true;
    }

    // Lockout expired, clear the data
    await _clearLockoutData(prefs);
    return false;
  }

  /// Get remaining lockout time in seconds (0 if not locked)
  /// FIX P1-7: Added rate limiting
  static Future<int> getRemainingLockoutSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final lockoutUntil = prefs.getInt(_lockoutUntilKey);

    if (lockoutUntil == null) return 0;

    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutUntil);
    final remaining = lockoutTime.difference(DateTime.now()).inSeconds;

    return remaining > 0 ? remaining : 0;
  }

  /// Get the number of failed attempts remaining before lockout
  /// FIX P1-7: Added rate limiting
  static Future<int> getRemainingAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final failedAttempts = prefs.getInt(_failedAttemptsKey) ?? 0;
    return _maxFailedAttempts - failedAttempts;
  }

  /// Verify if the provided PIN matches the stored PIN
  /// FIX P1-7: Now includes rate limiting - returns false if locked out
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();

    // FIX P1-7: Check for lockout first
    if (await isLockedOut()) {
      return false;
    }

    final storedHash = prefs.getString(_pinHashKey);
    final storedSalt = prefs.getString(_pinSaltKey);

    if (storedHash == null) {
      return false;
    }

    // Support legacy PINs without salt (migrate on next PIN change)
    bool isValid;
    if (storedSalt == null) {
      final inputHash = _hashPin(pin);
      isValid = inputHash == storedHash;
    } else {
      final inputHash = _hashPinWithSalt(pin, storedSalt);
      isValid = inputHash == storedHash;
    }

    // FIX P1-7: Track failed attempts
    if (isValid) {
      // Successful login - clear failed attempts
      await _clearLockoutData(prefs);
    } else {
      // Failed attempt - increment counter
      await _recordFailedAttempt(prefs);
    }

    return isValid;
  }

  /// Record a failed PIN attempt and lock out if necessary
  /// FIX P1-7: Added rate limiting
  static Future<void> _recordFailedAttempt(SharedPreferences prefs) async {
    final failedAttempts = (prefs.getInt(_failedAttemptsKey) ?? 0) + 1;
    await prefs.setInt(_failedAttemptsKey, failedAttempts);

    if (failedAttempts >= _maxFailedAttempts) {
      // Lock out the user
      final lockoutUntil = DateTime.now()
          .add(Duration(minutes: _lockoutDurationMinutes))
          .millisecondsSinceEpoch;
      await prefs.setInt(_lockoutUntilKey, lockoutUntil);
    }
  }

  /// Clear lockout data after successful login or lockout expiry
  /// FIX P1-7: Added rate limiting
  static Future<void> _clearLockoutData(SharedPreferences prefs) async {
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lockoutUntilKey);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_pinSaltKey);
    await prefs.setBool(_pinEnabledKey, false);
    await prefs.remove(_pinLengthKey);
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

  /// Hash the PIN using SHA-256 (legacy method without salt)
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Hash the PIN with salt using SHA-256
  static String _hashPinWithSalt(String pin, String salt) {
    final bytes = utf8.encode(salt + pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a cryptographically secure random salt
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(saltBytes);
  }

  /// Reset all PIN data (for debugging/testing only)
  static Future<void> resetPinData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_pinSaltKey);
    await prefs.remove(_pinEnabledKey);
    await prefs.remove(_pinLengthKey);
    // FIX P1-7: Also clear rate limiting data
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lockoutUntilKey);
  }
}
