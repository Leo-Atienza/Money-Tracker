import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'luminous_tokens.dart';

export 'luminous_tokens.dart';

/// Phase 2.3: Hanken Grotesk is now bundled as a variable TTF
/// (`assets/fonts/HankenGrotesk/HankenGrotesk-Variable.ttf`) and `google_fonts`
/// has been removed. The wght axis is driven explicitly via
/// `FontVariation('wght', …)` so each text role lands on the correct numeric
/// weight regardless of which fallback Flutter would otherwise synthesize.
TextTheme _luminousTextTheme(ColorScheme cs) {
  TextStyle hanken(
    double size,
    FontWeight w, {
    double height = 1.2,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: 'HankenGrotesk',
      fontSize: size,
      fontWeight: w,
      fontVariations: <FontVariation>[
        FontVariation('wght', w.value.toDouble()),
      ],
      height: height / size,
      letterSpacing: letterSpacing,
      color: cs.onSurface,
    );
  }

  // Every role the screens reach for is defined here. A role left out of
  // this table is not "inherited" — ThemeData fills it from Material's
  // default typography, i.e. Roboto at the default weight. bodySmall,
  // labelLarge and titleSmall were used across ~50 call sites and were
  // rendering in Roboto next to Hanken Grotesk until they were added.
  return TextTheme(
    displayLarge: hanken(34, FontWeight.w800, height: 41, letterSpacing: -0.5),
    headlineMedium:
        hanken(24, FontWeight.w700, height: 30, letterSpacing: -0.3),
    headlineSmall:
        hanken(20, FontWeight.w700, height: 26, letterSpacing: -0.2),
    titleLarge: hanken(20, FontWeight.w600, height: 26, letterSpacing: -0.2),
    titleMedium: hanken(16, FontWeight.w600, height: 22),
    titleSmall: hanken(14, FontWeight.w600, height: 20),
    bodyLarge: hanken(17, FontWeight.w400, height: 24, letterSpacing: -0.2),
    bodyMedium: hanken(15, FontWeight.w400, height: 20, letterSpacing: 0),
    bodySmall: hanken(13, FontWeight.w400, height: 18, letterSpacing: 0),
    labelLarge: hanken(14, FontWeight.w600, height: 20, letterSpacing: 0.1),
    labelMedium: hanken(12, FontWeight.w600, height: 16, letterSpacing: 0.4),
    labelSmall: hanken(12, FontWeight.w600, height: 16, letterSpacing: 1.2),
  );
}

// Neutral black-and-white palette (S17). The app's chrome — primary, nav,
// buttons, links, focus rings — is pure grayscale (near-black on light,
// near-white on dark), matching the simple original look. Income/expense stay
// green/red via `AppColors` (semantic, WCAG), `error` stays red, and per-
// category colours remain user-controllable through Settings → "Transaction
// Colors". (We hand-build a neutral scheme rather than `fromSeed`, which forces
// a minimum chroma and tints a gray seed faintly purple.)
ColorScheme luminousLightScheme() {
  return const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1B1B1B),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDADADA),
    onPrimaryContainer: Color(0xFF1B1B1B),
    secondary: Color(0xFF5A5A5A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE2E2E2),
    onSecondaryContainer: Color(0xFF1B1B1B),
    tertiary: Color(0xFF5A5A5A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE2E2E2),
    onTertiaryContainer: Color(0xFF1B1B1B),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFAFAFA),
    onSurface: Color(0xFF1B1B1B),
    surfaceContainerHighest: Color(0xFFE6E6E6),
    surfaceContainerHigh: Color(0xFFECECEC),
    surfaceContainer: Color(0xFFF2F2F2),
    surfaceContainerLow: Color(0xFFF7F7F7),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF5C5C5C),
    outline: Color(0xFF8C8C8C),
    outlineVariant: Color(0xFFCECECE),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2E2E2E),
    onInverseSurface: Color(0xFFF2F2F2),
    inversePrimary: Color(0xFFC6C6C6),
  );
}

