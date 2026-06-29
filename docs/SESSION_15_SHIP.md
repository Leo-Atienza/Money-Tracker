# Session 15 Ship Record — v5.1.0+9 (at-rest SQLCipher encryption)

**Shipped 2026-06-29.** Phase 6.1 (deferred in S12 and S14) implemented, device-verified, and released.

## What shipped
- **At-rest SQLCipher (AES-256) database encryption**, always-on for Android/iOS/macOS.
- Release commit `aa8bbd5`; `origin/main == origin/release/v5.0.0 == aa8bbd5`; annotated tag **`v5.1.0`**.
- APK **78.2 MB** (was 64.1 — bundled `libsqlcipher.so` across ABIs), **versionCode 9** (> 8, OTA-safe).
- SHA-1 **`f1d3177ef1b166d9f423ff8dc3506f04746b7f68`**. Landing pushed + `vercel --prod --yes`; live URL serves matching SHA-1. GitHub release `v5.1.0` published with the APK.
- **Tests: 2564 pass / 3 skipped**; analyze clean; preflight green; gate ratcheted 2552 → 2564 (`scripts/preflight.sh:56` + `.ps1:33`).

## Architecture (the single open seam)
`lib/database/db_open.dart` — `openAppDatabase()` funnels every DB open:
- On `cipherPlatform` (Android/iOS/macOS) **with a key** → `maybeMigrateToEncrypted()` then `cipher.openDatabase(..., password:)`.
- Else (FFI test runner / desktop / no key, or `databaseNameOverride` set) → plaintext `openDatabase()` exactly as before. **This is why the 2500+ integration tests and desktop builds are untouched.**

`maybeMigrateToEncrypted()` is **fail-safe** — plaintext is deleted only after a verified encrypted copy:
1. Detect plaintext via the `SQLite format 3\0` magic header (no-op if absent or already encrypted).
2. Copy `<db>.pre-sqlcipher-backup` (plaintext recovery copy, kept).
3. Export: open the **encrypted** `dest` as `main` (a fresh keyed DB the plugin creates cleanly), `ATTACH <plaintext> AS plaintext KEY ''`, `SELECT sqlcipher_export('main','plaintext')`, carry `user_version`, `DETACH`. **Opening a plaintext file directly as the cipher `main` connection is unreliable** — SQLCipher applies a key and the connection dies on first read — so keep `main` encrypted and the plaintext merely ATTACHed.
4. Verify: re-open `dest` with the key, `PRAGMA integrity_check`, row-count match vs. source.
5. Swap: delete the plaintext's stale `-wal`/`-shm`, then atomic `rename(dest → db)` (POSIX replace; delete-then-rename fallback on Windows tests).
On any failure: drop the temp, rethrow → `openAppDatabase` logs to `CrashLog` and falls back to a plaintext open; retries next launch.

Key management `lib/utils/db_encryption.dart` — `getOrCreateKey()`: 32-byte `Random.secure` key, base64 in the Keystore via `SecurePrefs('db_encryption_key')`, **read-back-verified** (returns `null` → plaintext fallback rather than encrypt with a key it couldn't persist). Independent of the PIN.

Backups stay portable `lib/utils/backup_helper.dart` — a `.etbackup` embeds raw DB bytes (`_createBackupInIsolate` does `readAsBytes`). When the DB is encrypted, `_backupSource` first decrypts to a plaintext temp via `exportPlaintextCopy` (the reverse: `main`=encrypted, `ATTACH plaintext KEY ''`, `sqlcipher_export('plaintext')`), so the embedded bytes are plaintext — restorable on any device and passing restore's SQLite-header check. The optional passphrase envelope (Phase 6.3) is unchanged.

## The gotcha (cost 3 device cycles)
The cipher connection intermittently threw `DatabaseException(database_closed)` mid-`_totalRowCount` when that function ran a **per-table `COUNT(*)` loop** (~16 round-trips). Fix: `_totalRowCount` is now a **single aggregate query** — `SELECT (SELECT COUNT(*) FROM "t1") + (SELECT COUNT(*) FROM "t2") + … AS total`. **Use one statement, not a query loop, on these connections.** Also: open all migration/export connections with `singleInstance: false`.

## Tests added (+18)
- `test/utils/db_encryption_test.dart` — key lifecycle over a mocked `flutter_secure_storage` channel.
- `test/database/db_open_migration_test.dart` — the migration state machine via injected `exportFn`/`verifyFn` seams (the real cipher can't run on the Windows runner — no Windows SQLCipher `sqlite3.dll`; pub marks it TODO).

## Device verification (emulator-5554)
- **DEBUG (full migration):** v17 plaintext → encrypted (31 rows, integrity ok, header is ciphertext, on-device `sqlite3 .tables` = "file is not a database"); schema 17→19 ran on the encrypted connection; data reads correctly (Jan 2026 expenses $711 / income $788, 4 transactions); **key persists across force-stop/restart (no re-migration)**; a real `.etbackup` made from the encrypted DB decrypts to PLAINTEXT bytes (155 648 B, `SQLite format 3` header); `FLAG_SECURE` blocks screencap (returns black); PIN/Keystore coexists with the DB key.
- **RELEASE/AOT:** fresh install encrypts; sample data writes + reads ($2,845.00 hero / $3,000.00 income / $155.00 expenses); `libsqlcipher.so` loads; no FATAL.

## Caveats (flagged to the user)
- **One-way door:** once a DB migrates to encrypted, downgrading to a pre-5.1.0 build cannot open it. Forward-only.
- **APK +14 MB** (universal APK bundles `libsqlcipher.so` for all ABIs).

## Dependency
`sqflite_sqlcipher: ^3.4.0` (resolved 3.4.0 — no downgrades to `sqflite` 2.4.2 / `sqflite_common` 2.5.6 / `sqflite_common_ffi`). `pubspec.lock` is gitignored.

## Emulator state after this session
`emulator-5554` (`Budget_Tracker_Emulator` AVD) now has the **RELEASE v5.1.0 build, fresh install, NO PIN, sample data loaded** (encrypted DB). `run-as` does **not** work on this release build (not debuggable) — reinstall a debug build to inspect DB files.
