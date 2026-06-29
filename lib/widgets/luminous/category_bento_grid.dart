import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/luminous_tokens.dart';

/// One cell in the [CategoryBentoGrid].
class CategoryBentoItem {
  /// Stable id (typically the category id) — passed back via `onSelected`.
  final Object id;

  /// Display label rendered beneath the icon.
  final String label;

  /// Icon rendered in the cell.
  final IconData icon;

  /// Tint color for the icon container.
  final Color color;

  const CategoryBentoItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// 4-column bento grid used as the category picker on the Add Transaction
/// screen. Each cell is a tappable glass tile with an icon + label.
class CategoryBentoGrid extends StatelessWidget {
  final List<CategoryBentoItem> items;
  final Object? selectedId;
  final ValueChanged<Object> onSelected;

  /// Number of columns. Defaults to 4 per the Luminous spec.
  final int columns;

  const CategoryBentoGrid({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.columns = 4,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Taller than wide so the icon + label fit without a vertical
        // overflow, including at the clamped 1.3x accessibility text scale
        // (0.95 clipped the label by ~8px).
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        return _BentoCell(
          item: item,
          selected: item.id == selectedId,
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(item.id);
          },
        );
      },
    );
  }
}

class _BentoCell extends StatelessWidget {
  final CategoryBentoItem item;
  final bool selected;
  final VoidCallback onTap;

  const _BentoCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // De-glass: solid cells; the selected cell gets a light tint of its
    // category colour plus a stronger coloured border.
    final tileFill = selected
        ? item.color.withValues(alpha: 0.14)
        : cs.surfaceContainerHighest;
    final border = selected
        ? item.color.withValues(alpha: 0.55)
        : cs.outlineVariant.withValues(alpha: 0.6);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(LuminousTokens.radiusMd),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: tileFill,
            borderRadius: BorderRadius.circular(LuminousTokens.radiusMd),
            border: Border.all(color: border, width: selected ? 1.4 : 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 22, color: item.color),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w600,
                    ) ??
                    const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