ColorScheme luminousDarkScheme() {
  return const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFE6E6E6),
    onPrimary: Color(0xFF1B1B1B),
    primaryContainer: Color(0xFF3A3A3A),
    onPrimaryContainer: Color(0xFFE6E6E6),
    secondary: Color(0xFFC6C6C6),
    onSecondary: Color(0xFF1B1B1B),
    secondaryContainer: Color(0xFF3A3A3A),
    onSecondaryContainer: Color(0xFFE6E6E6),
    tertiary: Color(0xFFC6C6C6),
    onTertiary: Color(0xFF1B1B1B),
    tertiaryContainer: Color(0xFF3A3A3A),
    onTertiaryContainer: Color(0xFFE6E6E6),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF121212),
    onSurface: Color(0xFFE6E6E6),
    surfaceContainerHighest: Color(0xFF333333),
    surfaceContainerHigh: Color(0xFF2A2A2A),
    surfaceContainer: Color(0xFF1F1F1F),
    surfaceContainerLow: Color(0xFF1A1A1A),
    surfaceContainerLowest: Color(0xFF0D0D0D),
    onSurfaceVariant: Color(0xFFB0B0B0),
    outline: Color(0xFF8C8C8C),
    outlineVariant: Color(0xFF3D3D3D),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6E6E6),
    onInverseSurface: Color(0xFF2E2E2E),
    inversePrimary: Color(0xFF1B1B1B),
  );
}

// Purple (S20, given a dark sibling in S22). A third, user-chosen appearance
// that sits beside Light and Dark instead of modifying them: lavender
// surfaces, one violet for the chrome, and a violet-cast ink in place of pure
// black so the page reads as a single material. Like the neutral pair it
// follows the phone: this scheme by day, [luminousPurpleDarkScheme] when the
// system is dark. `buildLuminousTheme(tonal: true)` adds the one place the
// violet leaves the chrome: the Home balance card and the nav pill sit on
// `primaryContainer`.
//
// Colour still means something here. Income / expense / warning / info stay
// the semantic colours from `AppColors` for the brightness, and category
// identity colours are untouched — the violet is chrome, not status. Contrast
// is not eyeballed: `test/theme/luminous_theme_test.dart` asserts every ink
// role clears 4.5:1 on every surface role, that `primary` still reads as an
// icon on its own tints (nav indicator, list-tile well), and that the
// semantic colours keep the floor they have on the neutral schemes.
ColorScheme luminousPurpleScheme() {
  return const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF5B44A6),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE6DEFF),
    onPrimaryContainer: Color(0xFF1D0A5A),
    secondary: Color(0xFF5F5878),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFE7E0F8),
    onSecondaryContainer: Color(0xFF1D1834),
    tertiary: Color(0xFF5F5878),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE7E0F8),
    onTertiaryContainer: Color(0xFF1D1834),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFF8F6FE),
    onSurface: Color(0xFF1E1A2E),
    surfaceContainerHighest: Color(0xFFE2DBEF),
    surfaceContainerHigh: Color(0xFFE8E2F4),
    surfaceContainer: Color(0xFFEEE9F8),
    surfaceContainerLow: Color(0xFFF3F0FB),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    onSurfaceVariant: Color(0xFF4E4762),
    outline: Color(0xFF7E7794),
    outlineVariant: Color(0xFFCFC7E0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF312D3F),
    onInverseSurface: Color(0xFFF3EFFA),
    inversePrimary: Color(0xFFC9B8FF),
  );
}

// Purple at night: violet-cast near-black surfaces, a light violet for the
// chrome. `primaryContainer` is deep enough that expense red still clears
// 3:1 on it, because the Home balance card sits on it and a negative
// carry-over prints in red.
ColorScheme luminousPurpleDarkScheme() {
  return const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFCDBEFF),
    onPrimary: Color(0xFF2F1D6F),
    primaryContainer: Color(0xFF3B2E7A),
    onPrimaryContainer: Color(0xFFE8DEFF),
    secondary: Color(0xFFCAC2DE),
    onSecondary: Color(0xFF322C44),
    secondaryContainer: Color(0xFF48425C),
    onSecondaryContainer: Color(0xFFE7E0F8),
    tertiary: Color(0xFFCAC2DE),
    onTertiary: Color(0xFF322C44),
    tertiaryContainer: Color(0xFF48425C),
    onTertiaryContainer: Color(0xFFE7E0F8),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF131118),
    onSurface: Color(0xFFE8E2F2),
    surfaceContainerHighest: Color(0xFF35313C),
    surfaceContainerHigh: Color(0xFF2A2631),
    surfaceContainer: Color(0xFF1F1C26),
    surfaceContainerLow: Color(0xFF1A1720),
    surfaceContainerLowest: Color(0xFF0D0B11),
    onSurfaceVariant: Color(0xFFC9C1D8),
    outline: Color(0xFF958EA6),
    outlineVariant: Color(0xFF49445A),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE8E2F2),
    onInverseSurface: Color(0xFF312D3B),
    inversePrimary: Color(0xFF5B44A6),
  );
}

