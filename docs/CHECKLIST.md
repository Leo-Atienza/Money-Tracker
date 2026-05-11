# Money Tracker → FinanceFlow — Master Plan Checklist

Per-task tracker for [MASTER_PLAN.md](MASTER_PLAN.md). Tick boxes as items land.

**Convention:** Each Phase 1 fix is a single commit. Phases 2–8 group related work into thematic commits.

---

## Phase 0 — Pre-flight

- [x] 0.1 Create `release/v5.0.0` branch off `main`
- [ ] 0.2 Snapshot DB from real device → `dist/baseline/v4.4.0+6.db` *(skipped — no device attached this session)*
- [ ] 0.3 `flutter test` baseline → `dist/baseline/test-baseline.txt` *(deferred — long run; will capture before Phase 1 ends)*
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
- [ ] 1.8 Mounted check after `_fadeController.reverse` (`main.dart:527`)
- [ ] 1.9 AndroidManifest hardening (`allowBackup="false"` + dataExtractionRules)
- [ ] 1.10 Notification lock-screen redaction (`notification_helper.dart`)

**Phase 1 gate:** all 10 commits land; build green; +10 regression tests.

---

## Phase 2 — Architectural Foundations

- [ ] 2.1 Move `AppColors` → `lib/theme/app_colors.dart` (21 import sites updated)
- [ ] 2.2 Consolidate spacing/sizing tokens → `lib/theme/luminous_tokens.dart` (+deprecate `Spacing.*`)
- [ ] 2.3 Bundle Hanken Grotesk as asset (remove `google_fonts`)
- [ ] 2.4 Luminous component library skeleton (`lib/widgets/luminous/`)
- [ ] 2.5 Kill `history_screen` `context.watch<AppState>` (narrow `select`s)
- [ ] 2.6 `_appVersion` from `pubspec.yaml` via `package_info_plus`
- [ ] 2.7 `NotificationHelper` singleton via `AppState`

**Phase 2 gate:** `grep "import '../main.dart'" lib/` = 0; `grep "GoogleFonts" lib/` = 0; airplane-mode font correct.

---

## Phase 3 — Race & Lifecycle Correctness

- [ ] 3.1 Notification payload queue (TOCTOU)
- [ ] 3.2 Recurring snackbar flag reset (or one-shot stream)
- [ ] 3.3 PIN lock timer + FocusManager hook
- [ ] 3.4 `accountJustSwitched` → one-shot stream
- [ ] 3.5 HomeWidgetHelper dispose on `paused`
- [ ] 3.6 `_performBackgroundMaintenance` post-await mounted checks
- [ ] 3.7 `_checkPendingNotification` re-check before push
- [ ] 3.8 (Optional, defer) AppPhase state machine

---

## Phase 4 — Schema v19 + Data Integrity

- [ ] 4.1 Pre-migration backup hook
- [ ] 4.2 Migration v19: trash table FKs
- [ ] 4.3 Migration v19: cascade v4 tables (`income`, `quick_templates`)
- [ ] 4.4 Migration v19: junction cleanup triggers
- [ ] 4.5 Soft-delete junction cleanup
- [ ] 4.6 Wrap `emptyTrash` + `clearOldDeleted` in tx
- [ ] 4.7 `moveToDeletedById` read inside tx
- [ ] 4.8 `monthly_balances` month-key normalization
- [ ] 4.9 `restoreFromJsonBackup` input validation
- [ ] 4.10 `Expense.fromMap` strict validation
- [ ] 4.11 Remove `accountId` dual-key in `Budget`/`MonthlyBalance.fromMap`
- [ ] 4.12 Migration v3→v19 integration test

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
- [ ] Brand alignment (FinanceFlow label everywhere)

---

## Phase 6 — Security Hardening

- [ ] 6.1 SQLCipher migration (`sqflite_sqlcipher`)
- [ ] 6.2 PIN hash → `flutter_secure_storage`
- [ ] 6.3 Backup file AES-GCM + passphrase
- [ ] 6.4 Home widget redaction when PIN enabled
- [ ] 6.5 `FLAG_SECURE` via `flutter_windowmanager`
- [ ] 6.6 Crash log PII redactor

---

## Phase 7 — Test Coverage Rebuild

- [ ] 7.1 Rename mislabeled `app_state_logic_test.dart`
- [ ] 7.2 Real `app_state_logic_test.dart` (every public mutator)
- [ ] 7.3 Real `onboarding_service_test.dart`
- [ ] 7.4 Migration test (covered in 4.12)
- [ ] 7.5 Cascade delete integration test
- [ ] 7.6 Screen tests for 8 hero screens
- [ ] 7.7 PIN lockout screen test
- [ ] 7.8 Golden tests for 8 hero screens
- [ ] 7.9 `Clock` injection in time-dependent code
- [ ] 7.10 CI gates (`flutter test` must pass; pass count ≥ baseline + 50)

---

## Phase 8 — Polish & Ship

- [ ] 8.1 Lint rules + `scripts/preflight.sh`
- [ ] 8.2 Final perf pass on real device
- [ ] 8.3 APK build + smoke test
- [ ] 8.4 Version bump → `5.0.0+1`, CHANGELOG entry, tag `v5.0.0+1`
- [ ] 8.5 Ship pipeline (build, copy to landing, push, `vercel --prod --yes`)

---

## Out of v5.0.0 (deferred to v5.1)

- AppState god-object split (TransactionService, BudgetService, SettingsService)
- DatabaseHelper per-domain repos
- Money as INTEGER cents (schema v20)
- AppPhase state machine
- Optional FTS5 for `searchExpenses`
