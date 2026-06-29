import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/luminous_tokens.dart';

/// One row inside a [GlassListSection]: icon · label (+ optional sublabel) ·
/// value · trailing widget (toggle, chevron, or custom).
///
/// All slots are optional except [label]; the widget collapses unused ones
/// so it works as a header tile, a navigation tile, a switch tile, etc.
class GlassListTile extends StatelessWidget {
  /// Optional leading icon. Rendered inside a soft container.
  final IconData? icon;

  /// Optional override for the icon container's fill color. Defaults to a
  /// tint of `colorScheme.primary`.
  final Color? iconColor;

  /// Primary label. Required.
  final String label;

  /// Optional secondary line below [label].
  final String? sublabel;

  /// Optional trailing value text (e.g. "USD" or "+$120").
  final String? value;

  /// Optional trailing widget. Most commonly a [Switch], chevron icon, or a
  /// custom indicator. Mutually exclusive with [chevron].
  final Widget? trailing;

  /// Whether to show a chevron at the right edge. Ignored if [trailing] is set.
  final bool chevron;

  /// Tap handler. When provided, the tile is wrapped in an InkWell with a
  /// haptic tick on press.
  final VoidCallback? onTap;

  const GlassListTile({
    super.key,
    this.icon,
    this.iconColor,
    required this.label,
    this.sublabel,
    this.value,
    this.trailing,
    this.chevron = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tint = iconColor ?? cs.primary;
    // De-glass: rows are transparent so the solid parent panel surface shows
    // through; dividers (drawn by GlassListSection) separate them.
    final content = Container(
      constraints: const BoxConstraints(
        minHeight: LuminousTokens.touchTargetMin + 4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.transparent,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: tint),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium ??
                      const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ) ??
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                value!,
                style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ) ??
                    TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: trailing,
            )
          else if (chevron)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.chevron_right,
                size: 22,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: content,
      ),
    );
  }
}
