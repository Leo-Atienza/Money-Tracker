import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracker/utils/crash_log.dart';

/// FIX Phase 3a: unit tests for [CrashLog].
///
/// Uses [CrashLog.directoryOverride] to redirect the rolling log into a
/// per-test temp directory so each test observes a clean slate without
/// stubbing out `path_provider`.
void main() {
  // CrashLog.init wires FlutterError.onError + PlatformDispatcher.onError.
  // The binding needs to exist before those handlers are touched in tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crash_log_test_');
    CrashLog.resetForTesting();
    CrashLog.directoryOverride = tempDir;
    await CrashLog.init(appVersion: 'test+0');
  });

  tearDown(() async {
    CrashLog.resetForTesting();
    // Windows sometimes holds file handles briefly after writes.
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup; leaking a temp dir is fine in CI.
    }
  });

  test('record writes a formatted entry to crash.log', () async {
    await CrashLog.record(
      Exception('boom'),
      stack: StackTrace.current,
      context: 'test',
    );
    final content = await CrashLog.readAll();
    expect(content, contains('Exception: boom'));
    expect(content, contains('Context: test'));
    expect(content, contains('App: FinanceFlow test+0'));
  });

  test('rotates when active file exceeds maxLogBytes', () async {
    // Each record carries a ~1KB stack; 300 records > 256KB → rotation.
    final bigStack = StackTrace.fromString('x' * 1024);
    for (int i = 0; i < 300; i++) {
      await CrashLog.record('err-$i', stack: bigStack, context: 'loop');
    }
    final files = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('crash.log'))
        .toList();
    expect(files.length, greaterThanOrEqualTo(2));
    expect(files.length, lessThanOrEqualTo(CrashLog.maxLogFiles));
  });

  test('readAll returns oldest first, newest last', () async {
    await CrashLog.record('first', context: 'a');
    await CrashLog.record('second', context: 'b');
    final content = await CrashLog.readAll();
    expect(content.indexOf('first'), lessThan(content.indexOf('second')));
  });

  test('clear deletes every rotation file', () async {
    await CrashLog.record('hello', context: 'a');
    await CrashLog.clear();
    final content = await CrashLog.readAll();
    expect(content.trim(), isEmpty);
  });

  // Phase 6.6: PII redactor coverage. Each test exercises one input class
  // end-to-end via `redactPii`, plus one integration test confirms the
  // formatter actually invokes the redactor when writing a record.

  group('PII redactor', () {
    test('masks Windows user paths but keeps the shape', () {
      const input =
          r'#0      _RootZone.runUnary (file:///C:/Users/jane.doe/AppData/dart-sdk/foo.dart:42:5)';
      final out = CrashLog.redactPii(input);
      expect(out, contains(r'C:/Users/[user]/AppData'));
      expect(out, isNot(contains('jane.doe')));
    });

    test('masks Unix /home and /Users paths', () {
      const input =
          '#0 main (file:///home/alice/code/app.dart) → /Users/bob/Library/logs';
      final out = CrashLog.redactPii(input);
      expect(out, contains('/home/[user]/code'));
      expect(out, contains('/Users/[user]/Library'));
      expect(out, isNot(contains('alice')));
      expect(out, isNot(contains('bob')));
    });

    test('masks email addresses', () {
      const input = 'SQLError on user "foo+bar@example.co.uk" insertion';
      final out = CrashLog.redactPii(input);
      expect(out, contains('[email]'));
      expect(out, isNot(contains('@example.co.uk')));
    });

    test('masks currency-tagged amounts', () {
      const input = 'Balance overflow: \$1,234.56 + €99.00 + £5 + ¥1000';
      final out = CrashLog.redactPii(input);
      expect(out, contains('[amount]'));
      expect(out, isNot(contains('1,234.56')));
      expect(out, isNot(contains('€99.00')));
    });

    test('masks credit card-shaped digit runs', () {
      const input = 'Bad description: card 4111-1111-1111-1111 was rejected';
      final out = CrashLog.redactPii(input);
      expect(out, contains('[cc]'));
      expect(out, isNot(contains('4111-1111-1111-1111')));
    });

    test('leaves plain digits and ids untouched', () {
      const input = 'expense id=12345 month=2026-05 row count=42';
      final out = CrashLog.redactPii(input);
      // Plain digits without currency / cc / path / email context are kept
      // verbatim so debugging stays useful.
      expect(out, equals(input));
    });

    test('returns empty string unchanged', () {
      expect(CrashLog.redactPii(''), equals(''));
    });

    test('record() persists the redacted form, not the raw', () async {
      await CrashLog.record(
        Exception(r'Failed to write C:\Users\leooa\app.db: \$500 overdrawn'),
        stack: StackTrace.fromString(
          r'#0 main (file:///C:/Users/leooa/code/main.dart:1:1)',
        ),
        context: 'restore_backup user=leo@example.com',
      );
      final content = await CrashLog.readAll();
      expect(content, isNot(contains('leooa')));
      expect(content, isNot(contains('leo@example.com')));
      expect(content, isNot(contains(r'$500')));
      expect(content, contains(r'C:\Users\[user]\app.db'));
      expect(content, contains('[email]'));
      expect(content, contains('[amount]'));
    });
  });
}
