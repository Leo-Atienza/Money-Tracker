import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:budget_tracker/utils/backup_helper.dart';

/// L32/L36: the raw-.db restore path must read the incoming database's
/// `user_version` from its file header to reject a schema newer than this
/// build can handle. These tests lock the byte-offset-60 big-endian read.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('uv_test_');
  });

  tearDown(() async {
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<File> makeDbWithUserVersion(int version) async {
    final path = '${tmpDir.path}/uv_$version.db';
    final db = await databaseFactoryFfi.openDatabase(path);
    await db.execute('PRAGMA user_version = $version');
    // A table forces a real header + page to be written to disk.
    await db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    await db.close();
    return File(path);
  }

  test('reads user_version 0 from a freshly created database', () async {
    final file = await makeDbWithUserVersion(0);
    expect(await BackupHelper.readSqliteUserVersion(file), 0);
  });

  test('reads a small user_version', () async {
    final file = await makeDbWithUserVersion(19);
    expect(await BackupHelper.readSqliteUserVersion(file), 19);
  });

  test('reads a large multi-byte user_version', () async {
    final file = await makeDbWithUserVersion(1000000);
    expect(await BackupHelper.readSqliteUserVersion(file), 1000000);
  });

  test('returns null for a file too short to hold a SQLite header', () async {
    final f = File('${tmpDir.path}/tiny.bin');
    await f.writeAsBytes(List<int>.filled(16, 0));
    expect(await BackupHelper.readSqliteUserVersion(f), isNull);
  });
}
