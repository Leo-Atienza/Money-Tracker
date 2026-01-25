import 'package:flutter/material.dart';
import '../utils/accessibility_helper.dart';

/// Accessible button widget with proper semantics and touch targets
class AccessibleButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isPrimary;
  final bool isDestructive;

  const AccessibleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget button;

    if (isPrimary) {
      button = FilledButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: isDestructive ? Colors.red : null,
          foregroundColor: isDestructive ? Colors.white : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(
            AccessibilityHelper.minTouchTargetSize,
            AccessibilityHelper.minTouchTargetSize,
          ),
        ),
      );
    } else {
      button = OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDestructive ? Colors.red : null,
          side: isDestructive ? const BorderSide(color: Colors.red) : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(
            AccessibilityHelper.minTouchTargetSize,
            AccessibilityHelper.minTouchTargetSize,
          ),
        ),
      );
    }

    return Semantics(
      label: label,
      button: true,
      enabled: true,
      child: button,
    );
  }
}

/// Accessible icon button with minimum touch target and semantic label
class AccessibleIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final double size;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: true,
      child: IconButton(
        icon: Icon(icon, size: size),
        onPressed: onPressed,
        color: color,
        tooltip: label,
        constraints: const BoxConstraints(
          minWidth: AccessibilityHelper.minTouchTargetSize,
          minHeight: AccessibilityHelper.minTouchTargetSize,
        ),
      ),
    );
  }
}
