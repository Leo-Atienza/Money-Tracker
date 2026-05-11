# Session Handoff — v5.0.0 Release Branch

**Branch**: `release/v5.0.0` (NEVER pushed to origin yet)
**Master plan**: `docs/MASTER_PLAN.md`
**Per-task checklist**: `docs/CHECKLIST.md`
**Last commit at handoff**: `eaec0ee feat(phase-8.1): preflight script + forbidden-patterns lint test`
**Paused**: 2026-05-11 (Session 2 — Phase 2.3 unblock + security wave)

> To resume: `git checkout release/v5.0.0` (already there) and read this file top-to-bottom plus `docs/CHECKLIST.md`. The master plan has the full "why" for each phase; this file has the "where we are" and "what to do next."

---

## TL;DR — what's done, what's next

| Phase | Status | Tests | What's in it |
|---|---|---|---|
| 0 — Pre-flight | ✅ Done | 1,643 baseline | Master plan + checklist + analyze baseline + APP_INFO design brief |
| 1 — Stop the Bleeding | ✅ Done (10/10) | 1,661 (+18) | useTemplate fix, pruneDistantMonths, Navigator.pushNamed, HomeWidget race, loadData coalesce, addExpense atomic tx, blur perf, fadeController mounted, Android backup hardening, notification redaction |
| 2 — Architectural Foundations | ✅ Done (7/7) | 1,673 (+12) | AppColors → lib/theme/, LuminousTokens consolidated, Luminous widget skeleton (8 components + tests), history_screen narrow selects, package_info_plus, NotificationHelper singleton, **2.3 Hanken Grotesk bundled as variable font (this session)** |
| 3 — Race & Lifecycle | 🟡 7/7 (3.8 deferred) | 1,683 (+10) | notification payload queue, recurring snackbar stream, FocusManager lock hook, accountSwitch stream, HomeWidgetHelper dispose on paused, mounted guards, pre-push re-check |
| 4 — Schema v19 + Data Integrity | ✅ 12/12 | 1,685 (+1 migration test) | v19 migration bundle (FK cascades + triggers + month-key normalisation), tx wrapping, soft-delete tag cleanup, backup validation + transaction_tags round-trip, strict model validation |
| 5 — Luminous Design Integration | 🟡 starter only | n/a | `a231db4 feat(phase-5/wip)` from prior session — MainNavigationScreen 5 tabs, Home redesign, AddHub/Analytics/AccountManager scaffolds, `buildLuminousTheme`. 5.1–5.9 still ahead. |
| 6 — Security Hardening | 🟡 3/6 (this session) | 1,715 (+30) | **6.2 PIN → flutter_secure_storage**, **6.5 FLAG_SECURE**, **6.6 Crash log PII redactor**. 6.1 SQLCipher / 6.3 backup AES-GCM / 6.4 widget redaction still ahead. |
| 7 — Test Coverage Rebuild | ⏳ Not started | — | Rename mislabeled tests, real logic tests, 8 hero-screen tests, goldens, Clock injection, CI gates |
| 8 — Polish & Ship | 🟡 2/5 (this session) | 1,720 (+5 lint) | **8.1 preflight + forbidden-patterns lint**, **8.3 APK build verified (59.2 MB)**. Perf pass / version bump / ship pipeline still ahead. |

---

## Commits on this branch (16 since main diverged)

