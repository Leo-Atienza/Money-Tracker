import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/luminous_tokens.dart';

/// Pill-shaped segmented switch with a sliding indicator.
///
/// Used for Expense/Income on the Add screen, All/Expenses/Income on History,
/// and Day/Week/Month/Year on Analytics. Two or more segments supported.
class GlassSegmentedControl<T> extends StatelessWidget {
  /// Segment values in display order.
  final List<T> values;

  /// Display label for each value. Must have the same length as [values].
  final List<String> labels;

  /// Currently selected value. Must be present in [values].
  final T selected;

  /// Called when the user taps a new segment.
  final ValueChanged<T> onChanged;

  const GlassSegmentedControl({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
  })  : assert(values.length == labels.length),
        assert(values.length >= 2, 'Segmented control needs at least 2 values');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // De-glass: solid track + solid active pill drawn from the colorScheme.
    final activeFill = cs.surface;
    final containerFill = cs.surfaceContainerHighest;

    return Semantics(
      container: true,
      label: 'Segmented control',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: containerFill,
          borderRadius: BorderRadius.circular(LuminousTokens.radiusPill),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: _Segment(
                    label: labels[i],
                    selected: values[i] == selected,
                    onTap: () {
                      if (values[i] == selected) return;
                      HapticFeedback.selectionClick();
                      onChanged(values[i]);
                    },
                    activeFill: activeFill,
                    activeColor: cs.onSurface,
                    inactiveColor: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeFill;
  final Color activeColor;
  final Color inactiveColor;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.activeFill,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
              color: selected ? activeColor : inactiveColor,
              fontWeight: FontWeight.w600,
            ) ??
        TextStyle(color: selected ? activeColor : inactiveColor);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(LuminousTokens.radiusPill),
        onTap: onTap,
        // L44: the tap target is >=48dp (Material minimum) while the painted
        // pill stays at 40dp, centered inside it.
        child: SizedBox(
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? activeFill : Colors.transparent,
                borderRadius: BorderRadius.circular(LuminousTokens.radiusPill),
              ),
              child: Text(label, style: textStyle),
            ),
          ),
        ),
      ),
    );
  }
}
