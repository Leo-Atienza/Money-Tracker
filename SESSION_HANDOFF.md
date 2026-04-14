# Session Handoff — Bug Fix + Safety Net Pass

**Branch**: `fix/bugs-and-safety-net-2026-04` (pushed to origin)
**Target version**: `4.0.0+4` → `4.1.0+5`
**Canonical plan**: `C:\Users\leooa\.claude\plans\typed-crunching-brooks.md`
**Last commit**: `db2406b feat(crash-log): global error handler + rolling crash log (Phase 3a, partial)`
**Paused**: 2026-04-14

> To resume: `git checkout fix/bugs-and-safety-net-2026-04 && git pull` and read this file top to bottom. The plan file above has the full "why" for each step; this file has the "where we are" and "what to do next."

---

## TL;DR — where we are

| Phase | Status | What's in it |
|---|---|---|
| 1. Critical bugs (1–3) | ✅ Done & committed | Bug 1 recurring frequency, Bug 2 month balance dates, Bug 3 backup restore |
| 2. High severity (4–10) | ✅ Done & committed | Bug 4 widget totals, Bug 5 _safeNotify, Bug 6 EOM bill reminders, Bug 7 counter reset, Bug 8 isToday, Bug 9 schema check, Bug 10 constant-time PIN |
| 3a. Global error handler | 🟡 **Half done** | Infrastructure + UI screen committed. Settings wiring + unit test **remaining** |
| 3b. sqflite_common_ffi scaffold | ⏳ Not started | pubspec dep + test/integration/_test_helpers.dart |
| 3c. Integration tests (×5) | ⏳ Not started | Regression coverage for Bugs 1, 2, 3, 4, 5, 7 |
| 4a. Remove biometric service | ⏳ Not started | Move 4 files to trash, update services_test.dart |
| 4b. Remove stale files | ⏳ Not started | 12 files move to trash |
| 4c. Version bump + CHANGELOG | ⏳ Not started | pubspec.yaml 4.1.0+5, new CHANGELOG.md |
| Verification | ⏳ Not started | analyze → test → build apk → manual smoke → graphify |

---

## Commits on this branch (11 so far)

```
db2406b feat(crash-log): global error handler + rolling crash log (Phase 3a, partial)
9f5af72 fix(security): constant-time PIN hash comparison (Bug #10)
2e07699 fix(date): align isToday with today() instead of DateTime.now() (Bug #8)
17ca6d7 fix(state): reset _lastAutoCreatedCount each run (Bug #7)
ef9ccde fix(notifications): reschedule end-of-month bill reminders (Bug #6)
a996491 fix(state): guard notifyListeners with _safeNotify after dispose (Bug #5)
037580c fix(widget): read month totals from DB to survive in-memory pruning
022290b fix(backup): preserve account_id and budget month on JSON restore
64f40f9 fix(db): use 10-char date strings in month-balance and range queries
f698289 fix(recurring): honor weekly/biweekly frequency when generating instances
```

Every commit is atomic and revertable — `git revert <sha>` restores a single bug fix.

---

## What changed in this session (full audit trail)

### Phase 1: Critical bugs (all committed)

**Bug 1 — Weekly/biweekly never generated** (`f698289`)
- `lib/providers/app_state.dart`: `_processMonthlyRecurring<T>` → `_processRecurringInstances<T>` with a step function; branches on `recurring.frequency` (weekly/biweekly/monthly).
- `lib/utils/date_helper.dart`: `addDays` helper (already existed at line 129).

**Bug 2 — `calculateMonthBalance` dropped day 1** (`64f40f9`)
- `lib/database/database_helper.dart:1767-1787`: replaced two `toIso8601String()` calls with `DateHelper.toDateString(...)`.

**Bug 3 — Backup restore collapsed accounts & budget months** (`022290b`)
- `lib/database/database_helper.dart`: added `restoreExpensesBatch`, `restoreIncomesBatch`, `restoreBudgetsBatch` that insert with explicit `accountId`/`month`.
- `lib/utils/backup_helper.dart`: rewrites `restoreBackup` to wrap the full restore in a single transaction and bypass `AppState` mutators.

### Phase 2: High severity (all committed)

