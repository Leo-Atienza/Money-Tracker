// FIX #37: Centralized spacing constants. Phase 5 will inline these
// screen-by-screen onto `lib/theme/luminous_tokens.dart`, after which this
// file gets deleted. Values are realigned to match LuminousTokens so the
// migration is mechanical.
//
// **Do not add new constants here.** Add them to `LuminousTokens` instead.

import '../theme/luminous_tokens.dart';

class Spacing {
  Spacing._();

  // Base spacing unit (8dp Material Design)
  static const double base = LuminousTokens.basePx;

  // Tiny spacing
  static const double tiny = 2.0;
  static const double xxs = 4.0;

  // Small spacing
  static const double xs = 8.0;
  static const double sm = 12.0;

  // Medium spacing (most common)
  static const double md = LuminousTokens.stackGap; // 16
  static const double lg = LuminousTokens.containerPadding; // 20
  static const double xl = LuminousTokens.glassPadding; // 24

  // Large spacing
  static const double xxl = LuminousTokens.sectionMargin; // 32
  static const double xxxl = 40.0;
  static const double huge = LuminousTokens.touchTargetMin; // 48

  // Screen padding — realigned to LuminousTokens (Phase 2.2):
  //   screenPadding 24 → 20 (matches containerPadding)
  //   cardPadding   20 → 24 (matches glassPadding)
  static const double screenPadding = LuminousTokens.containerPadding;
  static const double cardPadding = LuminousTokens.glassPadding;

  // Component-specific
  static const double iconSize = 20.0;
  static const double iconSizeLarge = LuminousTokens.iconMd; // 24
  static const double iconSizeHuge = 64.0;

  // FIX #32: Minimum touch target size for accessibility (WCAG AA)
  static const double minTouchTarget = LuminousTokens.touchTargetMin;

  // Border radius
  static const double radiusSmall = LuminousTokens.radiusSm; // 8
  static const double radiusMedium = 12.0;
  static const double radiusLarge = LuminousTokens.radiusMd; // 16
  static const double radiusXLarge = 20.0;

  // Divider
  static const double dividerThickness = 1.0;

  // Progress bars
  static const double progressBarHeight = 8.0;
  static const double progressBarHeightSmall = 4.0;
}
