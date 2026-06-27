import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/luminous_app_theme.dart';

class FloatingGlassNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingGlassNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Pill nav: `backdrop-blur`, glass edge, green-tinted shadow (coach green ~20%).
class FloatingGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingGlassNavDestination> destinations;

  const FloatingGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : LuminousTokens.glassFill;
    final stroke = Colors.white.withValues(alpha: isDark ? 0.22 : 0.4);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LuminousTokens.radiusPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: LuminousTokens.glassBlurSigma,
            sigmaY: LuminousTokens.glassBlurSigma,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LuminousTokens.radiusPill),
              color: fill,
              border: Border.all(color: stroke),
              boxShadow: [
                BoxShadow(
                  color: LuminousTokens.primaryContainer.withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 22),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(destinations.length, (i) {
                final d = destinations[i];
                final selected = i == currentIndex;
                final inactive = cs.onSurfaceVariant.withValues(alpha: 0.55);
                final active = LuminousTokens.primaryContainer;

                // M10: announce tab role + selected state to TalkBack/VoiceOver.
                // Label the node with the human-readable destination name (not
                // the uppercased Text) so the reader doesn't spell "H-O-M-E".
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: d.label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTap(i);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selected ? d.selectedIcon : d.icon,
                              size: i == 2 ? 26 : 24,
                              color: selected ? active : inactive,
                            ),
                            const SizedBox(height: 2),
                            // L46: the selected label gets the active color too
                            // (was always onSurface, so the active tab's text
                            // never reflected selection).
                            Text(
                              d.label.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    letterSpacing: 1,
                                    color: selected ? active : cs.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