**Bug 4 — Home widget reports 0** (`037580c`)
- `lib/database/database_helper.dart`: added `getCurrentMonthTotals(accountId, year, month)` (SQL SUM).
- `lib/utils/home_widget_helper.dart`: calls `getCurrentMonthTotals` directly instead of `AppState.getExpensesForMonth`.
- `lib/providers/app_state.dart`: defensive — `_pruneDistantMonths` exempts the current year-month key.

**Bug 5 — `notifyListeners` after dispose** (`a996491`)
- `lib/providers/app_state.dart`: added `_safeNotify()` helper that early-returns when `_isDisposed`. Replaced all ~70 call sites via `replace_all`. `dispose()` sets `_isDisposed = true` before `super.dispose()`.

**Bug 6 — End-of-month bill reminders fire once, forever** (`ef9ccde`)
- `lib/utils/notification_helper.dart`: added `_eomBillKeyPrefix` + `_eomBillKey(id)`. `scheduleBillReminder` EOM branch now reads/writes a SharedPreferences marker for idempotency. Added `rescheduleEndOfMonthBillReminders(List<RecurringExpense>)`.
- `lib/providers/app_state.dart`: calls the rescheduler after `_processRecurringExpenses` completes (outside the write mutex).

**Bug 7 — `_lastAutoCreatedCount` accumulated** (`17ca6d7`)
- `lib/providers/app_state.dart`: `_processRecurringInBackground` resets the counter to 0 after acquiring the `_processingRecurring` guard.

**Bug 8 — `DateHelper.isToday` timezone mismatch** (`2e07699`)
- `lib/utils/date_helper.dart:68`: `isSameDay(date, today())` (was `DateTime.now()`).

**Bug 9 — Backup schema version validation** (rolled into Bug 3 commit `022290b`)
- `lib/utils/backup_helper.dart`: validates `schema_version` in the header against `DatabaseConstants.dbVersion` before any writes; rejects newer-than-app backups with a user-visible error.

**Bug 10 — Non-constant-time PIN hash compare** (`9f5af72`)
- `lib/utils/pin_security_helper.dart:250-260`: new `_constantTimeEquals(String, String)` (XOR-accumulator over `codeUnitAt`). Both legacy and salted branches of `verifyPin` now route through it.

### Phase 3a: Crash log (partially committed — `db2406b`)

**Committed this session:**
- `lib/utils/crash_log.dart` (NEW, 264 lines): `CrashLog` static class with `init`, `record`, `readAll`, `clear`, `resetForTesting`. 256 KB rolling log, 3 files, serialized via future-chain. `@visibleForTesting directoryOverride` for tests.
- `lib/main.dart`: `main()` wrapped in `runZonedGuarded`. `CrashLog.init(appVersion: _appVersion)` called first. Existing try-catches in notification + home-widget init now record to the crash log with context tags.
- `lib/screens/crash_log_screen.dart` (NEW, 174 lines): read-only viewer with Share (uses existing `share_plus` v12 `SharePlus.instance.share(ShareParams(...))`) and Clear actions. `_EmptyCrashLog` widget for the zero-crashes state.

**NOT YET committed for Phase 3a** (see "Next session — exact steps" below):
- `lib/screens/settings_screen.dart`: needs a new ADVANCED section with a Crash Log tile that routes to `CrashLogScreen`. Without this, the screen exists but is unreachable from the UI.
- `test/utils/crash_log_test.dart`: unit test that exercises write / rotate at 256 KB / readAll ordering / clear using `directoryOverride` to point at a `Directory.systemTemp.createTempSync(...)`.

---

## Next session — exact steps to resume

### Step 0: Situate yourself (2 min)

```bash
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git checkout fix/bugs-and-safety-net-2026-04
git pull
git log --oneline -15              # confirm db2406b is at the tip
flutter analyze 2>&1 | tail -20    # should be clean
```

Read `C:\Users\leooa\.claude\plans\typed-crunching-brooks.md` Phase 3 onwards. This file (`SESSION_HANDOFF.md`) is the delta.

### Step 1: Finish Phase 3a (Settings wiring + unit test)

**1a. Wire Settings entry**

Edit `lib/screens/settings_screen.dart`:

1. Add import at the imports block (alphabetical order — insert between `category_manager_screen.dart` and `export_data_screen.dart`):
   ```dart
   import 'crash_log_screen.dart';
   ```

2. The file has sections in this order (line numbers from the last session's survey — re-grep if stale):
   - line 77: ACCOUNTS
   - line 94: APPEARANCE
   - line 207: SECURITY
   - line 214: PREFERENCES
   - line 287: INSIGHTS
   - line 322: DATA & BACKUP
   - line 370: NOTIFICATIONS (ends ~line 389)
   - line 394: APP INFO Center footer

   Insert a new ADVANCED section between the NOTIFICATIONS `_SettingsCard` close and the APP INFO Center footer. Match the existing pattern exactly:

   ```dart
   const SizedBox(height: Spacing.lg),
   const _SectionHeader(title: 'ADVANCED'),
   const SizedBox(height: Spacing.sm),
   _SettingsCard(
     children: [
       _SettingsTile(
         icon: Icons.bug_report_outlined,
         iconColor: appColors.warning,
         title: 'Crash Log',
         subtitle: 'View recorded errors and share with the developer',
         onTap: () {
           HapticFeedback.selectionClick();
           Navigator.push(
             context,
             PremiumPageRoute(page: const CrashLogScreen()),
           );
         },
       ),
     ],
   ),
   ```

   Use whichever color the other destructive/diagnostic tiles use — survey the file and match the convention. If `appColors.warning` isn't available, fall back to `theme.colorScheme.tertiary` or just `Icons.bug_report_outlined` with no override.

3. `flutter analyze lib/screens/settings_screen.dart` — must be clean.

**1b. Write the unit test**

Create `test/utils/crash_log_test.dart`:

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/utils/crash_log.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crash_log_test_');
    CrashLog.resetForTesting();
    CrashLog.directoryOverride = tempDir;
    await CrashLog.init(appVersion: 'test+0');
  });

  tearDown(() async {
    CrashLog.resetForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('record writes a formatted entry to crash.log', () async {
    await CrashLog.record(
      Exception('boom'),
      stack: StackTrace.current,
      context: 'test',
    );
    final content = await CrashLog.readAll();
    expect(content, contains('Exception: boom'));
    expect(content, contains('Context: test'));
    expect(content, contains('App: Money Tracker test+0'));
  });

  test('rotates when active file exceeds maxLogBytes', () async {
    // Write enough records to roll over.
    final bigStack = StackTrace.fromString('x' * 1024);
    for (int i = 0; i < 300; i++) {
      await CrashLog.record('err-$i', stack: bigStack, context: 'loop');
    }
    final files = tempDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('crash.log'))
        .toList();
    expect(files.length, greaterThanOrEqualTo(2));
    expect(files.length, lessThanOrEqualTo(CrashLog.maxLogFiles));
  });

  test('readAll returns oldest first, newest last', () async {
    await CrashLog.record('first', context: 'a');
    await CrashLog.record('second', context: 'b');
    final content = await CrashLog.readAll();
    expect(content.indexOf('first'), lessThan(content.indexOf('second')));
  });

  test('clear deletes every rotation file', () async {
    await CrashLog.record('hello', context: 'a');
    await CrashLog.clear();
    final content = await CrashLog.readAll();
    expect(content.trim(), isEmpty);
  });
}
```

Then:
```bash
flutter test test/utils/crash_log_test.dart
flutter analyze test/utils/crash_log_test.dart lib/screens/settings_screen.dart
```

**1c. Commit Phase 3a completion**

```bash
git add lib/screens/settings_screen.dart test/utils/crash_log_test.dart
git commit -m "feat(crash-log): wire Settings entry + unit tests (Phase 3a complete)"
```

### Step 2: Phase 3b — sqflite_common_ffi scaffold

1. Edit `pubspec.yaml` under `dev_dependencies:` — add `sqflite_common_ffi: ^2.3.3`.
2. `flutter pub get`
3. Create `test/integration/_test_helpers.dart`:
   ```dart
   import 'package:sqflite_common_ffi/sqflite_ffi.dart';
   // plus any common seeding helpers you end up needing in 3c.

   void setUpDbFfi() {
     sqfliteFfiInit();
     databaseFactory = databaseFactoryFfi;
   }
   ```
4. Check whether `DatabaseHelper` needs a `@visibleForTesting` constructor that accepts a `Database` (or an explicit DB path). If it hard-codes the path via `getDatabasesPath()`, you'll need to either (a) swap the factory globally via `databaseFactoryFfi` so the existing path is honored via the in-memory FFI backend, or (b) add a `@visibleForTesting DatabaseHelper.withDb(Database db)` ctor. Pick whichever causes less churn in `database_helper.dart`.
5. Commit: `test: add sqflite_common_ffi scaffold for integration tests (Phase 3b)`

### Step 3: Phase 3c — 5 integration tests

All under `test/integration/`. Each imports `_test_helpers.dart` and uses a fresh in-memory DB per test.

| File | Covers | Regression for |
|---|---|---|
| `recurring_processing_test.dart` | weekly/biweekly/monthly happy paths + Jan 31 → Feb 28 + leap year | Bug #1 |
| `database_helper_test.dart` | day-1, day-15, last-day of month inserted → all three in SUM | Bug #2 |
| `backup_restore_test.dart` | 2 accounts × 5 expenses × 3 historical budgets → round trip | Bug #3 + Bug #9 |
| `home_widget_helper_test.dart` | insert current-month data → prune → widget totals still correct | Bug #4 |
| `app_state_lifecycle_test.dart` | dispose mid-flight (no throw) + counter reset across runs | Bug #5 + Bug #7 |

Target: ~1,200 LOC of new tests, total test count 1,529 → ~1,600+.

Commit: `test(integration): regression suites for Bugs 1–7 (Phase 3c)`

### Step 4: Phase 4a — remove biometric service

Create the trash dir first: `mkdir -p /c/tmp/trash/money-tracker-cleanup-2026-04-14/`

Move (do NOT `rm` — user rule):
- `lib/services/biometric_service.dart`
- `lib/services/biometric_service.dart.bak`
- `lib/screens/biometric_lock_screen.dart`
- `lib/screens/biometric_lock_screen.dart.bak`

Then:
```bash
# Confirm nothing else references them
grep -rn "BiometricService\|biometric_service\|biometric_lock_screen" lib/ test/ android/
```

Update `test/services/services_test.dart` — remove any `BiometricService` references.

Commit: `chore: remove biometric service stub (dead code, Phase 4a)`

### Step 5: Phase 4b — remove stale files

Move to `/c/tmp/trash/money-tracker-cleanup-2026-04-14/`:
- `lib/l10n/app_en.arb` (unreferenced; no `AppLocalizations` imports anywhere — re-grep to confirm)
- `test/widget_test.dart` (22-line placeholder)
- Root docs (10 files):
  - `COMPLETE_FIXES_SUMMARY.md`
  - `FINAL_FIXES_SUMMARY.md`
  - `FIXES_COMPLETED.md`
  - `FIXES_IMPLEMENTED.md`
  - `FIXES_SUMMARY.md`
  - `FIREBASE_SETUP.md`
  - `WEB_DEPLOYMENT.md`
  - `LANDING_PAGE_SETUP.md`
  - `APK_HOSTING_GUIDE.md`
  - `IMPLEMENTATION_GUIDE.md`

Commit: `chore: remove stale docs and dead files (Phase 4b)`

### Step 6: Phase 4c — version bump + CHANGELOG

1. `pubspec.yaml`: `version: 4.1.0+5` (line ~19 — grep for `^version:`).
2. Create `CHANGELOG.md` at repo root:
   ```markdown
   # Changelog

   ## 4.1.0+5 — 2026-04-14

   ### Fixed
   - **Critical**: Weekly/biweekly recurring transactions now auto-generate correctly (previously only monthly worked)
   - **Critical**: Month balance totals now include transactions on the 1st of the month
   - **Critical**: Backup restore now preserves the original account and budget month (previously collapsed everything into the current selection)
   - **High**: Home screen widget no longer shows 0.00 after browsing historical months
   - **High**: No more "ChangeNotifier was used after being disposed" exceptions on app exit during writes
   - **High**: End-of-month bill reminders (days 29–31) now reschedule every month instead of firing once forever
   - **High**: Auto-created recurring counter no longer accumulates across background runs

   ### Security
   - PIN hash comparison is now constant-time (prevents a theoretical timing side channel)

   ### Added
   - Global error handler + local rolling crash log viewable from Settings → Advanced → Crash Log
   ```
3. `lib/main.dart`: `_appVersion` is already `'4.1.0+5'` from Phase 3a — no change needed. Verify it matches.

Commit: `chore: bump version to 4.1.0+5 + CHANGELOG (Phase 4c)`

### Step 7: Verification gate

```bash
flutter analyze                    # zero warnings
flutter test                       # target ~1,600+
flutter build apk --release        # must succeed
```

Manual smoke on emulator or device (the plan lists 7 scenarios — see "Verification" section of `typed-crunching-brooks.md`).

### Step 8: Open the PR

```bash
gh pr create --title "Bug fix + safety net pass (10 bugs + crash log + integration tests)" --body "$(cat <<'EOF'
## Summary
- Fixes 10 verified bugs (3 critical, 5 high, 2 medium/low)
- Adds global error handler + local rolling crash log
- Adds integration test scaffold (sqflite_common_ffi)
- Removes dead biometric service stub + stale root docs
- Bumps version to 4.1.0+5

