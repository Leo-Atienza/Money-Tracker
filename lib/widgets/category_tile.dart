import 'package:flutter/material.dart';
import '../theme/category_palette.dart';
import '../utils/category_icons.dart';
import '../widgets/color_picker.dart';

/// Default colours for categories.
///
/// The table itself now lives in `theme/category_palette.dart` — a colour map
/// in a widget file is how palettes drift out of reach of the theme. This
/// forwarder is kept so the existing call sites and tests do not have to move
/// in the same change.
class CategoryColors {
  CategoryColors._();

  /// Default colours for expense categories by name.
  static Map<String, Color> get expenseColors => CategoryPalette.expenseColors;

  /// Default colours for income categories by name.
  static Map<String, Color> get incomeColors => CategoryPalette.incomeColors;

  /// Get default colour for a category.
  static Color getDefaultColor(String categoryName, String categoryType) =>
      CategoryPalette.getDefaultColor(categoryName, categoryType);
}

/// A visual category indicator tile with colored background and icon.
/// Premium design with gradient background, shadow, and refined styling.
class CategoryTile extends StatelessWidget {
  /// The category name (used for default icon lookup)
  final String categoryName;

  /// Category type: 'expense' or 'income'
  final String categoryType;

  /// Hex color code for the category (e.g., '#FF5733')
  final String? color;

  /// Icon code point as string (optional, falls back to default)
  final String? icon;

  /// Size of the tile (default: 44)
  final double size;

  /// Border radius (default: 12)
  final double borderRadius;

  /// Icon size relative to tile size (default: 0.5)
  final double iconScale;

  const CategoryTile({
    super.key,
    required this.categoryName,
    required this.categoryType,
    this.color,
    this.icon,
    this.size = 44,
    this.borderRadius = 12,
    this.iconScale = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get the icon to display
    final iconData = CategoryIcons.getIcon(icon, categoryName, categoryType);

    // Determine the base color
    final Color baseColor;
    if (color != null && color!.isNotEmpty) {
      baseColor = ColorPicker.parseColor(color);
    } else {
      baseColor = CategoryColors.getDefaultColor(categoryName, categoryType);
    }

    // Premium gradient colors - more visible and vibrant
    final Color gradientStart = baseColor.withAlpha(isDark ? 70 : 50);
    final Color gradientEnd = baseColor.withAlpha(isDark ? 45 : 30);

    // Icon color - slightly brighter in dark mode for visibility
    final Color iconColor = isDark
        ? HSLColor.fromColor(baseColor)
            .withLightness(
              (HSLColor.fromColor(baseColor).lightness + 0.1).clamp(0.0, 1.0),
            )
            .toColor()
        : baseColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientStart, gradientEnd],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: baseColor.withAlpha(isDark ? 40 : 25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withAlpha(isDark ? 30 : 20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(iconData, color: iconColor, size: size * iconScale),
    );
  }
}

/// A smaller category tile for inline use (next to text)
class CategoryTileSmall extends StatelessWidget {
  final String categoryName;
  final String categoryType;
  final String? color;
  final String? icon;

  const CategoryTileSmall({
    super.key,
    required this.categoryName,
    required this.categoryType,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return CategoryTile(
      categoryName: categoryName,
      categoryType: categoryType,
      color: color,
      icon: icon,
      size: 36,
      borderRadius: 10,
      iconScale: 0.5,
    );
  }
}

/// A larger category tile for prominent displays (category management, etc.)
class CategoryTileLarge extends StatelessWidget {
  final String categoryName;
  final String categoryType;
  final String? color;
  final String? icon;

  const CategoryTileLarge({
    super.key,
    required this.categoryName,
    required this.categoryType,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return CategoryTile(
      categoryName: categoryName,
      categoryType: categoryType,
      color: color,
      icon: icon,
      size: 56,
      borderRadius: 14,
      iconScale: 0.5,
    );
  }
}
