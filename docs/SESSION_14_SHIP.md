# Session 14 — v5.0.1+8 SHIPPED (2026-06-28/29)

**FinanceFlow v5.0.1+8 is live.** Finished the v5.0.x tail from
`docs/SESSION_13_HANDOFF.md`: closed the giant test gaps, fixed two real
production bugs the new tests surfaced, polished the LOW tail, and shipped a
correctness/robustness patch.

## What shipped
- **Released commit:** `3eba7cf` on `release/v5.0.0`, fast-forward-merged to
  `main`. `origin/main == origin/release/v5.0.0 == tag v5.0.1 == 3eba7cf`.
- **APK:** `5.0.1+8`, **versionCode 8** (> shipped 7 — OTA-safe), 64.1 MB,
  SHA-1 `483106661aa47881f4a99cd883e0e3c7c0102c36`.
- **Landing:** pushed + `vercel --prod --yes`. Live URL serves the matching
  SHA-1 (verified). https://leo-money-tracker.vercel.app/downloads/money-tracker.apk
- **GitHub release:** https://github.com/Leo-Atienza/Money-Tracker/releases/tag/v5.0.1 (APK attached).
- **Tests:** **2552 pass / 3 skipped**, analyze clean, preflight green. Gate
  ratcheted 2050 → **2552** (both `scripts/preflight.sh:56` and `.ps1:33`).

## Two real production bugs found + fixed (by the new tests)
1. **`searchTransactionsUnified` threw on every match** (`e22afd6`). Its UNION
   SELECT omitted `account_id`, but `Expense/Income.fromMap` (called directly,
   not via the catch-protected `tryFromMap`) require it — so unified History
   search threw `ArgumentError` whenever it actually matched a row. Added
   `account_id` to both UNION branches.
2. **Account delete/reset deadlock + stale data** (`91e59c6`). `resetAccount`
   (and `deleteAccount`'s reload branch) called `_reloadAccountData()` while
   holding the non-reentrant `_writeMutex`; its public loaders re-acquire that
   mutex → **deadlock** (resetting the current account hung the app). Moved the
   reload outside the mutex (matching `switchAccount`). Also fixed `deleteAccount`
   checking `_currentAccount?.id == id` AFTER `_loadAccounts` had already reset
   it — so deleting the active account never reloaded and left stale rows.

## Work landed this session (15 commits on top of S13's `aa38a19`)
| Commit | What |
|---|---|
| `0a6a0a6` | Clock-wire `date_helper` today()/getRelativeTime() (+16 deterministic tests). |
| `0bf9303` | `@visibleForTesting` seams for permission_helper (SDK 29/30/33 branches) + glass_donut_chart `DonutPainter.shouldRepaint` (+20 tests). |
| `8f68816` | LOW tail money/resilience: L23 CSV Decimal totals, L54/L55 restore guards. |
| `3b8b4dd` | LOW tail db_helper: L28 (drop redundant non-atomic tag purge), L29 (WAL checkpoint pre-copy), L31 (malformed-month skip). |
| `704b5d3` | LOW tail UI: L43/L44/L47/L49/L50/L51 (a11y tooltips, 48dp targets, dark-mode tiles, GlassPanel loading, themed payment chips). |
| `e22afd6` | **searchTransactionsUnified account_id bug fix.** |
| `7c925a4` | **+277 database_helper.dart integration tests** (8-agent workflow). |
| `91e59c6` | **account delete/reset deadlock + stale-data bug fix.** |
| `80d3b8e` | **+176 app_state.dart integration tests** (6-agent workflow). |
| `5bf… docs` | SQLCipher deferral rationale. |
| `3eba7cf` | Version bump 5.0.0+7 → 5.0.1+8 + CHANGELOG. |

The +453 integration tests were authored by self-verifying multi-agent
workflows (one independent file per spec section), then integrated and verified
green as full-suite batches — the full run is the authoritative gate (it catches
the harness init-race that single-file self-verification cannot).

## Device-verified on the RELEASE/AOT build (emulator-5554, all passed)
- Onboarding renders over the blob background; Load Sample Data → Home.
- **M16 hero grouping: `$2,845.00`** (Income `$3,000.00` − Expenses `$155.00`).
- Relative-time strings render (`Yesterday`, `2 days ago`, `Jun 19`) — confirms
  the Clock wiring works in production.
- Settings & Security + Export screens render (UI-polish areas intact).
- **CSV export** → `transactions_*.csv` (the changed L23 Decimal builder, via
  `compute()` isolate under AOT) and **PDF export** → `monthly_summary_*.pdf`.
- Zero FATAL in logcat across the full smoke.

## Deferred (with written rationale — documented choices, not bugs)
1. **Phase 6.1 SQLCipher** — `docs/SQLCIPHER_DEFERRAL.md`. `sqflite_sqlcipher`
   is Android/iOS/macOS-only (no desktop FFI) and uses a different
   `databaseFactory` than the `sqflite_common_ffi` test harness → adopting it
   would break all 200+ integration tests on the Windows runner; plus the
   plaintext→encrypted migration is device-only-verifiable data-loss risk. App
   already ships PBKDF2 PIN + encrypted backups + FLAG_SECURE.
2. **D.3 hero-screen goldens** — golden tests of the glassmorphic screens
   (`BackdropFilter` blur, gradients, AnimatedCounter/FadeIn animations) are
   environment-fragile (break on any Flutter SDK/font/raster change even at 2%
   tolerance), which would make the suite intermittently red — counter to the
   "rock-solid" goal. Every hero screen already has a widget test + this
   session's device verification. Consistent with S12's deferral.
3. **Formal DevTools 60fps pass** — impractical to measure rigorously on the
   emulator (S12). The M5–M9 perf fixes are code-verified and the release build
   smoked without visible jank (Home/Settings/Export scroll + render clean).

## Notes
- The emulator (`emulator-5554`, `Budget_Tracker_Emulator` AVD) now has the
  **v5.0.1 release installed, no PIN, with sample data loaded**.
- `adb`/`screencap` on this emulator: when the screen is asleep, screencap
  returns an all-black PNG and uiautomator dumps fail — wake it first
  (`adb shell input keyevent KEYCODE_WAKEUP`). Pull screenshots via a device
  file (`screencap -p /sdcard/sc.png` then `pull`) with `MSYS_NO_PATHCONV=1` so
  Git Bash doesn't mangle the `/sdcard` path; piping `exec-out screencap -p`
  gets polluted by the emulator's multi-display warning.