```
eaec0ee feat(phase-8.1): preflight script + forbidden-patterns lint test
3a290ed feat(phase-6.2): move PIN hash/salt + counters to flutter_secure_storage
ce637e7 feat(phase-6): FLAG_SECURE + crash log PII redactor (6.5, 6.6)
d8f67b8 feat(phase-2.3): bundle Hanken Grotesk variable font
46175cf docs(handoff): refresh for Phase 4 close-out
b6a3da4 feat(phase-4): schema v19 + data integrity (4.1–4.12)
1d60bcd feat(phase-3): race & lifecycle correctness (3.1–3.7)
df6bcd1 feat(phase-2): architectural foundations (2.1, 2.2, 2.4, 2.5, 2.6, 2.7)
deec0d0 chore(phase-1): close-out — clean analyze + 1,661 tests pass
fe1db80 fix(phase-1.10): redact notification body on a secure lock screen
3cadee7 fix(phase-1.9): disable Android backup + data extraction
88af59c fix(phase-1.8): mounted check + generation token on tab-fade callback
2893dd0 fix(phase-1.7): perf — blur sigma 15 + RepaintBoundary on glass surfaces
a04d756 fix(phase-1.6): atomic addExpense/addIncome + carryover via db.transaction
0d45eaf fix(phase-1.5): coalesce concurrent loadData() calls
e53587d fix(phase-1.4): serialize closeDatabase with in-flight writes
1cc97a6 fix(phase-1.3): replace Navigator.pushNamed with typed PremiumPageRoute
d182410 fix(phase-1.2): _pruneDistantMonths preserves the real current month
15d6485 fix(phase-1.1): useTemplate must not auto-pay templated expense
a231db4 feat(phase-5/wip): Luminous design integration starter
5c061b0 docs(plan): Phase 0 pre-flight — master plan + baseline
```

---

## This session — what landed

Four thematic commits closing the highest-leverage non-Phase-5 work in the plan, plus an APK build verifying the new dependencies compile on Android:

### 1. `d8f67b8 feat(phase-2.3): bundle Hanken Grotesk variable font`
- Downloaded `HankenGrotesk[wght].ttf` directly from `github.com/google/fonts` and renamed to `HankenGrotesk-Variable.ttf` under `assets/fonts/HankenGrotesk/`.
- Replaced `GoogleFonts.hankenGrotesk(...)` in `lib/theme/luminous_app_theme.dart` with a plain `TextStyle` that drives the `wght` axis via `FontVariation('wght', w.value.toDouble())`.
- Dropped `google_fonts: ^6.2.1` from `pubspec.yaml`.
- Single ~130 KB asset replaces the package + runtime download. Cold launch on airplane mode now renders Hanken Grotesk instead of Roboto.

### 2. `ce637e7 feat(phase-6): FLAG_SECURE + crash log PII redactor (6.5, 6.6)`
- **6.5 FLAG_SECURE.** `MainActivity` registers a second method channel (`budget_tracker/secure_window`) that toggles `WindowManager.LayoutParams.FLAG_SECURE` on the UI thread. New `SecureWindow` Dart helper exposes `setSecure(bool)` / `syncFromPinState()`. Wired from `AppState.initializeLockState` (cold start) and `PinSetupScreen` (immediate, after successful setup). Settings-screen disable path was already covered via `initializeLockState`. **No external plugin added** — pure platform channel.
- **6.6 PII redactor.** `CrashLog.redactPii` strips Windows + Unix user paths, email addresses, currency-tagged amounts ($/€/£/¥/₹), and credit-card-shaped digit runs from every persisted record. Applied to error, stack, context, and platform strings inside `_formatRecord`. Plain numeric IDs and timestamps stay verbatim.
- +14 tests (8 redactor + 6 secure window).

### 3. `3a290ed feat(phase-6.2): move PIN hash/salt + counters to flutter_secure_storage`
- New `lib/utils/secure_prefs.dart` wraps `flutter_secure_storage` (Keystore on Android, Keychain on iOS, `encryptedSharedPreferences` as soft fallback) with lazy migration from `SharedPreferences`. On every successful migration the legacy entry is scrubbed; if the secure write fails the legacy entry stays intact so the next read can retry.
- `PinSecurityHelper` routes every read/write through `SecurePrefs`. Public API unchanged.
- Migrated keys: `app_pin_hash`, `app_pin_salt`, `pin_enabled`, `pin_length`, `pin_failed_attempts`, `pin_lockout_until`.
- Added `flutter_secure_storage: ^9.2.2` to `pubspec.yaml`.
- +16 tests (10 SecurePrefs + 6 PinSecurityHelper round-trip via mocked channel).
- **Open verification**: the migration is unit-tested end-to-end but has not run on a real Keystore. The commit message documents the smoke-test recipe.

