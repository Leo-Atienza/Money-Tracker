import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S22 (Leo's call) — SnackBars are plain M3: the theme's inverse surface
/// with its own ink, no green/red status fill.
///
/// The fills put light text on incomeGreen/expenseRed at 3.6–4.4:1 (under
/// the 4.5:1 floor for body text); the message already says what happened.
void main() {
  test('no SnackBar sets its own background colour', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: 'Run from repo root.');

    final start = RegExp(r'(?<![A-Za-z])SnackBar\(');
    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in start.allMatches(source)) {
        var depth = 1;
        var i = match.end;
        while (depth > 0 && i < source.length) {
          final c = source[i];
          if (c == '(') depth++;
          if (c == ')') depth--;
          i++;
        }
        // Any fill, not only the named status colours: one screen passed
        // expenseRed through a local `errorColor`.
        if (source.substring(match.start, i).contains('backgroundColor:')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          violations.add('${entity.path.replaceAll('\\', '/')}:${line + 1}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'SnackBars with their own fill:\n  ${violations.join('\n  ')}',
    );
  });
}
