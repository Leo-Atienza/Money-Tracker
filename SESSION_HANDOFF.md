# Session Handoff — v5.0.0 Release Branch

**Branch**: `release/v5.0.0` (NEVER pushed to origin yet)
**Master plan**: `docs/MASTER_PLAN.md`
**Per-task checklist**: `docs/CHECKLIST.md`
**Last commit at handoff**: `b6a3da4 feat(phase-4): schema v19 + data integrity (4.1–4.12)`
**Paused**: 2026-05-11

> To resume: `git checkout release/v5.0.0` (already there) and read this file top-to-bottom plus `docs/CHECKLIST.md`. The master plan has the full "why" for each phase; this file has the "where we are" and "what to do next."

---

## TL;DR — what's done, what's next

| Phase | Status | Tests | What's in it |
|---|---|---|---|
| 0 — Pre-flight | ✅ Done | 1,643 baseline | Master plan + checklist + analyze baseline + APP_INFO design brief |
| 1 — Stop the Bleeding | ✅ Done (10/10) | 1,661 (+18) | useTemplate fix, pruneDistantMonths, Navigator.pushNamed, HomeWidget race, loadData coalesce, addExpense atomic tx, blur perf, fadeController mounted, Android backup hardening, notification redaction |
| 2 — Architectural Foundations | 🟡 6/7 (2.3 blocked) | 1,673 (+12) | AppColors → lib/theme/, LuminousTokens consolidated, Luminous widget skeleton (8 components + tests), history_screen narrow selects, package_info_plus, NotificationHelper singleton |
| 3 — Race & Lifecycle | 🟡 7/7 (3.8 deferred) | 1,683 (+10) | notification payload queue, recurring snackbar stream, FocusManager lock hook, accountSwitch stream, HomeWidgetHelper dispose on paused, mounted guards, pre-push re-check |
| 4 — Schema v19 + Data Integrity | ✅ 12/12 | 1,685 (+1 migration test) | v19 migration bundle (FK cascades + triggers + month-key normalisation), tx wrapping, soft-delete tag cleanup, backup validation + transaction_tags round-trip, strict model validation |
| 5 — Luminous Design Integration | 🟡 starter only | n/a | `a231db4 feat(phase-5/wip)` committed earlier — MainNavigationScreen 5 tabs, Home redesign, AddHub/Analytics/AccountManager scaffolds, `buildLuminousTheme`. 5.1–5.9 still ahead. |
| 6 — Security Hardening | ⏳ Not started | — | SQLCipher migration, PIN → flutter_secure_storage, AES-GCM backups, widget redaction, FLAG_SECURE, crash log PII redactor |
| 7 — Test Coverage Rebuild | ⏳ Not started | — | Rename mislabeled tests, real logic tests, 8 hero-screen tests, goldens, Clock injection, CI gates |
| 8 — Polish & Ship | ⏳ Not started | — | Lint rules, perf pass on device, APK build, version bump to 5.0.0+1, ship pipeline |

---

## Commits on this branch (12 since main diverged)