### 4. `eaec0ee feat(phase-8.1): preflight script + forbidden-patterns lint test`
- `scripts/preflight.sh` (Bash, executable) + `scripts/preflight.ps1` (PowerShell port). Run `flutter analyze` → `flutter test` → forbidden-pattern grep sweep.
- `test/lint/no_forbidden_patterns_test.dart`: one test per rule — no `withOpacity(` / `print(` / `GoogleFonts` / `import '../main.dart'` / `package:budget_tracker/` self-imports in `lib/`.
- +5 tests.

### APK build verification
- `flutter build apk --release` succeeded after Phase 6.2 added the native `flutter_secure_storage` plugin. APK lives at `build/app/outputs/flutter-apk/app-release.apk`, 59.2 MB. The 3 obsolete-`source/target=8` Java warnings come from upstream plugins and are not action items here.

**Totals**: `flutter analyze` clean; 1,720 tests pass (was 1,685, +35 this session).

---

## Active deviations from the plan

1. **DD-001** (`docs/DESIGN_DEVIATIONS.md`) — blur sigma reduced from 25 → 15 for the 16.7 ms/frame budget on Pixel 4a. Documented during Phase 1.7.
2. **DD-002** — `Spacing.*` constants are NOT marked `@Deprecated` per the plan's letter. 757 call sites would each emit a `deprecated_member_use_from_same_package` warning, breaking the "No issues found" analyzer baseline. The values are realigned (`screenPadding` 24→20, `cardPadding` 20→24) so the migration is mechanical; Phase 5 will inline + delete the file.
3. **Phase 2.3 implemented as a variable font** — the plan called for four static TTFs (`HankenGrotesk-Regular`, `-SemiBold`, `-Bold`, `-ExtraBold`). The repo `github.com/google/fonts/ofl/hankengrotesk/` only ships the variable axis font, so we register one ~130 KB asset and drive the `wght` axis via `FontVariation` in `TextStyle`. Net APK size impact is smaller than the four-file approach; runtime weight selection is identical.
4. **Phase 3.8 deferred** — `AppPhase` state machine refactor explicitly deferred to v5.1 per the plan's "(Optional, defer if time-pressed)" note.
5. **Phase 4.12 scope** — written as v18 → v19 (not v3 → v19). The v3 → v18 chain is exercised by every production upgrade; rebuilding it by hand only to drive it through already-tested migrations adds churn without coverage. Test is in `test/integration/migration_v18_to_v19_test.dart`.
6. **Phase 6.5 implemented without `flutter_windowmanager`** — the plan called out the plugin by name, but FLAG_SECURE only needs four lines of Kotlin and a method channel. Skipping the plugin saves a transitive dep and keeps the toggle pinned to this codebase's lifecycle conventions.
7. **Phase 6.1 (SQLCipher) deferred** — flagged as "high risk, needs device validation" in the master plan. Not started this session; the next session should do it under a real-device round-trip before merging.
8. **Phase 8.4 (version bump to 5.0.0+1) deliberately held** — the headline change for the major-version jump is the Luminous redesign (Phase 5), and that's still WIP. Bumping now would mis-label the release. The session that closes Phase 5 should also do 8.4 + 8.5.

---

## What "Phase 5+" looks like

### Phase 5 — Luminous Design Integration (5–8 days remaining)
Each screen is a per-screen redesign that uses the Luminous widget library shipped in Phase 2.4 (`lib/widgets/luminous/`). The starter commit `a231db4` already wired the 5-tab navigation. Remaining work — one commit per screen so review stays tractable:

- 5.1 Settings & Security screen
- 5.2 Wallet & Accounts (rename `account_manager_screen.dart` → `wallet_screen.dart`)
- 5.3 Budgets & Planning
- 5.4 Analytics & Insights
- 5.5 Add Transaction — **STRUCTURAL CHANGE**: merges add_expense + add_income + hub
- 5.6 Transaction History — split into `lib/screens/history/`
- 5.7 Recurring Items — **STRUCTURAL CHANGE**: merge recurring_expenses + recurring_income
- 5.8 Home Dashboard polish
- 5.9 Secondary screens (onboarding, PIN, crash, export, trash, category mgr)
- Brand alignment: "FinanceFlow" label everywhere

Hanken Grotesk is now bundled (Phase 2.3 done this session), so every Phase 5 screen will render with the correct typography from the first commit.

### Phase 6 remainder — Security (1–2 days)
- 6.1 SQLCipher migration — adds `sqflite_sqlcipher` dep, generates per-install key in `flutter_secure_storage`, wraps existing DB. **Needs device validation.**
- 6.3 Backup file AES-GCM + passphrase
- 6.4 Home widget redaction when PIN enabled

### Phase 7 — Test Coverage Rebuild (3–4 days)
Mostly additive — rename mislabeled `app_state_logic_test.dart`, build real logic tests for every public AppState mutator, 8 hero-screen widget tests, 8 golden tests, `Clock` injection, CI gate that `flutter test` must pass with count ≥ baseline + 50.

### Phase 8 remainder — Polish & Ship (0.5–1 day)
- 8.2 Final perf pass on real device
- 8.4 Version bump `pubspec.yaml` → `5.0.0+1`, CHANGELOG entry, tag `v5.0.0+1`
- 8.5 Ship pipeline (build, copy to landing, push, `vercel --prod --yes` — see `CLAUDE.md` for the exact commands)

---

## Next session — exact steps to resume

### Step 0: Situate yourself (2 min)

```bash
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git checkout release/v5.0.0   # already here
git log --oneline -16         # confirm eaec0ee is at the tip
bash scripts/preflight.sh     # analyze + 1,720 tests + forbidden-pattern sweep
```

Read this file plus `docs/CHECKLIST.md`. The master plan has the full "why" for each phase.

### Step 1: Smoke-test Phase 6.2 on a real device

The PIN secure-storage migration is unit-tested but unproven on Keystore. Before going further:

1. Install the previously-shipped APK (any v4.x build) on a test device.
2. Set a PIN.
3. Force-stop the app, sideload the new APK from `build/app/outputs/flutter-apk/app-release.apk`.
4. Open the app — the existing PIN must still verify on the first attempt.
5. `adb shell run-as com.moneytracker.app cat shared_prefs/FlutterSharedPreferences.xml` must NOT contain `app_pin_hash` or `app_pin_salt`.

If anything goes wrong, revert commit `3a290ed` and re-plan the migration.

### Step 2: Start Phase 5

Read `docs/MASTER_PLAN.md` Phase 5.1, then either:
- Ask the next-session agent for "5.1 — Settings & Security redesign" (one commit), or
- Ask for "Phase 5" and the agent will work through all 9 screens autonomously.

Each redesign should:
1. Use components from `lib/widgets/luminous/`.
2. Drop `Spacing.*` calls in favor of `LuminousTokens.*`.
3. Inline values where Phase 5 says to inline them (the plan calls those out).
4. Commit as a single thematic commit per screen.

### Step 3: Phase 6 remainder + Phase 7 in parallel

6.1 SQLCipher needs device validation per the plan. 6.3 (backup AES-GCM) and 6.4 (widget redaction) are mechanical. Phase 7 is additive coverage work that doesn't block Phase 5 — could run in parallel.

### Step 4: Ship

After Phase 5 + Phase 6 remainder + at least the Phase 7 minimums:
1. Run `bash scripts/preflight.sh`. Must be green.
2. Phase 8.2 manual perf pass on real device.
3. Phase 8.4 bump to `5.0.0+1` + CHANGELOG.
4. Phase 8.5 ship pipeline (see `CLAUDE.md` `## Shipping the APK`).

