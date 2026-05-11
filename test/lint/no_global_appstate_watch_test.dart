import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FIX Phase 2.5 — structural guard against global `context.watch<AppState>()`.
///
/// `context.watch<AppState>()` registers a rebuild on EVERY `notifyListeners`,
/// including unrelated state changes (theme, currency, account switch). That
/// makes screens with heavy build methods — especially `history_screen` —
/// rebuild constantly, dropping frames during scroll.
///
/// Rule: every screen must use narrow `context.select<AppState, X>` calls or
/// wrap its rebuild surface in a `Selector`/`Consumer`. If a screen really
/// needs the entire AppState (e.g. it's the navigation root), add it to the
/// allowlist below with a one-line rationale.
///
/// Phase 5.6 will further tighten history_screen so each section selects only
/// its own slice. Once that lands, this test should keep new offenders out.
void main() {
  /// Files allowed to use `context.watch<AppState>()`.
  /// Add an entry here only with a clear reason — these files take the
  /// full-rebuild hit on every state change.
  const allowlistedFiles = <String>{
    // None at the moment. main.dart wires the Provider but doesn't watch it.
  };

  test('no context.watch<AppState>() in lib/screens or lib/widgets', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: 'Run from repo root.');

    final pattern = RegExp(r'context\.watch<AppState>\s*\(\s*\)');
    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('.g.dart') ||
          entity.path.contains('.freezed.dart')) {
        continue;
      }
      // Path normalisation for the allowlist (use forward slashes everywhere).
      final relPath = entity.path.replaceAll('\\', '/');
      if (allowlistedFiles.contains(relPath)) continue;

      final source = entity.readAsStringSync();
      if (pattern.hasMatch(source)) {
        violations.add(
          '$relPath: uses context.watch<AppState>() — replace with '
          'narrow context.select<AppState, X>() calls or a Selector. '
          'If this screen genuinely needs the whole AppState, add it to '
          'the allowlist in this test with a rationale.',
        );
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'AppState global-watch violations:\n  ${violations.join('\n  ')}',
    );
  });
}
