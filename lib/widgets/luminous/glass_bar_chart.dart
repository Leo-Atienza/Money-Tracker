import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/luminous_tokens.dart';

/// One column in a [GlassBarChart].
class BarDatum {
  final String label;
  final double value;

  /// Optional override color. Defaults to the chart's [GlassBarChart.barColor].
  final Color? color;

  const BarDatum({
    required this.label,
    required this.value,
    this.color,
  });
}

/// Vertical bar chart used for monthly comparisons.
///
/// Skeleton: bars are drawn with a CustomPainter so it stays cheap and
/// stylistically consistent with the rest of the Luminous library. Phase 5
/// hooks this up to the Analytics monthly comparison.
class GlassBarChart extends StatelessWidget {
  final List<BarDatum> data;

  /// Color used for bars that don't override their own color.
  final Color? barColor;

  /// Optional formatter for the on-axis value labels above each bar.
  /// If null, the value is rendered with a single decimal place.
  final String Function(double value)? valueFormatter;

  /// Optional axis-line color. Defaults to outlineVariant.
  final Color? axisColor;

  /// Chart height. Width is taken from the parent constraints.
  final double height;

  const GlassBarChart({
    super.key,
    required this.data,
    this.barColor,
    this.valueFormatter,
    this.axisColor,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultBarColor = barColor ?? theme.colorScheme.primary;
    final defaultAxisColor = axisColor ??
        theme.colorScheme.outlineVariant.withValues(alpha: 0.35);
    final labelStyle = theme.textTheme.labelSmall ??
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600);

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BarPainter(
          data: data,
          defaultBarColor: defaultBarColor,
          axisColor: defaultAxisColor,
          textStyle: labelStyle,
          valueFormatter: valueFormatter ?? ((v) => v.toStringAsFixed(1)),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<BarDatum> data;
  final Color defaultBarColor;
  final Color axisColor;
  final TextStyle textStyle;
  final String Function(double) valueFormatter;

  _BarPainter({
    required this.data,
    required this.defaultBarColor,
    required this.axisColor,
    required this.textStyle,
    required this.valueFormatter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const padding = 24.0;
    const valueLabelHeight = 16.0;
    const axisLabelHeight = 18.0;
    final innerHeight = size.height - padding - valueLabelHeight - axisLabelHeight;
    final maxV = math.max(
      data.map((d) => d.value).fold<double>(0, math.max),
      1.0,
    );

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    final axisY = size.height - axisLabelHeight - 2;
    canvas.drawLine(Offset(0, axisY), Offset(size.width, axisY), axisPaint);

    final barCount = data.length;
    final totalGap = padding * (barCount - 1) / 2;
    final barWidth = math.max(
      8.0,
      (size.width - totalGap) / barCount * 0.7,
    );
    final stride = (size.width - barWidth) / math.max(barCount - 1, 1);

    for (var i = 0; i < barCount; i++) {
      final d = data[i];
      final x = (barCount == 1) ? (size.width - barWidth) / 2 : i * stride;
      final h = innerHeight * (d.value / maxV);
      final top = axisY - h;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, barWidth, h),
        const Radius.circular(LuminousTokens.radiusSm),
      );
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (d.color ?? defaultBarColor).withValues(alpha: 0.95),
            (d.color ?? defaultBarColor).withValues(alpha: 0.65),
          ],
        ).createShader(rect.outerRect);
      canvas.drawRRect(rect, fill);

      // Value label above bar
      _drawLabel(
        canvas,
        valueFormatter(d.value),
        Offset(x + barWidth / 2, top - valueLabelHeight),
        textStyle,
      );
      // Axis label below
      _drawLabel(
        canvas,
        d.label,
        Offset(x + barWidth / 2, axisY + 2),
        textStyle.copyWith(fontWeight: FontWeight.w500),
      );
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset anchor, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(anchor.dx - tp.width / 2, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) {
    if (oldDelegate.defaultBarColor != defaultBarColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.data.length != data.length) {
      return true;
    }
    for (var i = 0; i < data.length; i++) {
      if (oldDelegate.data[i].value != data[i].value ||
          oldDelegate.data[i].label != data[i].label ||
          oldDelegate.data[i].color != data[i].color) {
        return true;
      }
    }
    return false;
  }
}
