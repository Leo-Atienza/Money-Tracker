import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FIX Phase 2.7 — structural guard against direct `NotificationHelper()`
/// instantiations in screens or widgets.
///
/// `NotificationHelper` is a singleton (factory ctor in
/// `lib/utils/notification_helper.dart`) so a direct call always returns the
/// same instance. The problem is *testability*: when a screen calls
/// `NotificationHelper()` we can't swap it for a mock in widget tests.
///
/// Rule: screens and widgets dispatch via `context.read<AppState>().notificationHelper`.
/// The only files allowed to call `NotificationHelper()` directly are the
/// bootstrap (`lib/main.dart`) and the singleton's owner (`AppState`).
///
/// Phase 7 will add a `FakeAppState` test helper that lets widget tests inject
/// a mock helper. This lint keeps the door open.
void main() {
  /// Files allowed to instantiate `NotificationHelper()` directly.
  const allowlistedFiles = <String>{
    // Bootstrap — runs before AppState exists.
    'lib/main.dart',
    // Owns the singleton field.
    'lib/providers/app_state.dart',
    // Internal factory definition.
    'lib/utils/notification_helper.dart',
  };

  test('no direct NotificationHelper() calls outside the allowlist', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: 'Run from repo root.');

    // Match `NotificationHelper(` (with optional whitespace before the paren)
    // but skip docstring and comment lines.
    final pattern = RegExp(r'(?<![A-Za-z0-9_])NotificationHelper\s*\(');
    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('.g.dart') ||
          entity.path.contains('.freezed.dart')) {
        continue;
      }
      final relPath = entity.path.replaceAll('\\', '/');
      if (allowlistedFiles.contains(relPath)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // Skip pure comment lines.
        if (line.startsWith('//') || line.startsWith('///')) continue;
        if (pattern.hasMatch(line)) {
          violations.add(
            '$relPath:${i + 1}: direct NotificationHelper() instantiation — '
            'use `context.read<AppState>().notificationHelper` instead.',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'NotificationHelper singleton violations:\n  ${violations.join('\n  ')}',
    );
  });
}
