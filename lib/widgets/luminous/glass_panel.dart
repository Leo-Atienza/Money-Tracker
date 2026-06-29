import 'package:flutter/material.dart';
import '../../theme/luminous_app_theme.dart';

/// Solid Material 3 card surface.
///
/// De-glass (2026-06-29): formerly a frosted `BackdropFilter` panel. Now a
/// plain opaque container drawn from the colorScheme container roles, with a
/// hairline border and a soft shadow in light mode. The class name + API are
/// kept so the ~20 screens that build on it compile unchanged.
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
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final fill = isDark ? cs.surfaceContainerHigh : cs.surfaceContainer;
    final borderCol = cs.outlineVariant.withValues(alpha: isDark ? 0.4 : 0.6);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderCol),
        color: fill,
        boxShadow: boxShadow ??
            (isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Top app bar strip: solid surface strip with a bottom hairline.
///
/// De-glass (2026-06-29): the blurred frosted strip is now an opaque
/// `colorScheme.surface` strip. API unchanged.
class GlassHeaderStrip extends StatelessWidget {
  final Widget child;

  const GlassHeaderStrip({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: child,
    );
  }
}