See CHANGELOG.md for the per-bug breakdown.

## Test plan
- [x] flutter analyze — zero warnings
- [x] flutter test — [fill in count]
- [x] flutter build apk --release
- [x] Manual smoke: weekly/biweekly recurring generation, month-1 analytics, backup round trip, widget totals after history browse, PIN flow, crash log round trip
EOF
)"
```

Then `python -m graphify .` to rebuild the knowledge graph (plan flags the current `graphify-out/` only indexes native Windows runner code).

---

## Uncommitted / untracked files at pause time

These are noise — `.gitignore` candidates for a separate chore PR, not part of this branch:

```
.firebase/            — leftover from when Firebase was briefly present (removed per MEMORY.md)
.idea/                — JetBrains IDE files
graphify-out/         — generated knowledge graph (plan flags it needs rebuilding anyway)
raw/                  — unclear — user work-in-progress?
session-state.md      — likely a hook-generated session scratchpad
wiki/                 — project wiki (check `wiki/index.md` before deleting; referenced in CLAUDE.md)
```

**Do not delete `wiki/` without user confirmation** — the global CLAUDE.md references it as a project knowledge store.

Leave these alone until the branch merges, then handle them in a separate `chore: gitignore cleanup` commit on main.

---

## Decisions / deviations from the original plan

1. **Bug 6 (EOM bill reminders)**: chose to put the idempotency check inside `scheduleBillReminder` (end-of-month branch) rather than in the rescheduler wrapper, so every caller benefits from the skip. Trace:
   - App restart → stored epoch equals computed → skip
   - User edits recurring → `cancelBillReminder` clears marker → next schedule proceeds
   - Generator runs, old reminder fired → computed epoch differs → reschedule for next month

2. **Bug 6 call site**: rescheduler runs *outside* `_writeMutex.synchronized` block (SharedPreferences + notification plugin I/O, not DB).

3. **Bug 7 reset location**: `_processRecurringInBackground` (sole entry point) rather than each individual processor. Keeps both processors consistent.

4. **Bug 8 honesty**: commit message documents that `today()` is built from local `DateTime.now()` components, so in practice the old `isSameDay(date, DateTime.now())` returned the same answer. The fix is about contract consistency and forward-compatibility (if `today()` ever becomes UTC-based for real), not a currently-reproducible user-visible bug.

5. **Phase 3a split**: landing in two commits — infrastructure first (done), Settings wiring + test second (pending). Each commit stays small and revertable.

6. **Version bump deferred to Phase 4c**: `main.dart` already has `const String _appVersion = '4.1.0+5';` but `pubspec.yaml` is still `4.0.0+4`. They'll be bumped together in 4c so the version string only goes live alongside the CHANGELOG entry.

---

## Known issues to watch for in next session

1. **Line endings**: `git add` warned `LF will be replaced by CRLF` for `crash_log.dart` and `crash_log_screen.dart`. If CI ever gets strict about EOL, may need a `.gitattributes` entry. Not blocking.
2. **`notifyListeners` vs `_safeNotify` in new code**: if Phase 3c tests call `AppState` mutations after disposal, they'll need to hit the `_safeNotify` guard — that's the whole point of the test. Don't add new raw `notifyListeners()` calls.
3. **`sqflite_common_ffi` on Windows**: pulls in `sqlite3.dll`. The FFI package bundles it but if it fails to load, the test will say "failed to load dynamic library" — check the package README for the Windows troubleshooting note.
4. **Share sheet on Windows desktop target**: `share_plus` v12 supports Windows, but the `CrashLogScreen` share button is primarily tested on Android/iOS. If a Windows user opens the screen the share may fall back to saving via the file picker — leave for now, flag if reported.

---

## File-by-file inventory (what's live, what's stubbed)

### Fully committed (safe to rely on)
- `lib/providers/app_state.dart` — Bugs 1, 5, 6, 7 all landed
- `lib/database/database_helper.dart` — Bugs 2, 3, 4 all landed
- `lib/utils/backup_helper.dart` — Bugs 3, 9 landed
- `lib/utils/home_widget_helper.dart` — Bug 4 landed
- `lib/utils/date_helper.dart` — Bug 8 landed
- `lib/utils/notification_helper.dart` — Bug 6 landed
- `lib/utils/pin_security_helper.dart` — Bug 10 landed
- `lib/utils/crash_log.dart` — NEW (Phase 3a)
- `lib/main.dart` — Phase 3a wiring landed
- `lib/screens/crash_log_screen.dart` — NEW (Phase 3a)

### Unchanged but needed for Phase 3a completion
- `lib/screens/settings_screen.dart` — needs ADVANCED section + import

### Unchanged but needed for Phase 3b/3c
- `pubspec.yaml` — add `sqflite_common_ffi` dev dep + version bump in 4c
- `test/integration/_test_helpers.dart` — NEW
- `test/integration/recurring_processing_test.dart` — NEW
- `test/integration/database_helper_test.dart` — NEW
- `test/integration/backup_restore_test.dart` — NEW
- `test/integration/home_widget_helper_test.dart` — NEW
- `test/integration/app_state_lifecycle_test.dart` — NEW
- `test/utils/crash_log_test.dart` — NEW (Phase 3a finish)

### To be deleted (moved to trash, Phase 4)
- `lib/services/biometric_service.dart` + `.bak`
- `lib/screens/biometric_lock_screen.dart` + `.bak`
- `lib/l10n/app_en.arb`
- `test/widget_test.dart`
- 10 stale root markdown files (see Step 5)

---

## Fast-path commands for next session

```bash
# Resume
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git checkout fix/bugs-and-safety-net-2026-04 && git pull

