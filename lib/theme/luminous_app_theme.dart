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

ColorScheme luminousLightScheme() {
  return ColorScheme(
    brightness: Brightness.light,
    primary: LuminousTokens.primary,
    onPrimary: LuminousTokens.onPrimary,
    primaryContainer: LuminousTokens.primaryContainer,
    onPrimaryContainer: LuminousTokens.onPrimaryContainer,
    secondary: LuminousTokens.secondary,
    onSecondary: LuminousTokens.onSecondary,
    secondaryContainer: LuminousTokens.secondaryContainer,
    onSecondaryContainer: const Color(0xFFFEFCFF),
    tertiary: const Color(0xFF9C413D),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFFF8E86),
    onTertiaryContainer: const Color(0xFF772523),
    error: LuminousTokens.error,
    onError: Colors.white,
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF93000A),
    surface: LuminousTokens.background,
    onSurface: LuminousTokens.onSurface,
    surfaceContainerHighest: LuminousTokens.surfaceContainerHighest,
    surfaceContainerHigh: LuminousTokens.surfaceContainerHigh,
    surfaceContainer: LuminousTokens.surfaceContainer,
    surfaceContainerLow: const Color(0xFFF6F3F5),
    surfaceContainerLowest: Colors.white,
    onSurfaceVariant: LuminousTokens.onSurfaceVariant,
    outline: LuminousTokens.outline,
    outlineVariant: LuminousTokens.outlineVariant,
    shadow: Colors.black26,
    scrim: Colors.black54,
    inverseSurface: const Color(0xFF303032),
    onInverseSurface: const Color(0xFFF3F0F2),
    inversePrimary: const Color(0xFF53E16F),
  );
}

ColorScheme luminousDarkScheme() {
  const surface = Color(0xFF1C1C1E);
  return ColorScheme(
    brightness: Brightness.dark,
    primary: const Color(0xFF53E16F),
    onPrimary: const Color(0xFF002107),
    primaryContainer: const Color(0xFF00531C),
    onPrimaryContainer: const Color(0xFF72FE88),
    secondary: const Color(0xFFADC6FF),
    onSecondary: const Color(0xFF001A41),
    secondaryContainer: const Color(0xFF004493),
    onSecondaryContainer: const Color(0xFFD8E2FF),
    tertiary: const Color(0xFFFFB3AD),
    onTertiary: const Color(0xFF410004),
    tertiaryContainer: const Color(0xFF7E2A27),
    onTertiaryContainer: const Color(0xFFFFDAD7),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
    surface: surface,
    onSurface: const Color(0xFFE4E2E4),
    surfaceContainerHighest: const Color(0xFF3A3A3C),
    surfaceContainerHigh: const Color(0xFF303032),
    surfaceContainer: const Color(0xFF2C2C2E),
    surfaceContainerLow: const Color(0xFF242426),
    surfaceContainerLowest: const Color(0xFF121212),
    onSurfaceVariant: const Color(0xFFBCCBB8),
    outline: const Color(0xFF6D7B6B),
    outlineVariant: const Color(0xFF3D4A3C),
    shadow: Colors.black54,
    scrim: Colors.black87,
    inverseSurface: const Color(0xFFE4E2E4),
    onInverseSurface: const Color(0xFF303032),
    inversePrimary: LuminousTokens.primary,
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
