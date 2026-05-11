import 'package:flutter/material.dart';

import '../../theme/luminous_tokens.dart';
import 'glass_panel.dart';

/// Settings/Wallet-style section: an all-caps header followed by a [GlassPanel]
/// containing the section's rows.
///
/// Use with [GlassListTile] (or any custom child) to assemble Luminous-style
/// settings pages.
class GlassListSection extends StatelessWidget {
  /// Section heading, rendered as an all-caps label above the panel.
  final String title;

  /// The rows that make up the section. Typically a list of [GlassListTile].
  final List<Widget> children;

  /// Optional bottom margin so adjacent sections stack with consistent rhythm.
  final EdgeInsetsGeometry padding;

  const GlassListSection({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.only(bottom: LuminousTokens.sectionMargin),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headingStyle = theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ) ??
        TextStyle(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 4,
              bottom: 12,
            ),
            child: Text(title.toUpperCase(), style: headingStyle),
          ),
          GlassPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i != children.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 56,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
