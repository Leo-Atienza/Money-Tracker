// FIX #37: Centralized spacing constants to avoid magic numbers throughout the codebase
// This improves maintainability and ensures consistent design system

class Spacing {
  // Base spacing unit (8dp Material Design)
  static const double base = 8.0;

  // Tiny spacing
  static const double tiny = 2.0;
  static const double xxs = 4.0;

  // Small spacing
  static const double xs = 8.0;
  static const double sm = 12.0;

  // Medium spacing (most common)
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;

  // Large spacing
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;

  // Screen padding
  static const double screenPadding = 24.0;
  static const double cardPadding = 20.0;

  // Component-specific
  static const double iconSize = 20.0;
  static const double iconSizeLarge = 24.0;
  static const double iconSizeHuge = 64.0;

  // FIX #32: Minimum touch target size for accessibility (WCAG AA)
  static const double minTouchTarget = 48.0;

  // Border radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;

  // Divider
  static const double dividerThickness = 1.0;

  // Progress bars
  static const double progressBarHeight = 8.0;
  static const double progressBarHeightSmall = 4.0;

  Spacing._(); // Prevent instantiation
}
