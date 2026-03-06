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

  /// Show a progress dialog with granular progress tracking
  /// FIX #6: For operations like CSV export that can report progress
  static Future<void> showWithProgress(
    BuildContext context, {
    required String title,
    required Future<void> Function(
      void Function(double progress, String status) updateProgress,
    ) operation,
  }) async {
    double progress = 0.0;
    String status = 'Starting...';
    StateSetter? dialogSetState;

    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          dialogSetState = setState;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text(
                    status,
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    // Run operation with progress callback
    try {
      await operation((newProgress, newStatus) {
        progress = newProgress.clamp(0.0, 1.0);
        status = newStatus;
        dialogSetState?.call(() {});
      });
    } finally {
      // Close dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Hide the progress dialog
  static void hide(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Show progress for a future operation
  static Future<T> showDuring<T>(
    BuildContext context,
    Future<T> operation, {
    String message = 'Processing...',
  }) async {
    show(context, message: message);
    try {
      final result = await operation;
      return result;
    } finally {
      if (context.mounted) {
        hide(context);
      }
    }
  }
}
