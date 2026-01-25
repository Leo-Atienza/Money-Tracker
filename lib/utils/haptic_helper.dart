// FIX #29: Centralized haptic feedback for important actions
import 'package:flutter/services.dart';

class HapticHelper {
  /// Light impact - for button presses, taps
  static Future<void> lightImpact() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium impact - for selections, toggles
  static Future<void> mediumImpact() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for important actions, confirmations
  static Future<void> heavyImpact() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection click - for scrolling through options
  static Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }

  /// Vibrate - for errors, warnings
  /// FIX #29: Use for budget exceeded, transaction deletion
  static Future<void> vibrate() async {
    await HapticFeedback.vibrate();
  }

  /// FIX #29: Haptic feedback for budget exceeded alert
  static Future<void> budgetExceeded() async {
    await HapticFeedback.heavyImpact();
  }

  /// FIX #29: Haptic feedback for transaction deletion
  static Future<void> itemDeleted() async {
    await HapticFeedback.mediumImpact();
  }

  /// FIX #29: Haptic feedback for successful operation
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
  }

  /// FIX #29: Haptic feedback for error
  static Future<void> error() async {
    await HapticFeedback.vibrate();
  }
}
