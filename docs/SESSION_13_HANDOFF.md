# Money Tracker (FinanceFlow) — Session 13 Handoff: Finish the v5.0.x tail

> **You are picking this up after v5.0.0 shipped (Session 12).** This is the
> complete, self-contained plan to finish the remaining deferred work. It
> supersedes the forward-looking parts of `docs/SESSION_11_HANDOFF.md` and
> `docs/NEXT_SESSION_HANDOFF.md` (those remain the source for per-function test
> specs and the original master plan). Read `docs/SESSION_12_SHIP.md` for what
> already shipped.

---

## 0. Status snapshot (start here)

- **SHIPPED:** v5.0.0+7 is live. `origin/main == origin/release/v5.0.0 == 6c1e0fd`. Tag `v5.0.0` → commit `e11400d`. GitHub release published (APK attached). Landing serves the matching APK (SHA-1 `ff6a84370f2f1d3bf7627a08af1bb59ed1617d68`).
- **Branch to work on:** `release/v5.0.0` (do NOT branch off main; this project does release-branch → ff-merge main at session close).
- **Version:** `pubspec.yaml` is now `5.0.0+7`. Next ship bumps the build number to **+8** (anything you ship must keep versionCode monotonically increasing above 7).
- **Tests:** 2062 pass / 3 skipped, `flutter analyze` clean, `bash scripts/preflight.sh` green. **Gate `TEST_COUNT_MIN` is 2050** in `scripts/preflight.sh:56` AND `scripts/preflight.ps1:33` — ratchet BOTH after each batch.
- **Device:** `emulator-5554` (API 36) is up; app id `com.moneytracker.app`. ADB at `C:/Users/leooa/AppData/Local/Android/Sdk/platform-tools/adb.exe`. Drive the UI via the `mobile` MCP (`mcp__mobile__*`). The emulator currently has the **release build, no PIN, with sample data loaded**.

### What's DONE (don't redo)
H1, H2 (PBKDF2 PIN), M1, M5 (CSV **and** PDF isolates), M6–M21, L27, L30, L32, L33, L34, L36, L42, L46, L48, L52, L56, L57, model bulk-read hardening, +129 model/util/widget tests, version bump + CHANGELOG, the full ship pipeline, and a security merge that incorporated PR #11 (untracked the leaked `google-services.json`).

---

## 1. Environment & tooling

### Build / install / run
```bash
flutter build apk --release            # ~135s; outputs build/app/outputs/flutter-apk/app-release.apk (~64 MB)
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk   # -r preserves data; uninstall first for a clean run
```
Verify versionCode after a bump:
```bash
"C:/Users/leooa/AppData/Local/Android/Sdk/build-tools/36.1.0/aapt.exe" dump badging build/app/outputs/flutter-apk/app-release.apk | head -1
```

### Preflight (the gate)
```bash
bash scripts/preflight.sh > /tmp/pf.log 2>&1
grep -E 'preflight green|Some tests failed|test pass count' /tmp/pf.log   # ALWAYS grep the log, not $?
```

### Ship pipeline (only when DoD is green — see §7). Corrected from the old handoff:
1. `flutter build apk --release` → record `sha1sum build/app/outputs/flutter-apk/app-release.apk`.
2. `cp` it to `expense-tracker-landing/public/downloads/money-tracker.apk`.
3. `git push origin release/v5.0.0` ; then ff main: `git push origin release/v5.0.0:main`.
4. In `expense-tracker-landing`: `git add public/downloads/money-tracker.apk && git commit -m "chore: update APK to <ver>" && git push`.
5. **`vercel --prod --yes`** from the landing dir (Git integration is DISCONNECTED — push alone does NOT deploy).
6. Verify: `curl -sL https://leo-money-tracker.vercel.app/downloads/money-tracker.apk | sha1sum` == the built APK sha1.
7. `git tag -a v5.0.x <commit> -m "…" && git push origin v5.0.x` ; `gh release create v5.0.x <apk> --title … --notes …`.

---

## 2. Process traps (already paid for — don't re-hit)

