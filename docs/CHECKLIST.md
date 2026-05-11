# Money Tracker → FinanceFlow — Master Plan Checklist

Per-task tracker for [MASTER_PLAN.md](MASTER_PLAN.md). Tick boxes as items land.

**Convention:** Each Phase 1 fix is a single commit. Phases 2–8 group related work into thematic commits.

---

## Phase 0 — Pre-flight

- [x] 0.1 Create `release/v5.0.0` branch off `main`
- [ ] 0.2 Snapshot DB from real device → `dist/baseline/v4.4.0+6.db` *(skipped — no device attached this session)*
- [x] 0.3 `flutter test` post-Phase 1 → `dist/baseline/test-post-phase1.txt` (1,661 pass, +18 from baseline)
- [x] 0.4 `flutter analyze` baseline → `dist/baseline/analyze-baseline.txt` (No issues found, 257.6s)
- [ ] 0.5 `flutter build apk --release --analyze-size` → `dist/baseline/size.json` *(deferred — long run)*
- [ ] 0.6 Performance Overlay screenshots *(manual, skipped)*
- [x] 0.7 Move `lib/screens/backup_restore_screen.dart.backup` → `TRASH/`
- [x] 0.8 Create `MASTER_PLAN.md` + this `CHECKLIST.md`
- [x] **Phase 0 baseline commit** — WIP Phase 5 starter committed separately

---

## Phase 1 — Stop the Bleeding (10 critical fixes)

Each lands as its own commit with regression test.

- [x] 1.1 useTemplate auto-pay (`app_state.dart:1594` — `amountPaid: Decimal.zero`) + 2 tests in `test/integration/app_state_use_template_test.dart`
- [x] 1.2 `_pruneDistantMonths` month-key padding (`app_state.dart:558` — use `_monthKey(now)`) + test in `test/integration/app_state_prune_test.dart`
- [x] 1.3 Replace `Navigator.pushNamed` to unregistered routes + structural lint test
  - [x] `history_screen.dart:2239` `/add_expense` → `PremiumPageRoute(page: AddExpenseScreen())`
  - [x] `history_screen.dart:2251` `/add_income` → `PremiumPageRoute(page: AddIncomeScreen())`
  - [x] `add_hub_screen.dart:72` `/budgets` → `PremiumPageRoute(page: BudgetScreen())`
  - [x] `analytics_screen.dart:934` `/budgets` → same (bonus consistency fix)
  - [x] `test/lint/no_unregistered_pushnamed_test.dart` enforces the rule going forward
- [x] 1.4 HomeWidget vs DB close lifecycle race — `main.dart` paused-state awaits via `_handlePaused`; `app_state.dart:closeDatabase` now wrapped in `_writeMutex.synchronized` + 2 tests (behavioural smoke + structural guard) in `test/integration/app_state_close_database_race_test.dart`
- [x] 1.5 Coalesce `loadData()` re-entrancy — `_loadingFuture ??= _loadDataInternal()...whenComplete(...)` + `loadDataInternalRunCount` test seam + 2 tests in `test/integration/app_state_load_data_coalesce_test.dart`
- [x] 1.6 Wrap `addExpense`/`addIncome` + carryover in single tx — new `DatabaseHelper.createExpenseWithCarryover` / `createIncomeWithCarryover` use `db.transaction`; AppState pre-computes balances via new `_computeCarryoverForMonth` / `_prepareCarryoverUpserts`; 3 tests in `test/integration/database_helper_atomic_add_test.dart` (commit-success + rollback-on-FK-fail for both expense and income)
- [x] 1.7 Blur sigma 25→15 + RepaintBoundary nav/transactions + `docs/DESIGN_DEVIATIONS.md` DD-001 + 3 structural tests in `test/lint/glass_blur_perf_test.dart`
- [x] 1.8 Mounted check + generation token after `_fadeController.reverse` (`main.dart`) + structural test in `test/lint/fade_controller_mounted_check_test.dart`
- [x] 1.9 AndroidManifest hardening — `allowBackup="false"`, `fullBackupContent="false"`, `dataExtractionRules="@xml/data_extraction_rules"` + new `data_extraction_rules.xml` (deny cloud-backup + device-transfer) + 2 structural tests in `test/lint/android_manifest_hardening_test.dart`
- [x] 1.10 Notification lock-screen redaction — `visibility: NotificationVisibility.private` on all 4 `AndroidNotificationDetails` (bill reminders, budget alerts, scheduled monthly summary, immediate monthly summary) + structural test in `test/lint/notification_visibility_test.dart`

