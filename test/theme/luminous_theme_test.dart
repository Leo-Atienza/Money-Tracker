import 'package:budget_tracker/theme/app_colors.dart';
import 'package:budget_tracker/theme/luminous_app_theme.dart';
import 'package:budget_tracker/utils/color_contrast_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Purple appearance is a pair of hand-built `ColorScheme`s (lavender by
/// day, violet at night), so nothing but these assertions keeps its ink
/// readable. They cover every ink role on every surface role the theme
/// actually paints, the places the chrome tints itself (nav pill, list-tile
/// icon well, the violet balance card), and — because `AppColors` is shared
/// with the neutral schemes — that violet surfaces do not make the money
/// colours harder to read than they already are on plain Light and Dark.
void main() {
  group('themeModeFor', () {
    test('light pins ThemeMode.light', () {
      expect(themeModeFor('light'), ThemeMode.light);
    });

    test('dark pins ThemeMode.dark', () {
      expect(themeModeFor('dark'), ThemeMode.dark);
    });

    test('purple follows the phone, like system', () {
      expect(themeModeFor('purple'), ThemeMode.system);
    });

    test('system and anything unrecognised follow the OS', () {
      expect(themeModeFor('system'), ThemeMode.system);
      expect(themeModeFor(''), ThemeMode.system);
      expect(themeModeFor('sepia'), ThemeMode.system);
    });
  });

  schemeSuite('luminousPurpleScheme', luminousPurpleScheme(),
      neutral: luminousLightScheme());
  schemeSuite('luminousPurpleDarkScheme', luminousPurpleDarkScheme(),
      neutral: luminousDarkScheme());

  for (final cs in [luminousPurpleScheme(), luminousPurpleDarkScheme()]) {
    group('buildLuminousTheme, tonal Purple (${cs.brightness.name})', () {
      final theme = buildLuminousTheme(
        brightness: cs.brightness,
        appColorsExtension: AppColors.fromBrightness(cs.brightness),
        colorScheme: cs,
        tonal: true,
      );
      final hero = theme.extension<LuminousHeroColors>()!;
      final status = AppColors.fromBrightness(cs.brightness);

      test('paints the scheme with the matching status-bar style', () {
        final dark = cs.brightness == Brightness.dark;
        expect(theme.brightness, cs.brightness);
        expect(theme.colorScheme.primary, cs.primary);
        expect(theme.scaffoldBackgroundColor, cs.surface);
        expect(theme.appBarTheme.backgroundColor, cs.surface);
        expect(
          theme.appBarTheme.systemOverlayStyle,
          dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );
      });

      test('keeps the single typeface and the semantic colour extension', () {
        expect(theme.textTheme.bodyMedium?.fontFamily, 'HankenGrotesk');
        expect(theme.textTheme.labelSmall?.fontFamily, 'HankenGrotesk');
        expect(theme.extension<AppColors>(), isNotNull);
      });

      test('the nav pill is primaryContainer with its own ink', () {
        final nav = theme.navigationBarTheme;
        expect(nav.indicatorColor, cs.primaryContainer);
        final selected = nav.iconTheme!.resolve({WidgetState.selected})!;
        expect(selected.color, cs.onPrimaryContainer);
        expect(
          ColorContrastHelper.contrastRatio(
              selected.color!, cs.primaryContainer),
          greaterThanOrEqualTo(ColorContrastHelper.minContrastLargeText),
        );
      });

      test('the balance card is violet and its text clears 4.5:1', () {
        expect(hero.fill, cs.primaryContainer);
        for (final ink in {'ink': hero.ink, 'inkVariant': hero.inkVariant}
            .entries) {
          final ratio = ColorContrastHelper.contrastRatio(ink.value, hero.fill!);
          expect(
            ratio,
            greaterThanOrEqualTo(ColorContrastHelper.minContrastNormalText),
            reason: '${ink.key}: ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('a carried-over amount, either sign, clears 3:1 on the card', () {
        // _CarryoverLine prints the signed amount in income green or, when
        // negative, expense red, straight on the balance card.
        for (final c in {
          'incomeGreen': status.incomeGreen,
          'expenseRed': status.expenseRed,
        }.entries) {
          final ratio = ColorContrastHelper.contrastRatio(c.value, hero.fill!);
          expect(
            ratio,
            greaterThanOrEqualTo(ColorContrastHelper.minContrastLargeText),
            reason: '${c.key}: ${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('refuses a scheme whose brightness disagrees', () {
        final other = cs.brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
        expect(
          () => buildLuminousTheme(
            brightness: other,
            appColorsExtension: AppColors.fromBrightness(other),
            colorScheme: cs,
          ),
          throwsAssertionError,
        );
      });
    });
  }

  group('buildLuminousTheme without overrides', () {
    final light = buildLuminousTheme(
      brightness: Brightness.light,
      appColorsExtension: AppColors.fromBrightness(Brightness.light),
    );
    final dark = buildLuminousTheme(
      brightness: Brightness.dark,
      appColorsExtension: AppColors.fromBrightness(Brightness.dark),
    );

    test('the neutral schemes are unchanged', () {
      expect(light.colorScheme.primary, luminousLightScheme().primary);
      expect(light.colorScheme.surface, luminousLightScheme().surface);
      expect(dark.colorScheme.primary, luminousDarkScheme().primary);
      expect(dark.colorScheme.surface, luminousDarkScheme().surface);
    });

    test('the balance card stays a plain card and the pill a primary wash',
        () {
      for (final (theme, alpha) in [(light, 0.14), (dark, 0.30)]) {
        final cs = theme.colorScheme;
        final hero = theme.extension<LuminousHeroColors>()!;
        expect(hero.fill, isNull);
        expect(hero.border, isNull);
        expect(hero.ink, cs.onSurface);
        expect(hero.inkVariant, cs.onSurfaceVariant);
        expect(theme.navigationBarTheme.indicatorColor,
            cs.primary.withValues(alpha: alpha));
      }
    });
  });
}

/// Contrast floors for a hand-built Purple scheme, checked against the
/// neutral scheme of the same brightness ([neutral]) where the semantic
/// colours are shared.
void schemeSuite(String name, ColorScheme cs, {required ColorScheme neutral}) {
  final dark = cs.brightness == Brightness.dark;

  group(name, () {
    final surfaces = <String, Color>{
      'surface': cs.surface,
      'surfaceContainerLowest': cs.surfaceContainerLowest,
      'surfaceContainerLow': cs.surfaceContainerLow,
      'surfaceContainer': cs.surfaceContainer,
      'surfaceContainerHigh': cs.surfaceContainerHigh,
      'surfaceContainerHighest': cs.surfaceContainerHighest,
    };

    test('matches the neutral scheme it stands in for', () {
      expect(cs.brightness, neutral.brightness);
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

    test('primary still reads as an icon in a list-tile well', () {
      // GlassListTile paints its icon well as primary at 12% (18% at night)
      // over the card. Color.lerp(bg, fg, a) is exactly what compositing fg
      // at alpha a over bg produces.
      final card = dark ? cs.surfaceContainerHigh : cs.surfaceContainer;
      final iconWell = Color.lerp(card, cs.primary, dark ? 0.18 : 0.12)!;
      expect(
        ColorContrastHelper.contrastRatio(cs.primary, iconWell),
        greaterThanOrEqualTo(ColorContrastHelper.minContrastLargeText),
      );
    });

    test('the card is visibly distinct from the page', () {
      // A card that matches the page is the failure glass hid for a while.
      // GlassPanel fills with surfaceContainer by day and surfaceContainerHigh
      // at night; the neutral schemes keep at least ~1.11:1 there.
      final card = dark ? cs.surfaceContainerHigh : cs.surfaceContainer;
      expect(
        ColorContrastHelper.contrastRatio(card, cs.surface),
        greaterThanOrEqualTo(1.1),
      );
    });

    test('money colours keep the floor they have on the neutral scheme', () {
      // AppColors is the same set for both appearances of a brightness, so
      // the only way Purple can regress an amount's legibility is through its
      // surfaces. Hold each colour to within 10% of the ratio it gets on the
      // matching neutral role, and to the 3:1 large/bold-text floor on the
      // roles amounts actually render on.
      final status = AppColors.fromBrightness(cs.brightness);
      final colours = <String, Color>{
        'incomeGreen': status.incomeGreen,
        'expenseRed': status.expenseRed,
        'infoBlue': status.infoBlue,
        'warningOrange': status.warningOrange,
      };
      final roles = <String, (Color, Color)>{
        'surface': (neutral.surface, cs.surface),
        'surfaceContainerLow': (
          neutral.surfaceContainerLow,
          cs.surfaceContainerLow
        ),
        'surfaceContainer': (neutral.surfaceContainer, cs.surfaceContainer),
        'surfaceContainerHigh': (
          neutral.surfaceContainerHigh,
          cs.surfaceContainerHigh
        ),
        'surfaceContainerHighest': (
          neutral.surfaceContainerHighest,
          cs.surfaceContainerHighest
        ),
      };
      for (final c in colours.entries) {
        for (final r in roles.entries) {
          final onNeutral =
              ColorContrastHelper.contrastRatio(c.value, r.value.$1);
          final onPurple =
              ColorContrastHelper.contrastRatio(c.value, r.value.$2);
          expect(
            onPurple,
            greaterThanOrEqualTo(onNeutral * 0.9),
            reason: '${c.key} on ${r.key}: neutral '
                '${onNeutral.toStringAsFixed(2)} vs purple '
                '${onPurple.toStringAsFixed(2)}',
          );
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
}
