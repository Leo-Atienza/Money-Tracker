import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

import '../utils/crash_log.dart';

/// Phase 6.1: at-rest database encryption seam.
///
/// All database opens funnel through [openAppDatabase]. On the platforms where
/// the SQLCipher native plugin exists ([cipherPlatform]) and a key is supplied,
/// it migrates an existing plaintext database to SQLCipher (fail-safe) and then
/// opens it encrypted. Everywhere else — notably the Windows/Linux test runner
/// driven by `sqflite_common_ffi`, or when no key could be persisted — it opens
/// through the standard `sqflite` factory exactly as before, so the existing
/// integration suite and desktop builds are untouched.
///
/// The real cipher cannot run on the desktop test runner (no prebuilt SQLCipher
/// `sqlite3.dll`), so the risky part — the migration state machine — is written
/// against injectable [CipherExportFn] / [CipherVerifyFn] seams and unit-tested
/// with stubs. The cipher itself is exercised by on-device verification.

/// Performs the plaintext -> encrypted export into [dest], returning the source
/// row count for post-migration verification. Throws on any failure.
typedef CipherExportFn = Future<int> Function({
  required String source,
  required String dest,
  required String password,
});

/// Opens [dbPath] WITH [password] and returns its row count, proving the
/// encrypted file is readable with the key. Throws if it cannot be decrypted.
typedef CipherVerifyFn = Future<int> Function({
  required String dbPath,
  required String password,
});

/// The database file is SQLCipher-encrypted, but no key that opens it is
/// available: the Keystore read failed, or the key is gone. Thrown instead of
/// minting a replacement key (it could never decrypt the existing file) and
/// instead of a plaintext open (on Android, sqflite treats the unreadable file
/// as corrupt and deletes it). The file is left untouched, so the open fails
/// into the app's load-error path and the next attempt retries.
class DatabaseKeyUnavailableException implements Exception {
  const DatabaseKeyUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'DatabaseKeyUnavailableException: $message';
}

/// The 16-byte magic prefixing every *plaintext* SQLite file:
/// `"SQLite format 3\0"`. A SQLCipher file's header is encrypted, so the
/// absence of this magic is how a still-plaintext database is detected.
const List<int> _sqliteMagic = <int>[
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, //
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
];

/// Suffix of the plaintext recovery copy [maybeMigrateToEncrypted] keeps beside
/// the database until [sweepPlaintextRecoveryCopy] proves it can go.
const String _recoveryCopySuffix = '.pre-sqlcipher-backup';

/// Filename prefix of the throwaway plaintext copies the backup paths export to
/// the temp directory ([exportPlaintextCopy]); [deleteStalePlaintextExports]
/// reaps any that a killed backup left behind.
const String plaintextExportPrefix = 'ff-backup-plaintext-';

/// Platforms carrying the `sqflite_sqlcipher` native plugin. Everything else
/// (the FFI test runner, Windows/Linux desktop) takes the plaintext path.
bool get cipherPlatform =>
    Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

/// Opens the application database, encrypting at rest when a [password] is
/// supplied on a [cipherPlatform]. Falls back to a plaintext open — never
/// losing data — on any migration failure.
///
/// Never opens an encrypted file as plaintext: that cannot work, and on Android
/// sqflite then treats the file as corrupt and DELETES it. With no key for an
/// encrypted file this throws [DatabaseKeyUnavailableException] instead.
Future<Database> openAppDatabase({
  required String dbPath,
  required int version,
  required OnDatabaseConfigureFn onConfigure,
  required OnDatabaseCreateFn onCreate,
  required OnDatabaseVersionChangeFn onUpgrade,
  required String? password,
}) async {
  Future<Database> openPlaintext() async {
    if (await isEncryptedDatabaseFile(dbPath)) {
      throw const DatabaseKeyUnavailableException(
        'the database is encrypted; refusing to open it as plaintext',
      );
    }
    return openDatabase(
      dbPath,
      version: version,
      onConfigure: onConfigure,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    );
  }

  // Plaintext path: tests/desktop FFI, or no key available.
  if (password == null || !cipherPlatform) {
    return openPlaintext();
  }

  // Encrypted path. Migrate an existing plaintext database first; on ANY
  // failure the original plaintext file is left intact (see
  // [maybeMigrateToEncrypted]), so fall back to a plaintext open and retry the
  // migration on the next launch rather than risk the user's data.
  try {
    await maybeMigrateToEncrypted(dbPath: dbPath, password: password);
  } catch (e, st) {
    await CrashLog.record(e, stack: st, context: 'sqlcipher_migration');
    return openPlaintext();
  }

  // Retire the plaintext recovery copy (this launch's migration or an earlier
  // one's) once the encrypted file proves it opens with the key.
  await sweepPlaintextRecoveryCopy(dbPath: dbPath, password: password);

  return cipher.openDatabase(
    dbPath,
    password: password,
    version: version,
    onConfigure: onConfigure,
    onCreate: onCreate,
    onUpgrade: onUpgrade,
  );
}

