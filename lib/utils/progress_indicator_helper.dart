// FIX #6: Helper for showing progress indicators during long operations
import 'package:flutter/material.dart';

class ProgressIndicatorHelper {
  /// Show a progress dialog with optional message
  /// FIX #6: Provides visual feedback for long database operations (10+ seconds)
  static void show(BuildContext context, {String message = 'Processing...'}) {
    showDialog(
      context: context,
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
  }

  /// Hide the progress dialog
  static void hide(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