---

## Known issues to watch for in next session

1. **Phase 6.2 migration unverified on real Keystore.** See Step 1 above.
2. **`google_fonts` removal also touched `pubspec.lock` indirectly via `flutter pub get`.** If any future PR adds a different transitive dep that previously came via `google_fonts`, it'll now have to be added explicitly.
3. **Variable font wght axis** — `lib/theme/luminous_app_theme.dart` now sets both `fontWeight` and `fontVariations: [FontVariation('wght', w.value.toDouble())]`. If you ever swap to a non-variable font, drop the `fontVariations` line — leaving it harmless but redundant.
4. **`MonthlyBalance.fromMap` YYYY-MM handling** (from prior session) — after Phase 4.8, `toMap` writes `YYYY-MM` and `fromMap` expands it back to `YYYY-MM-01` for parsing. If a future change touches either side, keep them in sync.
5. **`_upsertMonthlyBalanceTxn` lookup uses `LIKE 'YYYY-MM%'`** — this matches both pre- and post-migration rows. If you tighten back to `=`, the next pre-migration row encountered will create a duplicate and trip the UNIQUE constraint.
6. **`Expense.tryFromMap` / `Income.tryFromMap`** — Phase 4.10 bulk-read paths swallow corrupt rows with a `debugPrint`. If you see `DatabaseHelper: skipping corrupt expense row id=N` on a real device, that's an actual data corruption — investigate the row.
7. **Two `MainActivity.kt` files exist** — the canonical one at `com/moneytracker/app/MainActivity.kt` (loaded by `namespace` in `build.gradle.kts`) and a dead-code template at `com/example/budget_tracker/MainActivity.kt`. The orphan is harmless but should be deleted in a future cleanup commit.

---

## Architecture decisions (cumulative)

- **Theme**: `AppColors` ThemeExtension lives in `lib/theme/app_colors.dart`. `LuminousTokens` lives in `lib/theme/luminous_tokens.dart` and is the single source of truth. `Spacing.*` aliases through `LuminousTokens` for now (Phase 5 will inline). Hanken Grotesk is now bundled as a variable font asset (~130 KB) at `assets/fonts/HankenGrotesk/HankenGrotesk-Variable.ttf`.
- **Widget library**: `lib/widgets/luminous/` contains 9 components (glass_panel, glass_top_app_bar, glass_segmented_control, glass_pill_chip, glass_list_section, glass_list_tile, glass_progress_bar, glass_donut_chart, glass_bar_chart, category_bento_grid). Phase 5 swaps every hand-rolled equivalent.
- **State management**: Provider. AppState exposes `onRecurringBatch` and `onAccountSwitch` broadcast streams (Phase 3) replacing flag-based patterns. `notificationHelper` getter on AppState (Phase 2.7) is the canonical accessor.
- **Database**: schema v19 (Phase 4). FK cascades on every trash table; junction-cleanup triggers on hard-delete; YYYY-MM month-keys; pre-migration `.v18-backup` lives next to the active DB if a future migration needs to roll back. All multi-step deletes wrapped in `db.transaction`.
- **Models**: `*.fromMap` is strict — throws on missing required fields. `*.tryFromMap` is the non-throwing variant for bulk reads. Snake_case keys only (no `accountId` fallback).
- **Security**: `android:allowBackup="false"` + custom data extraction rules (Phase 1.9). `FLAG_SECURE` toggled from Dart when PIN is configured (Phase 6.5). PIN hash + salt + counters now live in Keystore-backed `flutter_secure_storage` with lazy migration from `SharedPreferences` (Phase 6.2). Crash log records are PII-redacted before persistence (Phase 6.6). Notifications use `NotificationVisibility.private` (Phase 1.10).
- **CI gate**: `scripts/preflight.sh` runs analyze + tests + forbidden-pattern grep. The structural lint suite under `test/lint/` runs as part of `flutter test`.

---

**End of handoff. Good luck, future-us.**
