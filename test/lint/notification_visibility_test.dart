import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// FIX Phase 1.10 — every `AndroidNotificationDetails` in
/// `notification_helper.dart` must declare
/// `visibility: NotificationVisibility.private`.
///
/// **Bug.** Bill-reminder and budget-alert notifications carried the
/// description + dollar amount in the body. On a phone in "Show
/// notifications on lock screen" mode (the default), the amount was
/// readable by anyone glancing at the locked screen.
///
/// **Fix.** Set `visibility: NotificationVisibility.private` on every
/// channel's `AndroidNotificationDetails`. The OS then shows a
/// system-provided "Sensitive notification" placeholder on a secure
/// lock screen when the user picked "Hide sensitive content".
///
/// This test scans the file and fails if any `AndroidNotificationDetails`
/// block is missing the visibility declaration. Pre-fix all four
/// blocks lacked it; post-fix all four declare it.
void main() {
  test('every AndroidNotificationDetails sets visibility=private', () {
    final src = File('lib/utils/notification_helper.dart').readAsStringSync();

    // Find every `AndroidNotificationDetails(` block and read up to the
    // matching `)` (heuristic: we look for the next blank-line break
    // OR the next `iOS:` line which always follows the Android block).
    final blockPattern = RegExp(
      r'AndroidNotificationDetails\(([\s\S]*?)(?=\n\s*\)|\n\s*iOS:)',
      multiLine: true,
    );
    final blocks = blockPattern.allMatches(src).toList();
    expect(blocks, isNotEmpty,
        reason: 'No AndroidNotificationDetails found — file rearranged?');

    final violations = <String>[];
    for (final block in blocks) {
      final body = block.group(1)!;
      if (!body.contains('NotificationVisibility.private')) {
        // Grab a short identifier for the violation message.
        final firstLine = body.split('\n').take(2).join(' / ').trim();
        violations.add('Block missing visibility=private: $firstLine ...');
      }
    }
    expect(
      violations,
      isEmpty,
      reason: 'Every AndroidNotificationDetails block must set '
          'visibility: NotificationVisibility.private (Phase 1.10). '
          'Violations:\n  ${violations.join('\n  ')}',
    );
  });
}
