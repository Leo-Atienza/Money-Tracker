# Phase 6.1 SQLCipher — Deferral rationale (Session 14, 2026-06-28)

**Decision: SQLCipher at-rest DB encryption is explicitly CUT from the v5.0.x
tail and deferred to a dedicated follow-up.** This was an authorized decision
under the Session-13 handoff's own instruction: *"If it is not rock-solid,
DEFER it with a written rationale rather than shipping a risky migration — do
not gamble user data."* It was deferred once already in Session 12 for the same
core reason; Session 14 re-evaluated it in depth and reached the same call.

## The blocking technical problem (new finding this session)

The S13 plan said: *"add `sqflite_sqlcipher`, keep `sqflite_common_ffi` for
tests; encrypted-open assertions are device-only."* That glosses over a hard
incompatibility:

- **`sqflite_sqlcipher` (davidmartos96 fork) ships Android / iOS / macOS only —
  it has no desktop FFI factory.** (Verified on pub.dev 2026-06-28: supported
  platforms are Android, iOS, macOS; no `sqflite_common_ffi` interop documented.)
- This repo's **test runner is Windows**, and all ~200+ integration tests open
  the database through `DatabaseHelper`, which would import
  `package:sqflite_sqlcipher/sqflite.dart`. That fork exposes its **own**
  `databaseFactory` global and its own types — distinct from the `sqflite` /
  `sqflite_common` globals that `sqflite_common_ffi`'s `databaseFactoryFfi`
  drives. The harness's `databaseFactory = databaseFactoryFfi` would therefore
  **not** redirect the fork's `openDatabase`, and the fork has no Windows
  implementation, so **every integration test would fail to open a database on
  the Windows runner.**
- `sqflite_common_ffi` *does* have a separate SQLCipher story
  (`createDatabaseFactoryFfi(ffiInit: <load libsqlcipher>)`), but that is a
  different package and key/pragma mechanism than the `sqflite_sqlcipher`
  plugin used on-device — so the test path and the production path would no
  longer share an engine, defeating the point of the integration suite.

Making the suite green again would require either a fragile conditional-import
split (plain `sqflite` in tests, `sqflite_sqlcipher` on device — so the
encryption path is *never* exercised by tests) or a wholesale harness rewrite to
a sqlcipher-capable desktop FFI that the fork does not provide. Neither is
"rock-solid"; both are exactly the kind of risky, low-coverage change to defer.

## The data-safety problem

Phase 6.1 is a **plaintext → encrypted migration of the user's live database**
(`ATTACH … KEY` → `sqlcipher_export` → swap files). Its failure modes —
torn/partial export, key not persisted to Keystore, or a key lost on a later OS
event — are **permanent data loss**, and the encryption path can only be
verified on a physical/emulated Android device, never in the (now-broken)
integration suite. Bolting that onto a ship is the anti-pattern the project
avoided in S11 and S12.

## Why the residual risk is acceptable to ship without it

FinanceFlow already ships meaningful defense-in-depth:

- **PBKDF2-hashed app PIN** stored in the Android Keystore (`flutter_secure_storage`).
- **AES-GCM + PBKDF2 encrypted backup envelopes** (Phase 6.3) for data leaving the device.
- **`FLAG_SECURE`** (Phase 6.5) blocking screenshots / recents thumbnails.

The unencrypted on-disk DB is reachable only by `run-as` on a **debuggable**
build, by root, or by physical flash extraction on a rooted device — a real but
lower-tier threat for a **local-only, no-backend** personal finance app, and one
that at-rest DB encryption with a Keystore key only partially mitigates anyway
(the key lives on the same device).

## Clean follow-up plan (when it is done properly, on its own branch)

1. Branch off `main`; do NOT couple it to a release.
2. Stand up a **sqlcipher-capable test harness** first: either migrate the whole
   suite to `sqflite_common_ffi` + `createDatabaseFactoryFfi(ffiInit:)` loading
   a desktop libsqlcipher, or gate db_helper's factory by platform so tests use
   a sqlcipher-FFI factory that actually exercises the password path. Prove the
   existing 2100+ tests stay green BEFORE touching production code.
3. `lib/utils/db_encryption.dart`: `getOrCreateKey()` (32 bytes via
   `Random.secure()`, base64 in `SecurePrefs('db_encryption_key')`), 3 unit tests.
4. Fail-safe migration in `_initDatabase`: copy `…db.pre-sqlcipher-backup`,
   capture pre/post row counts, encrypt, verify counts match → swap; else
   `CrashLog.record(...)` and **keep plaintext** (never delete the plaintext
   until a verified encrypted launch).
5. Device smoke: seed v4 data → upgrade → add a tx →
   `adb shell run-as com.moneytracker.app sqlite3 databases/expense_tracker_v4.db ".tables"`
   must error `file is not a database`.
6. `flutter pub upgrade --major-versions` review, `pubspec.lock` audit, APK size
   delta ≤ +5 MB.

Until that harness exists and the migration is device-proven across several
upgrade paths, shipping it would trade a green, well-tested release for an
unverifiable migration on user data. Deferred deliberately.