**Phase 1 gate:** ✅ all 10 commits land; build green (`flutter analyze` = No issues); +18 regression tests across 9 new test files (1,661 total, up from 1,643).

---

## Phase 2 — Architectural Foundations

- [x] 2.1 Move `AppColors` → `lib/theme/app_colors.dart` (21 lib + 2 test import sites updated)
- [x] 2.2 Consolidate spacing/sizing tokens → `lib/theme/luminous_tokens.dart` (+`Spacing.*` realigned; `@Deprecated` swap deferred to Phase 5 — see DD-002)
- [x] 2.3 Bundle Hanken Grotesk as variable TTF (`assets/fonts/HankenGrotesk/HankenGrotesk-Variable.ttf`); `GoogleFonts.hankenGrotesk(...)` → `TextStyle` with explicit `FontVariation('wght', …)`; `google_fonts` dep removed. Single ~130 KB asset replaces ~150 KB package + runtime download.
- [x] 2.4 Luminous component library skeleton (`lib/widgets/luminous/`) — `glass_surface.dart` shimmed to `glass_panel.dart`; 8 new components (top app bar, segmented control, pill chip, list section, list tile, progress bar, donut chart, bar chart, bento grid) with 9 smoke tests
- [x] 2.5 Kill `history_screen` `context.watch<AppState>` (narrow `select`s) + `test/lint/no_global_appstate_watch_test.dart` enforcement
- [x] 2.6 `_appVersion` from `pubspec.yaml` via `package_info_plus` — `_resolveAppVersion()` in `main.dart`
- [x] 2.7 `NotificationHelper` singleton via `AppState` — `AppState.notificationHelper` getter; `notification_settings_screen` rewired; `test/lint/notification_helper_singleton_test.dart` enforcement

**Phase 2 gate:** `grep "import '../main.dart'" lib/` = 0 ✅; airplane-mode font check deferred with 2.3; `flutter analyze` clean; 1,673 tests pass (+12).

---

## Phase 3 — Race & Lifecycle Correctness

- [x] 3.1 Notification payload queue (TOCTOU) — `consumePendingPayloads()` drains a JSON-array queue + legacy single-slot migration + de-dup loop in `_checkPendingNotification` + resume-time re-check; 16 unit tests
- [x] 3.2 Recurring snackbar flag reset → `onRecurringBatch` broadcast stream + subscription in `MainNavigationScreen`; 2 integration tests
- [x] 3.3 PIN lock timer + `FocusManager.instance.addListener(_onFocusEvent)` in `MainNavigationScreen` covers keyboard focus changes that bypass `GestureDetector`
- [x] 3.4 `accountJustSwitched` → `onAccountSwitch` broadcast stream + subscription in `MainNavigationScreen` (boolean + `clearAccountSwitchFlag` removed)
- [x] 3.5 `HomeWidgetHelper.dispose()` moved from `_closeDatabaseSafely` (detached) → `_handlePaused` (paused) + idempotent guard at top of `initialize()`; back-compat call retained in detached for OS variations
- [x] 3.6 `_performBackgroundMaintenance` + `_handlePaused` post-await `mounted` / `context.mounted` checks
- [x] 3.7 `_checkPendingNotification` re-check `mounted && context.mounted` immediately before each `Navigator.push`
- [ ] 3.8 (Optional, deferred to v5.1) `AppPhase` state machine

---

## Phase 4 — Schema v19 + Data Integrity

