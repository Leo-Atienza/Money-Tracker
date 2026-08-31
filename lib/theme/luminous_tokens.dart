/// Single source of truth for the layout design tokens — spacing, radii, icon
/// sizes, and touch targets.
///
/// Tokens from `stitch_premium_glassmorphism_ui/luminous_glass_system/DESIGN.md`,
/// augmented per `docs/MASTER_PLAN.md` Phase 2.2.
///
/// The colour tokens that used to live here were removed once the S17
/// black-and-white palette hand-built `luminousLightScheme`/`luminousDarkScheme`
/// in `luminous_app_theme.dart` — nothing referenced them any more. Colour now
/// comes from `Theme.of(context).colorScheme` and the `AppColors` extension
/// (income/expense/warning/info), so there is exactly one place to change it.
class LuminousTokens {
  LuminousTokens._();

  // --- Spacing scale --------------------------------------------------------
  static const double basePx = 8;
  static const double stackGap = 16;
  static const double containerPadding = 20;
  static const double glassPadding = 24;
  static const double sectionMargin = 32;

  // --- Radii ----------------------------------------------------------------
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusPill = 9999;

  // Legacy alias retained for screens still on the original token names.
  static const double radiusCard = radiusLg;

  // --- Icon sizes -----------------------------------------------------------
  static const double iconSm = 18;

  // --- Touch target ---------------------------------------------------------
  // WCAG AA — minimum tappable area on either axis.
  static const double touchTargetMin = 48;
}
