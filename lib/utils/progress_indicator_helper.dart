// FIX #6: Helper for showing progress indicators during long operations
import 'package:flutter/material.dart';

class ProgressIndicatorHelper {
  /// Show a progress dialog with optional message
  /// FIX #6: Provides visual feedback for long database operations (10+ seconds)
  ///
  /// Returns a callback that closes exactly this dialog, by its route rather
  /// than by popping whatever is on top: the screen that opened it can be
  /// gone by the time the work ends, and a blind pop took down whatever sat
  /// above it instead (a passphrase prompt, the PIN unlock screen, the
  /// navigation shell). Calling it twice, or after the dialog is gone, is a
  /// no-op.
  static VoidCallback show(
    BuildContext context, {
    String message = 'Processing...',
  }) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
    navigator.push(route);
    return () {
      if (!route.isActive) return;
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    };
  }
}
