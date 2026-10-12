import 'dart:io';
import 'dart:typed_data';

import 'package:budget_tracker/database/db_open.dart';
import 'package:budget_tracker/utils/crash_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Phase 6.1 — the plaintext -> SQLCipher migration STATE MACHINE.
///
/// SQLCipher itself can't run on the Windows test runner (no prebuilt cipher
/// `sqlite3.dll`), so [maybeMigrateToEncrypted] takes injectable export/verify
/// seams. These tests stub them to prove the fail-safe orchestration: the
/// plaintext database is replaced ONLY after a verified encrypted copy, and on
/// any failure the original is left untouched. The real cipher is covered by
/// on-device verification.
///
/// Also the guards around it: an encrypted file is never opened as plaintext,
/// and the plaintext copies (the migration's recovery copy, a backup's export)
/// are deleted only once they are provably no longer needed.
void main() {
  // SQLite plaintext magic header: "SQLite format 3\0".
  final magic = Uint8List.fromList(<int>[
    0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, //
    0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
  ]);

  late Directory tmp;
  late String dbPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ff_sqlcipher_test');
    dbPath = p.join(tmp.path, 'expense_tracker_v4.db');
    CrashLog.directoryOverride = tmp;
  });

  tearDown(() async {
    CrashLog.resetForTesting();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> writePlaintextDb() async {
    final bytes = Uint8List(64);
    bytes.setRange(0, 16, magic);
    await File(dbPath).writeAsBytes(bytes);
  }

  Uint8List encryptedBytes() =>
      Uint8List.fromList(List<int>.generate(48, (i) => 200 + (i % 50)));

  test('no-op when the database file is absent (fresh install)', () async {
    var exportCalled = false;
    await maybeMigrateToEncrypted(
      dbPath: dbPath,
      password: 'pw',
      exportFn: ({required source, required dest, required password}) async {
        exportCalled = true;
        return 0;
      },
      verifyFn: ({required dbPath, required password}) async => 0,
    );
    expect(exportCalled, isFalse);
    expect(await File(dbPath).exists(), isFalse);
  });

  test('no-op when the file is already encrypted (no magic header)', () async {
    await File(dbPath).writeAsBytes(encryptedBytes());
    var exportCalled = false;
    await maybeMigrateToEncrypted(
      dbPath: dbPath,
      password: 'pw',
      exportFn: ({required source, required dest, required password}) async {
        exportCalled = true;
        return 0;
      },
      verifyFn: ({required dbPath, required password}) async => 0,
    );
    expect(exportCalled, isFalse);
    // Untouched.
    expect(await File(dbPath).readAsBytes(), encryptedBytes());
  });

  test('successful migration swaps in the encrypted file, keeps the recovery '
      'backup, removes the temp', () async {
    await writePlaintextDb();
    final enc = encryptedBytes();

    await maybeMigrateToEncrypted(
      dbPath: dbPath,
      password: 'pw',
      exportFn: ({required source, required dest, required password}) async {
        expect(source, dbPath);
        await File(dest).writeAsBytes(enc);
        return 5;
      },
      verifyFn: ({required dbPath, required password}) async => 5,
    );

    expect(await File(dbPath).readAsBytes(), enc);
    expect(await File('$dbPath.pre-sqlcipher-backup').exists(), isTrue);
    expect(await File('$dbPath.sqlcipher-tmp').exists(), isFalse);
  });

  test('row-count mismatch aborts and keeps the plaintext intact', () async {
    await writePlaintextDb();
    final original = await File(dbPath).readAsBytes();

    await expectLater(
      maybeMigrateToEncrypted(
        dbPath: dbPath,
        password: 'pw',
        exportFn: ({required source, required dest, required password}) async {
          await File(dest).writeAsBytes(Uint8List(32));
          return 5;
        },
        verifyFn: ({required dbPath, required password}) async => 4,
      ),
      throwsA(isA<StateError>()),
    );

    expect(await File(dbPath).readAsBytes(), original);
    expect(await File('$dbPath.sqlcipher-tmp').exists(), isFalse);
  });

  test('export failure aborts, cleans the partial temp, keeps the plaintext',
      () async {
    await writePlaintextDb();
    final original = await File(dbPath).readAsBytes();

    await expectLater(
      maybeMigrateToEncrypted(
        dbPath: dbPath,
        password: 'pw',
        exportFn: ({required source, required dest, required password}) async {
          await File(dest).writeAsBytes(Uint8List(8)); // partial write
          throw const FileSystemException('simulated disk full');
        },
        verifyFn: ({required dbPath, required password}) async => 0,
      ),
      throwsA(isA<FileSystemException>()),
    );

    expect(await File(dbPath).readAsBytes(), original);
    expect(await File('$dbPath.sqlcipher-tmp').exists(), isFalse);
  });

  test('a stale temp from a prior aborted attempt is cleared before re-export',
      () async {
    await writePlaintextDb();
    await File('$dbPath.sqlcipher-tmp').writeAsBytes(Uint8List.fromList([1, 2, 3]));

    await maybeMigrateToEncrypted(
      dbPath: dbPath,
      password: 'pw',
      exportFn: ({required source, required dest, required password}) async {
        // The stale temp must have been removed before the fresh export.
        expect(await File(dest).exists(), isFalse);
        await File(dest).writeAsBytes(encryptedBytes());
        return 1;
      },
      verifyFn: ({required dbPath, required password}) async => 1,
    );

    expect(await File(dbPath).readAsBytes(), encryptedBytes());
  });

  group('isEncryptedDatabaseFile', () {
    test('false when absent, empty, or plaintext', () async {
      expect(await isEncryptedDatabaseFile(dbPath), isFalse);
      expect(
        await isEncryptedDatabaseFile(p.join(tmp.path, 'gone', 'x.db')),
        isFalse,
        reason: 'a missing parent directory is absent too, not an error',
      );
      await File(dbPath).writeAsBytes(const <int>[]);
      expect(await isEncryptedDatabaseFile(dbPath), isFalse,
          reason: 'a 0-byte file is an empty database, not ciphertext');
      await writePlaintextDb();
      expect(await isEncryptedDatabaseFile(dbPath), isFalse);
    });

    test('true for a file without the SQLite magic', () async {
      await File(dbPath).writeAsBytes(encryptedBytes());
      expect(await isEncryptedDatabaseFile(dbPath), isTrue);
    });
  });

  test('openAppDatabase without a key refuses to open an encrypted file as '
      'plaintext and leaves it intact', () async {
    await File(dbPath).writeAsBytes(encryptedBytes());

    await expectLater(
      openAppDatabase(
        dbPath: dbPath,
        version: 1,
        onConfigure: (db) async {},
        onCreate: (db, version) async {},
        onUpgrade: (db, oldVersion, newVersion) async {},
        password: null,
      ),
      throwsA(isA<DatabaseKeyUnavailableException>()),
    );
    expect(await File(dbPath).readAsBytes(), encryptedBytes());
  });

  group('sweepPlaintextRecoveryCopy', () {
    late File copy;
    setUp(() {
      copy = File('$dbPath.pre-sqlcipher-backup');
    });

    test('deletes the copy once the encrypted file opens with the key',
        () async {
      await File(dbPath).writeAsBytes(encryptedBytes());
      await copy.writeAsBytes(magic);
      String? verifiedPath;
      String? verifiedPassword;

      await sweepPlaintextRecoveryCopy(
        dbPath: dbPath,
        password: 'pw',
        verifyFn: ({required dbPath, required password}) async {
          verifiedPath = dbPath;
          verifiedPassword = password;
          return 5;
        },
      );

      expect(verifiedPath, dbPath);
      expect(verifiedPassword, 'pw');
      expect(await copy.exists(), isFalse);
      expect(await File(dbPath).readAsBytes(), encryptedBytes());
    });

    test('keeps the copy when the encrypted file fails verification',
        () async {
      await File(dbPath).writeAsBytes(encryptedBytes());
      await copy.writeAsBytes(magic);

      await sweepPlaintextRecoveryCopy(
        dbPath: dbPath,
        password: 'wrong',
        verifyFn: ({required dbPath, required password}) async =>
            throw StateError('file is not a database'),
      );

      expect(await copy.exists(), isTrue);
    });

    test('keeps the copy while the live file is still plaintext', () async {
      await writePlaintextDb();
      await copy.writeAsBytes(magic);
      var verifyCalled = false;

      await sweepPlaintextRecoveryCopy(
        dbPath: dbPath,
        password: 'pw',
        verifyFn: ({required dbPath, required password}) async {
          verifyCalled = true;
          return 0;
        },
      );

      expect(verifyCalled, isFalse);
      expect(await copy.exists(), isTrue);
    });

    test('does nothing when there is no copy', () async {
      await File(dbPath).writeAsBytes(encryptedBytes());
      var verifyCalled = false;

      await sweepPlaintextRecoveryCopy(
        dbPath: dbPath,
        password: 'pw',
        verifyFn: ({required dbPath, required password}) async {
          verifyCalled = true;
          return 0;
        },
      );

      expect(verifyCalled, isFalse);
    });
  });

  group('deleteStalePlaintextExports', () {
    test('deletes stale exports and their journals, spares fresh exports and '
        'other files', () async {
      final stale = File(p.join(tmp.path, '${plaintextExportPrefix}1.db'));
      final staleJournal = File('${stale.path}-journal');
      final fresh = File(p.join(tmp.path, '${plaintextExportPrefix}2.db'));
      final other = File(dbPath);
      final old = DateTime.now().subtract(const Duration(hours: 2));
      for (final f in [stale, staleJournal, fresh, other]) {
        await f.writeAsBytes(magic);
      }
      for (final f in [stale, staleJournal, other]) {
        await f.setLastModified(old);
      }

      expect(await deleteStalePlaintextExports(tmp), 2);

      expect(await stale.exists(), isFalse);
      expect(await staleJournal.exists(), isFalse);
      expect(await fresh.exists(), isTrue);
      expect(await other.exists(), isTrue);
    });

    test('a missing directory is not an error', () async {
      final missing = Directory(p.join(tmp.path, 'missing'));
      expect(await deleteStalePlaintextExports(missing), 0);
    });
  });
}