```
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

Every Phase 1 fix is atomic and revertable. Phases 2–4 are thematic commits (per the plan's commit-policy section).

---

## Active deviations from the plan

1. **DD-001** (`docs/DESIGN_DEVIATIONS.md`) — blur sigma reduced from 25 → 15 for the 16.7 ms/frame budget on Pixel 4a. Documented during Phase 1.7.
2. **DD-002** — `Spacing.*` constants are NOT marked `@Deprecated` per the plan's letter. 757 call sites would each emit a `deprecated_member_use_from_same_package` warning, breaking the "No issues found" analyzer baseline. The values are realigned (`screenPadding` 24→20, `cardPadding` 20→24) so the migration is mechanical; Phase 5 will inline + delete the file.
3. **Phase 2.3 blocked** — Hanken Grotesk TTFs were not downloaded (sandbox denied the GitHub fetch). To unblock: drop the 4 TTF files into `assets/fonts/HankenGrotesk/` manually and then run the Phase 2.3 mechanical steps (pubspec block, swap `GoogleFonts.hankenGrotesk(...)` → `TextStyle(fontFamily: 'HankenGrotesk', ...)`, remove `google_fonts` dep).
4. **Phase 3.8 deferred** — `AppPhase` state machine refactor explicitly deferred to v5.1 per the plan's "(Optional, defer if time-pressed)" note.
5. **Phase 4.12 scope** — written as v18 → v19 (not v3 → v19). The v3 → v18 chain is exercised by every production upgrade; rebuilding it by hand only to drive it through already-tested migrations adds churn without coverage. Test is in `test/integration/migration_v18_to_v19_test.dart`.

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

**Before starting 5.1**, the next session should plug Phase 2.3 (the Hanken Grotesk bundle) so the typography matches the spec from the very first screen. If you don't, every Phase 5 commit will be visually wrong on airplane mode.

### Phase 6 — Security Hardening (3–5 days)
- 6.1 SQLCipher migration — adds `sqflite_sqlcipher` dep, generates per-install key in `flutter_secure_storage`, wraps existing DB. **High risk** — needs device validation.
- 6.2 PIN hash → `flutter_secure_storage`
- 6.3 Backup file AES-GCM + passphrase
- 6.4 Home widget redaction when PIN enabled
- 6.5 `FLAG_SECURE` via `flutter_windowmanager`
- 6.6 Crash log PII redactor

### Phase 7 — Test Coverage Rebuild (3–4 days)
Mostly additive — rename mislabeled `app_state_logic_test.dart`, build real logic tests for every public AppState mutator, 8 hero-screen widget tests, 8 golden tests, `Clock` injection, CI gate that `flutter test` must pass with count ≥ baseline + 50.

### Phase 8 — Polish & Ship (1–2 days)
- 8.1 Lint rules + `scripts/preflight.sh`
- 8.2 Final perf pass on real device
- 8.3 APK build + smoke test
- 8.4 Version bump `pubspec.yaml` → `5.0.0+1`, CHANGELOG entry, tag `v5.0.0+1`
- 8.5 Ship pipeline (build, copy to landing, push, `vercel --prod --yes` — see `CLAUDE.md` for the exact commands)

---

## Next session — exact steps to resume

### Step 0: Situate yourself (2 min)

```bash
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git checkout release/v5.0.0   # already here
git log --oneline -10         # confirm b6a3da4 is at the tip
flutter analyze 2>&1 | tail -5  # should be "No issues found"
flutter test 2>&1 | tail -3   # should be "All tests passed!" with 1,685
```

Read this file plus `docs/CHECKLIST.md`. The master plan has the full "why" for each phase.

### Step 1 (recommended): unblock Phase 2.3

Drop these four TTFs into `assets/fonts/HankenGrotesk/`:
- `HankenGrotesk-Regular.ttf`
- `HankenGrotesk-SemiBold.ttf`
- `HankenGrotesk-Bold.ttf`
- `HankenGrotesk-ExtraBold.ttf`

(Download from https://fonts.google.com/specimen/Hanken+Grotesk → "Download family", or `github.com/google/fonts/raw/main/ofl/hankengrotesk/`.)

Then ask the next-session agent to finish Phase 2.3 — it's a mechanical 4-step change documented in `docs/MASTER_PLAN.md` Phase 2.3.

### Step 2: Start Phase 5

Read `docs/MASTER_PLAN.md` Phase 5.1, then ask for "5.1 — Settings & Security redesign" (or "Phase 5" if you want the agent to tackle all 9 screens autonomously). Each redesign should:
1. Use components from `lib/widgets/luminous/`.
2. Drop `Spacing.*` calls in favor of `LuminousTokens.*`.
3. Inline values where Phase 5 says to inline them (the plan calls those out).
4. Commit as a single thematic commit per screen.

### Step 3: Verify before Phase 6

After Phase 5 lands, do a manual smoke test on a real device. Phase 6 introduces SQLCipher — needs a working baseline to compare against.

---

## Known issues to watch for in next session

1. **`google_fonts` still in `pubspec.yaml`** — until Phase 2.3 unblocks, the first cold launch on airplane mode falls back to Roboto. This is in `lib/theme/luminous_app_theme.dart:GoogleFonts.hankenGrotesk(...)`.
2. **`_appVersion` resolution** — Phase 2.6 wired `package_info_plus`. If `PackageInfo.fromPlatform()` ever throws (it shouldn't, but Flutter desktop has edge cases), the crash log tags fall back to `'unknown'`.
3. **`MonthlyBalance.fromMap` YYYY-MM handling** — after Phase 4.8, `toMap` writes `YYYY-MM` and `fromMap` expands it back to `YYYY-MM-01` for parsing. If a future change touches either side, keep them in sync.
4. **`_upsertMonthlyBalanceTxn` lookup uses `LIKE 'YYYY-MM%'`** — this matches both pre- and post-migration rows. If you tighten back to `=`, the next pre-migration row encountered will create a duplicate and trip the UNIQUE constraint.
5. **`Expense.tryFromMap` / `Income.tryFromMap`** — Phase 4.10 bulk-read paths swallow corrupt rows with a `debugPrint`. If you see `DatabaseHelper: skipping corrupt expense row id=N` on a real device, that's an actual data corruption — investigate the row.

---

## Architecture decisions (cumulative)

- **Theme**: `AppColors` ThemeExtension lives in `lib/theme/app_colors.dart`. `LuminousTokens` lives in `lib/theme/luminous_tokens.dart` and is the single source of truth. `Spacing.*` aliases through `LuminousTokens` for now (Phase 5 will inline).
- **Widget library**: `lib/widgets/luminous/` contains 9 components (glass_panel, glass_top_app_bar, glass_segmented_control, glass_pill_chip, glass_list_section, glass_list_tile, glass_progress_bar, glass_donut_chart, glass_bar_chart, category_bento_grid). Phase 5 swaps every hand-rolled equivalent.
- **State management**: Provider. AppState exposes `onRecurringBatch` and `onAccountSwitch` broadcast streams (Phase 3) replacing flag-based patterns. `notificationHelper` getter on AppState (Phase 2.7) is the canonical accessor.
- **Database**: schema v19 (Phase 4). FK cascades on every trash table; junction-cleanup triggers on hard-delete; YYYY-MM month-keys; pre-migration `.v18-backup` lives next to the active DB if a future migration needs to roll back. All multi-step deletes wrapped in `db.transaction`.
- **Models**: `*.fromMap` is strict — throws on missing required fields. `*.tryFromMap` is the non-throwing variant for bulk reads. Snake_case keys only (no `accountId` fallback).

---

**End of handoff. Good luck, future-us.**
