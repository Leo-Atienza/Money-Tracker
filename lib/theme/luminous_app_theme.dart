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

  return TextTheme(
    displayLarge: hanken(34, FontWeight.w800, height: 41, letterSpacing: -0.5),
    headlineMedium:
        hanken(24, FontWeight.w700, height: 30, letterSpacing: -0.3),
    titleLarge: hanken(20, FontWeight.w600, height: 26, letterSpacing: -0.2),
    bodyLarge: hanken(17, FontWeight.w400, height: 24, letterSpacing: -0.2),
    bodyMedium: hanken(15, FontWeight.w400, height: 20, letterSpacing: 0),
    labelSmall: hanken(12, FontWeight.w600, height: 16, letterSpacing: 1.2),
    titleMedium: hanken(16, FontWeight.w600, height: 22),
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

ThemeData buildLuminousTheme({
  required Brightness brightness,
  required ThemeExtension<dynamic> appColorsExtension,
}) {
  final cs = brightness == Brightness.light
      ? luminousLightScheme()
      : luminousDarkScheme();
  final textTheme = _luminousTextTheme(cs);
  final isDark = brightness == Brightness.dark;

  // De-glass (2026-06-29): every surface is now solid. The Luminous glass +
  // OrganicBlobBackground layer was removed in favour of the clean, minimalist
  // Material 3 look the app originally shipped with. Surfaces draw from the
  // colorScheme container roles so light/dark both read as flat, opaque cards.
  return ThemeData(
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
      // low-contrast white icon on a pale blue pill).
      indicatorColor: cs.primary.withValues(alpha: isDark ? 0.30 : 0.14),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 26,
          color: selected ? cs.primary : cs.onSurfaceVariant,
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
    extensions: [appColorsExtension],
  );
}
