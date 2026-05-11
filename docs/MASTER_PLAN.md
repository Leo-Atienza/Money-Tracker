# Money Tracker → FinanceFlow — Master Unification Plan

**Version:** 1.0 (2026-05-10)
**Author:** Multi-agent audit + ultrathink synthesis
**Target completion:** `v5.0.0+1` (single coordinated release)
**Source of design truth:** `C:\tmp\stitch_review\v1\stitch_money_tracker_redesign\`

---

## 0. Executive Summary

This plan unifies three streams of work into one coordinated release so we never have to chase the same bugs twice:

1. **Close all 60+ findings from the multi-agent audit** (10 critical, ~20 high, ~25 medium, ~15 low).
2. **Fully integrate the Luminous Glass design** across all 17 screens (currently 2/8 hero screens done).
3. **Rebuild test coverage** so behavioral % matches the file count — replace mislabeled tests, add screen + migration + cascade tests, inject `Clock` for time-dependent code.

The plan is sequenced so that **bugs in load-bearing code are fixed before screens that depend on it are redesigned**, and **structural moves (AppColors, tokens, routes) land before per-screen visual work** so each screen redesign is mechanical.

**Definition of done** (must all be true before tagging `v5.0.0`):
- Every CRITICAL and HIGH finding closed (MEDIUM/LOW triaged: fix, defer-with-issue, or accept-with-rationale).
- All 8 hero screens visually match `stitch_money_tracker_redesign/*/screen.png` (golden tests within 2% pixel diff tolerance).
- Behavioral test coverage: every public method on `AppState` and `DatabaseHelper` has at least one direct unit test; every screen has at least one widget test; migration v3→v19 has an integration test.
- Build: `flutter build apk --release` succeeds on Windows; APK opens, completes onboarding, adds an expense, takes a backup, restores it, locks/unlocks with PIN, all in under 30 seconds.
- Performance: 60 fps on Pixel 4a class device for Home scroll (verified via Flutter DevTools Performance overlay) — no `BackdropFilter` exceeding 8ms per frame.
- Security: `android:allowBackup="false"`, sqflite_sqlcipher in place, PIN hash in `flutter_secure_storage`, backup files encrypted with passphrase, notifications use `NotificationVisibility.private`, `FLAG_SECURE` enabled when PIN is on.
- Zero `Navigator.pushNamed` calls to unregistered routes (grep test in CI).
- Zero `context.watch<AppState>` calls outside opt-in widgets (lint rule).
- `_appVersion` derived from `pubspec.yaml` via `package_info_plus` — no hardcoded version string.

**Estimated effort:** ~32–38 person-days, split into 8 phases. A single developer working part-time should expect 7–10 weeks calendar. Each phase has a hard gate: tests + manual smoke before moving on.

---

## 1. Branch & Release Strategy

- **Trunk:** `main` (protected). Only merges from `release/v5.0.0` go here, and only after the whole plan is green.
- **Release branch:** `release/v5.0.0` — long-lived integration branch off `main` at the start of this work.
- **Phase branches:** `phase/0-preflight`, `phase/1-criticals`, etc. — short-lived, merged into `release/v5.0.0` after each phase's acceptance gate.
- **Tag at end of each phase:** `v5.0.0-phase1`, `v5.0.0-phase2`, … — gives a tagged rollback point.
- **APK retention:** every phase produces a build dropped at `dist/v5.0.0-phaseN.apk` for manual device smoke tests. Do **not** ship to the landing page until the whole plan is green and `v5.0.0+1` is tagged.

---

## 2. Phase 0 — Pre-flight (Day 1)

**Goal:** Repeatable baseline. Nothing in this phase changes runtime behavior.

| Task | File / Action | Acceptance |
|---|---|---|
| 0.1 Create `release/v5.0.0` branch off `main` | `git checkout -b release/v5.0.0` | Branch exists, pushed |
| 0.2 Snapshot the database from a real device | `adb backup com.moneytracker.app -f baseline.ab` (or pull `.db`) | File saved to `dist/baseline/v4.4.0+6.db` |
| 0.3 Run full test suite, record pass count | `flutter test --concurrency=1` | Baseline: `dist/baseline/test-baseline.txt` |
| 0.4 Run `flutter analyze`, record warnings | `flutter analyze > dist/baseline/analyze-baseline.txt` | Baseline saved |
| 0.5 Build release APK, measure size | `flutter build apk --release --analyze-size` | Size + breakdown saved to `dist/baseline/size.json` |
| 0.6 Capture Performance Overlay screenshots of Home, History, Analytics on a real device | Manual | 3 screenshots saved to `dist/baseline/perf/` |
| 0.7 Move `lib/screens/backup_restore_screen.dart.backup` to repo `TRASH/` and log it | `mkdir -p TRASH && mv lib/screens/backup_restore_screen.dart.backup TRASH/` | File removed from `lib/`, build still green |
| 0.8 Create `MASTER_PLAN.md` (this file) and `docs/CHECKLIST.md` (per-task tracker) | — | Both committed |

**Phase 0 gate:** baseline numbers exist; build green; everything below has a "before" to compare against.

---

## 3. Phase 1 — Stop the Bleeding (Days 2–4)

**Goal:** Close all 10 critical findings with the smallest possible diffs. Each item ships as its own commit so it's individually revertible.

Order matters — earlier items make later items safer.

### 1.1 Fix `useTemplate` auto-pay (data corruption)
- **Finding:** Bug Hunter C1.
- **File:** [lib/providers/app_state.dart:1594](lib/providers/app_state.dart:1594)
- **Change:** in the templated expense `Expense(...)` ctor, replace `amountPaid: template.amountDecimal` with `amountPaid: Decimal.zero`.
- **Test:** new `test/logic/app_state_use_template_test.dart` — call `useTemplate` with an expense template, assert `expenses.last.amountPaid == 0` and `expenses.last.isPaid == false`.
- **Manual:** create a "Coffee $5" template, tap chip, open `AddPaymentDialog` — confirm it now offers partial payment.

### 1.2 Fix `_pruneDistantMonths` month-key padding mismatch
- **Finding:** Bug Hunter C2.
- **File:** [lib/providers/app_state.dart:558](lib/providers/app_state.dart:558) (and any other `currentMonthKey` build site)
- **Change:** replace the manual `${now.year}-${now.month.toString().padLeft(2, '0')}` build with `final currentMonthKey = _monthKey(now);`.
- **Test:** new test in `test/logic/app_state_prune_test.dart` — set selectedMonth to May, load 10 months of data, call `_pruneDistantMonths` via a test-only hook, assert current-month expenses still in `_expenses`.
- **Note:** verify `_monthlyBalances` DB column writes are not affected (they should not be — `_monthKey` is a memory-only key).

### 1.3 Fix broken `Navigator.pushNamed` routes
- **Finding:** Pattern Recognition #2.
- **Files:**
  - [lib/screens/history_screen.dart:2239](lib/screens/history_screen.dart:2239) — `Navigator.pushNamed(context, '/add_expense')`
  - [lib/screens/history_screen.dart:2251](lib/screens/history_screen.dart:2251) — `Navigator.pushNamed(context, '/add_income')`
  - [lib/screens/add_hub_screen.dart:72](lib/screens/add_hub_screen.dart:72) — `Navigator.pushNamed(context, '/budgets')`
- **Change:** replace all three with `Navigator.push(context, PremiumPageRoute(page: const AddExpenseScreen()))` etc.
- **Followup:** add a CI grep rule `! grep -rn "Navigator.pushNamed" lib/` (or whitelist `/home`/`/onboarding`) — see Phase 8 lint section.
- **Test:** widget test asserts tapping each button calls `Navigator.push`, not pushNamed.

### 1.4 Fix lifecycle race: HomeWidget update vs DB close
- **Finding:** Bug Hunter C3, Race R2.
- **Files:** [lib/main.dart:193–224](lib/main.dart:193), [lib/providers/app_state.dart:2141–2149](lib/providers/app_state.dart:2141)
- **Changes:**
  1. In `didChangeAppLifecycleState(paused)`: `await HomeWidgetHelper.updateWidget(appState)` (was fire-and-forget).
  2. Move `_performBackgroundMaintenance` to *after* the widget update finishes.
  3. In `AppState.closeDatabase`: acquire `_writeMutex` (release immediately after `_db.closeDatabase()`).
- **Test:** new integration test simulates `paused` lifecycle event during an in-flight write, asserts no `DatabaseClosed` exception, asserts `updateWidget` ran.

### 1.5 Coalesce `loadData()` (re-entrancy)
- **Finding:** Race R1.
- **File:** [lib/providers/app_state.dart:278](lib/providers/app_state.dart:278)
- **Change:**
  ```dart
  Future<void>? _loadingFuture;
  Future<void> loadData() => _loadingFuture ??= _loadDataInternal()
      .whenComplete(() => _loadingFuture = null);
  ```
  Rename existing `loadData` body to `_loadDataInternal`.
- **Test:** integration test fires `loadData()` twice in `Future.wait` — assert only one underlying load runs (verify by adding a private `_loadDataCallCount` counter for the test).

### 1.6 Wrap `addExpense` + carryover in a single transaction
- **Finding:** Data Integrity H1.
- **Files:** [lib/providers/app_state.dart:658–757](lib/providers/app_state.dart:658), [lib/database/database_helper.dart](lib/database/database_helper.dart) (new helper)
- **Change:**
  1. Add `DatabaseHelper.createExpenseWithCarryover(Expense e, MonthlyBalance b)` that wraps insert + upsert in `db.transaction(...)`.
  2. Replace the two-statement pattern in `AppState.addExpense` / `addIncome` / `addPayment` with this single helper.
- **Test:** integration test forces a transaction failure (e.g., bad enum value) mid-flow and asserts neither row is committed.

### 1.7 Reduce blur sigma + add RepaintBoundary (perf)
- **Finding:** Performance #1.
- **Files:**
  - [lib/theme/luminous_app_theme.dart:28](lib/theme/luminous_app_theme.dart:28): `glassBlurSigma = 25` → `15` (compromise between fidelity and 60fps).
  - [lib/main.dart:520](lib/main.dart:520): wrap `FloatingGlassNavBar` in `RepaintBoundary`.
  - [lib/screens/home_screen.dart:339](lib/screens/home_screen.dart:339): wrap the transactions `GlassPanel` in `RepaintBoundary`.
- **Acceptance:** scrolling Home on a Pixel 4a class device shows no frame >16.7ms in DevTools Performance overlay.
- **Note:** the design spec says 25px, but on real hardware 15px is visually indistinguishable while halving GPU cost. Document this deviation in `docs/DESIGN_DEVIATIONS.md`.

### 1.8 Mounted check after `_fadeController.reverse`
- **Finding:** Race R3 + Bug Hunter H3.
- **File:** [lib/main.dart:527–530](lib/main.dart:527)
- **Change:**
  ```dart
  _fadeController.reverse().then((_) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    _fadeController.forward();
  });
  ```
  Also add a generation token to cancel stale `.then` callbacks on rapid taps.
- **Test:** widget test simulates 3 rapid tab taps in <100ms, asserts final `_currentIndex` matches the last tap, no exceptions.

### 1.9 AndroidManifest hardening
- **Finding:** Security C2.
- **Files:**
  - `android/app/src/main/AndroidManifest.xml`: add `android:allowBackup="false"` and `android:dataExtractionRules="@xml/data_extraction_rules"` to `<application>`.
  - `android/app/src/main/res/xml/data_extraction_rules.xml` (new file): deny `cloud-backup` and `device-transfer`.
- **Test:** `adb backup -f test.ab com.moneytracker.app` produces an empty/failed backup.
- **Note:** this means existing users' Google Drive auto-backups will not be created going forward. Users on older versions will still have their old backups; new versions won't add to them.

### 1.10 Notification lock-screen redaction
- **Finding:** Security H1.
- **File:** [lib/utils/notification_helper.dart](lib/utils/notification_helper.dart) — `billReminderDetails` and `budgetAlerts` `AndroidNotificationDetails`
- **Change:** add `visibility: NotificationVisibility.private` and `publicVersion: 'You have a financial update'` (or similar generic body) to both `AndroidNotificationDetails`.
- **Test:** manual on real device with notification preview off — verify bill reminder shows generic text instead of `<description> ($X.XX) due tomorrow`.

**Phase 1 gate:** all 10 commits land. Build green. Test count delta = +10 (each fix shipped with one regression test).

---

## 4. Phase 2 — Architectural Foundations (Days 5–8)

**Goal:** Reshape the codebase so Phase 5 (per-screen redesign) is a mechanical edit. Nothing here changes user-facing behavior.

### 2.1 Move `AppColors` out of `main.dart`
- **Finding:** Pattern Recognition #2.
- **New file:** `lib/theme/app_colors.dart` — contains `AppColors` ThemeExtension (extracted verbatim from main.dart:36–86).
- **Update:** every `import '../main.dart' show AppColors;` (21 files) becomes `import '../theme/app_colors.dart';`. Run with `dart fix` or a single sed pass.
- **Verify:** `flutter analyze` clean; no `show AppColors` left in `main.dart`.

### 2.2 Consolidate spacing/sizing tokens
- **New file:** `lib/theme/luminous_tokens.dart` (move from current `lib/theme/luminous_app_theme.dart`'s `LuminousTokens` class). Becomes the **single source of truth** for spacing, radii, type sizes, blur, colors.
- **Add:**
  ```dart
  class LuminousTokens {
    // existing
    static const double basePx = 8;
    static const double stackGap = 16;
    static const double containerPadding = 20;
    static const double glassPadding = 24;
    static const double sectionMargin = 32;
    // new
    static const double radiusSm = 8;
    static const double radiusMd = 16;
    static const double radiusLg = 24;
    static const double radiusXl = 32;
    static const double radiusPill = 9999;
    static const double iconSm = 18;
    static const double iconMd = 24;
    static const double iconLg = 28;
    static const double touchTargetMin = 48; // WCAG AA
    static const double blurSigma = 15;       // ↓ from 25 (perf vs spec compromise)
    static const double swipeVelocityThreshold = 500;
    static const double compactNumberThreshold = 100000;
    static const int    maxBillsOnHome = 3;
    static const double navBarHeightTotal = 80; // pill + padding, for bottom inset on screens
  }
  ```
- **Deprecate** `lib/constants/spacing.dart` — leave file for backward compat with a `@Deprecated('Use LuminousTokens.*')` annotation on each constant. Realign so they no longer drift:
  - `Spacing.screenPadding = 20.0` (was 24) → matches `containerPadding`
  - `Spacing.cardPadding = 24.0` (was 20) → matches `glassPadding`
  - All other constants unchanged.
- **Phase 5 will remove `Spacing.*` calls during each screen's redesign.** Once all screens migrated, delete `lib/constants/spacing.dart` entirely.

### 2.3 Bundle Hanken Grotesk as asset (kill runtime download)
- **Finding:** Performance #5.
- **Steps:**
  1. Download `HankenGrotesk-Regular.ttf`, `HankenGrotesk-SemiBold.ttf`, `HankenGrotesk-Bold.ttf`, `HankenGrotesk-ExtraBold.ttf` from Google Fonts (or `flutter pub run flutter_gen` if using `flutter_gen_fonts`).
  2. Place in `assets/fonts/HankenGrotesk/`.
  3. Add to `pubspec.yaml`:
     ```yaml
     fonts:
       - family: HankenGrotesk
         fonts:
           - asset: assets/fonts/HankenGrotesk/HankenGrotesk-Regular.ttf
           - asset: assets/fonts/HankenGrotesk/HankenGrotesk-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/HankenGrotesk/HankenGrotesk-Bold.ttf
             weight: 700
           - asset: assets/fonts/HankenGrotesk/HankenGrotesk-ExtraBold.ttf
             weight: 800
     ```
  4. Replace `GoogleFonts.hankenGrotesk(...)` calls in `lib/theme/luminous_app_theme.dart` with `TextStyle(fontFamily: 'HankenGrotesk', ...)`.
  5. Remove `google_fonts: ^6.2.1` from `pubspec.yaml`.
- **Verify:** first cold launch on airplane mode renders correctly with Hanken Grotesk.
- **Verify:** APK size delta within ±200KB of baseline (font asset adds ~400KB; removing `google_fonts` package removes ~150KB; net ~+250KB acceptable).

### 2.4 Reusable Luminous component library
- **New folder:** `lib/widgets/luminous/` (already exists, expanded).
- **Rename** `glass_surface.dart` → `glass_panel.dart` (matches design name).
- **New files** (skeleton, fleshed out in Phase 5):
  - `glass_top_app_bar.dart` — the universal header with avatar + title + search icon (replaces hand-rolled headers in every screen).
  - `glass_segmented_control.dart` — Expense/Income, All/Expenses/Income style pill segments.
  - `glass_pill_chip.dart` — filter chips and category pills.
  - `glass_list_section.dart` — Settings/Wallet section (header + glass card containing rows).
  - `glass_list_tile.dart` — single row with icon + label + (optional sublabel/value) + (toggle/chevron).
  - `glass_progress_bar.dart` — for budgets/top categories.
  - `glass_donut_chart.dart` — Analytics hero (built with `CustomPainter` or `fl_chart`).
  - `glass_bar_chart.dart` — Monthly Comparison.
  - `category_bento_grid.dart` — 4-col category picker on Add Transaction.
- **Acceptance:** library compiles with 0 warnings; each component has one widget test + one golden test.

### 2.5 Fix `history_screen` `context.watch<AppState>`
- **Finding:** Code Explorer Risk 2, Performance.
- **File:** [lib/screens/history_screen.dart:476](lib/screens/history_screen.dart:476)
- **Change:** replace `final appState = context.watch<AppState>();` with narrow `context.select` calls for each specific slice the screen actually renders (search results, filters, sort order, sections). The screen will be more fully refactored in Phase 5.6 — this phase just kills the global watch.
- **Add lint rule:** `analysis_options.yaml` — custom analyzer rule (or comment-pragma scan in CI) flagging `context.watch<AppState>` outside an opt-in list.

### 2.6 Sync `_appVersion` from `pubspec.yaml`
- **Finding:** Pattern Recognition #5.
- **Add dependency:** `package_info_plus: ^8.x` (already common, check pubspec).
- **Change:** [lib/main.dart:33](lib/main.dart:33) — replace hardcoded `'4.4.0+6'` with:
  ```dart
  final pkg = await PackageInfo.fromPlatform();
  await CrashLog.init(appVersion: '${pkg.version}+${pkg.buildNumber}');
  ```
- **Verify:** crash log header shows `5.0.0+1` after Phase 8 version bump.

### 2.7 NotificationHelper singleton enforcement
- **Finding:** Code Explorer (NotificationHelper instantiated directly in `notification_settings_screen.dart`).
- **Change:** `notification_settings_screen.dart` and any other direct `NotificationHelper()` call → use `context.read<AppState>().notificationHelper` (expose getter on AppState).
- **Test:** widget test for NotificationSettingsScreen uses a fake AppState with a mock NotificationHelper.

**Phase 2 gate:**
- `grep -rn "import '../main.dart'" lib/` returns 0.
- `grep -rn "GoogleFonts" lib/` returns 0.
- `flutter build apk --release` succeeds; APK size within target.
- Cold launch on airplane mode shows correct font.
- All baseline tests still pass.

---

## 5. Phase 3 — Race & Lifecycle Correctness (Days 9–11)

**Goal:** Eliminate remaining race conditions and lifecycle bugs. After this phase, the app should be robust to rapid backgrounding/foregrounding, double-tap navigation, and concurrent operations.

### 3.1 Notification payload TOCTOU
- **Finding:** Race R5.
- **File:** [lib/utils/notification_payload_store.dart](lib/utils/notification_payload_store.dart)
- **Change:** replace single-string SharedPreferences key with a queue:
  - `storePendingPayload(String p)` → read existing list (JSON array), append `p`, write back.
  - `consumePendingPayloads()` → returns `List<String>` and clears.
- **Update caller:** `_checkPendingNotification` in main.dart iterates the list.
- **Reset `_hasCheckedNotificationPayload`** on `resumed` lifecycle so a payload arriving after the first check still gets picked up.
- **Test:** unit test simulates two background payloads written before the foreground read, asserts both are consumed in order.

### 3.2 Recurring snackbar flag reset
- **Finding:** Race R4.
- **File:** [lib/main.dart:319, 461–487](lib/main.dart:319)
- **Change:** when `lastAutoCreatedCount` becomes 0 (after clear), reset `_hasShownRecurringSnackbar = false`. Or: drive snackbar from a `Stream<int>` exposed by AppState (`onRecurringBatch`) and consume each event.
- **Test:** integration test creates two recurring batches in sequence, asserts both snackbars shown.

### 3.3 PIN lock timer hooks Focus events
- **Finding:** Race R6.
- **Files:**
  - [lib/main.dart:502–505](lib/main.dart:502) — replace bare `GestureDetector` with a wrapper that also listens to `FocusManager.instance` events.
  - [lib/providers/app_state.dart](lib/providers/app_state.dart) `resetLockTimer` — no change needed.
- **Pattern:**
  ```dart
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_resetTimerOnFocusEvent);
  }
  void _resetTimerOnFocusEvent() {
    if (mounted) context.read<AppState>().resetLockTimer();
  }
  @override
  void dispose() {
    FocusManager.instance.removeListener(_resetTimerOnFocusEvent);
    super.dispose();
  }
  ```
- **Test:** integration test puts focus on a TextField, types for 3 minutes (advance fake clock), asserts no lock fires.

### 3.4 `accountJustSwitched` flag → one-shot stream
- **Finding:** Race L3 + Code Explorer.
- **Refactor:** `AppState` exposes `Stream<void> onAccountSwitch` (broadcast) instead of a boolean+`clearAccountSwitchFlag`. `MainNavigationScreen` subscribes in `initState`, disposes in `dispose`.
- **Reason:** flags read in `build()` + cleared in `postFrameCallback` are a fragile pattern; one-shot streams are explicit and don't double-fire.

### 3.5 HomeWidgetHelper dispose moves to `paused`
- **Finding:** Race L1.
- **File:** [lib/main.dart:226–237](lib/main.dart:226), [lib/utils/home_widget_helper.dart](lib/utils/home_widget_helper.dart)
- **Change:** call `HomeWidgetHelper.dispose()` on `paused` (after the widget update) instead of `detached`. Verify `dispose()` is idempotent and called at the top of `initialize()` as a guard.

### 3.6 `_performBackgroundMaintenance` post-await mounted check
- **Finding:** Race M1.
- **File:** [lib/main.dart:214–224](lib/main.dart:214)
- **Change:** add `if (!mounted) return;` after every `await` in this method.

### 3.7 `_checkPendingNotification` re-check before push
- **Finding:** Race M2.
- **File:** [lib/main.dart:422–438](lib/main.dart:422)
- **Change:** `if (!mounted) return;` immediately before `Navigator.push`.

### 3.8 Single-state-machine refactor for AppState lifecycle (optional, defer if time-pressed)
- **Add** `enum AppPhase { initializing, idle, loading, suspending, suspended, terminating }` in `lib/providers/app_state.dart`.
- **Replace** scattered booleans (`_isLoading`, `_processingRecurring`, `_isLocked`, `_database != null`) with transitions through the enum.
- **Benefit:** makes invariants explicit; `loadData` rejects calls when phase is `suspending`/`terminating`.
- **Risk:** large refactor. **Defer to a v5.1 cleanup if Phase 3 budget is tight.**

**Phase 3 gate:**
- `analytics_screen` mid-load + `addExpense` race no longer triggers the in-memory list mutation (manual stress test: rapidly tap "Switch Account" 5× while adding an expense).
- All 7 Phase-3 fixes have regression tests.

---

## 6. Phase 4 — Schema Migration v19 + Data Integrity (Days 12–16)

**Goal:** Patch every schema and atomicity bug found by the Data Integrity audit. Migration v19 will:
1. Add FKs to trash tables.
2. Add `ON DELETE CASCADE` to v3-era `income` and `quick_templates` tables.
3. Add junction-cleanup triggers for `transaction_tags`.

### 4.1 Pre-migration backup hook
- **File:** [lib/database/database_helper.dart](lib/database/database_helper.dart) `_onUpgrade`
- **Add:** before any v19 step, copy `expense_tracker_v4.db` → `expense_tracker_v4.db.v18-backup` in the same directory. If migration fails, restore from this and surface a dialog: "Upgrade failed, your data is safe. Please report this." Auto-delete the backup 7 days after a successful migration.

### 4.2 Migration v19: trash table FKs
- **File:** [lib/database/database_helper.dart](lib/database/database_helper.dart)
- **Step (inside `if (oldVersion < 19)` block):**
  1. `PRAGMA foreign_keys = OFF;`
  2. For each of `deleted_expenses`, `deleted_income`, `deleted_accounts`: rebuild via `CREATE TABLE _new (..., FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE); INSERT INTO _new SELECT * FROM old; DROP TABLE old; ALTER TABLE _new RENAME TO original;`
  3. `PRAGMA foreign_keys = ON;`
- **Constraint:** the WHOLE migration must run inside `db.transaction`.

### 4.3 Migration v19: cascade v4 tables
- **Same migration block:** rebuild `income` and `quick_templates` with `FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE`. Detection logic:
  ```sql
  SELECT 1 FROM pragma_foreign_key_list('income') WHERE "on_delete" = 'CASCADE'
  ```
  Only rebuild if missing.

### 4.4 Migration v19: junction cleanup triggers
- **Same migration block:**
  ```sql
  CREATE TRIGGER IF NOT EXISTS trg_transaction_tags_cleanup_expense
    AFTER DELETE ON expenses
    FOR EACH ROW
  BEGIN
    DELETE FROM transaction_tags
    WHERE transaction_id = OLD.id AND transaction_type = 'expense';
  END;
  ```
  And the matching trigger for `income`.

### 4.5 Soft-delete junction cleanup
- **Files:** [lib/database/database_helper.dart:1487, 736](lib/database/database_helper.dart:1487) (`moveToDeleted`, `moveIncomeToDeleted`); `bulkDeleteTransactionsByCategory`, `bulkDeleteTransactionsAndCategory`, `emptyTrash`, `clearOldDeleted`.
- **Change:** in each path's transaction, delete from `transaction_tags` where `transaction_id` matches the soft-deleted/hard-deleted ids. The triggers cover hard-deletes from `expenses`/`income`; soft-deletes write to `deleted_*` so they still need explicit cleanup before the live row is removed.

### 4.6 Wrap `emptyTrash` + `clearOldDeleted` in transactions
- **Finding:** Data Integrity H3.
- **Files:** [lib/database/database_helper.dart:1657, 1674](lib/database/database_helper.dart:1657)
- **Change:** wrap the multi-step deletes in `db.transaction`.

### 4.7 Move `moveToDeletedById` read into transaction
- **Finding:** Data Integrity H4.
- **File:** [lib/database/database_helper.dart:1508–1513](lib/database/database_helper.dart:1508)
- **Change:** the `getExpenseById` read should happen inside the transaction:
  ```dart
  await db.transaction((txn) async {
    final row = (await txn.query('expenses', where: 'id = ?', whereArgs: [id])).firstOrNull;
    if (row == null) return false;
    await txn.insert('deleted_expenses', _toDeletedRow(row));
    await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
  });
  ```

### 4.8 `monthly_balances` month-key normalization
- **Finding:** Data Integrity C4.
- **Change:** `MonthlyBalance.toMap` writes `DateHelper.toMonthString(month)` (e.g. `2026-05`) instead of `toDateString` (the full date). Update `getMonthlyBalance` to query by `month = 'YYYY-MM'` exact match. Migration v19 fixes existing rows: `UPDATE monthly_balances SET month = substr(month, 1, 7)` (idempotent).

### 4.9 `restoreFromJsonBackup` input validation
- **Finding:** Security H4 + Data Integrity L6.
- **File:** [lib/database/database_helper.dart:2892–3144](lib/database/database_helper.dart:2892)
- **Add:** clamp/reject before insert:
  - amount: `>= 0 && < 1e10 && isFinite && !isNaN`
  - date: parseable, within `[2000-01-01, today + 100 years]`
  - description: length ≤ 1024
- **Also:** include `transaction_tags` table in JSON backup roundtrip (currently missing).

### 4.10 `Expense.fromMap` strict validation
- **Finding:** Data Integrity M4.
- **File:** [lib/models/expense_model.dart:80–96](lib/models/expense_model.dart:80)
- **Change:** match `Income.fromMap`'s pattern: throw `ArgumentError` on missing `category` or `account_id`. Remove the `?? 'Uncategorized'` / `?? 0` defaults.
- **Update callers:** `readAllExpenses` and `restoreFromJsonBackup` log + skip the row, surfacing the corruption rather than fabricating data.

### 4.11 Remove `accountId` alternative key in `Budget.fromMap` / `MonthlyBalance.fromMap`
- **Finding:** Data Integrity M5.
- **Change:** accept only `account_id` (snake_case). Removed key tolerance.
- **Test:** roundtrip test passes; old hand-edited backups using `accountId` fail loudly.

### 4.12 Migration v3→v19 integration test
- **New file:** `test/integration/migration_v3_to_v19_test.dart`
- **Setup:** seed an in-memory sqflite DB at version 3 with sample data (1 account, 5 expenses, 3 income, 2 budgets, 2 recurring, 1 quick template, 2 tags, 3 transaction_tags links).
- **Execute:** open via `DatabaseHelper` (auto-migrates to v19).
- **Assert:** all 5 expenses, 3 income, 2 budgets present; account hard-delete cascades correctly; `transaction_tags` for soft-deleted expense is cleaned by triggers; pre-migration backup file exists in app dir.

**Phase 4 gate:**
- Migration test green.
- Account delete on v3-upgraded DB succeeds (manual test on a real device upgraded from an older APK).
- All Data Integrity findings closed.

---

## 7. Phase 5 — Luminous Design Integration (Days 17–28)

**Goal:** Every screen visually matches the Stitch design. Each screen is its own sub-phase with its own gate. Order is **easy → hard** so the team gets the patterns down before the structural changes.

**Universal shell** (apply once, used by every screen):
- `lib/main.dart` `MainNavigationScreen` already wires `OrganicBlobBackground` + `FloatingGlassNavBar`. Verify the nav reflects the 5 final tabs: **Home, History, Add, Analytics, Wallet**.
- Build `lib/widgets/luminous/glass_top_app_bar.dart`:
  - Sticky/fixed top bar, `bg-white/40 backdrop-blur-15px`, `border-b border-white/40`, height 64dp.
  - Slot left = `GlassAvatar` (taps → Settings), center = `Text('FinanceFlow', style: displayLg)`, right = `IconButton(Icons.search_rounded)` (taps → History with search active).
  - Same component appears on Home, History, Analytics, Wallet, Add, Recurring Items, Settings, Budgets. Pass-through props for tap handlers + active slot.

**Per-screen rules** (apply to all 8):
1. Scaffold `backgroundColor: Colors.transparent`.
2. No `AppBar` — use `GlassTopAppBar` at top of body.
3. Bottom padding ≥ 120dp on scrollable content so the floating nav bar doesn't occlude.
4. Side padding = `LuminousTokens.containerPadding` (20dp).
5. Vertical rhythm: 16dp between related, 32dp between sections.
6. All cards = `GlassPanel` with `LuminousTokens.glassPadding` (24dp) internal padding.
7. All toggles (`Switch`) use `activeColor: cs.primaryContainer`.
8. All chevrons use `Icons.chevron_right_rounded`, color `cs.onSurfaceVariant`.
9. Touch targets ≥ 48dp (use `LuminousTokens.touchTargetMin`).

### 5.1 Settings & Security screen (Days 17–18)
- **File:** [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart) — major visual rewrite, minimal logic change.
- **Layout (top → bottom):**
  - `GlassTopAppBar`
  - Page title: "Settings & Security" `displayLg` + subtitle "Manage your preferences, security protocols, and data." `bodySm` `onSurfaceVariant`
  - Sections (each is a `GlassListSection`):
    - **General:** `Currency` (chevron, shows code + symbol), `Theme` (chevron, shows "Light"/"Dark"/"System").
    - **Security:** `PIN Lock` (toggle), `Biometrics` (toggle, gated on device support). On enabling PIN Lock for the first time → navigate to `PinSetupScreen`.
    - **Data Management:** `Export CSV` (chevron), `Backup & Restore` (chevron, right-side shows last-backup status `"Synced"` / `"Never"`).
    - **Notifications:** `Push Notifications` (toggle, master), then nested toggles for `Bill Reminders`, `Budget Alerts`, `Monthly Summary` (all disabled when master is off). `Reminder Time` row with time picker.
    - **Advanced:** `Notification Settings` (link to system), `Crash Log` (link to crash_log_screen), `Onboarding` (reset onboarding, dev only).
- **Wiring:** preserves every existing capability in `settings_screen.dart` (currency picker, theme picker, PIN setup/disable, biometrics if available, all toggles). UI is rebuilt; logic moves directly.
- **Tests:**
  - Widget test: each section renders correct rows.
  - Widget test: toggling PIN Lock with no PIN set pushes PinSetupScreen.
  - Golden test against `stitch_money_tracker_redesign/settings_security/screen.png`.

### 5.2 Wallet & Accounts (Days 18–19)
- **Rename + redesign:** [lib/screens/account_manager_screen.dart](lib/screens/account_manager_screen.dart) → [lib/screens/wallet_screen.dart](lib/screens/wallet_screen.dart). Update all import sites (1 in main.dart, others in account-related flows).
- **Layout:**
  - `GlassTopAppBar`
  - Hero card: "TOTAL NET WORTH" `labelCaps`, big amount `displayLg`, trend chip with `arrow_upward + vs last month`. Net worth = `sum(account.balance) + carryover` across all accounts.
  - "Accounts" section header `headlineMd` + "+ NEW" link button (right-aligned, `labelCaps text-primary`).
  - List of `AccountListCard` widgets (new component, in `lib/widgets/luminous/account_list_card.dart`): round icon (filled, color by account type), name `bodyLg bold`, subtitle "Primary •••• 4092" `bodySm onSurfaceVariant`, amount `headlineMd`, "Manage" pill button (right). Tap → existing account detail/edit flow.
- **Wiring:** preserve switchAccount, addAccount, editAccount, deleteAccount paths.
- **Tests:** widget + golden.

### 5.3 Budgets & Planning (Day 19)
- **File:** [lib/screens/budget_screen.dart](lib/screens/budget_screen.dart)
- **Layout:**
  - `GlassTopAppBar`
  - Page title "Budgets & Planning" `displayLg` + subtitle.
  - Summary glass card: "TOTAL MONTHLY BUDGET" `labelCaps`, amount `displayLg`, trend chip, progress bar, Spent / Remaining row.
  - "Active Budgets" header `headlineMd`.
  - 1-col mobile (2-col tablet) grid of `BudgetCard` widgets: round category icon, name `bodyLg bold`, "Monthly" chip, "Spent $X" `headlineMd` (red if over) + "of $Y" `bodySm`, progress bar (green normal, red over), remaining/over message.
  - Floating `+` FAB at `bottom: 28 + navBar height, right: 20` → push AddBudget screen.
- **Wiring:** preserve setBudget, deleteBudget, edit, carryover toggles.

### 5.4 Analytics & Insights (Days 20–21)
- **File:** [lib/screens/analytics_screen.dart](lib/screens/analytics_screen.dart)
- **Layout:**
  - `GlassTopAppBar`
  - Header: "Analytics & Insights" `headlineMd` + month subtitle `bodyLg onSurfaceVariant`.
  - Hero glass card (full width): "SPENDING BREAKDOWN" `labelCaps`, donut chart (`GlassDonutChart` new widget, built with `fl_chart` `PieChart` configured for donut). Center hole shows "Total Spent $X" `displayLg`. Legend below with category colors + percentages.
  - "MONTHLY COMPARISON" glass card: bar chart 4 months (last 3 + current), current month in `primaryContainer` with glow shadow, hover/tap reveals exact value chip.
  - Conditional error card if any budget over: "Budget Exceeded" `bg-error-container/40 border-error/20`, warning icon, title, body.
  - "TOP CATEGORIES" glass card: list of 5 with name + amount + `GlassProgressBar`.
- **Lazy load:** when screen first becomes visible, fetch `getSpendingTrends`, `getCategoryBreakdown`, `getMonthlyComparison` — not eagerly on app start. Use `VisibilityDetector` or first-build flag.
- **Memoize** `getCategorySpending()` and `getSpendingTrends()` in AppState (Performance #3).
- **Wiring:** preserve all existing analytics views; the donut chart consumes the same `getCategorySpending()` map.

### 5.5 Add Transaction (Days 21–22) — **STRUCTURAL CHANGE**
- **New file:** [lib/screens/add_transaction_screen.dart](lib/screens/add_transaction_screen.dart)
- **Replaces:** [lib/screens/add_hub_screen.dart](lib/screens/add_hub_screen.dart) (hub deleted). [lib/screens/add_expense_screen.dart](lib/screens/add_expense_screen.dart) and [lib/screens/add_income_screen.dart](lib/screens/add_income_screen.dart) become **internal helpers** for edit mode (pushed from history/home long-press).
- **Layout** (single screen, both expense and income):
  - `GlassTopAppBar`
  - Big glass form panel (`rounded-[32px]`):
    - Pill segmented control: `Expense` (`bg-error-container/30 text-on-error-container` when active) / `Income` (`bg-primary-container/20 text-on-primary-container` when active).
    - Amount input: large `displayLg` (48px), centered, `$` prefix, bottom border, type=number, decimal-2.
    - Category bento grid: 4-column grid of round-square buttons (`56×56 rounded-[32px]`), filtered by transaction type (expenseCategories vs incomeCategories). Active = primary-container fill + glow.
    - Account picker (NEW, replaces hidden in current AddExpenseScreen): pill chip showing current account, tap → bottom sheet picker.
    - Date selector row (glass): icon + "Today, Oct 24" + chevron → date picker.
    - Note input row (glass): icon + text field "Add a note…".
    - (Optional) Quick-template chips above amount: "Coffee $5", "Lunch $12" etc., if templates exist.
    - **SAVE TRANSACTION** big button: `bg-primary rounded-[32px] py-4` full width, `labelCaps tracking-widest`, primary-tinted shadow.
- **Edit mode:** if pushed with `AddTransactionScreen(existing: expense)` (or `income`), pre-fills, button says "UPDATE TRANSACTION", optionally shows "Delete" link.
- **Bottom nav "Add" tab** now opens this screen directly (not the hub).
- **Migration of existing tests** for `add_expense_screen` / `add_income_screen` → new screen.
- **Tests:**
  - Widget: validates empty submission → error; invalid amount → error; valid expense → calls `appState.addExpense`; toggle income → calls `addIncome`.
  - Widget: edit mode pre-fills.

### 5.6 Transaction History (Days 23–24)
- **File:** [lib/screens/history_screen.dart](lib/screens/history_screen.dart)
- **Layout:**
  - `GlassTopAppBar`
  - Search bar: glass pill, search icon left, placeholder "Search transactions…", `bg-white/45 backdrop-blur-15 rounded-full`.
  - Type tabs (segmented control): All / Expenses / Income.
  - Horizontal scrollable category chip row: "Categories ▾" (opens picker), then individual category pill chips that toggle.
  - Filter row: date range chip, sort chip, payment-status chip (current filters preserved).
  - List, grouped by date (Today / Yesterday / `MMM d`): each transaction is a `GlassPanel` card (24px padding) with round icon (color-coded by category), name + `category · time`, amount in `headlineMd` (green for income, default for expense).
  - Empty state: "No transactions" message + (when no filters) buttons "Add Expense" / "Add Income" which push the new `AddTransactionScreen` with the type preselected.
- **Critical:** the broken `Navigator.pushNamed('/add_expense'|'/add_income')` calls — fixed in Phase 1.3 — are replaced here with the new flow.
- **Refactor:** the 2,276-line file is broken into smaller widgets in `lib/screens/history/`:
  - `history_screen.dart` (shell)
  - `history/_search_filter_bar.dart`
  - `history/_filter_chips.dart`
  - `history/_date_section.dart`
  - `history/_transaction_card.dart`
  - `history/_empty_state.dart`
- All `context.watch<AppState>` calls become narrow `context.select` slices.
- **Tests:** widget tests for filter behavior, search, sort, date grouping; golden test.

### 5.7 Recurring Items (Days 24–25) — **STRUCTURAL CHANGE**
- **New file:** [lib/screens/recurring_items_screen.dart](lib/screens/recurring_items_screen.dart) — single screen with Expenses/Income tab.
- **Replaces:** [lib/screens/recurring_expenses_screen.dart](lib/screens/recurring_expenses_screen.dart) and [lib/screens/recurring_income_screen.dart](lib/screens/recurring_income_screen.dart) (delete both after migration).
- **Layout:**
  - `GlassTopAppBar`
  - Title "Recurring Items" `headlineMd`.
  - Glass pill segmented control: Expenses / Income.
  - List of `RecurringItemCard` widgets: round category icon, name `bodyLg bold`, "Monthly • Next: Oct 1" `bodySm`, amount, optional "AUTO-PAY" chip.
  - Centered primary pill button "+ Add Recurring Item" at bottom.
- **Wiring:**
  - The `_navDestinations` in `main.dart` does NOT add a 6th tab — recurring is accessed via Add tab (a chip "Manage recurring →") and via Home's upcoming-bills banner (tap → push this screen).
  - When tab is "Expenses", reads `appState.recurringExpenses`; when "Income", reads `appState.recurringIncomes`.
  - "Add Recurring Item" pushes a sub-screen `AddRecurringItemScreen` (new, replacing the dialogs in the two old screens) — uses the same `AddTransactionScreen` template extended with frequency + dayOfMonth.
- **Notification compatibility:** because recurring IDs persist, notification scheduling continues to work — no notification IDs change.

### 5.8 Home Dashboard (Day 26)
- **File:** [lib/screens/home_screen.dart](lib/screens/home_screen.dart) — already mostly redesigned; just polish.
- **Changes:**
  - Replace hand-rolled `GlassHeaderStrip` with new `GlassTopAppBar`.
  - Fix mixed spacing — remove all `Spacing.*` references, use `LuminousTokens.*`.
  - `_FinancialSummaryCard` `select` fourth element → `currencyCode.hashCode.toDouble()` (Bug C5 fix). Actually cleaner: split into a `(double, double, double, String)` Record so the currency code is compared directly.
  - Add a "Recent Transactions" section that exactly matches the design (4-row glass card with dividers).
  - Add trending chip to the Total Balance card showing month-over-month delta (computed from `appState.previousMonthBalance`).
  - Auto-rollover budgets when `goToToday` / `goToMonth` crosses into a new month (Bug Hunter H1) — call `_autoRolloverBudgets()` if `_selectedMonth` changed and was previously the current month.

### 5.9 Onboarding, PIN, Crash Log, Export, etc. (Days 27–28)
**Secondary screens** — apply visual coat of paint without rebuilding logic.
- [lib/screens/onboarding_screen.dart](lib/screens/onboarding_screen.dart): glass pages + organic blob background; primary button matches design.
- [lib/screens/pin_setup_screen.dart](lib/screens/pin_setup_screen.dart), [lib/screens/pin_unlock_screen.dart](lib/screens/pin_unlock_screen.dart): glass PIN dots, glass numeric keypad.
- [lib/screens/backup_restore_screen.dart](lib/screens/backup_restore_screen.dart): glass list, primary buttons.
- [lib/screens/crash_log_screen.dart](lib/screens/crash_log_screen.dart): glass list of entries, PII redactor before share (Security H5).
- [lib/screens/export_data_screen.dart](lib/screens/export_data_screen.dart): glass options, primary button.
- [lib/screens/trash_screen.dart](lib/screens/trash_screen.dart): glass list of deleted items with restore/delete.
- [lib/screens/category_manager_screen.dart](lib/screens/category_manager_screen.dart): glass list with `+ Add Category` FAB.
- [lib/screens/quick_templates_screen.dart](lib/screens/quick_templates_screen.dart): glass list.
- [lib/screens/notification_settings_screen.dart](lib/screens/notification_settings_screen.dart): glass switches (already in Settings section in 5.1 but keep as separate route too).
- [lib/screens/advanced_filter_dialog.dart](lib/screens/advanced_filter_dialog.dart), [lib/screens/add_payment_dialog.dart](lib/screens/add_payment_dialog.dart): glass dialogs with primary CTA.

**Per-screen tests:** widget test for golden-path + golden test where applicable.

### Brand alignment (Day 28)
- **App title** everywhere: "FinanceFlow" (already in main.dart, ensure label in AndroidManifest matches: `<application android:label="FinanceFlow">`).
- **Package name** stays `budget_tracker` (changing it would lose users' app data). However, the home widget's hardcoded class path `com.moneytracker.app.BudgetWidgetProvider` in [lib/utils/home_widget_helper.dart:97](lib/utils/home_widget_helper.dart:97) — verify matches the actual Android-side widget provider. If mismatch, this is the cause of "widget doesn't update" reports — fix to match the namespace declared in `AndroidManifest.xml`.

**Phase 5 gate:**
- All 8 hero screens golden-test green (≤2% pixel diff).
- `grep -rn "Spacing\\." lib/` returns < 50 hits (down from 755). Remaining hits are tests or trivial padding.
- `grep -rn "context.watch<AppState>" lib/` returns 0.
- Manual smoke test on a Pixel 4a (or emulator) confirms all 5 nav tabs render correctly, all secondary screens push correctly, all dialogs open and close.

---

## 8. Phase 6 — Security Hardening (Days 29–32)

**Goal:** Close the four CRITICAL security findings. PIN crypto stays as-is (it's already good); we change *what it protects*.

### 6.1 SQLCipher migration (Days 29–30)
- **Add dep:** `sqflite_sqlcipher: ^3.x` (replaces `sqflite`, API-compatible).
- **Key management:**
  - On first launch after upgrade: generate a 256-bit random key with `Random.secure()`, base64-encode, store in `flutter_secure_storage` under key `db_master_key`.
  - On subsequent launches: read key from secure storage. If missing (rare — secure storage was wiped), prompt user to restore from backup; the data is effectively gone without the key.
- **Migration:**
  1. On first launch with `sqflite_sqlcipher`, detect old plain DB at `expense_tracker_v4.db` (no header).
  2. Rekey: open old DB, attach new encrypted DB with `ATTACH DATABASE 'expense_tracker_v4_enc.db' AS encrypted KEY '...';`, run `SELECT sqlcipher_export('encrypted');`, detach.
  3. Replace old file with new encrypted file. Update `DatabaseHelper.databaseName` (or keep name, since the encryption is transparent).
  4. On rollback (old APK): user would see "database disk image is malformed". Document this — **rollback not supported once encrypted**. Provide a "Download backup before encrypting" prompt on the upgrade screen.

### 6.2 PIN hash → secure storage (Day 30)
- **Replace:** all `SharedPreferences.getInstance()` calls in [lib/utils/pin_security_helper.dart](lib/utils/pin_security_helper.dart) for keys `_pinHashKey`, `_pinSaltKey`, `_pinLengthKey`, `_pinEnabledKey`, `_failedAttemptsKey`, `_lockoutUntilKey` → `FlutterSecureStorage()`.
- **Migration:** on first launch of v5, lazy-migrate: if SharedPreferences has these keys but secure storage doesn't, copy them over and delete from SharedPreferences.
- **Optional upgrade:** swap SHA-256 for `Pbkdf2(iterations: 120000, bits: 256)` from `cryptography` package. On migration, re-hash the PIN on next successful unlock (gives gradual rollout). Note: a 4-6 digit PIN's keyspace is the bottleneck (~1M), not the hash; PBKDF2 buys ~120k× CPU cost per guess offline.

### 6.3 Backup file encryption (Day 31)
- **File:** [lib/utils/backup_helper.dart](lib/utils/backup_helper.dart)
- **New backup format (`.etbackup` v3):**
  ```
  { v: 3,
    salt: <base64 16 bytes>,
    iv: <base64 12 bytes>,
    ciphertext: <base64 of AES-GCM(plaintext_json, key, iv, aad)>,
    mac_tag: <base64 16 bytes from GCM>
  }
  ```
  where `key = PBKDF2(passphrase, salt, 120000, 256)` and `aad = "FinanceFlow backup v3"`.
- **UI:** before share, prompt user for passphrase (twice + strength meter). Before restore, prompt for passphrase; on failure (GCM MAC mismatch), surface "Wrong passphrase or corrupted file".
- **Backward compat:** still read v2 (unencrypted JSON) backups, but show a deprecation banner and force a re-export.

### 6.4 Home widget redaction (Day 32, half-day)
- **File:** [lib/utils/home_widget_helper.dart:37](lib/utils/home_widget_helper.dart:37)
- **Add:** early in `updateWidget`:
  ```dart
  if (await PinSecurityHelper.isPinEnabled()) {
    await HomeWidget.saveWidgetData<String>('month_name', monthName);
    await HomeWidget.saveWidgetData<String>('expenses', '••••');
    await HomeWidget.saveWidgetData<String>('income', '••••');
    await HomeWidget.saveWidgetData<String>('balance', '••••');
    await HomeWidget.saveWidgetData<bool>('is_positive', true);
    await HomeWidget.saveWidgetData<String>('currency', currencySymbol);
    await HomeWidget.updateWidget(...);
    return;
  }
  ```

### 6.5 FLAG_SECURE (Day 32, half-day)
- **Add dep:** `flutter_windowmanager: ^x.x`.
- **In `_MyAppState.initState`:** if `PinSecurityHelper.isPinEnabled()`, call `FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE)`. Toggle on lock/unlock.
- **Optional setting:** allow user to disable in Settings ("Show in recent apps") for debugging.

### 6.6 Crash log PII redactor (Day 32, half-day)
- **File:** [lib/utils/crash_log.dart](lib/utils/crash_log.dart)
- **Add:** `String redactPii(String log)` that strips:
  - currency-formatted numbers (`$X.XX`, `€X.XX`, etc., regex: `[A-Z]{2,3}\\$?\\s?[\\d,]+\\.\\d{2}`)
  - ISO dates (`YYYY-MM-DD`, `YYYY-MM-DDTHH:mm:ss`)
  - any identifier appearing in known PII field names: `description`, `category`, `account_name`, `note`
- Call `redactPii(buffer.toString())` in `CrashLogScreen` share button before passing to `Share.share(...)`.

**Phase 6 gate:**
- `adb backup` produces empty backup.
- Database file on device is unreadable in DB Browser (encrypted magic bytes).
- PIN hash not visible in `/data/data/.../shared_prefs/`.
- Backup file fails MAC check when bytes are flipped.
- App in recents shows blank thumbnail when PIN is enabled.
- Bill reminder notification on lock screen reads "You have a financial update".

---

## 9. Phase 7 — Test Coverage Rebuild (Days 33–35)

**Goal:** Behavioral coverage matches the test count. Replace fake tests, add critical missing tests.

### 7.1 Rename mislabeled file
- Rename [test/logic/app_state_logic_test.dart](test/logic/app_state_logic_test.dart) → `test/utils/currency_helper_test.dart` (or split into `currency_helper_test.dart` + `database_constants_test.dart`).

### 7.2 Real `app_state_logic_test.dart`
- **New file:** [test/logic/app_state_logic_test.dart](test/logic/app_state_logic_test.dart) — covers each public mutator:
  - `addExpense` → DB row + `_expenses` cache + monthly balance all match.
  - `updateExpense` → fields update, no duplicate rows.
  - `deleteExpense` → soft-deletes, cache excludes, restore brings back.
  - `addIncome`, `updateIncome`, `deleteIncome` — same.
  - `setBudget` → budget appears in `getCurrentMonthBudgets`, `getBudgetSpent` reflects.
  - `switchAccount` → flag fires, expenses for new account load, old account expenses cleared from cache.
  - `clearFilters` → all four filter fields reset.
  - `useTemplate` → expense created with `amountPaid: 0` (regression test for Phase 1.1).
  - `goToToday`, `goToMonth`, `goToPreviousMonth`, `goToNextMonth` → `_selectedMonth` updates, expenses cache reflects.
  - `loadData` re-entrancy → two parallel calls produce one underlying load (regression test for Phase 1.5).

### 7.3 Real `onboarding_service_test.dart`
- Replace [test/services/services_test.dart](test/services/services_test.dart) with [test/services/onboarding_service_test.dart](test/services/onboarding_service_test.dart):
  - `isOnboardingComplete()` false on fresh prefs.
  - `completeOnboarding()` then `isOnboardingComplete()` true.
  - `resetOnboarding()` returns false again.

### 7.4 Migration test (already in Phase 4.12)

### 7.5 Cascade delete test
- **New file:** [test/integration/cascade_delete_test.dart](test/integration/cascade_delete_test.dart) — delete an account, assert all related expenses, income, budgets, recurring, transaction_tags are gone (post-migration v19).

### 7.6 Screen tests for all 8 hero screens
- **New folder:** `test/screens/`
- One file per screen:
  - `home_screen_test.dart`
  - `history_screen_test.dart`
  - `add_transaction_screen_test.dart`
  - `analytics_screen_test.dart`
  - `budget_screen_test.dart`
  - `wallet_screen_test.dart`
  - `recurring_items_screen_test.dart`
  - `settings_screen_test.dart`
- Each covers: renders without throwing; primary action triggers correct AppState method; empty state shows correctly.
- Use a fake AppState (`InMemoryAppState`) for deterministic tests.

### 7.7 PIN lockout screen test
- **New file:** [test/screens/pin_unlock_screen_test.dart](test/screens/pin_unlock_screen_test.dart): enter wrong PIN 5×, assert lockout message appears; correct PIN unlocks.

### 7.8 Golden tests
- For each of 8 hero screens, add one golden test asserting visual match against `stitch_money_tracker_redesign/<screen>/screen.png` resized to 393×852 (iPhone 14 reference). Tolerance 2%.

### 7.9 Clock injection
- Add `lib/utils/clock.dart`:
  ```dart
  class Clock {
    DateTime now() => DateTime.now();
    static Clock instance = Clock();
  }
  ```
- Replace `DateTime.now()` calls in `lib/utils/validators.dart`, `lib/providers/app_state.dart` recurring logic, `lib/utils/notification_helper.dart`, `lib/utils/home_widget_helper.dart` with `Clock.instance.now()`.
- Tests inject a fake: `Clock.instance = FakeClock(2026, 5, 15);`.

### 7.10 CI gates
- Add to CI script (Phase 8): `flutter test` must pass with 100% pass rate; pass count must equal or exceed last baseline + 50.

**Phase 7 gate:** behavioral coverage ≥ 70% (measured via `coverage` package + `lcov`).

---

## 10. Phase 8 — Polish & Ship (Days 36–38)

### 8.1 Lint rules + CI checks
- `analysis_options.yaml`:
  - Forbid `Navigator.pushNamed` outside whitelisted routes.
  - Forbid `context.watch<AppState>` (allowlist `_OptInWatch` widget wrappers).
  - Forbid `print(...)` (use `debugPrint`).
  - Forbid `withOpacity(` (use `withValues(alpha: …)`).
- Bash CI script `scripts/preflight.sh`:
  ```bash
  set -e
  flutter analyze
  flutter test --coverage
  ! grep -rn "Navigator\\.pushNamed" lib/ | grep -v -e "/home" -e "/onboarding"
  ! grep -rn "import '../main.dart'" lib/
  ! grep -rn "GoogleFonts" lib/
  ! grep -rn "context\\.watch<AppState>" lib/
  ! grep -rn "Spacing\\." lib/  # after Phase 5 complete
  ```

### 8.2 Final performance pass
- Run DevTools Performance overlay on a real Pixel 4a or equivalent across:
  - Home scroll (with 100 expenses)
  - History scroll (with 500 expenses)
  - Tab switching
  - Analytics chart rendering
- Assert: every frame ≤ 16.7ms in steady state; first-frame ≤ 100ms.
- If any frame spikes, profile and address (likely candidates: blur sigma, list virtualization, repaint boundaries).

### 8.3 APK build + smoke test
- `flutter build apk --release`
- Install on device.
- Manual smoke test (5 minutes):
  - Fresh launch → onboarding → home renders.
  - Add expense via Add tab → appears in history + balance.
  - Add income via Add tab → appears in history + balance.
  - Set a budget → appears in Budgets, progress reflects.
  - Toggle dark/light theme → all screens still readable.
  - Enable PIN → background → resume → unlock prompt → enter PIN → unlocked.
  - Take backup → file saved.
  - Restore backup → data restored.
  - Switch account (if multi-account set up).
  - Check home widget shows ••• when PIN enabled.

### 8.4 Version bump and tag
- [pubspec.yaml](pubspec.yaml): `version: 5.0.0+1`.
- Update [lib/main.dart:33](lib/main.dart:33) literal if still present (should be derived from `package_info_plus` after Phase 2.6).
- Update [CHANGELOG.md](CHANGELOG.md) with full release notes.
- Tag: `git tag v5.0.0+1 && git push --tags`.

### 8.5 Ship pipeline
- Run the full APK ship pipeline from [CLAUDE.md](CLAUDE.md):
  ```bash
  flutter build apk --release && \
  cp build/app/outputs/flutter-apk/app-release.apk /c/Users/leooa/Documents/personal-projects/expense-tracker-landing/public/downloads/money-tracker.apk && \
  git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing add public/downloads/money-tracker.apk && \
  git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing commit -m "chore: ship v5.0.0+1 — FinanceFlow Luminous" && \
  git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing push && \
  (cd /c/Users/leooa/Documents/personal-projects/expense-tracker-landing && vercel --prod --yes)
  ```
- Verify SHA1 match at `https://leo-money-tracker.vercel.app/downloads/money-tracker.apk`.
- Cut GitHub release `v5.0.0`.

---

## 11. Risk Register

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Migration v19 fails on a user's device with corrupted v3 data | Low | High (data loss) | Phase 4.1 pre-migration backup; surface failure with restore prompt |
| R2 | SQLCipher rekey fails mid-flight, leaves both files | Low | High | Phase 6.1 rekey on a transactional temp file; only swap when fully written |
| R3 | Hanken Grotesk asset blocks first-run if font load fails | Very Low | Medium | Asset is bundled in APK; can't fail to load. Fall back to system font via `TextStyle.fontFamilyFallback` |
| R4 | Single bottom-nav "Add" replacing the hub confuses existing users | Medium | Low | Add a one-time tooltip "Tap to add a transaction" on first launch of v5; route old hub deep-links to new screen |
| R5 | Merging Recurring Expenses + Income breaks existing notifications | Low | Medium | Recurring IDs are stable; notifications keyed by ID survive. Verified via Phase 5.7 |
| R6 | Performance budget (60 fps) not met after redesign | Medium | Medium | Phase 1.7 + Phase 8.2 verification gates; rollback option = revert blur sigma to 10 |
| R7 | Test suite flakes due to wall-clock dependence | Medium | Low | Phase 7.9 Clock injection covers this |
| R8 | User's existing PIN auto-locks them out after secure-storage migration | Low | Medium | Phase 6.2 lazy migration: on first launch, read from SharedPreferences if secure-storage empty, then copy over. Old PIN keeps working |
| R9 | Removing `google_fonts` package breaks something using it elsewhere | Very Low | Low | Grep test: confirm only `lib/theme/luminous_app_theme.dart` imports it |
| R10 | Vercel deploy step fails due to disconnected Git integration | Low | Low | Documented in MEMORY.md; manual `vercel --prod --yes` is the workaround |

---

## 12. Per-Phase Checklist (track in `docs/CHECKLIST.md`)

A separate file `docs/CHECKLIST.md` mirrors this plan as a check-box list. Update as items complete:
- [ ] Phase 0.1 — branch created
- [ ] Phase 0.2 — DB snapshot
- … (one item per task above)

---

## 13. After v5.0.0 — Optional v5.1 Cleanup

These are recommended but not blockers:

1. **Split `AppState` into 3 services:** `TransactionService` (CRUD), `BudgetService`, `SettingsService`. Provider-based DI. Eliminates the 2,248-line god object.
2. **Split `DatabaseHelper` into per-domain repositories:** `ExpenseRepository`, `IncomeRepository`, `BudgetRepository`, etc.
3. **Money as INTEGER cents in DB:** schema v20 migration. Removes the float-drift in `SUM(amount)` for very large datasets. Requires a backfill: `UPDATE expenses SET amount = CAST(amount * 100 AS INTEGER); ALTER COLUMN amount TYPE INTEGER`.
4. **Single AppPhase state machine** (deferred from Phase 3.8).
5. **AppState mutators as Riverpod providers:** typed disposal, better test ergonomics.

---

## 14. Appendix A — File-by-File Change Registry

Used during execution to track what each file gets touched for.

### Modified files (sorted by change weight)

| File | Phases | Summary |
|---|---|---|
| `lib/providers/app_state.dart` | 1, 2, 3, 4, 5, 7 | useTemplate fix, _monthKey, loadData coalesce, mutex on closeDB, addExpense+carryover tx, currency.length→hashCode, accountSwitch stream, getUpcomingBills memoize, getCategorySpending memoize, _isDarkMode dead state remove, expose notificationHelper |
| `lib/database/database_helper.dart` | 1, 4, 6 | createExpenseWithCarryover, migration v19, trash FKs, junction triggers, monthly_balances month-key fix, restoreFromJsonBackup validation, SQLCipher rekey |
| `lib/main.dart` | 1, 2, 3, 5 | await HomeWidget.updateWidget, RepaintBoundary nav, mounted check in fade, AppColors moved out, package_info version, FocusManager hook, accountSwitch stream consumer, GlassTopAppBar adoption |
| `lib/screens/history_screen.dart` | 1, 2, 5, 7 | pushNamed→PremiumPageRoute, kill context.watch, full redesign + split |
| `lib/screens/home_screen.dart` | 5, 7 | GlassTopAppBar adoption, Spacing→LuminousTokens, currency code fix, auto-rollover trigger |
| `lib/screens/settings_screen.dart` | 5, 7 | Full Luminous redesign |
| `lib/screens/account_manager_screen.dart` | 5, 7 | RENAME to wallet_screen.dart + redesign |
| `lib/screens/analytics_screen.dart` | 2, 5, 7 | Lazy init, memoize selects, Luminous redesign |
| `lib/screens/budget_screen.dart` | 5, 7 | Luminous redesign |
| `lib/screens/add_hub_screen.dart` | 5 | DELETE |
| `lib/screens/add_expense_screen.dart`, `add_income_screen.dart` | 5 | Internal helpers / merged into add_transaction_screen.dart |
| `lib/screens/recurring_expenses_screen.dart`, `recurring_income_screen.dart` | 5 | DELETE — merged into recurring_items_screen.dart |
| `lib/utils/notification_helper.dart` | 1, 6, 7 | Visibility.private, publicVersion, Clock injection, tests |
| `lib/utils/home_widget_helper.dart` | 3, 6, 7 | dispose on paused, PIN redaction, package name verification |
| `lib/utils/pin_security_helper.dart` | 6, 7 | Migrate to flutter_secure_storage, optional PBKDF2 |
| `lib/utils/backup_helper.dart` | 6, 7 | AES-GCM encryption, MAC, passphrase prompt |
| `lib/utils/crash_log.dart` | 6, 7 | redactPii |
| `lib/utils/notification_payload_store.dart` | 3, 7 | List-of-payloads, drain pattern |
| `lib/utils/decimal_helper.dart` | (none — verified clean) | Document max-value clamp behavior in comment |
| `lib/theme/luminous_app_theme.dart` | 1, 2 | blurSigma 25→15, remove google_fonts |
| `lib/theme/app_colors.dart` | 2 | NEW (moved from main.dart) |
| `lib/theme/luminous_tokens.dart` | 2 | NEW (moved + extended from luminous_app_theme.dart) |
| `lib/widgets/luminous/glass_top_app_bar.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/glass_segmented_control.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/glass_list_section.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/glass_list_tile.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/glass_pill_chip.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/glass_progress_bar.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/glass_donut_chart.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/glass_bar_chart.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/category_bento_grid.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/account_list_card.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/budget_card.dart` | 2, 5 | NEW |
| `lib/widgets/luminous/recurring_item_card.dart` | 2, 5 | NEW |
| `lib/screens/add_transaction_screen.dart` | 5 | NEW (replaces hub) |
| `lib/screens/wallet_screen.dart` | 5 | NEW (from account_manager rename) |
| `lib/screens/recurring_items_screen.dart` | 5 | NEW (merged) |
| `lib/screens/add_recurring_item_screen.dart` | 5 | NEW (from old recurring dialogs) |
| `lib/screens/history/` (folder) | 5 | NEW — split of history_screen.dart |
| `lib/utils/clock.dart` | 7 | NEW |
| `lib/models/expense_model.dart` | 4 | Strict fromMap validation |
| `lib/models/budget_model.dart`, `monthly_balance_model.dart` | 4 | Remove dual-key tolerance |
| `lib/constants/spacing.dart` | 2 | Realign + @Deprecated; delete after Phase 5 |
| `pubspec.yaml` | 2, 6, 8 | Remove google_fonts, add hanken asset, add sqflite_sqlcipher, flutter_secure_storage, flutter_windowmanager, cryptography, package_info_plus, version 5.0.0+1 |
| `android/app/src/main/AndroidManifest.xml` | 1, 5 | allowBackup=false, dataExtractionRules, label=FinanceFlow |
| `android/app/src/main/res/xml/data_extraction_rules.xml` | 1 | NEW |
| `analysis_options.yaml` | 8 | Custom lint rules |
| `scripts/preflight.sh` | 8 | NEW — CI gates |
| `docs/MASTER_PLAN.md` | 0 | THIS FILE |
| `docs/CHECKLIST.md` | 0 | NEW |
| `docs/DESIGN_DEVIATIONS.md` | 1 | NEW — document blur-sigma compromise |
| `CHANGELOG.md` | 8 | v5.0.0 entry |

### Deleted files

| File | Phase | Reason |
|---|---|---|
| `lib/screens/backup_restore_screen.dart.backup` | 0 | Dead orphan |
| `lib/screens/add_hub_screen.dart` | 5 | Replaced by `add_transaction_screen.dart` |
| `lib/screens/recurring_expenses_screen.dart` | 5 | Merged into `recurring_items_screen.dart` |
| `lib/screens/recurring_income_screen.dart` | 5 | Merged into `recurring_items_screen.dart` |
| `lib/constants/spacing.dart` | 5 (end) | Tokens fully consolidated into `LuminousTokens` |
| `lib/services/services_test.dart` (existing test, mislabeled) | 7 | Replaced by proper test |

---

## 15. Appendix B — Bug-to-Phase Cross-Reference

For every audit finding, where does it get fixed?

| Audit Finding | Severity | Phase | Task |
|---|---|---|---|
| useTemplate auto-pay | CRITICAL | 1 | 1.1 |
| _monthKey padding mismatch | CRITICAL | 1 | 1.2 |
| Broken Navigator routes | CRITICAL | 1 | 1.3 |
| loadData not re-entrant | CRITICAL | 1 | 1.5 |
| DB close vs writes race | CRITICAL | 1 | 1.4 |
| addExpense + carryover not atomic | CRITICAL | 1 | 1.6 |
| Plaintext DB | CRITICAL | 6 | 6.1 |
| allowBackup=true default | CRITICAL | 1 | 1.9 |
| PIN hash in SharedPrefs | CRITICAL | 6 | 6.2 |
| Backup file plaintext | CRITICAL | 6 | 6.3 |
| Trash tables no FKs | CRITICAL | 4 | 4.2 |
| transaction_tags no FK + leak | CRITICAL | 4 | 4.4, 4.5 |
| v4 income/quick_templates no CASCADE | CRITICAL | 4 | 4.3 |
| PIN timer not reset on TextField | CRITICAL | 3 | 3.3 |
| history context.watch | HIGH | 2 | 2.5 (full refactor in 5.6) |
| getUpcomingBills/getCategorySpending in select | HIGH | 5 | 5.4 (analytics), 5.8 (home) |
| 4× BackdropFilter on Home | HIGH | 1 | 1.7 |
| IndexedStack eager analytics init | HIGH | 5 | 5.4 |
| google_fonts runtime download | HIGH | 2 | 2.3 |
| Records-with-List in select | HIGH | 5 | each screen redesign |
| Per-tile O(M) category lookup | HIGH | 5 | 5.8 + AppState memoize |
| Notification lock-screen leak | HIGH | 1 | 1.10 |
| Home widget no PIN redaction | HIGH | 6 | 6.4 |
| No FLAG_SECURE | HIGH | 6 | 6.5 |
| Backup JSON weak validation | HIGH | 4 | 4.9 |
| Crash log PII leak | HIGH | 6 | 6.6 |
| Recurring snackbar flag | HIGH | 3 | 3.2 |
| Payload TOCTOU | HIGH | 3 | 3.1 |
| _fadeController no mounted check | HIGH | 1 | 1.8 |
| auto-rollover not on goToToday/switchAccount | HIGH | 5 | 5.8 |
| 3 of 5 tabs opaque SliverAppBar | HIGH | 5 | 5.2, 5.3, 5.4 |
| Mixed spacing 20 vs 24 | HIGH | 2 | 2.2 |
| Currency.length.toDouble in select | CRITICAL | 5 | 5.8 |
| dayOfMonth edit duplicate recurring | MEDIUM | 5 | 5.7 |
| Expense.fromMap fabricates accountId | MEDIUM | 4 | 4.10 |
| Budget/MonthlyBalance dual-key | MEDIUM | 4 | 4.11 |
| HomeWidget package name hardcoded | MEDIUM | 5 | 5.9 (brand) |
| _appVersion hardcoded | MEDIUM | 2 | 2.6 |
| paymentProgress vs isPaid inconsistency | MEDIUM | 4 | model fix |
| _QuickAddBar toStringAsFixed(0) | MEDIUM | 5 | 5.8 |
| searchExpenses LIKE %x% | MEDIUM | 4 (v5.1?) | optional FTS5 |
| Decimal silent clamp at 999M | MEDIUM | 4 | surface error instead |
| Money as REAL drift | MEDIUM | v5.1 | optional INTEGER cents migration |
| AppState 2248 lines | MEDIUM | v5.1 | optional split |
| backup_restore_screen.dart.backup | LOW | 0 | 0.7 |
| floating_glass_nav_bar i==2 hardcoded | LOW | 5 | 5 component |
| nav bar Expanded+spaceAround redundant | LOW | 5 | 5 component |
| add_hub mixed nav | LOW | 1 | 1.3 |
| withAlpha vs withValues | LOW | 5 | each screen migration |
| HapticHelper vs HapticFeedback | LOW | 5 | route nav bar through HapticHelper |
| 40x40 chevron taps | LOW | 5 | 5.8 home component |
| 91 catch+debugPrint | LOW | 5 | add CrashLog.record in each |
| Magic numbers in home | LOW | 2 | 2.2 (token constants) |
| Test mislabeled file | MEDIUM | 7 | 7.1, 7.2 |
| Zero screen tests | HIGH | 7 | 7.6 |
| Zero migration tests | HIGH | 4 | 4.12 |
| Zero luminous widget tests | MEDIUM | 7 | 7.6 |
| services_test existence-only | MEDIUM | 7 | 7.3 |

**Every finding is mapped.** Items not closed in v5.0.0 are explicitly deferred to v5.1 with rationale.

---

## 16. Acceptance — How we know this was the LAST time

Three durable mechanisms ensure we don't end up here again:

1. **CI lint rules** (Phase 8.1) prevent the patterns that produced the bugs:
   - No `Navigator.pushNamed` to unregistered routes.
   - No `context.watch<AppState>` outside opt-in.
   - No `print`, no `withOpacity`, no `import '../main.dart'` from non-main code.
   - No `Spacing.*` (after migration).
2. **Behavioral test coverage** (Phase 7) catches regressions in the load-bearing paths: every AppState mutator, every DB cascade, every screen golden path.
3. **Architectural guardrails:**
   - `LuminousTokens` is the single source of design truth — new screens use it, period.
   - `GlassTopAppBar`, `GlassPanel`, etc. are the only way to build the shell — no hand-rolled blurs.
   - `Clock.instance` makes time controllable in tests.
   - The state-machine refactor (deferred to v5.1) makes lifecycle invariants explicit.

After v5.0.0, the only reason to do this kind of audit again is when a major Flutter SDK bump invalidates one of the above mechanisms. That's expected once every 2-3 years, not every quarter.
