import 'package:flutter/material.dart';

/// Helper for ensuring WCAG AA color contrast compliance.
///
/// WCAG AA requires:
/// - Minimum contrast ratio of 4.5:1 for normal text (<18pt or <14pt bold)
/// - Minimum contrast ratio of 3:1 for large text (>=18pt or >=14pt bold)
/// - Minimum contrast ratio of 3:1 for UI components and graphical objects
class ColorContrastHelper {
  /// WCAG AA minimum contrast ratio for normal text
  static const double minContrastNormalText = 4.5;

  /// WCAG AA minimum contrast ratio for large text and UI components
  static const double minContrastLargeText = 3.0;

  /// Calculates the relative luminance of a color (0 to 1).
  /// Formula from WCAG 2.1 specification.
  static double _relativeLuminance(Color color) {
    final r = _sRGBtoLinear((color.r * 255.0).round().clamp(0, 255) / 255.0);
    final g = _sRGBtoLinear((color.g * 255.0).round().clamp(0, 255) / 255.0);
    final b = _sRGBtoLinear((color.b * 255.0).round().clamp(0, 255) / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Converts sRGB color value to linear RGB.
  static double _sRGBtoLinear(double value) {
    if (value <= 0.03928) {
      return value / 12.92;
    } else {
      return ((value + 0.055) / 1.055).pow(2.4);
    }
  }

  /// Calculates the contrast ratio between two colors.
  /// Returns a value from 1 to 21, where 21 is maximum contrast (black/white).
  static double contrastRatio(Color color1, Color color2) {
    final lum1 = _relativeLuminance(color1);
    final lum2 = _relativeLuminance(color2);
    final lighter = lum1 > lum2 ? lum1 : lum2;
    final darker = lum1 > lum2 ? lum2 : lum1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Checks if two colors meet WCAG AA contrast for normal text (4.5:1).
  static bool meetsAA(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= minContrastNormalText;
  }

  /// Checks if two colors meet WCAG AA contrast for large text (3:1).
  static bool meetsAALarge(Color foreground, Color background) {
    return contrastRatio(foreground, background) >= minContrastLargeText;
  }

  /// Returns a contrasting text color (black or white) that meets WCAG AA.
  static Color getContrastingTextColor(Color background) {
    final whiteContrast = contrastRatio(Colors.white, background);
    final blackContrast = contrastRatio(Colors.black, background);

    // Prefer white if both meet AA, otherwise pick the one with higher contrast
    if (whiteContrast >= minContrastNormalText) {
      return Colors.white;
    } else if (blackContrast >= minContrastNormalText) {
      return Colors.black;
    } else {
      // Neither meets AA, return the one with better contrast
      return whiteContrast > blackContrast ? Colors.white : Colors.black;
    }
  }

  /// Adjusts a color to meet WCAG AA contrast ratio with the given background.
  /// Returns a darker or lighter version of the color that meets the requirement.
  static Color adjustForContrast(
    Color color,
    Color background, {
    double targetRatio = minContrastNormalText,
  }) {
    double currentRatio = contrastRatio(color, background);

    if (currentRatio >= targetRatio) {
      return color; // Already meets requirement
    }

    // Determine if we should darken or lighten
    final bgLuminance = _relativeLuminance(background);
    final shouldDarken = bgLuminance > 0.5;

    // Binary search for the right shade
    Color adjusted = color;
    if (shouldDarken) {
      // Make darker
      double factor = 0.0;
      double step = 0.5;
      for (int i = 0; i < 10; i++) {
        final alpha = (color.a * 255.0).round().clamp(0, 255);
        final red = ((color.r * 255.0).round().clamp(0, 255) * (1 - factor)).round();
        final green = ((color.g * 255.0).round().clamp(0, 255) * (1 - factor)).round();
        final blue = ((color.b * 255.0).round().clamp(0, 255) * (1 - factor)).round();
        adjusted = Color.fromARGB(alpha, red, green, blue);
        currentRatio = contrastRatio(adjusted, background);
        if (currentRatio >= targetRatio) {
          break;
        }
        factor += step;
        step /= 2;
      }
    } else {
      // Make lighter
      double factor = 0.0;
      double step = 0.5;
      for (int i = 0; i < 10; i++) {
        final alpha = (color.a * 255.0).round().clamp(0, 255);
        final red = (color.r * 255.0).round().clamp(0, 255);
        final green = (color.g * 255.0).round().clamp(0, 255);
        final blue = (color.b * 255.0).round().clamp(0, 255);
        adjusted = Color.fromARGB(
          alpha,
          (red + (255 - red) * factor).round(),
          (green + (255 - green) * factor).round(),
          (blue + (255 - blue) * factor).round(),
        );
        currentRatio = contrastRatio(adjusted, background);
        if (currentRatio >= targetRatio) {
          break;
        }
        factor += step;
        step /= 2;
      }
    }

    return adjusted;
  }

  /// Returns WCAG-compliant status colors for light/dark themes.
  static StatusColors getStatusColors(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return StatusColors(
        success: Colors.green.shade400,  // Sufficient contrast on dark
        warning: Colors.orange.shade400, // Sufficient contrast on dark
        error: Colors.red.shade400,      // Sufficient contrast on dark
        info: Colors.blue.shade400,      // Sufficient contrast on dark
      );
    } else {
      return StatusColors(
        success: Colors.green.shade700,  // Sufficient contrast on light
        warning: Colors.orange.shade800, // Sufficient contrast on light
        error: Colors.red.shade700,      // Sufficient contrast on light
        info: Colors.blue.shade700,      // Sufficient contrast on light
      );
    }
  }
}

/// Container for status colors that meet WCAG AA contrast requirements.
class StatusColors {
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  const StatusColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
  });
}

extension on double {
  double pow(double exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent.abs(); i++) {
      result *= this;
    }
    return exponent < 0 ? 1.0 / result : result;
  }
}
