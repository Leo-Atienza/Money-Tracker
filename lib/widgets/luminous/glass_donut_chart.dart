import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/luminous_tokens.dart';

/// Single slice of a [GlassDonutChart].
class DonutSlice {
  final String label;
  final double value;
  final Color color;

  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Donut chart used as the hero on the Analytics screen.
///
/// Skeleton: takes a list of slices and an optional center child (typically
/// the total amount + label). Phase 5 will replace the inline `fl_chart`
/// donut on Analytics with this widget.
class GlassDonutChart extends StatelessWidget {
  /// Slices in display order (clockwise from 12 o'clock).
  final List<DonutSlice> slices;

  /// Outer diameter of the donut in logical pixels.
  final double size;

  /// Thickness of the donut ring.
  final double thickness;

  /// Optional widget rendered at the center of the donut (e.g. total amount).
  final Widget? center;

  /// Gap angle between slices, in radians.
  final double sliceGap;

  const GlassDonutChart({
    super.key,
    required this.slices,
    this.size = 220,
    this.thickness = 28,
    this.center,
    this.sliceGap = 0.04,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: DonutPainter(
          slices: slices,
          thickness: thickness,
          sliceGap: sliceGap,
          trackColor: Theme.of(context).colorScheme.outlineVariant.withValues(
                alpha: 0.25,
              ),
        ),
        child: Center(child: center),
      ),
    );
  }
}

/// Painter for [GlassDonutChart]. Public + `@visibleForTesting` only so the
/// [shouldRepaint] contract can be asserted directly in unit tests; treat it
/// as private to this library otherwise.
@visibleForTesting
class DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double thickness;
  final double sliceGap;
  final Color trackColor;

  DonutPainter({
    required this.slices,
    required this.thickness,
    required this.sliceGap,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - thickness / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final total = slices.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;

    final twoPi = math.pi * 2;
    final totalGap = sliceGap * slices.length;
    final usable = twoPi - totalGap;

    double start = -math.pi / 2 + sliceGap / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * usable;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = thickness
        ..color = slice.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep + sliceGap;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) {
    if (oldDelegate.thickness != thickness ||
        oldDelegate.sliceGap != sliceGap ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.slices.length != slices.length) {
      return true;
    }
    for (var i = 0; i < slices.length; i++) {
      if (oldDelegate.slices[i].value != slices[i].value ||
          oldDelegate.slices[i].color != slices[i].color) {
        return true;
      }
    }
    return false;
  }
}

/// Compact legend used alongside a donut chart.
class DonutLegend extends StatelessWidget {
  final List<DonutSlice> slices;
  final String Function(DonutSlice slice) valueFormatter;

  const DonutLegend({
    super.key,
    required this.slices,
    required this.valueFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final slice in slices) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: slice.color,
                  borderRadius: BorderRadius.circular(LuminousTokens.radiusSm),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  slice.label,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                valueFormatter(slice),
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
