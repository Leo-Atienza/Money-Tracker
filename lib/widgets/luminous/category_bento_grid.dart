import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/luminous_tokens.dart';

/// One choice in the [CategoryBentoGrid].
class CategoryBentoItem {
  /// Stable id (typically the category id) — passed back via `onSelected`.
  final Object id;

  /// Display label rendered beside the icon.
  final String label;

  /// Icon rendered in the chip's tinted square.
  final IconData icon;

  /// Tint color for the icon square and the selected state.
  final Color color;

  const CategoryBentoItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Category picker used on the Add Transaction screen: a wrapping set of
/// tappable chips, each a tinted category icon plus the full category name.
///
/// The name is historical (like the `Glass*` widgets). This used to be a
/// fixed 4-column bento grid, which truncated real names on phones —
/// "Entertai…", "Freel…", "Invest…" — and a fixed column count cannot fix
/// that: even three columns clip "Entertainment" on a 360dp screen. Chips
/// size to their label, so every default name shows in full and only a
/// custom name longer than the whole row wraps to a second line.
///
/// It is a plain [Wrap], not a `GridView`: a scrollable without an explicit
/// `padding` inherits the MediaQuery status-bar inset, which is what put an
/// empty band between the CATEGORY header and the first row.
class CategoryBentoGrid extends StatelessWidget {
  final List<CategoryBentoItem> items;
  final Object? selectedId;
  final ValueChanged<Object> onSelected;

  const CategoryBentoGrid({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: LuminousTokens.basePx,
      runSpacing: LuminousTokens.basePx,
      children: [
        for (final item in items)
          _CategoryChip(
            item: item,
            selected: item.id == selectedId,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(item.id);
            },
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final CategoryBentoItem item;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Selection is carried three ways so it never rests on colour alone: a
    // light tint of the category colour, a stronger border, and a heavier,
    // full-contrast label.
    final fill = selected
        ? item.color.withValues(alpha: 0.14)
        : cs.surfaceContainerHighest;
    final border = selected
        ? item.color.withValues(alpha: 0.55)
        : cs.outlineVariant.withValues(alpha: 0.6);

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        // The fill lives on the Material (not a decoration above the
        // InkWell) so the press ripple paints on top of it and is visible.
        child: Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LuminousTokens.radiusMd),
            side: BorderSide(color: border, width: selected ? 1.4 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: LuminousTokens.touchTargetMin,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.icon,
                        size: LuminousTokens.iconSm,
                        color: item.color,
                      ),
                    ),
                    const SizedBox(width: LuminousTokens.basePx),
                    Flexible(
                      child: Text(
                        item.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? cs.onSurface : cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
