import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';

/// Helper class for managing app permissions
/// Handles storage permissions for backup/restore functionality
class PermissionHelper {
  // Cache the Android SDK version to avoid repeated platform channel calls
  static int? _cachedAndroidSdk;

  /// Request storage permissions for file operations
  /// Returns true if permission granted, false otherwise
  static Future<bool> requestStoragePermission(BuildContext context) async {
    // iOS doesn't need explicit storage permissions for file picker
    if (!Platform.isAndroid) {
      return true;
    }

    if (kDebugMode) debugPrint('=== PERMISSION CHECK START ===');

    // Get actual Android SDK version
    final sdkVersion = await _getAndroidSdkVersion();
    if (kDebugMode) debugPrint('Android SDK version: $sdkVersion');

    // Android 13+ (API 33+): SAF handles permissions automatically via FilePicker
    // No explicit permission is needed - the system file picker grants access
    if (sdkVersion >= 33) {
      if (kDebugMode) debugPrint('Android 13+: SAF handles permissions, no explicit permission needed');
      return true;
    }

    // Android 11-12 (API 30-32): Need READ_EXTERNAL_STORAGE for some file operations
    // But FilePicker with SAF should work without it - try permissionless approach first
    if (sdkVersion >= 30) {
      if (kDebugMode) debugPrint('Android 11-12: Checking storage permission');
      final status = await Permission.storage.status;
      if (kDebugMode) debugPrint('Current storage status: $status');

      // If already granted or restricted (meaning SAF-only), allow operation
      if (status.isGranted || status.isRestricted) {
        if (kDebugMode) debugPrint('Permission granted or restricted (SAF mode)');
        return true;
      }

      // For Android 11-12, try to proceed anyway since SAF might work
      // Only block if permission was explicitly denied AND user needs legacy access
      if (status.isPermanentlyDenied) {
        if (kDebugMode) debugPrint('Permission permanently denied - but SAF should still work');
        // Still return true - FilePicker uses SAF which doesn't need this permission
        return true;
      }

      // Request permission for better compatibility
      if (kDebugMode) debugPrint('Requesting storage permission for better compatibility...');
      final requestResult = await Permission.storage.request();
      if (kDebugMode) debugPrint('Permission request result: $requestResult');

      // Always return true for Android 11+ since SAF should work regardless
      return true;
    }

    // Android 10 and below (API 29-): Need WRITE_EXTERNAL_STORAGE
    if (kDebugMode) debugPrint('Android 10 and below: Checking WRITE_EXTERNAL_STORAGE');
    var status = await Permission.storage.status;
    if (kDebugMode) debugPrint('Current status: $status');

    if (status.isGranted) {
      if (kDebugMode) debugPrint('Permission already granted');
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (kDebugMode) debugPrint('Permission permanently denied, showing settings dialog');
      if (!context.mounted) return false;
      return await _showPermissionDeniedDialog(context);
    }

    // Request permission
    if (kDebugMode) debugPrint('Requesting storage permission...');
    status = await Permission.storage.request();
    if (kDebugMode) debugPrint('Permission request result: $status');

    if (status.isGranted) {
      if (kDebugMode) debugPrint('Permission granted');
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (kDebugMode) debugPrint('Permission permanently denied after request');
      if (!context.mounted) return false;
      return await _showPermissionDeniedDialog(context);
    }

    if (kDebugMode) debugPrint('Permission denied');
    return false;
  }

  /// Get actual Android SDK version using platform channel
  /// Returns 0 if not on Android or if detection fails
  static Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;

    // Return cached value if available
    if (_cachedAndroidSdk != null) {
      return _cachedAndroidSdk!;
    }

    try {
      // Use MethodChannel to get the actual SDK version
      const platform = MethodChannel('budget_tracker/device_info');
      final int sdkInt = await platform.invokeMethod('getAndroidSdkVersion');
      _cachedAndroidSdk = sdkInt;
      if (kDebugMode) debugPrint('Got Android SDK version from platform channel: $sdkInt');
      return sdkInt;
    } catch (e) {
      if (kDebugMode) debugPrint('Platform channel not available: $e');
      // Fallback: Try to detect using permission behavior
      return await _detectAndroidVersionFallback();
    }
  }

  /// Fallback method to detect Android version based on permission behavior
  static Future<int> _detectAndroidVersionFallback() async {
    try {
      // On Android 13+, Permission.photos exists and can be checked
      // On older versions, it throws or returns a specific status
      final photosStatus = await Permission.photos.status;
      if (kDebugMode) debugPrint('Photos permission status: $photosStatus');

      // If photos permission returns a valid status (not limited/restricted in a way
      // that indicates it doesn't exist), we're likely on Android 13+
      // This is still imperfect but better than the previous logic

      // Check if manageExternalStorage is available (Android 11+)
      final manageStatus = await Permission.manageExternalStorage.status;
      if (kDebugMode) debugPrint('Manage external storage status: $manageStatus');

      // If manageExternalStorage returns permanentlyDenied without ever requesting,
      // it likely means Android 11+ but feature is restricted
      if (manageStatus.isPermanentlyDenied || manageStatus.isDenied || manageStatus.isGranted) {
        // Android 11+ for sure, try to distinguish 13+ from 11-12
        // On Android 13+, photos permission is granular
        if (photosStatus.isGranted || photosStatus.isDenied || photosStatus.isPermanentlyDenied) {
          // Photos permission check worked, likely Android 13+
          _cachedAndroidSdk = 33;
          return 33;
        }
        // Assume Android 11-12
        _cachedAndroidSdk = 30;
        return 30;
      }

      // Assume older Android
      _cachedAndroidSdk = 29;
      return 29;
    } catch (e) {
      if (kDebugMode) debugPrint('Error in fallback version detection: $e');
      // Conservative fallback: assume Android 13+ since it's the safest
      // (SAF works without permissions)
      _cachedAndroidSdk = 33;
      return 33;
    }
  }

  /// Show dialog when permission is permanently denied
  /// Offers to open app settings
  static Future<bool> _showPermissionDeniedDialog(BuildContext context) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Storage Permission Required'),
          content: const Text(
            'This app needs storage permission to save and restore backup files.\n\n'
            'Please grant storage permission in app settings to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, true);
                await AppSettings.openAppSettings(type: AppSettingsType.settings);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Check if storage permission is currently granted
  /// For Android 11+, this always returns true since SAF handles file access
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final sdkVersion = await _getAndroidSdkVersion();

    // Android 11+ (API 30+): SAF handles permissions via FilePicker
    // No explicit permission needed
    if (sdkVersion >= 30) {
      return true;
    }

    // Android 10 and below: Check legacy storage permission
    final status = await Permission.storage.status;
    return status.isGranted;
  }

  /// Show a user-friendly error message when permission is denied
  static void showPermissionDeniedSnackbar(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Storage permission is required to save and restore backups. '
          'Please grant permission in app settings.',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            AppSettings.openAppSettings(type: AppSettingsType.settings);
          },
        ),
      ),
    );
  }
}
