import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FIX Phase 1.7 — performance guardrails on the Luminous shell.
///
/// 25-sigma `BackdropFilter` measured ~14ms/frame per tile on Pixel 4a.
/// The shell shows 3-4 glass surfaces simultaneously (header card,
/// transactions panel, summary tiles, nav bar), so we'd blow the 16.7ms
/// 60fps budget. We compromise on 15 — documented in
/// `docs/DESIGN_DEVIATIONS.md`. This test pins the value so a future
/// "let me bump this back to 25" doesn't slip through review.
///
/// We also assert the nav bar and the home-screen transactions panel
/// each sit inside a `RepaintBoundary`, isolating their `BackdropFilter`
/// repaints from the rest of the scene.
void main() {
  test('LuminousTokens.blurSigma stays at 15 (Phase 1.7 perf gate)', () {
    // Phase 2.2 moved the token from luminous_app_theme.dart to
    // luminous_tokens.dart and renamed `glassBlurSigma` → `blurSigma`
    // (with a legacy alias kept for the same numeric value). The legacy
    // alias is asserted below as a separate guard.
    final src = File('lib/theme/luminous_tokens.dart').readAsStringSync();
    final match = RegExp(
      r'static\s+const\s+double\s+blurSigma\s*=\s*(\d+)',
    ).firstMatch(src);
    expect(match, isNotNull,
        reason: 'LuminousTokens.blurSigma declaration removed or renamed.');
    final value = int.parse(match!.group(1)!);
    expect(
      value,
      15,
      reason: 'blurSigma must be 15 (Phase 1.7). The design spec '
          'says 25 but real-hardware testing shows that blows the 60-fps '
          'frame budget on Pixel 4a class devices. See '
          'docs/DESIGN_DEVIATIONS.md → DD-001 before changing.',
    );
  });

  test('LuminousTokens.glassBlurSigma legacy alias still resolves to 15', () {
    // The legacy alias is kept so call sites that read `glassBlurSigma`
    // (added before the Phase 2.2 rename) keep working. Phase 5 will
    // sweep the call sites and let us drop the alias.
    final src = File('lib/theme/luminous_tokens.dart').readAsStringSync();
    expect(
      src.contains('static const double glassBlurSigma = blurSigma'),
      isTrue,
      reason: 'Legacy alias `glassBlurSigma = blurSigma` removed before '
          'Phase 5 swept call sites. Restore the alias or migrate the '
          'remaining call sites first.',
    );
  });

  test('FloatingGlassNavBar is wrapped in RepaintBoundary in main.dart',
      () {
    final src = File('lib/main.dart').readAsStringSync();
    // Look for `RepaintBoundary(\s*child: FloatingGlassNavBar(`
    final pattern = RegExp(
      r'RepaintBoundary\s*\(\s*[^)]*child:\s*FloatingGlassNavBar',
      multiLine: true,
    );
    expect(
      pattern.hasMatch(src),
      isTrue,
      reason: 'FloatingGlassNavBar must sit behind a RepaintBoundary '
          'so its BackdropFilter does not force the rest of the '
          'scaffold to repaint every frame. Phase 1.7.',
    );
  });

  test('home_screen transactions GlassPanel sits behind a RepaintBoundary',
      () {
    final src = File('lib/screens/home_screen.dart').readAsStringSync();
    final pattern = RegExp(
      r'RepaintBoundary\s*\(\s*[^)]*child:\s*GlassPanel',
      multiLine: true,
    );
    expect(
      pattern.hasMatch(src),
      isTrue,
      reason: 'The transactions GlassPanel on home_screen must sit '
          'behind a RepaintBoundary so unrelated header/header-summary '
          'rebuilds do not force a blur repaint. Phase 1.7.',
    );
  });
}
