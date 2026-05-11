import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pin_security_helper.dart';

/// Phase 6.5: thin wrapper over the platform `FLAG_SECURE` toggle.
///
/// When the user has a PIN enabled, the host window should refuse:
///
/// - Screenshots (`adb screencap`, hardware screenshot keys).
/// - Screen recording / casting (system Cast service, third-party recorders).
/// - The launcher's Recents thumbnail (shows a placeholder instead of the
///   live app, so balances don't leak when switching apps).
///
/// Android exposes this as `WindowManager.LayoutParams.FLAG_SECURE`. iOS has
/// no exact equivalent — the method is a no-op there (the Recents leak is
/// blocked separately via the secure-input view convention, which this app
/// already follows on the PIN screen).
///
/// The class is a thin static facade so callers don't have to know about the
/// underlying method channel. Failures (e.g. plugin not registered on a
/// non-default `FlutterEngine`) are swallowed and logged in debug mode —
/// FLAG_SECURE is a defense-in-depth measure, not a correctness gate.
class SecureWindow {
  SecureWindow._();

  static const MethodChannel _channel =
      MethodChannel('budget_tracker/secure_window');

  /// Test seam: when set, [setSecure] / [syncFromPinState] use this stub
  /// instead of the real `MethodChannel`. The tests inject a recorder so
  /// they can assert the right boolean was sent without touching Android.
  @visibleForTesting
  static Future<void> Function(bool on)? testHandler;

  /// Test seam: when set, [syncFromPinState] reads PIN state from this
  /// callback instead of `PinSecurityHelper`. Lets the test cover the
  /// branching without spinning up `SharedPreferences`.
  @visibleForTesting
  static Future<bool> Function()? pinStateOverride;

  /// Set the secure flag on the host window.
  ///
  /// Idempotent and platform-aware: on iOS / desktop / web the call is a
  /// silent no-op. Returns normally even if the platform side throws —
  /// callers should treat this as best-effort.
  static Future<void> setSecure(bool on) async {
    if (testHandler != null) {
      await testHandler!(on);
      return;
    }
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'on': on});
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('SecureWindow.setSecure($on) failed: ${e.message}');
      }
    } on MissingPluginException catch (e) {
      // Happens in widget tests that don't register the native side.
      if (kDebugMode) {
        debugPrint('SecureWindow.setSecure($on) missing plugin: ${e.message}');
      }
    }
  }

  /// Read the current PIN state and call [setSecure] accordingly. Convenience
  /// wrapper for the common "sync after PIN config changed" path — used from
  /// `AppState.initializeLockState`, the PIN setup screen, and the settings
  /// screen's "disable PIN" toggle.
  static Future<void> syncFromPinState() async {
    final pinEnabled = pinStateOverride != null
        ? await pinStateOverride!()
        : await PinSecurityHelper.isPinEnabled();
    await setSecure(pinEnabled);
  }
}
