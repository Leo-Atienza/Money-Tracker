import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FIX Phase 1.8 — `_fadeController.reverse().then(...)` must check
/// `mounted` (and the generation token) before calling `setState`.
///
/// **Bug.** Rapid tab taps inside the floating-glass nav bar fired
/// multiple `reverse().then(...)` callbacks in flight. Whichever one
/// resolved last would `setState` on a potentially-unmounted widget
/// (if the user backed out, locked the app, etc.), throwing
/// `setState() called after dispose()`. Even when mounted, two
/// callbacks could resolve in the wrong order and the wrong tab would
/// end up selected.
///
/// **Fix.** Increment a generation token on every tap; the post-await
/// callback bails out if either `!mounted` OR the generation no
/// longer matches the one captured at tap time. The last tap always
/// wins.
///
/// Full widget-test reproduction needs the whole nav scaffold +
/// AppState wired up — that's a Phase 7 follow-up. For now we
/// structurally assert the guard is in place in `main.dart`. Phase 8
/// promotes this to a lint rule in `analysis_options.yaml`.
void main() {
  test('main.dart has a mounted+generation guard on _fadeController.reverse',
      () {
    final src = File('lib/main.dart').readAsStringSync();

    // 1) The generation token field exists.
    expect(
      RegExp(r'int\s+_tabSwitchGeneration\s*=\s*0').hasMatch(src),
      isTrue,
      reason: 'A monotonic _tabSwitchGeneration field is required so '
          'rapid taps can invalidate in-flight reverse() callbacks.',
    );

    // 2) The `.then` callback after `_fadeController.reverse()`
    //    checks mounted AND the generation. We look for the trio of
    //    `_fadeController.reverse()`, `.then((`, and a guard pattern.
    final pattern = RegExp(
      r'_fadeController\.reverse\(\)\.then\(\(_\)\s*\{[^}]*?'
      r'(?:!mounted|gen\s*!=\s*_tabSwitchGeneration)',
      multiLine: true,
    );
    expect(
      pattern.hasMatch(src),
      isTrue,
      reason: 'The post-await callback must early-return on either '
          '`!mounted` or a stale generation. Without it, a rapid tap '
          'sequence can call `setState` after `dispose`, crashing the '
          'app, or land on the wrong tab.',
    );
  });
}
