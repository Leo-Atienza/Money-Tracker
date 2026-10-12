import 'dart:io';

import 'package:budget_tracker/database/database_helper.dart';
import 'package:budget_tracker/database/db_open.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '_test_helpers.dart';

/// `cleanOrphanedBackupFiles` (startup maintenance) runs in the background,
/// outside the AppState write mutex, so each directory sweep must tell a real
/// orphan from a file another operation is still producing:
///
/// - a backup's plaintext export of the encrypted database, which the backup
///   deletes itself unless it is killed mid-way;
/// - a deleted account's backup JSON, which `deleteAccount` writes BEFORE it
///   inserts the `deleted_accounts` row that registers it.
///
/// path_provider is pointed at a private temp directory so these sweeps cannot
/// race the shared `.dart_tool/test_path_provider` other test files use.
void main() {
  const pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ff_orphan_sweeps');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      pathProviderChannel,
      (_) async => tempDir.path,
    );
    await makeFreshDb();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await DatabaseHelper.resetForTesting();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  DateTime twoHoursAgo() => DateTime.now().subtract(const Duration(hours: 2));

  test('reaps a stale plaintext export and spares a fresh one', () async {
    final stale = File(p.join(tempDir.path, '${plaintextExportPrefix}1.db'));
    final fresh = File(p.join(tempDir.path, '${plaintextExportPrefix}2.db'));
    await stale.writeAsBytes(const <int>[1]);
    await fresh.writeAsBytes(const <int>[1]);
    await stale.setLastModified(twoHoursAgo());

    await DatabaseHelper().cleanOrphanedBackupFiles();

    expect(await stale.exists(), isFalse);
    expect(await fresh.exists(), isTrue);
  });

  test('spares a deleted-account backup that is not registered yet, reaps an '
      'old unregistered one, keeps a registered one', () async {
    final dir = Directory(p.join(tempDir.path, 'deleted_accounts'));
    await dir.create();
    final inFlight = File(p.join(dir.path, 'account_1_1.json'));
    final orphan = File(p.join(dir.path, 'account_2_2.json'));
    final registered = File(p.join(dir.path, 'account_3_3.json'));
    for (final f in [inFlight, orphan, registered]) {
      await f.writeAsString('{}');
    }
    await orphan.setLastModified(twoHoursAgo());
    await registered.setLastModified(twoHoursAgo());
    final db = await DatabaseHelper().database;
    await db.insert('deleted_accounts', {
      'original_id': 3,
      'name': 'Registered',
      'deletedAt': DateTime.now().toUtc().toIso8601String(),
      'data': registered.path,
    });

    await DatabaseHelper().cleanOrphanedBackupFiles();

    expect(await inFlight.exists(), isTrue,
        reason: 'deleteAccount registers its backup only after writing it');
    expect(await orphan.exists(), isFalse);
    expect(await registered.exists(), isTrue);
  });
}