/// Maps the persisted `theme_mode` string (see `SettingsHelper`) to what
/// `MaterialApp.themeMode` needs. `'purple'` follows the phone like
/// `'system'` does; `main.dart` swaps the Purple pair into the `theme` and
/// `darkTheme` slots. Anything unrecognised (a value written by a newer
/// build, a hand-edited pref) degrades to following the OS rather than
/// throwing.
ThemeMode themeModeFor(String mode) {
  switch (mode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

/// Colours of the Home balance card. The neutral themes paint it like every
/// other card (null [fill] and [border] keep `GlassPanel`'s own); Purple
/// paints it on `primaryContainer` (see `buildLuminousTheme(tonal: true)`).
@immutable
class LuminousHeroColors extends ThemeExtension<LuminousHeroColors> {
  const LuminousHeroColors({
    this.fill,
    this.border,
    required this.ink,
    required this.inkVariant,
  });

  /// The neutral card: GlassPanel's fill and border, the scheme's inks.
  LuminousHeroColors.plain(ColorScheme cs)
      : this(ink: cs.onSurface, inkVariant: cs.onSurfaceVariant);

  /// Purple's violet card. Secondary text is the card's own ink at 74%, not
  /// a grey, so it stays tonal on the violet.
  LuminousHeroColors.tonal(ColorScheme cs)
      : this(
          fill: cs.primaryContainer,
          border: cs.primaryContainer,
          ink: cs.onPrimaryContainer,
          inkVariant: Color.lerp(
            cs.primaryContainer,
            cs.onPrimaryContainer,
            0.74,
          )!,
        );

  final Color? fill;
  final Color? border;
  final Color ink;
  final Color inkVariant;

  @override
  LuminousHeroColors copyWith({
    Color? fill,
    Color? border,
    Color? ink,
    Color? inkVariant,
  }) {
    return LuminousHeroColors(
      fill: fill ?? this.fill,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      inkVariant: inkVariant ?? this.inkVariant,
    );
  }

  @override
  LuminousHeroColors lerp(LuminousHeroColors? other, double t) {
    if (other is! LuminousHeroColors) return this;
    return LuminousHeroColors(
      fill: Color.lerp(fill, other.fill, t),
      border: Color.lerp(border, other.border, t),
      ink: Color.lerp(ink, other.ink, t)!,
      inkVariant: Color.lerp(inkVariant, other.inkVariant, t)!,
    );
  }
}

ThemeData buildLuminousTheme({
  required Brightness brightness,
  required ThemeExtension<dynamic> appColorsExtension,
  // Replaces the neutral scheme for [brightness]; the Purple appearance
  // passes [luminousPurpleScheme]. Its own brightness has to agree, because
  // everything else in here (status-bar icons, shadow strength, and the
  // `brightness == dark` branches in the screens) keys off [brightness].
  ColorScheme? colorScheme,
  // Purple's treatment (option 1b, S22): the nav pill and the Home balance
  // card sit on primaryContainer instead of a primary wash / a plain card.
  bool tonal = false,
}) {
  assert(
    colorScheme == null || colorScheme.brightness == brightness,
    'colorScheme.brightness must match brightness',
  );
  final cs = colorScheme ??
      (brightness == Brightness.light
          ? luminousLightScheme()
          : luminousDarkScheme());
  final textTheme = _luminousTextTheme(cs);
  final isDark = brightness == Brightness.dark;

  // De-glass (2026-06-29): every surface is now solid. The Luminous glass +
  // OrganicBlobBackground layer was removed in favour of the clean, minimalist
  // Material 3 look the app originally shipped with. Surfaces draw from the
  // colorScheme container roles so light/dark both read as flat, opaque cards.
  return ThemeData(
    // Belt and braces for any text role not listed in _luminousTextTheme
    // (display/headline sizes the app does not use): they still get the
    // app's one typeface instead of Roboto.
    fontFamily: 'HankenGrotesk',
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      titleTextStyle: textTheme.headlineMedium,
      systemOverlayStyle:
          isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cs.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuminousTokens.radiusCard),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cs.surface,
      elevation: 0,
      // De-glass: a soft primary-tinted pill with a green selected icon/label
      // (the default seeded indicator was blue secondaryContainer, which put a
      // low-contrast white icon on a pale blue pill). Tonal: a solid violet
      // container pill with its own ink.
      indicatorColor: tonal
          ? cs.primaryContainer
          : cs.primary.withValues(alpha: isDark ? 0.30 : 0.14),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 26,
          color: selected
              ? (tonal ? cs.onPrimaryContainer : cs.primary)
              : cs.onSurfaceVariant,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'HankenGrotesk',
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? cs.primary : cs.onSurfaceVariant,
        );
      }),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cs.inverseSurface,
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: cs.onInverseSurface),
    ),
    extensions: [
      appColorsExtension,
      tonal ? LuminousHeroColors.tonal(cs) : LuminousHeroColors.plain(cs),
    ],
  );
}