1. **`preflight.sh > log; echo $?` masks the real exit** (the wrapper/`echo`/`tail` exit, not preflight's). **Always `grep` the log** for `preflight green` / `Some tests failed`.
2. **Never edit `lib/`/`test/` while a `flutter test`/preflight/build runs**, and **don't run two `flutter` commands at once** — the shared `.dart_tool` build cache produces phantom "Failed to load" errors. (Background subagents that run `flutter test` count — let them finish, or only do read-only work meanwhile.)
3. **The DB test harness has a real init race.** `DatabaseHelper.resetForTesting()` now awaits in-flight init (fixed S12), but any NEW work that makes `performMaintenance`/`loadData` do more async DB work can re-expose ordering fragility across the integration files. Run the FULL suite, not just the one file, after touching DB code — a generated test can pass alone and fail in-suite (happened with `organic_blob_background_test.dart`).
4. **Device verification catches what units miss** (the M16 hero `$2845.00`, and confirming `compute()` isolates work under release/AOT). Always smoke the **release** build, not just debug.
5. **`google-services.json` is vestigial** (gms gradle plugin is `apply false`, no Firebase deps in `pubspec.yaml`). It's now gitignored + untracked and was deleted from disk by the security merge. Builds DON'T need it. Only regenerate (`flutterfire configure`) if Firebase is ever re-added.

---

## 3. Remaining work, in priority order

### A. Phase 6.1 — SQLCipher at-rest DB encryption  (HIGH risk, device-only) — the big one
The single largest open item; deferred from S12 deliberately (don't bolt a data-loss-risk migration onto a ship). Full plan in `docs/NEXT_SESSION_HANDOFF.md` Group 7 (lines 328-341). Summary + corrections:

1. **Dep swap** (`pubspec.yaml`): add **`sqflite_sqlcipher`** (latest is **3.4.0** as of 2026-06; `^3.4.0`), keep `sqflite_common_ffi` for tests, remove plain `sqflite`. Swap the import in `lib/database/database_helper.dart` and `lib/utils/backup_helper.dart` to `package:sqflite_sqlcipher/sqflite.dart` (API identical except `password:` on `openDatabase`). `flutter pub get && flutter analyze`.
2. **Key:** new `lib/utils/db_encryption.dart` — `DbEncryption.getOrCreateKey()` reads base64 key from `SecurePrefs.readString('db_encryption_key')` or makes 32 bytes via `Random.secure()` and stores it. 3 unit tests.
3. **Migration** in `_initDatabase()` when `!hasKey && plaintextExists`: copy `expense_tracker_v4.db` → `…db.pre-sqlcipher-backup`; capture `preCounts`; gen key; `ATTACH … KEY` → `SELECT sqlcipher_export('encrypted')` → `DETACH`; reopen encrypted, capture `postCounts`; if counts match → swap files (keep the backup until next good launch); else → `CrashLog.record(...)`, delete enc file, **keep plaintext** (fail safe).
4. **Tests** (`test/integration/sqlcipher_migration_test.dart`): plaintext→encrypted row-count match; verification-failure preserves plaintext + writes CrashLog + no enc file; second launch returns encrypted DB without regenerating the key; `_isPlaintextDatabase(File)`. Encrypted-open assertions are device-only (no plugin on the test runner).
5. **Device smoke:** seed v4 data, upgrade, expect 1-3s startup (the export), add a tx, and confirm `adb shell run-as com.moneytracker.app sqlite3 databases/expense_tracker_v4.db ".tables"` → `Error: file is not a database`.
6. **After it lands:** `flutter pub upgrade --major-versions` once, review (don't auto-accept); `pubspec.lock` audit; APK size delta ≤ +5 MB.

> **NOTE on `CrashLog`:** the API is `CrashLog.record(error, {stack, context})` (NOT `CrashLog.write` as the old plan says). Verify before calling.

### B. Test gaps — close the remaining ❌/🟡 (or justify)
The deterministic model/util/widget layers are CLOSED (S12). What's left, by file (gap counts; full per-function specs are in `docs/NEXT_SESSION_HANDOFF.md` — search the header `### \`lib/...\``):

- **`lib/database/database_helper.dart` — ~110 gaps (85❌/25🟡).** Biggest. Needs the integration harness: `test/integration/_test_helpers.dart` `makeFreshDb()` (assigns a unique `databaseNameOverride` per call) + `DatabaseHelper.resetForTesting()` in tearDown. **Race-prone — run the FULL suite after each batch.** Add tests in waves of ~10, ratchet the gate, commit per wave.
- **`lib/providers/app_state.dart` — ~82 gaps (53❌/29🟡).** Same harness (see `test/integration/app_state_crud_test.dart` for the setUp/bootstrap pattern: mock `homeWidgetChannel`/`notifChannel`/`secureChannel`/`pathProviderChannel`, `SharedPreferences.setMockInitialValues`).
- **Screens (1-3 gaps each):** onboarding_screen, history_screen/list/grouping/filter_bar, recurring views, budget/wallet/analytics/settings/notification_settings/add_payment/advanced_filter/crash_log/pin_* screens. Widget tests — use `tester.binding.setSurfaceSize(const Size(800, 1600))` so slivers stay in viewport; for PIN/secure screens mock `MethodChannel('plugins.it_nomads.com/flutter_secure_storage')` (pattern in `test/utils/pin_lockout_test.dart`).
- **Per-agent honest deferrals from S12 — these need a small `lib/` test-seam (now allowed; lib is no longer frozen):**
  - `permission_helper.dart`: SDK-branch paths are gated by `if (!Platform.isAndroid) return true;`. Add a `@visibleForTesting` setter to override the platform check / `_cachedAndroidSdk`, then test the SDK 29/30/33 branches.
  - `date_helper.dart`: `today()`/`isPast`/`isFuture`/`isToday` read `DateTime.now()` directly. Wire them through the existing `lib/utils/clock.dart` `Clock.instance` so a `FakeClock` makes them deterministic + testable (also enables the midnight-rollover case). This also helps Group C goldens.
  - `glass_donut_chart.dart`: make `_DonutPainter` (or just its `shouldRepaint`) `@visibleForTesting` so the repaint contract can be asserted directly.
  - `currency_helper.dart` `formatCompact` catch-block: genuinely unreachable for the 25 mapped locales — leave it, or add a seam only if you want the coverage line.
  - `category_tile.dart` exact dark-mode HSL-clamp RGB: leave to a golden (Group C).

### C. D.3 — golden tests for the 8 hero screens  (LOW risk, no device)
**No golden infra exists yet** (greenfield) — `docs/NEXT_SESSION_HANDOFF.md` Group 8 (lines 344-352). Per hero screen (Settings, Wallet, Budgets, Analytics, Add Transaction, History, Recurring Items, Home): `flutter test --update-goldens test/screens/<name>_test.dart`, lock to Windows, `matchesGoldenFile(name)` at 2% tolerance, document in `test/golden/README.md`. **Wrap relative-time strings in a fixed clock** (ties into the Clock work in §B), drain `FadeInOnLoad`/`BounceAnimation` timers (`pumpAndSettle`/bounded pump) so none are pending at dispose, and skip the notifications-permission screen. Re-enable the two skipped tests during this: `TRASH/analytics_screen_test.dart_skipped`, `TRASH/notification_settings_screen_test.dart_skipped`.

### D. 8.2 — device performance pass  (MEDIUM, device)
`docs/NEXT_SESSION_HANDOFF.md` Group 9 (lines 356-362). DevTools Performance overlay on emulator-5554: Home scroll w/ 100 expenses, History scroll w/ 500, rapid tab switching, Analytics first paint — steady-state ≤16.7ms/frame, first frame ≤100ms. Validates the already-landed M5/M6/M7/M8/M9 fixes. Documented rollback if regressed: bump glass blur radius back to 10.

### E. LOW-tail remainder — opportunistic
Full file:line + surgical fix for every item: `docs/AUDIT_FINDINGS_2026-06.md` and `docs/NEXT_SESSION_HANDOFF.md` Group 6 (lines 304-324). Status:

| Worth doing (real defect/robustness) | Optional (audit says leave / pure cleanup) |
|---|---|
| L23 CSV totals drift — accumulate in `Decimal` (`csv_exporter.dart` builders) | L22 budget-progress `double` vs `Decimal` (`app_state.dart:1163,1178`) |
| L28 `deleteAccount` non-atomic tag purge — delete redundant block `database_helper.dart:1429-1468` (triggers cover it) | L24 edit-screen amount seed cosmetic (`add_transaction_screen.dart:115,117,130`) |
| L29 v19 pre-migration WAL — `wal_checkpoint(TRUNCATE)` before copy (`database_helper.dart:762-772`) | L25 switchAccount/loadData mutex (concurrency; risky) |
| L31 budget-restore month validation (`database_helper.dart:3684-3713`) | L26 `registerInteractivityCallback` dead (has subscription+dispose tendrils) |
| L54 comprehensive-restore rollback guard (`backup_helper.dart:1166-1176`) | L35 PIN lockout backoff (by-design; not a sub for H2) |
| L55 comprehensive-backup `as String` guard (`backup_helper.dart:101-103`) | L37 legacy hash force-migrate — **already done by H2** |
| L43 backup/restore icon tooltips (`backup_restore_screen.dart:1187,1203,1624`) | L38/L39/L40/L41 perf micro-opts |
| L44 segmented-control 48dp target (`glass_segmented_control.dart:115-124`) | L45 donut legend (pre-emptive; live donut already labeled) |
| L47 home inset/avatar dark-mode (`home_screen.dart:599-602,70-71`) | L58 triplicated contrast logic (visual change) |
| L49 home empty-state behind nav bar (`home_screen.dart:286-333`) | L59 DecimalHelper unused helpers — **keep `clamp` :191** (used by `parse()`) |
| L50 analytics loading → `GlassPanel` (`analytics_screen.dart:161-172`) | L60 AccessibilityHelper unused statics |
| L51 payment-method tag colors → `colorScheme` (`history_screen.dart:1752-1762`) | L61 ColorContrastHelper unused WCAG helpers |

(L53 startup loadData-not-awaited: already effectively handled by M17's try/catch — drop the security framing.)

### F. Cross-cutting cleanups (none blocking)
Populate or remove `dist/baseline/v4.4.0+6.db` + `dist/baseline/perf/`; `pubspec.lock` audit after SQLCipher; fix the `pubspec.yaml` description ("A minimalistic money tracking app" is fine — verify it's not the template string); confirm `.v18-backup` auto-clean on device.

---

## 4. Suggested execution order (lowest-risk first, ship-ready throughout)
1. **Clock wiring** (`date_helper.dart` → `Clock.instance`) — unblocks deterministic date tests AND goldens. Small, high-leverage.
2. **Per-agent test seams** (permission_helper, glass_donut_chart) + close those gaps.
3. **Goldens (C)** — now that the clock is injectable.
4. **LOW-tail "worth doing" column (E)** — wave-based, preflight after each ~5.
5. **Giant test gaps (B)** — db_helper then app_state, in ~10-test waves, FULL suite each time, ratchet gate.
6. **SQLCipher (A)** — last among code work (highest risk; device-gated). Do it on its own branch state, verify exhaustively.
7. **Device perf pass (D).**
8. **Version bump → `5.0.1+8` (or `5.1.0+8` if SQLCipher lands) + CHANGELOG**, then the §1 ship pipeline.

> Ratchet `TEST_COUNT_MIN` (both `.sh` and `.ps1`) after every batch. Commit per logical group with test count + pass rate in the body. Never push/ship until preflight is green AND the release build is device-smoked.

---

## 5. Definition of Done (for the v5.0.x tail to be "complete")
- SQLCipher landed + device-verified (or explicitly cut from scope with sign-off).
- Every ❌/🟡 in the per-function test plan closed or justified-in-PR; `flutter test` green with a ratcheted gate.
- Goldens committed and pass a second run within tolerance.
- Device perf pass meets 60fps steady-state on the four flows.
- Version bumped (build number > 7) + CHANGELOG; APK ≤ 70 MB; release build 5-min device smoke; tag + `gh release`; `origin/main == origin/release`; landing serves matching SHA-1.

---

## 6. Quick file/line reference
- Preflight gate: `scripts/preflight.sh:56`, `scripts/preflight.ps1:33` (both `2050`).
- DB init + the race fix: `lib/database/database_helper.dart` `database` getter ~`:75-99`, `resetForTesting()` ~`:55-80`.
- Maintenance (L30/L34 live here): `performMaintenance()` ~`:3013`, `cleanOrphanedBackupFiles()` ~`:1507`, `purgeExpiredDeletedAccounts()` (new).
- M5 isolate builders (public, testable): `CsvExporter.buildExpensesCsv/buildIncomeCsv/buildAllTransactionsCsv` (`lib/utils/csv_exporter.dart`); `PdfExporter.buildExpensesPdf/buildIncomePdf/buildMonthlySummaryPdf` (`lib/utils/pdf_exporter.dart`).
- Integration harness: `test/integration/_test_helpers.dart` (`makeFreshDb`), `test/integration/app_state_crud_test.dart` (setUp/bootstrap pattern).
- Audit (every finding): `docs/AUDIT_FINDINGS_2026-06.md`. Per-function test specs: `docs/NEXT_SESSION_HANDOFF.md` (the long "Comprehensive Per-Function Test Plan").