# Sanity check
flutter analyze 2>&1 | tail -20
git log --oneline -12

# Read the plan + this handoff
cat SESSION_HANDOFF.md
cat "/c/Users/leooa/.claude/plans/typed-crunching-brooks.md"

# Phase 3a finish
# edit lib/screens/settings_screen.dart
# write test/utils/crash_log_test.dart
flutter analyze lib/screens/settings_screen.dart test/utils/crash_log_test.dart
flutter test test/utils/crash_log_test.dart
git add lib/screens/settings_screen.dart test/utils/crash_log_test.dart
git commit -m "feat(crash-log): wire Settings entry + unit tests (Phase 3a complete)"
git push
```

---

## If something's gone wrong

- `flutter analyze` fails in Phase 3a files → re-read `lib/utils/crash_log.dart` end-to-end; most likely an import drift after a Flutter SDK update.
- `crash_log_test.dart` fails on Windows due to temp dir locking → add `try { await tempDir.delete(recursive: true); } catch (_) {}` in `tearDown`.
- `flutter test` before any Phase 3c test runs because the FFI factory wasn't initialized → make sure every integration test file calls `setUpDbFfi()` in its `main()` before any `test(...)` blocks.
- Analyzer complains about `CrashLogScreen` being unused → that was expected until Step 1a wires Settings; after wiring it should resolve.

---

**End of handoff. Good luck, future-us.**
