import 'package:flutter/material.dart';

class ColorPicker extends StatelessWidget {
  final String? selectedColor;
  final Function(String?) onColorSelected;

  const ColorPicker({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
  });

  // Curated palette with good contrast in both light and dark modes
  static const List<String?> colors = [
    null, // No color option
    '#EF4444', // Red
    '#F97316', // Orange
    '#F59E0B', // Amber
    '#84CC16', // Lime
    '#10B981', // Green
    '#14B8A6', // Teal
    '#06B6D4', // Cyan
    '#3B82F6', // Blue
    '#6366F1', // Indigo
    '#8B5CF6', // Violet
    '#A855F7', // Purple
    '#EC4899', // Pink
    '#F43F5E', // Rose
    '#64748B', // Slate
    '#78716C', // Stone
  ];

  static Color parseColor(String? hex) {
    if (hex == null || hex.isEmpty) {
      return Colors.transparent;
    }
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Choose Color',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optional visual indicator for this category',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: colors.map((color) {
                final isSelected = color == selectedColor;
                final isNone = color == null;

                return GestureDetector(
                  onTap: () {
                    onColorSelected(color);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isNone
                          ? theme.colorScheme.surfaceContainerHighest
                          : parseColor(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline.withAlpha(100),
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isNone
                        ? Icon(
                            Icons.block,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 24,
                          )
                        : isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              )
                            : null,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
