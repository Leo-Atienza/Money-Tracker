import 'package:flutter/material.dart';

/// Helper class for accessibility improvements throughout the app
class AccessibilityHelper {
  /// Minimum touch target size per Material Design guidelines (48x48 dp)
  static const double minTouchTargetSize = 48.0;

  /// Check if a widget meets minimum touch target requirements
  static bool meetsMinimumTouchTarget(double width, double height) {
    return width >= minTouchTargetSize && height >= minTouchTargetSize;
  }

  /// Wrap a widget with minimum touch target padding if needed
  static Widget ensureMinTouchTarget(Widget child, {
    double currentWidth = 0,
    double currentHeight = 0,
  }) {
    final needsHorizontalPadding = currentWidth < minTouchTargetSize;
    final needsVerticalPadding = currentHeight < minTouchTargetSize;

    if (!needsHorizontalPadding && !needsVerticalPadding) {
      return child;
    }

    final horizontalPadding = needsHorizontalPadding
        ? (minTouchTargetSize - currentWidth) / 2
        : 0.0;
    final verticalPadding = needsVerticalPadding
        ? (minTouchTargetSize - currentHeight) / 2
        : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: child,
    );
  }

  /// Create a semantically labeled icon button
  static Widget semanticIconButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    double size = 24.0,
    Color? color,
  }) {
    return Semantics(
      label: label,
      button: true,
      child: IconButton(
        icon: Icon(icon, size: size),
        onPressed: onPressed,
        color: color,
        tooltip: label,
        // Ensure minimum touch target
        constraints: const BoxConstraints(
          minWidth: minTouchTargetSize,
          minHeight: minTouchTargetSize,
        ),
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

  /// Get budget status icon based on percentage
  static IconData getBudgetStatusIcon(double percentage) {
    if (percentage >= 100) {
      return Icons.cancel;
    } else if (percentage >= 85) {
      return Icons.warning;
    } else {
      return Icons.check_circle;
    }
  }

  /// Check if text contrast ratio meets WCAG AA standards (4.5:1 for normal text)
  /// Simplified implementation - returns true if background is sufficiently different
  static bool meetsContrastRequirement(Color foreground, Color background) {
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();

    final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;

    final contrast = (lighter + 0.05) / (darker + 0.05);

    return contrast >= 4.5; // WCAG AA requirement for normal text
  }

  /// Get appropriate text color for accessibility on given background
  static Color getAccessibleTextColor(Color background) {
    final luminance = background.computeLuminance();
    // Use white text on dark backgrounds, black on light backgrounds
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Make any widget focusable for keyboard navigation
  static Widget makeFocusable(Widget child, {
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: Semantics(
              label: semanticLabel,
              button: true,
              focusable: true,
              focused: hasFocus,
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Create an accessible chip with proper semantics
  static Widget accessibleChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
    IconData? icon,
    Color? selectedColor,
    Color? backgroundColor,
  }) {
    return Semantics(
      label: '$label, ${isSelected ? 'selected' : 'not selected'}',
      button: true,
      selected: isSelected,
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: onSelected,
        selectedColor: selectedColor,
        backgroundColor: backgroundColor,
        // Ensure proper padding for touch target
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }

  /// Add semantic announcement for screen readers
  static void announce(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 500),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  /// Get payment progress semantic label
  static String getPaymentProgressLabel(double amountPaid, double totalAmount) {
    // FIX: Prevent division by zero if totalAmount is zero
    final percentage = totalAmount > 0
        ? (amountPaid / totalAmount * 100).toStringAsFixed(0)
        : '0';
    return 'Payment progress: $percentage% complete, $amountPaid of $totalAmount paid';
  }
}
