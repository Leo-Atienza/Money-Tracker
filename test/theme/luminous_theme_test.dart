import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/utils/color_contrast_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Purple appearance is a hand-built `ColorScheme`, so nothing but these
/// assertions keeps its ink readable. They cover every ink role on every
/// surface role the theme actually paints, the two places the chrome tints
/// itself with `primary` (nav indicator, list-tile icon well), and — because
/// `AppColors` is shared with the neutral light scheme — that lavender
/// surfaces do not make the money colours harder to read than they already
/// are on the plain light theme.
void main() {
  group('themeModeFor', () {
    test('light and purple both pin ThemeMode.light', () {
      expect(themeModeFor('light'), ThemeMode.light);
      expect(themeModeFor('purple'), ThemeMode.light);
    });

    test('dark pins ThemeMode.dark', () {
      expect(themeModeFor('dark'), ThemeMode.dark);
    });

    test('system and anything unrecognised follow the OS', () {
      expect(themeModeFor('system'), ThemeMode.system);
      expect(themeModeFor(''), ThemeMode.system);
      expect(themeModeFor('sepia'), ThemeMode.system);
    });
  });

  group('luminousPurpleScheme', () {
    final cs = luminousPurpleScheme();
    final surfaces = <String, Color>{
      'surface': cs.surface,
      'surfaceContainerLowest': cs.surfaceContainerLowest,
      'surfaceContainerLow': cs.surfaceContainerLow,
      'surfaceContainer': cs.surfaceContainer,
      'surfaceContainerHigh': cs.surfaceContainerHigh,
      'surfaceContainerHighest': cs.surfaceContainerHighest,
    };

    test('is a light-brightness scheme', () {
      expect(cs.brightness, Brightness.light);
    });

    test('text ink clears 4.5:1 on every surface role', () {
      final inks = <String, Color>{
        'onSurface': cs.onSurface,
        'onSurfaceVariant': cs.onSurfaceVariant,
        'primary': cs.primary,
        'error': cs.error,
      };
      final failures = <String>[];
      for (final s in surfaces.entries) {
        for (final ink in inks.entries) {
          final ratio = ColorContrastHelper.contrastRatio(ink.value, s.value);
          if (ratio < ColorContrastHelper.minContrastNormalText) {
            failures.add(
                '${ink.key} on ${s.key}: ${ratio.toStringAsFixed(2)}:1');
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join(', '));
    });

    test('outline clears the 3:1 non-text floor on every surface role', () {
      for (final s in surfaces.entries) {
        expect(
          ColorContrastHelper.contrastRatio(cs.outline, s.value),
          greaterThanOrEqualTo(ColorContrastHelper.minContrastLargeText),
          reason: 'outline on ${s.key}',
        );
      }
    });

    test('every on-colour clears 4.5:1 on its own container', () {
      final pairs = <String, (Color, Color)>{
        'onPrimary/primary': (cs.onPrimary, cs.primary),
        'onPrimaryContainer/primaryContainer': (
          cs.onPrimaryContainer,
          cs.primaryContainer
        ),
        'onSecondary/secondary': (cs.onSecondary, cs.secondary),
        'onSecondaryContainer/secondaryContainer': (
          cs.onSecondaryContainer,
          cs.secondaryContainer
        ),
        'onTertiary/tertiary': (cs.onTertiary, cs.tertiary),
        'onTertiaryContainer/tertiaryContainer': (
          cs.onTertiaryContainer,
          cs.tertiaryContainer
        ),
        'onError/error': (cs.onError, cs.error),
        'onErrorContainer/errorContainer': (
          cs.onErrorContainer,
          cs.errorContainer
        ),
        'onInverseSurface/inverseSurface': (
          cs.onInverseSurface,
          cs.inverseSurface
        ),
        'inversePrimary/inverseSurface': (cs.inversePrimary, cs.inverseSurface),
      };
      for (final p in pairs.entries) {
        expect(
          ColorContrastHelper.meetsAA(p.value.$1, p.value.$2),
          isTrue,
          reason: '${p.key}: '
              '${ColorContrastHelper.contrastRatio(p.value.$1, p.value.$2).toStringAsFixed(2)}:1',
        );
      }
    });

    test('primary still reads as an icon on its own tints', () {
      // navigationBarTheme paints the indicator as primary at 14% over the
      // surface; GlassListTile paints its icon well as primary at 12% over the
      // card. Color.lerp(bg, fg, a) is exactly what compositing fg at alpha a
      // over bg produces.
      final indicator = Color.lerp(cs.surface, cs.primary, 0.14)!;
      final iconWell = Color.lerp(cs.surfaceContainer, cs.primary, 0.12)!;
      expect(
        ColorContrastHelper.contrastRatio(cs.primary, indicator),
        greaterThanOrEqualTo(ColorContrastHelper.minContrastLargeText),
      );
      expect(
        ColorContrastHelper.contrastRatio(cs.primary, iconWell),
        greaterThanOrEqualTo(ColorContrastHelper.minContrastLargeText),
      );
    });

    test('the card is visibly distinct from the page', () {
      // A card that matches the page is the failure glass hid for a while;
      // the neutral light scheme keeps ~1.11:1 between the two, so hold the
      // lavender pair to the same.
      expect(
        ColorContrastHelper.contrastRatio(cs.surfaceContainer, cs.surface),
        greaterThanOrEqualTo(1.1),
      );
    });

    test('money colours keep the floor they have on the neutral light scheme',
        () {
      // AppColors is the light set for both appearances, so the only way
      // Purple can regress an amount's legibility is through its surfaces.
      // Hold each colour to within 10% of the ratio it gets on the matching
      // neutral light role, and to the 3:1 large/bold-text floor on the
      // roles amounts actually render on.
      final status = AppColors.fromBrightness(Brightness.light);
      final light = luminousLightScheme();
      final colours = <String, Color>{
        'incomeGreen': status.incomeGreen,
        'expenseRed': status.expenseRed,
        'infoBlue': status.infoBlue,
        'warningOrange': status.warningOrange,
      };
      final roles = <String, (Color, Color)>{
        'surface': (light.surface, cs.surface),
        'surfaceContainerLow': (
          light.surfaceContainerLow,
          cs.surfaceContainerLow
        ),
        'surfaceContainer': (light.surfaceContainer, cs.surfaceContainer),
        'surfaceContainerHighest': (
          light.surfaceContainerHighest,
          cs.surfaceContainerHighest
        ),
      };
      for (final c in colours.entries) {
        for (final r in roles.entries) {
          final onLight = ColorContrastHelper.contrastRatio(c.value, r.value.$1);
          final onPurple =
              ColorContrastHelper.contrastRatio(c.value, r.value.$2);
          expect(
            onPurple,
            greaterThanOrEqualTo(onLight * 0.9),
            reason: '${c.key} on ${r.key}: light ${onLight.toStringAsFixed(2)}'
                ' vs purple ${onPurple.toStringAsFixed(2)}',
          );
        }
      }
      // All four clear the 3:1 floor on every surface an amount, tag or tier
      // renders on - in Light and in Purple.
      for (final c in colours.entries) {
        for (final r in roles.entries) {
          for (final surface in [r.value.$1, r.value.$2]) {
            expect(
              ColorContrastHelper.contrastRatio(c.value, surface),
              greaterThanOrEqualTo(ColorContrastHelper.minContrastLargeText),
              reason: '${c.key} on ${r.key} $surface',
            );
          }
        }
      }
    });
  });

  group('buildLuminousTheme with the purple scheme', () {
    final purple = buildLuminousTheme(
      brightness: Brightness.light,
      appColorsExtension: AppColors.fromBrightness(Brightness.light),
      colorScheme: luminousPurpleScheme(),
    );

    test('paints the lavender scheme with light-brightness status bar', () {
      expect(purple.brightness, Brightness.light);
      expect(purple.colorScheme.primary, luminousPurpleScheme().primary);
      expect(purple.scaffoldBackgroundColor, luminousPurpleScheme().surface);
      expect(purple.appBarTheme.backgroundColor, luminousPurpleScheme().surface);
      expect(purple.appBarTheme.systemOverlayStyle, SystemUiOverlayStyle.dark);
    });

    test('keeps the single typeface and the semantic colour extension', () {
      expect(purple.textTheme.bodyMedium?.fontFamily, 'HankenGrotesk');
      expect(purple.textTheme.labelSmall?.fontFamily, 'HankenGrotesk');
      expect(purple.extension<AppColors>(), isNotNull);
    });

    test('refuses a scheme whose brightness disagrees', () {
      expect(
        () => buildLuminousTheme(
          brightness: Brightness.dark,
          appColorsExtension: AppColors.fromBrightness(Brightness.dark),
          colorScheme: luminousPurpleScheme(),
        ),
        throwsAssertionError,
      );
    });

    test('without an override the neutral schemes are unchanged', () {
      final light = buildLuminousTheme(
        brightness: Brightness.light,
        appColorsExtension: AppColors.fromBrightness(Brightness.light),
      );
      final dark = buildLuminousTheme(
        brightness: Brightness.dark,
        appColorsExtension: AppColors.fromBrightness(Brightness.dark),
      );
      expect(light.colorScheme.primary, luminousLightScheme().primary);
      expect(light.colorScheme.surface, luminousLightScheme().surface);
      expect(dark.colorScheme.primary, luminousDarkScheme().primary);
      expect(dark.colorScheme.surface, luminousDarkScheme().surface);
    });
  });
}
