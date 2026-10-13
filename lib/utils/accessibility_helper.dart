import 'package:flutter/material.dart';

/// Helper class for accessibility improvements throughout the app
class AccessibilityHelper {
  /// Minimum touch target size per Material Design guidelines (48x48 dp)
  static const double minTouchTargetSize = 48.0;

  /// Create a semantically labeled icon button
  static Widget semanticIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    double size = 24.0,
    Color? color,
  }) {
    // IconButton's `tooltip` doubles as its accessibility label, so the
    // button already exposes one node with the label, the button flag and
    // the tap action. The previous outer `Semantics(label:, button:)`
    // wrapper produced a second node — TalkBack read "Previous month,
    // button" twice for every header button on Home and Budgets.
    return IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      color: color,
      tooltip: label,
      // Ensure minimum touch target
      constraints: const BoxConstraints(
        minWidth: minTouchTargetSize,
        minHeight: minTouchTargetSize,
      ),
    );
  }

  /// Get budget status semantic label with icon
  static String getBudgetStatusLabel(double percentage, String category) {
    String status;
    if (percentage >= 100) {
      status = 'Over budget';
    } else if (percentage >= 85) {
      status = 'Approaching limit';
    } else {
      status = 'Under budget';
    }
    return '$category budget: $status at ${percentage.toStringAsFixed(0)}%';
  }

  /// Create accessible progress indicator with semantic label
  static Widget accessibleProgressIndicator({
    required double value,
    required String label,
    Color? color,
    Color? backgroundColor,
  }) {
    final percentage = (value * 100).toInt();
    return Semantics(
      label: '$label: $percentage% complete',
      value: '$percentage%',
      child: LinearProgressIndicator(
        value: value,
        color: color,
        backgroundColor: backgroundColor,
        minHeight: 8, // Thicker for better visibility
      ),
    );
  }
}
