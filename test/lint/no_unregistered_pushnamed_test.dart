import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FIX Phase 1.3 — structural guard against unregistered named routes.
///
/// `Navigator.pushNamed(context, '/foo')` is a *runtime* lookup against
/// `MaterialApp.routes`. If '/foo' is not in that table the call
/// silently fails (or throws, depending on Flutter version). We had three
/// such cold-call sites — '/add_expense', '/add_income', '/budgets' —
/// any of which could break a critical user path the moment someone
/// reorganises the routes table.
///
/// Rule for this codebase: prefer typed `Navigator.push(... PremiumPageRoute)`
/// so the navigation target is statically checked by the compiler.
/// The only `pushNamed` calls allowed in `lib/` go to the routes that
/// `MaterialApp.routes` actually declares (today: '/home', '/onboarding',
/// '/budgets').
///
/// This test scans every `.dart` file under `lib/screens/` and `lib/widgets/`
/// (the surfaces that initiate navigation) and fails if it finds a
/// `Navigator.pushNamed(`. Phase 8.1 promotes this to a CI lint script.
void main() {
  /// Routes that ARE registered in `MaterialApp.routes` (see `lib/main.dart`).
  /// Adding/removing entries here must mirror that table.
  const allowlistedRoutes = <String>{
    '/home',
    '/onboarding',
    '/budgets',
  };

  /// Routes that we banned outright because they were never registered.
  /// Used to produce a sharper error message when a regression slips in.
  const knownBadRoutes = <String>{
    '/add_expense',
    '/add_income',
    '/add_payment',
  };

  test('no Navigator.pushNamed to unregistered routes in lib/', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: 'Run from repo root.');

    final pattern = RegExp(r"Navigator\.pushNamed\s*\(\s*[^,]+,\s*'([^']+)'");
    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Skip generated files.
      if (entity.path.contains('.g.dart') ||
          entity.path.contains('.freezed.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final route = match.group(1)!;
        if (knownBadRoutes.contains(route)) {
          violations.add(
            '${entity.path}: pushNamed to KNOWN-BAD route "$route" — '
            'this route is not registered and will fail at runtime. '
            'Use Navigator.push + PremiumPageRoute instead.',
          );
        } else if (!allowlistedRoutes.contains(route)) {
          violations.add(
            '${entity.path}: pushNamed to "$route" which is not in the '
            'allowlist {${allowlistedRoutes.join(', ')}}. Either register '
            'the route in MaterialApp.routes OR (preferred) use '
            'Navigator.push + PremiumPageRoute and add a typed import.',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Navigator.pushNamed violations:\n  ${violations.join('\n  ')}',
    );
  });
}
