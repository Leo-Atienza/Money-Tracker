import 'package:flutter/material.dart';

import '../../theme/luminous_tokens.dart';
import 'glass_panel.dart';

/// Universal header used by every Luminous screen: blurred strip with a leading
/// slot (avatar, back chevron, or app icon), a title, and an optional trailing
/// action slot (search, filter, settings).
///
/// Phase 5 replaces every hand-rolled `Row` header across the codebase with
/// this widget so search/avatar/title spacing stays consistent.
class GlassTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Optional leading widget — typically an avatar or a back button.
  final Widget? leading;

  /// Title text. Rendered with `headlineMedium`.
  final String title;

  /// Optional subtitle below the title (Luminous "AI Insights →" style hint).
  final String? subtitle;

  /// Optional trailing action widgets. Provide 0–2; the bar handles spacing.
  final List<Widget> actions;

  /// Whether to draw the hairline divider at the bottom edge.
  final bool showDivider;

  const GlassTopAppBar({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showDivider = true,
  });

  static const double _height = 64;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.headlineMedium ??
        const TextStyle(fontSize: 24, fontWeight: FontWeight.w700);
    final subtitleStyle = theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600);

    final strip = SafeArea(
      bottom: false,
      child: SizedBox(
        height: _height,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LuminousTokens.containerPadding,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: subtitleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              for (final action in actions) ...[
                const SizedBox(width: 8),
                action,
              ],
            ],
          ),
        ),
      ),
    );

    return showDivider ? GlassHeaderStrip(child: strip) : strip;
  }
}
