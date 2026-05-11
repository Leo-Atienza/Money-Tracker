import 'package:flutter/material.dart';
import '../../theme/luminous_app_theme.dart';

/// Soft organic blobs from the stitch glass redesign (mint + blue radial washes).
class OrganicBlobBackground extends StatelessWidget {
  const OrganicBlobBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = Theme.of(context).colorScheme.surface;

    if (isDark) {
      return ColoredBox(
        color: base,
        child: Stack(
          children: [
            Positioned(
              top: -MediaQuery.sizeOf(context).height * 0.08,
              right: -MediaQuery.sizeOf(context).width * 0.22,
              child: _Blob(
                diameter: MediaQuery.sizeOf(context).width * 0.85,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF53E16F).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.72],
                ),
              ),
            ),
            Positioned(
              bottom: MediaQuery.sizeOf(context).height * 0.06,
              left: -MediaQuery.sizeOf(context).width * 0.25,
              child: _Blob(
                diameter: MediaQuery.sizeOf(context).width * 0.95,
                gradient: RadialGradient(
                  colors: [
                    LuminousTokens.secondaryContainer.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.72],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: LuminousTokens.background,
      child: Stack(
        children: [
          Positioned(
            top: -MediaQuery.sizeOf(context).height * 0.08,
            right: -MediaQuery.sizeOf(context).width * 0.22,
            child: _Blob(
              diameter: MediaQuery.sizeOf(context).width * 0.72,
              gradient: const RadialGradient(
                colors: [
                  Color(0x2653E16F), // rgba(83,225,111,0.15)-ish
                  Color(0x00FCF8FB),
                ],
                stops: [0, 0.7],
              ),
            ),
          ),
          Positioned(
            bottom: MediaQuery.sizeOf(context).height * 0.06,
            left: -MediaQuery.sizeOf(context).width * 0.22,
            child: _Blob(
              diameter: MediaQuery.sizeOf(context).width * 0.82,
              gradient: RadialGradient(
                colors: [
                  LuminousTokens.secondaryContainer.withValues(alpha: 0.08),
                  LuminousTokens.background.withValues(alpha: 0),
                ],
                stops: const [0, 0.7],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double diameter;
  final Gradient gradient;

  const _Blob({required this.diameter, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
        ),
      ),
    );
  }
}
