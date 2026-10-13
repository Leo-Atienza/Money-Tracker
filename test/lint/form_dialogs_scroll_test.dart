import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// S22 — an `AlertDialog` with a text field must be able to scroll.
///
/// The keyboard takes about a third of the screen while a field has focus.
/// The category dialog ran 22px past its bottom on a 411x914dp phone once an
/// error showed under the field. `scrollable: true` (or content wrapped in a
/// `SingleChildScrollView`) lets the dialog shrink without overflowing.
void main() {
  test('every AlertDialog with a text field can scroll', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: 'Run from repo root.');

    final start = RegExp(r'(?<![A-Za-z])AlertDialog\(');
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
        final body = source.substring(match.start, i);
        final hasField =
            body.contains('TextField(') || body.contains('TextFormField(');
        final scrolls = body.contains('scrollable: true') ||
            body.contains('SingleChildScrollView(');
        if (hasField && !scrolls) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          violations.add('${entity.path.replaceAll('\\', '/')}:${line + 1}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Form dialogs that cannot scroll:\n  ${violations.join('\n  ')}',
    );
  });
}
