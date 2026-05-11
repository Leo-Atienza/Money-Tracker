import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/luminous_tokens.dart';

/// Filter chip / category pill used on History, Analytics, and Add screens.
///
/// Tappable, animated, and accepts an optional leading icon plus an active
/// state. Phase 5 swaps every ad-hoc `FilterChip` and category pill for this.
class GlassPillChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  /// Optional override color for the active fill. Defaults to a translucent
  /// version of `colorScheme.primary`.
  final Color? activeColor;

  const GlassPillChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fill = selected
        ? (activeColor ?? cs.primary).withValues(alpha: 0.18)
        : (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.45));
    final border = selected
        ? (activeColor ?? cs.primary).withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: isDark ? 0.14 : 0.6);
    final fg = selected
        ? (activeColor ?? cs.primary)
        : cs.onSurfaceVariant;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(LuminousTokens.radiusPill),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(LuminousTokens.radiusPill),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: LuminousTokens.iconSm, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ) ??
                    TextStyle(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
