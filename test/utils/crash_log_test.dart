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
    expect(content, contains('App: Money Tracker test+0'));
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
}