- [x] 4.1 Pre-migration backup hook — `.v18-backup` file alongside the live DB; auto-cleaned on success, left for manual recovery on failure
- [x] 4.2 Migration v19: trash table FKs — `deleted_expenses` + `deleted_income` rebuilt via SQLite "12-step alter" with `FOREIGN KEY (account_id) … ON DELETE CASCADE`
- [x] 4.3 Migration v19: cascade v4 tables — `income`, `quick_templates` rebuilt only when `_tableHasAccountCascade` returns false (skip when already correct)
- [x] 4.4 Migration v19: junction cleanup triggers — `trg_transaction_tags_cleanup_expense` + `_income` cover hard-deletes
- [x] 4.5 Soft-delete junction cleanup — `moveToDeleted`, `moveIncomeToDeleted`, `moveToDeletedById`, `moveIncomeToDeletedById`, `bulkDeleteTransactionsByCategory`, `bulkDeleteTransactionsAndCategory` all clean `transaction_tags` before deleting the live row
- [x] 4.6 Wrap `emptyTrash` + `clearOldDeleted` in `db.transaction`
- [x] 4.7 `moveToDeletedById` + `moveIncomeToDeletedById` rewritten so read+insert+delete happen inside a single transaction (uses `Expense.tryFromMap` so corrupt rows are skipped instead of half-deleted)
- [x] 4.8 `monthly_balances.month` normalised to YYYY-MM — `MonthlyBalance.toMap` writes the month key; migration does `UPDATE … SET month = substr(month, 1, 7)`; `_upsertMonthlyBalanceTxn` lookup uses `LIKE 'YYYY-MM%'` so it hits both pre- and post-migration rows; `MonthlyBalance.fromMap` expands YYYY-MM → YYYY-MM-01 before parsing
- [x] 4.9 `restoreFromJsonBackup` input validation — `_isValidAmount`, `_isValidBackupDate`, `_isValidDescription` gate expense/income/budget/recurring/template inserts; `rowsSkipped` counter on `BackupRestoreStats`; `transaction_tags` round-trip with `expenseIdMap` / `incomeIdMap` / `tagIdMap`; backup export bumped to `version: 3` and includes `transaction_tags`
- [x] 4.10 `Expense.fromMap` strict validation — throws on missing `category` or `account_id` (matches `Income.fromMap`); `Expense.tryFromMap` + `Income.tryFromMap` non-throwing variants; `DatabaseHelper._parseExpenseRows` / `_parseIncomeRows` swap the 7 bulk-read sites
- [x] 4.11 Remove `accountId` dual-key in `Budget.fromMap` / `MonthlyBalance.fromMap` — snake-case only; throw on missing field
- [x] 4.12 v18→v19 integration test — `test/integration/migration_v18_to_v19_test.dart` seeds 5 expenses / 3 income / 2 budgets / 2 recurring / 1 template / 2 tags / 3 transaction_tags / 1 monthly_balances, runs the upgrade, asserts row counts preserved, month-key normalised, trash-table FKs installed, cleanup trigger fires on hard delete, account cascade reaches trash tables. (Scope tightened from "v3→v19" because the v3→v18 chain is exercised by every production upgrade already — see the test's preamble.)

**Phase 4 gate:**
- `flutter analyze` — No issues found.
- `flutter test` — 1,685 pass (+1 migration test; +0 from other waves which amended existing tests).
- `DatabaseConstants.databaseVersion` = 19.

---

## Phase 5 — Luminous Design Integration

- [x] **Phase 5 starter (WIP from previous session)** — `MainNavigationScreen` nav rewired (5 tabs), Home redesigned, AddHub/Analytics/AccountManager screens scaffolded, `buildLuminousTheme` in place
- [ ] 5.1 Settings & Security screen
- [ ] 5.2 Wallet & Accounts (rename `account_manager_screen.dart` → `wallet_screen.dart`)
- [ ] 5.3 Budgets & Planning
- [ ] 5.4 Analytics & Insights
- [ ] 5.5 Add Transaction (STRUCTURAL: replaces hub + merges add_expense/add_income)
- [ ] 5.6 Transaction History (split into `lib/screens/history/`)
- [ ] 5.7 Recurring Items (STRUCTURAL: merge expenses + income)
- [ ] 5.8 Home Dashboard polish
- [ ] 5.9 Secondary screens (onboarding, PIN, crash, export, trash, category mgr, etc.)
- [x] **5.10 Brand alignment** — AndroidManifest `android:label="FinanceFlow"`; every "Money Tracker" string in `lib/` rebranded (backup/CSV/PDF subjects, crash log header, schema-upgrade snackbar, pin unlock title, settings about line); crash_log_test expectation updated. `grep -rn "Money Tracker" lib/` = 0.

---

## Phase 6 — Security Hardening

- [ ] 6.1 SQLCipher migration (`sqflite_sqlcipher`) — deferred; needs device validation per master plan
- [x] 6.2 PIN hash + salt + counters → `flutter_secure_storage` via new `SecurePrefs` wrapper; lazy migration from `SharedPreferences` on first read; 16 tests across `secure_prefs_test.dart` + `pin_security_storage_test.dart`
- [x] **6.3 Backup AES-GCM + passphrase (crypto layer)** — `lib/utils/backup_crypto.dart` wraps `package:cryptography ^2.7.0` for 256-bit AES-GCM + PBKDF2-HMAC-SHA256 @ 100k iterations. Produces v4 envelope `{version, encrypted, salt, iv, ciphertext, tag}`. `decrypt` returns null on any failure (wrong passphrase, malformed JSON, tampered ciphertext, wrong salt) — never throws, never silently returns wrong plaintext. 15 tests. **UX wiring (passphrase prompt in backup_restore_screen) deliberately deferred — needs device verification.**
- [x] **6.4 Home widget redaction when PIN enabled** — `lib/utils/widget_payload.dart` (pure functions); `WidgetPayload.redactIfLocked` swaps monetary fields for `•••` and month label for `Locked`. Currency code + `isPositive` accent stay verbatim so the widget layout doesn't shift on toggle. `home_widget_helper.dart` consults `PinSecurityHelper.isPinEnabled()` before publishing. Side-fix: `home_widget_helper_test.dart` now seeds `SharedPreferences.setMockInitialValues` so the SecurePrefs fallback doesn't `MissingPluginException` the whole pipeline. 6 tests.
- [x] 6.5 `FLAG_SECURE` via native method channel — `MainActivity` registers `budget_tracker/secure_window`; `SecureWindow` Dart helper toggles the flag; wired from `AppState.initializeLockState` (cold start) + `PinSetupScreen` (after successful setup). No external plugin needed. 6 tests.
- [x] 6.6 Crash log PII redactor — `CrashLog.redactPii` masks Windows/Unix user paths, emails, currency-tagged amounts, and credit-card-shaped digit runs before every record is persisted. 8 tests.

---

## Phase 7 — Test Coverage Rebuild

- [ ] 7.1 Rename mislabeled `app_state_logic_test.dart` — DEFERRED. File actually tests `CurrencyHelper` + `DatabaseConstants`; the spec's `app_state_smoke_test` rename is misleading and a no-op without 7.2 brings no value.
- [ ] 7.2 Real `app_state_logic_test.dart` (every public mutator) — DEFERRED. ~30 mutators, ~1 day of focused work.
- [x] **7.3 Real `onboarding_service_test.dart`** — new file at `test/services/onboarding_service_test.dart`; 8 tests cover the full SharedPreferences round-trip (fresh-install false, post-complete true, persists across instances, reset works, isFirstLaunch self-extinguishes, completeOnboarding idempotency).
- [x] 7.4 Migration test (covered in 4.12)
- [x] **7.5 Cascade delete integration test** — new `test/integration/cascade_delete_test.dart`; 5 tests pin: `moveToDeletedById` scrubs `transaction_tags` before moving (Phase 4.5), same for income, hard-delete triggers fire (Phase 4.4), `emptyTrash` is account-scoped.
- [ ] 7.6 Screen tests for 8 hero screens — DEFERRED until Stage B hero redesigns land.
- [x] **7.7 PIN lockout flow under FakeClock** — new `test/utils/pin_lockout_test.dart`; 5 tests drive the 5-minute window in sub-second wall time via Clock injection: correct PIN clears counter, 5 wrongs arm lockout, countdown reflects clock, isLockedOut self-heals after expiry, mid-streak correct PIN resets.
- [ ] 7.8 Golden tests for 8 hero screens — DEFERRED. Platform-sensitive and depends on Stage B.
- [x] **7.9 `Clock` injection** — new `lib/utils/clock.dart` (`Clock` + `FakeClock.fixed` + `FakeClock.sequence`). 20 `DateTime.now()` call sites migrated across `validators.dart` (7), `notification_helper.dart` (2), `home_widget_helper.dart` (1), `pin_security_helper.dart` (3), `app_state.dart` (7). UI/export code paths intentionally left on `DateTime.now()` per spec rationale. 5 tests.
- [x] **7.10 CI test-count gate** — `scripts/preflight.sh` + `.ps1` parse the `+N: All tests passed!` trailer and fail when N drops below `$TEST_COUNT_MIN` (1750). Catches silent coverage drops.

---

## Phase 8 — Polish & Ship

- [x] 8.1 `scripts/preflight.sh` + `scripts/preflight.ps1` + `test/lint/no_forbidden_patterns_test.dart` (5 grep rules: no `withOpacity(` / `print(` / `GoogleFonts` / `import '../main.dart'` / `package:budget_tracker/` self-import in lib/)
- [ ] 8.2 Final perf pass on real device
- [x] 8.3 APK build verified — `flutter build apk --release` succeeds, 59.2 MB, includes `flutter_secure_storage` native plugin. Smoke test on real device still required before tagging.
- [ ] 8.4 Version bump → `5.0.0+1`, CHANGELOG entry, tag `v5.0.0+1` (held until Phase 5 design integration lands — bumping to 5.0.0 without it would misrepresent the release)
- [ ] 8.5 Ship pipeline (build, copy to landing, push, `vercel --prod --yes`)

---

## Out of v5.0.0 (deferred to v5.1)

- AppState god-object split (TransactionService, BudgetService, SettingsService)
- DatabaseHelper per-domain repos
- Money as INTEGER cents (schema v20)
- AppPhase state machine
- Optional FTS5 for `searchExpenses`