/// Migrates a plaintext database at [dbPath] to SQLCipher in place, keyed with
/// [password]. No-op when the file is absent (fresh install) or already
/// encrypted.
///
/// **Fail-safe invariant:** the plaintext file at [dbPath] is deleted/replaced
/// ONLY after an encrypted copy has been written AND re-opened with the key AND
/// verified to hold the same number of rows. On any error the original is
/// untouched and a `.pre-sqlcipher-backup` recovery copy remains on disk.
Future<void> maybeMigrateToEncrypted({
  required String dbPath,
  required String password,
  CipherExportFn? exportFn,
  CipherVerifyFn? verifyFn,
}) async {
  final export = exportFn ?? _sqlcipherExport;
  final verify = verifyFn ?? _sqlcipherVerify;

  final file = File(dbPath);
  if (!await _isPlaintextSqlite(file)) return; // absent or already encrypted

  final backupPath = '$dbPath$_recoveryCopySuffix';
  final tmpPath = '$dbPath.sqlcipher-tmp';
  final tmp = File(tmpPath);

  try {
    // 1. Last-resort plaintext recovery copy (survives a crash mid-swap).
    await file.copy(backupPath);

    // 2. Clear any half-written temp from a previously aborted attempt.
    if (await tmp.exists()) await tmp.delete();
    await _deleteSidecars(tmpPath);

    // 3. Export plaintext -> encrypted temp; capture the source row count.
    final exportedRows =
        await export(source: dbPath, dest: tmpPath, password: password);

    // 4. Prove the encrypted temp opens with the key and matches row counts.
    final verifiedRows = await verify(dbPath: tmpPath, password: password);
    if (verifiedRows != exportedRows) {
      throw StateError(
        'SQLCipher migration row-count mismatch: '
        'exported $exportedRows, verified $verifiedRows',
      );
    }

    // 5. Swap. Clear the plaintext's stale journals first so SQLite cannot
    //    replay them against the encrypted file, then move the temp into place.
    //    On POSIX (Android/iOS/macOS) rename-onto-existing replaces atomically,
    //    leaving no window where the live path is missing. Windows (tests only)
    //    cannot do that, so delete-then-rename there.
    await _deleteSidecars(dbPath);
    try {
      await tmp.rename(dbPath);
    } on FileSystemException {
      if (await file.exists()) await file.delete();
      await tmp.rename(dbPath);
    }
    // `.pre-sqlcipher-backup` is intentionally left on disk as the recovery
    // copy; [sweepPlaintextRecoveryCopy] deletes it once the swapped-in file is
    // proven to open with the key.
  } catch (_) {
    // Fail-safe: dbPath is still the intact plaintext (only deleted post-verify
    // above). Drop the temp and rethrow so the caller opens plaintext.
    try {
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {}
    try {
      await _deleteSidecars(tmpPath);
    } catch (_) {}
    rethrow;
  }
}

/// Deletes the plaintext `.pre-sqlcipher-backup` [maybeMigrateToEncrypted]
/// leaves beside [dbPath] (this launch's, or one an earlier build left behind)
/// once the database is proven encrypted: the file at [dbPath] must be
/// ciphertext that opens with [password] and passes `integrity_check`. Until
/// then the copy is the only readable recovery path and stays; after that it is
/// a full plaintext copy of the database defeating at-rest encryption. Never
/// throws; a copy it could not prove or delete is retried on the next open.
Future<void> sweepPlaintextRecoveryCopy({
  required String dbPath,
  required String password,
  CipherVerifyFn? verifyFn,
}) async {
  final copy = File('$dbPath$_recoveryCopySuffix');
  try {
    if (!await copy.exists() || !await isEncryptedDatabaseFile(dbPath)) return;
    await (verifyFn ?? _sqlcipherVerify)(dbPath: dbPath, password: password);
    await copy.delete();
  } catch (e, st) {
    await CrashLog.record(e, stack: st, context: 'sqlcipher_recovery_copy');
  }
}

/// True when the file at [dbPath] exists and is NOT a plaintext SQLite file —
/// i.e. it is SQLCipher-encrypted. Lets the backup paths decide whether a
/// plaintext export is needed before embedding the raw database bytes, and
/// gates what would destroy an encrypted file (a new key, a plaintext open).
/// A file shorter than the 16-byte header (0 bytes when an open was killed
/// before its first write) holds no database yet, so it does not count.
Future<bool> isEncryptedDatabaseFile(String dbPath) async {
  final header = await _readHeader(File(dbPath));
  if (header == null || header.length < _sqliteMagic.length) return false;
  return !_hasSqliteMagic(header);
}

/// Writes a plaintext copy of the encrypted database at [dbPath] to [dest],
/// keyed with [password]. Used by the backup paths so `.etbackup` files (which
/// embed the raw database bytes) stay portable across devices instead of
/// carrying ciphertext that only this device's Keystore key could open.
Future<void> exportPlaintextCopy({
  required String dbPath,
  required String password,
  required String dest,
}) async {
  final destFile = File(dest);
  if (await destFile.exists()) await destFile.delete();
  await _deleteSidecars(dest);

  final src = await cipher.openDatabase(
    dbPath,
    password: password,
    singleInstance: false,
  );
  try {
    final userVersion = await _userVersion(src);
    // KEY '' produces a *plaintext* attached database.
    await src.execute("ATTACH DATABASE ? AS plaintext KEY ''", <Object?>[dest]);
    await src.rawQuery("SELECT sqlcipher_export('plaintext')");
    await src.execute('PRAGMA plaintext.user_version = $userVersion');
    await src.execute('DETACH DATABASE plaintext');
  } finally {
    await src.close();
  }
}

/// Deletes plaintext backup exports ([plaintextExportPrefix], journals
/// included) in [dir] last modified more than [maxAge] ago: each is an
/// unencrypted copy of the whole database that a backup killed mid-way never
/// cleaned up. The age gate spares the export of a backup running right now.
/// Returns how many files were deleted; never throws.
Future<int> deleteStalePlaintextExports(
  Directory dir, {
  Duration maxAge = const Duration(hours: 1),
}) async {
  final cutoff = DateTime.now().subtract(maxAge);
  var deleted = 0;
  try {
    await for (final entity in dir.list()) {
      if (entity is! File ||
          !p.basename(entity.path).startsWith(plaintextExportPrefix)) {
        continue;
      }
      if ((await entity.stat()).modified.isBefore(cutoff)) {
        await entity.delete();
        deleted++;
      }
    }
  } catch (e, st) {
    await CrashLog.record(e, stack: st, context: 'plaintext_export_sweep');
  }
  return deleted;
}

// --- production cipher operations (device-only; never run on the test runner)

Future<int> _sqlcipherExport({
  required String source,
  required String dest,
  required String password,
}) async {
  // Open the *encrypted* target as `main` (a fresh keyed database the plugin
  // creates cleanly), then pull the plaintext source in via an ATTACH with an
  // empty key. Opening the plaintext file directly as the cipher `main`
  // connection is unreliable — SQLCipher applies a key to it and the
  // connection dies on the first read — so keep `main` encrypted and the
  // plaintext merely ATTACHed (`KEY ''` is SQLCipher's explicit plaintext
  // marker). `singleInstance: false` keeps this transient maintenance
  // connection out of sqflite's path cache, isolated from the app's open.
  final db = await cipher.openDatabase(
    dest,
    password: password,
    singleInstance: false,
  );
  try {
    await db.execute(
      "ATTACH DATABASE ? AS plaintext KEY ''",
      <Object?>[source],
    );
    // Copy the whole attached plaintext database into the encrypted `main`.
    await db.rawQuery("SELECT sqlcipher_export('main', 'plaintext')");
    // Count the *source* (attached plaintext) rows for the caller's
    // post-migration verification.
    final srcCount = await _totalRowCount(db, schema: 'plaintext');
    // Carry the schema version across so the subsequent keyed open does not
    // re-run onCreate/onUpgrade against the already-populated schema.
    final userVersion = await _userVersion(db, schema: 'plaintext');
    await db.execute('PRAGMA user_version = $userVersion');
    await db.execute('DETACH DATABASE plaintext');
    return srcCount;
  } finally {
    await db.close();
  }
}

Future<int> _sqlcipherVerify({
  required String dbPath,
  required String password,
}) async {
  final db = await cipher.openDatabase(
    dbPath,
    password: password,
    singleInstance: false,
  );
  try {
    final check = await db.rawQuery('PRAGMA integrity_check');
    final ok = check.isNotEmpty &&
        (check.first.values.first?.toString().toLowerCase() == 'ok');
    if (!ok) {
      throw StateError('integrity_check failed on the encrypted database');
    }
    // `await` matters: returning the bare future would run the `finally`
    // (db.close) before the count finished (unawaited_return_in_try_block).
    return await _totalRowCount(db);
  } finally {
    await db.close();
  }
}

/// Sum of `COUNT(*)` across every user table (excludes SQLite-internal
/// `sqlite_*` tables). Both sides of the migration count the same table set, so
/// `android_metadata` etc. cancel out.
Future<int> _totalRowCount(Database db, {String? schema}) async {
  final prefix = schema == null ? '' : '"$schema".';
  final tables = await db.rawQuery(
    "SELECT name FROM ${prefix}sqlite_master "
    "WHERE type='table' AND name NOT LIKE 'sqlite_%'",
  );
  if (tables.isEmpty) return 0;
  // Sum every table's COUNT(*) in a SINGLE statement. The cipher connection
  // proved fragile across a long sequence of per-table round-trips, so one
  // aggregate query (plus the table-list query) keeps the migration robust.
  final terms = tables
      .map((r) => '(SELECT COUNT(*) FROM $prefix"${r['name'] as String}")')
      .join(' + ');
  final result = await db.rawQuery('SELECT $terms AS total');
  return (result.first['total'] as int?) ?? 0;
}

Future<int> _userVersion(Database db, {String? schema}) async {
  final prefix = schema == null ? '' : '$schema.';
  final rows = await db.rawQuery('PRAGMA ${prefix}user_version');
  if (rows.isEmpty) return 0;
  return (rows.first.values.first as int?) ?? 0;
}

Future<bool> _isPlaintextSqlite(File f) async {
  final header = await _readHeader(f);
  return header != null && _hasSqliteMagic(header);
}

/// The first 16 bytes of [f] (fewer when it is shorter), or null when it does
/// not exist. A single open, so a file deleted mid-check reads as absent
/// instead of failing between separate exists/length/read calls. Any other
/// I/O error propagates: an unreadable file must not pass for "no database".
Future<List<int>?> _readHeader(File f) async {
  try {
    final raf = await f.open();
    try {
      return await raf.read(_sqliteMagic.length);
    } finally {
      await raf.close();
    }
  } on PathNotFoundException {
    return null;
  }
}

bool _hasSqliteMagic(List<int> header) {
  if (header.length < _sqliteMagic.length) return false;
  for (var i = 0; i < _sqliteMagic.length; i++) {
    if (header[i] != _sqliteMagic[i]) return false;
  }
  return true;
}

Future<void> _deleteSidecars(String dbPath) async {
  for (final suffix in const <String>['-wal', '-shm', '-journal']) {
    final f = File('$dbPath$suffix');
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best-effort cleanup; a locked/absent journal must not abort the swap.
    }
  }
}
