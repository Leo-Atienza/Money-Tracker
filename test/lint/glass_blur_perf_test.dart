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
  test('LuminousTokens.glassBlurSigma stays at 15 (Phase 1.7 perf gate)',
      () {
    final src = File('lib/theme/luminous_app_theme.dart').readAsStringSync();
    final match = RegExp(r'glassBlurSigma\s*=\s*(\d+)').firstMatch(src);
    expect(match, isNotNull, reason: 'glassBlurSigma declaration removed?');
    final value = int.parse(match!.group(1)!);
    expect(
      value,
      15,
      reason: 'glassBlurSigma must be 15 (Phase 1.7). The design spec '
          'says 25 but real-hardware testing shows that blows the 60-fps '
          'frame budget on Pixel 4a class devices. See '
          'docs/DESIGN_DEVIATIONS.md → DD-001 before changing.',
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
