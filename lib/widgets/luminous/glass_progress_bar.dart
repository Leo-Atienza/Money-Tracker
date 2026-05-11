import 'package:flutter/material.dart';

import '../../theme/luminous_tokens.dart';

/// Soft, rounded progress bar used for budgets and top-category breakdowns.
///
/// Animates the fill on every value change. Caps at 1.0 visually but exposes
/// the raw [progress] in semantics so screen readers announce e.g. "115%".
class GlassProgressBar extends StatelessWidget {
  /// 0.0 — 1.0 normally; values above 1.0 render as a full bar but the raw
  /// number is still announced for screen readers.
  final double progress;

  /// Optional override fill color. Defaults to `colorScheme.primary`.
  final Color? color;

  /// Bar thickness. Defaults to 8 px.
  final double height;

  /// Optional semantic label (e.g. "Groceries budget"). Forms the screen
  /// reader announcement together with the percentage.
  final String? semanticLabel;

  const GlassProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.height = 8,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = color ?? cs.primary;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final clamped = progress.clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel,
      value: '${(progress * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuminousTokens.radiusPill),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(color: trackColor),
              LayoutBuilder(
                builder: (context, c) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    width: c.maxWidth * clamped,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          fillColor.withValues(alpha: 0.85),
                          fillColor,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
