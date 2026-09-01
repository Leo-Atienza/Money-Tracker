import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/theme/category_palette.dart';
import 'package:budget_tracker/utils/color_contrast_helper.dart';

/// The category tile paints the category colour twice: once as a low-alpha
/// tint for the tile background, once at full strength as the icon on top of
/// it. If those two are too close the icon disappears, which is exactly the
/// failure a hand-picked palette produces and nobody notices until a user
/// squints at a list.
///
/// WCAG 1.4.11 puts the floor for non-text UI (an icon is not text) at 3:1.
/// These tests reproduce the tile's real compositing so the palette cannot
/// regress silently.
void main() {
  /// Alpha values lifted from `CategoryTile.build`.
  const tintAlphaLight = 50;
  const tintAlphaDark = 70;

  const lightSurface = Color(0xFFFCFCFC);
  const darkSurface = Color(0xFF121212);

  /// Flatten `fg` at `alpha` over `bg`, matching what the GPU actually shows.
  Color composite(Color fg, int alpha, Color bg) {
    final a = alpha / 255.0;
    return Color.fromARGB(
      255,
      ((fg.r * 255 * a) + (bg.r * 255 * (1 - a))).round(),
      ((fg.g * 255 * a) + (bg.g * 255 * (1 - a))).round(),
      ((fg.b * 255 * a) + (bg.b * 255 * (1 - a))).round(),
    );
  }

  /// Dark mode lightens the icon by 0.1 HSL — mirror that here.
  Color darkModeIcon(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
  }

  group('CategoryPalette icon-on-tile contrast', () {
    test('every colour clears 3:1 as an icon on its own tint (light)', () {
      final failures = <String>[];
      for (final c in CategoryPalette.allColors) {
        final tile = composite(c, tintAlphaLight, lightSurface);
        final ratio = ColorContrastHelper.contrastRatio(c, tile);
        if (ratio < 3.0) {
          failures.add('$c -> ${ratio.toStringAsFixed(2)}:1');
        }
      }
      expect(failures, isEmpty,
          reason: 'below the 3:1 non-text floor in light mode: $failures');
    });

    test('every colour clears 3:1 as an icon on its own tint (dark)', () {
      final failures = <String>[];
      for (final c in CategoryPalette.allColors) {
        final tile = composite(c, tintAlphaDark, darkSurface);
        final ratio = ColorContrastHelper.contrastRatio(darkModeIcon(c), tile);
        if (ratio < 3.0) {
          failures.add('$c -> ${ratio.toStringAsFixed(2)}:1');
        }
      }
      expect(failures, isEmpty,
          reason: 'below the 3:1 non-text floor in dark mode: $failures');
    });
  });

  group('CategoryPalette semantics', () {
    test('no category colour collides with income green or expense red', () {
      // Category colour must not restate what the amount beside it already
      // says. Anything within 20 degrees of hue of the semantic colours, at
      // comparable saturation, reads as that status rather than as an identity.
      for (final b in [Brightness.light, Brightness.dark]) {
        final status = ColorContrastHelper.getStatusColors(b);
        for (final semantic in [status.success, status.error]) {
          final semanticHue = HSLColor.fromColor(semantic).hue;
          for (final c in CategoryPalette.allColors) {
            final hsl = HSLColor.fromColor(c);
            var delta = (hsl.hue - semanticHue).abs();
            if (delta > 180) delta = 360 - delta;
            final collides = delta < 20 && hsl.saturation > 0.45;
            expect(collides, isFalse,
                reason: '$c sits ${delta.toStringAsFixed(0)}deg from the '
                    '${b.name} semantic colour $semantic at saturation '
                    '${hsl.saturation.toStringAsFixed(2)}');
          }
        }
      }
    });

    test('expense hues are distinct enough to be scannable', () {
      // The previous palette gave Shopping and Grocery the same emerald, and
      // Education/Bills/Utilities the same indigo, which defeats the point of
      // a per-category colour. Allow reuse only where it is intentional.
      final counts = <Color, int>{};
      for (final c in CategoryPalette.expenseColors.values) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
      final overused = counts.entries.where((e) => e.value > 2).toList();
      expect(overused, isEmpty,
          reason: 'a hue used 3+ times across expense categories: $overused');
    });
  });
}
