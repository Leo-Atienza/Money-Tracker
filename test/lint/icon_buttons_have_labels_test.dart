import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S22 — every `IconButton` in lib/ names itself with `tooltip:`.
///
/// An icon has no text, so without a tooltip TalkBack announces it as an
/// unlabeled button. The device walk found six (sheet close buttons, the
/// Budgets month picker's year arrows, Settings' account options). Wrapping
/// the button in `Semantics(label:)` is not a substitute: it leaves a second,
/// unlabeled button node under the label. `AccessibilityHelper
/// .semanticIconButton(label:)` is the other accepted form (not matched here).
void main() {
  test('every IconButton in lib/ has a tooltip', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: 'Run from repo root.');

    // `IconButton(` not preceded by a letter, so `semanticIconButton(` and
    // other identifiers ending in IconButton are skipped.
    final start = RegExp(r'(?<![A-Za-z])IconButton\(');
    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in start.allMatches(source)) {
        // The constructor's argument list, up to its matching parenthesis.
        var depth = 1;
        var i = match.end;
        while (depth > 0 && i < source.length) {
          final c = source[i];
          if (c == '(') depth++;
          if (c == ')') depth--;
          i++;
        }
        if (!source.substring(match.start, i).contains('tooltip:')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          violations.add('${entity.path.replaceAll('\\', '/')}:${line + 1}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'IconButtons without a tooltip:\n  ${violations.join('\n  ')}',
    );
  });
}
