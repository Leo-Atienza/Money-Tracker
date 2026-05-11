import 'package:flutter/material.dart';

/// Single source of truth for Luminous design tokens — spacing, radii, blur,
/// icon sizes, touch targets, and surface colors.
///
/// Tokens from `stitch_premium_glassmorphism_ui/luminous_glass_system/DESIGN.md`,
/// augmented per `docs/MASTER_PLAN.md` Phase 2.2.
///
/// Phase 5 will migrate every screen off `lib/constants/spacing.dart` and onto
/// these tokens, after which `Spacing.*` can be deleted entirely.
class LuminousTokens {
  LuminousTokens._();

  // --- Surface palette ------------------------------------------------------
  static const Color background = Color(0xFFFCF8FB);
  static const Color onBackground = Color(0xFF1B1B1D);
  static const Color primary = Color(0xFF006E28);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF34C759);
  static const Color onPrimaryContainer = Color(0xFF004D1A);
  static const Color secondary = Color(0xFF0058BC);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF0070EB);
  static const Color onSurface = Color(0xFF1B1B1D);
  static const Color onSurfaceVariant = Color(0xFF3D4A3C);
  static const Color surfaceContainer = Color(0xFFF0EDEF);
  static const Color surfaceContainerHigh = Color(0xFFEAE7EA);
  static const Color surfaceContainerHighest = Color(0xFFE4E2E4);
  static const Color outline = Color(0xFF6D7B6B);
  static const Color outlineVariant = Color(0xFFBCCBB8);
  static const Color error = Color(0xFFBA1A1A);
  static const Color glassFill = Color(0x73FFFFFF); // ~45% white
  static const Color glassBorder = Color(0x66FFFFFF); // 40% white stroke

  // --- Spacing scale --------------------------------------------------------
  static const double basePx = 8;
  static const double stackGap = 16;
  static const double containerPadding = 20;
  static const double glassPadding = 24;
  static const double sectionMargin = 32;

  // --- Radii ----------------------------------------------------------------
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusXl = 32;
  static const double radiusPill = 9999;

  // Legacy alias retained for screens still on the original token names.
  // Phase 5 will inline-rename these to radiusLg.
  static const double radiusCard = radiusLg;

  // --- Icon sizes -----------------------------------------------------------
  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 28;

  // --- Touch target ---------------------------------------------------------
  // WCAG AA — minimum tappable area on either axis.
  static const double touchTargetMin = 48;

  // --- Blur -----------------------------------------------------------------
  // Phase 1.7 reduced from 25 → 15 to stay under 8 ms/frame on a Pixel 4a
  // class device. Documented in `docs/DESIGN_DEVIATIONS.md` (DD-001).
  static const double blurSigma = 15;

  // Legacy alias for screens that read the original name.
  static const double glassBlurSigma = blurSigma;

  // --- Behavioural constants -----------------------------------------------
  static const double swipeVelocityThreshold = 500;
  static const double compactNumberThreshold = 100000;
  static const int maxBillsOnHome = 3;

  // Pill + padding, used as bottom inset on screens behind the floating nav.
  static const double navBarHeightTotal = 80;
}
