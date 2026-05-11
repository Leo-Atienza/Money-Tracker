import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'luminous_tokens.dart';

export 'luminous_tokens.dart';

TextTheme _luminousTextTheme(ColorScheme cs) {
  TextStyle hanken(
    double size,
    FontWeight w, {
    double height = 1.2,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.hankenGrotesk(
      fontSize: size,
      fontWeight: w,
      height: height / size,
      letterSpacing: letterSpacing,
      color: cs.onSurface,
    );
  }

  return TextTheme(
    displayLarge: hanken(34, FontWeight.w800, height: 41, letterSpacing: -0.5),
    headlineMedium: hanken(24, FontWeight.w700, height: 30, letterSpacing: -0.3),
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
  final cs =
      brightness == Brightness.light ? luminousLightScheme() : luminousDarkScheme();
  final textTheme = _luminousTextTheme(cs);
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: cs.onSurface,
      titleTextStyle: textTheme.headlineMedium,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuminousTokens.radiusCard),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: LuminousTokens.glassBorder.withValues(alpha: isDark ? 0.35 : 1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: LuminousTokens.glassBorder.withValues(alpha: isDark ? 0.25 : 0.8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: LuminousTokens.primary.withValues(alpha: 0.85),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: cs.primaryContainer.withValues(alpha: 0.35),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cs.inverseSurface.withValues(alpha: 0.92),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: cs.onInverseSurface),
    ),
    extensions: [appColorsExtension],
  );
}
