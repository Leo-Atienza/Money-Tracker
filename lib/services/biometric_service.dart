import 'package:shared_preferences/shared_preferences.dart';

/// Biometric authentication service.
///
/// Note: This is a stub implementation. To enable biometric authentication,
/// add 'local_auth' and 'flutter_secure_storage' packages to pubspec.yaml.
class BiometricService {
  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Check if device supports biometric authentication
  /// Returns false since dependencies are not installed
  Future<bool> isDeviceSupported() async {
    return false;
  }

  /// Check if biometric authentication is enabled in app settings
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Enable biometric authentication
  Future<void> enableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, true);
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, false);
  }

  /// Authenticate user with biometric
  /// Returns true since biometric is not available (allow access)
  Future<bool> authenticate({String reason = 'Authenticate to access your budget data'}) async {
    // Not enabled/supported, so allow access
    return true;
  }

  /// Get available biometric types
  /// Returns empty list since dependencies are not installed
  Future<List<String>> getAvailableBiometrics() async {
    return [];
  }
}
