import 'dart:ui';

import 'package:flutter/material.dart';
import '../../theme/luminous_app_theme.dart';

/// Frosted glass panel: white ~45% + blur 25 + 1px highlight edge.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LuminousTokens.glassPadding),
    this.borderRadius = LuminousTokens.radiusCard,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : LuminousTokens.glassFill;
    final borderCol = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : LuminousTokens.glassBorder;

    // M9: isolate each panel's BackdropFilter under its own RepaintBoundary.
    // Analytics stacks ~5 live 15-sigma blurs; without this any single panel
    // repaint re-samples the whole shared backdrop for every panel.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: LuminousTokens.glassBlurSigma,
            sigmaY: LuminousTokens.glassBlurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderCol),
              color: fill,
              boxShadow: boxShadow ??
                  [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Top app bar strip: blurred frosted strip with bottom hairline (redesign header).
class GlassHeaderStrip extends StatelessWidget {
  final Widget child;

  const GlassHeaderStrip({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.white.withValues(alpha: 0.4);
    final borderSide = Colors.white.withValues(alpha: isDark ? 0.18 : 0.4);

    // M9: isolate the header strip's blur under its own RepaintBoundary too.
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: LuminousTokens.glassBlurSigma,
            sigmaY: LuminousTokens.glassBlurSigma,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: base,
              border: Border(bottom: BorderSide(color: borderSide, width: 1)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
