# Session 7+ — Final Push to `v5.0.0+1` Ship

**Drafted:** 2026-05-12 (end of session 6, in preparation for next session).
**Status at draft time:** `release/v5.0.0` and `main` both at `b753604` on origin. `flutter test`: 1,798 pass. `flutter analyze`: clean.
**Companions:** `docs/MASTER_PLAN.md` (why), `docs/CHECKLIST.md` (per-task ticks), `docs/NEXT_STEPS.md` (post-session-6 snapshot), `SESSION_HANDOFF.md` (last close).

This is a **playbook**, not a status report — it tells the next session (or whoever picks up) exactly what to do, in what order, with file paths, acceptance criteria, and risk notes. Anything not in this file is out of scope for v5.0.0 (see `MASTER_PLAN.md` §"Out of v5.0.0").

---

## 0. Snapshot — what's done, what's left

### Done (sessions 0–6)
- Phases 0–4: pre-flight + Stop-the-Bleeding (10) + Architectural Foundations (7) + Race & Lifecycle (7/7; 3.8 deferred) + Schema v19 (12)
- Phase 5: 17/20 — Settings, Wallet, Budgets, Analytics, Home, all 10 secondaries, brand alignment, Spacing retirement
- Phase 6: 5/6 — PIN secure storage, backup AES-GCM + UX, FLAG_SECURE, widget redaction, crash PII redactor
- Phase 7: 7/10 — onboarding tests, cascade-delete tests, AppState mutator subset, PIN lockout, Clock injection, CI gates
- Phase 8: 2/5 — preflight + lint guard, APK build verified

### Remaining (in execution order)
| Stage | Task | Risk | Effort |
|---|---|---|---|
| **A** | Device smoke tests (PIN migration / FLAG_SECURE / PII redactor / widget redaction / backup round-trip) | Medium | 1–2 hours, device required |
| **B.6** | History split — 2,307 lines → 4 files under `lib/screens/history/` | Low | 4–6 hours |
| **B.7** | Recurring merge — `recurring_expenses` + `recurring_income` → `recurring_items` | Medium (R5: notification IDs) | 5 hours |
| **B.5** | Add Transaction merge — delete `add_hub` + `add_expense` + `add_income`, create unified screen | High (R4: user behaviour) | 1 day |
| **C** | Phase 6.1 SQLCipher migration | High (R1/R2/R11: data-loss) | 1.5 days, device required |
| **D.2** | Remaining AppState CRUD mutator tests | Low | 1 day |
| **D.6** | Hero-screen widget tests with seeded data | Low | 1 day |
| **D.8** | Goldens for 8 hero screens | Low | 1 day |
| **E** | Perf pass + version bump + ship pipeline | Medium | 1 day, device required |

**Realistic wall-clock to a live `v5.0.0+1`:** 7–10 days with one engineer + agent pair. **Fast path** (multiple parallel windows, hands-on device): 4–6 days.

---

## 1. Sequencing rationale

1. **Stage A first.** Every Phase 6 commit so far has had its production-validation deferred to "next session with device". Run the device smokes before adding more risk on top. If any fail, revert the offending commit before continuing.
2. **B.6 before B.7 before B.5.** Pure refactor first (B.6 changes zero behaviour), then medium-risk merge (B.7 keeps existing screens working), then highest-risk structural change (B.5 deletes three screens and rewires every caller).
3. **C after B.** SQLCipher rekey runs against a stable codebase. Doing it in parallel with B.5 risks a rekey failure being misattributed to a refactor.
4. **D after B.** Writing widget tests against soon-to-be-deleted screens is waste.
5. **E is a gate, not a step.** Only tag `v5.0.0+1` after every stage above is green AND a 5-minute device smoke (per `MASTER_PLAN.md §8.3`) passes end-to-end.

---

## 2. Stage A — Device smoke tests (1–2 hours, device required)

**Goal:** validate the security work from sessions 2–5 on a real device. If anything regresses, revert the offending commit and replan.

### A.0 — Push everything and sync (already done at session-6 close, but re-verify)
```bash
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git fetch --all
git status                # clean
git log --oneline -3      # last three commits match origin
```

### A.1 — Fresh release APK install (10 min)
```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.moneytracker.app/.MainActivity
```
**Acceptance:** app opens. Home shows current account + empty transactions list (or seeded data on existing install).

### A.2 — PIN migration smoke (20 min)
1. Settings → Security → enable PIN → enter `1397`.
2. `adb shell am force-stop com.moneytracker.app`
3. **Clean-install case:** `adb shell run-as com.moneytracker.app cat shared_prefs/FlutterSharedPreferences.xml` — `app_pin_hash`, `app_pin_salt`, `pin_enabled` should be **absent** (they live in Keystore).
4. Reopen app → PIN unlock screen → enter `1397` → unlocks.
5. **Legacy-migration case (separate device or wipe data first):**
   - Install a v4.4.0+6 APK from `expense-tracker-landing` (the previous version on the landing page).
   - Set PIN under legacy build.
   - Verify legacy entries present in SharedPreferences.
   - Sideload the v5.0.0 build over top (`adb install -r`).
   - Open → enter PIN → must verify on first attempt.
   - Re-check SharedPreferences — `app_pin_hash` / `app_pin_salt` should now be **absent** (migrated).

**Acceptance:** both flows pass. PIN never has to be re-set.
**On failure:** `git revert 3a290ed` (PIN secure-storage commit). File an issue documenting device + Android version + symptom. Stage B does NOT start until this is fixed or reverted.

### A.3 — FLAG_SECURE in Recents (5 min)
1. With PIN enabled, hit the device's Recents button.
2. Expected: FinanceFlow's Recents thumbnail shows a black/blank surface.
3. Disable PIN → hit Recents again → thumbnail now shows the real screen.

**Acceptance:** thumbnail visibility toggles with PIN state.

### A.4 — Crash PII redactor (5 min)
1. Temporarily add `throw Exception(r'fake $123 leak C:\Users\leooa\fake.db');` to `AppState.loadData()` (just before `_isInitialized = true;`).
2. `flutter build apk --release && adb install -r ...`
3. Open app → expect a crash log entry.
4. Settings → Advanced → Crash Log → verify the latest entry contains `[user]` and `[amount]`, **not** the literal `leooa` or `$123`.
5. Revert the temporary throw, rebuild.

**Acceptance:** PII redactor fires on a real-device crash record.

### A.5 — Widget PIN redaction (5 min)
1. Long-press launcher home screen → Widgets → FinanceFlow → drop on home.
2. Toggle PIN OFF → widget shows current balance / month / income / expenses normally.
3. Toggle PIN ON → widget shows `•••` in every monetary field, `Locked` for the month label. Currency symbol stays (e.g. `$ •••`).
4. Force a widget refresh (launcher's update-now action).

**Acceptance:** widget content matches PIN state on every refresh. No layout shift.

### A.6 — Backup AES-GCM round-trip (10 min)
1. Backup & Restore → Save Backup → enter passphrase `testpass1` (min-6-char) → confirm.
2. Open the saved `.etbackup` file in a text editor — content should look like opaque JSON envelope, not readable plaintext.
3. Restore Backup → pick the same file → enter `wrongpass` → expect "Wrong passphrase — try again" banner.
4. Enter `testpass1` → restore completes.
5. Restore a legacy plaintext backup (v2/v3 from before the encryption feature) → should restore transparently without a passphrase prompt.

**Acceptance:** correct passphrase decrypts; wrong rejects; cancel aborts cleanly; legacy plaintext passes through.

**Stage A gate:** all 5 smokes pass. If yes → Stage B. If anything fails, revert + plan a fix session.

---

## 3. Stage B.6 — History split (4–6 hours, LOWEST RISK)

**Why first:** pure refactor. Zero behavior change. Big readability win. Unblocks B.5 if any code-sharing is needed.

### B.6.1 — Plan the split

`lib/screens/history_screen.dart` (2,306 lines) becomes a folder:

```
lib/screens/history/
├── history_screen.dart            # Top-level composition + state (was: HistoryScreen class)
├── history_filter_bar.dart        # Search field + type filter + category filter + date filter UI
├── history_list.dart              # The actual transaction ListView (per-section)
└── history_grouping.dart          # Pure functions: groupByDay, groupByWeek, groupByMonth, formatGroupHeader
```

The split is "behavior in / extract widgets out", so do it as a series of **independent pull-outs** rather than a single big-bang rewrite.

### B.6.2 — Pull out grouping first (1 hour, pure extract)
- Find all `groupBy*` helpers in `history_screen.dart` (search for `Map<String, List<` and `groupBy`).
- Move them to `lib/screens/history/history_grouping.dart` as top-level functions (not class methods).
- Add a **unit test file**: `test/screens/history_grouping_test.dart` with 5 tests:
  - Day-grouping bucket boundary at midnight.
  - Week-grouping respects locale start-of-week.
  - Month-grouping uses YYYY-MM key (matches Phase 4.8 normalisation).
  - Empty input → empty map.
  - Group headers format consistently.
- Update `history_screen.dart` to import + use the extracted functions.
- Verify: `flutter analyze` clean, `flutter test test/screens/history_grouping_test.dart` 5 pass.
- **Commit:** `refactor(phase-5.6.1): extract history grouping pure functions`.

### B.6.3 — Pull out filter bar (1.5 hours)
- Find the filter UI block (search field + GlassPillChip row + GlassSegmentedControl for type).
- Move into `lib/screens/history/history_filter_bar.dart` as a `StatelessWidget` with these parameters:
  ```dart
  class HistoryFilterBar extends StatelessWidget {
    final String searchQuery;
    final ValueChanged<String> onSearchChanged;
    final String typeFilter;          // 'all' | 'expenses' | 'income'
    final ValueChanged<String> onTypeChanged;
    final String? categoryFilter;
    final ValueChanged<String?> onCategoryChanged;
    final DateTimeRange? dateRange;
    final ValueChanged<DateTimeRange?> onDateRangeChanged;
    ...
  }
  ```
- Keep state in the parent (history_screen.dart). The filter bar is dumb.
- Verify: `flutter analyze` clean, `flutter test` green.
- **Commit:** `refactor(phase-5.6.2): extract HistoryFilterBar widget`.

### B.6.4 — Pull out list (1.5 hours)
- The transaction-list block + per-day grouping headers + `_TransactionTile` rendering.
- Move into `lib/screens/history/history_list.dart` as a `StatelessWidget`:
  ```dart
  class HistoryList extends StatelessWidget {
    final List<Expense> expenses;
    final List<Income> incomes;
    final Map<String, List<dynamic>> grouped;
    final ValueChanged<Expense> onEditExpense;
    final ValueChanged<Income> onEditIncome;
    ...
  }
  ```
- Critical: preserve the narrow `context.select<AppState, ...>` calls — `test/lint/no_global_appstate_watch_test.dart` must stay green.
- Preserve the `RepaintBoundary` placement (if any — Phase 1.7 is on Home, but check History too).
- Verify: `flutter analyze` clean, `flutter test` green.
- **Commit:** `refactor(phase-5.6.3): extract HistoryList widget`.

### B.6.5 — Slim down `history_screen.dart` (1 hour)
- Move the (now-much-smaller) file to `lib/screens/history/history_screen.dart`.
- Update `main.dart`'s `_screens` list import (`import 'screens/history_screen.dart';` → `import 'screens/history/history_screen.dart';`).
- Grep for any other imports of the old path and update them.
- Verify: `flutter analyze` clean, `flutter test` green.
- **Commit:** `refactor(phase-5.6.4): relocate HistoryScreen into history/ subfolder`.

### B.6.6 — Smoke test (30 min)
- Open History screen on device → scroll 500 expenses → confirm 60 fps on Pixel 4a class.
- Toggle every filter combination (search + type + category + date range) → confirm results match.
- Tap a transaction → edit dialog still pushes correctly (AddExpense/AddIncome — note these still exist at this point; B.5 hasn't run yet).

**B.6 gate:** all four commits land, `bash scripts/preflight.sh` green, device smoke passes.

---

## 4. Stage B.7 — Recurring items merge (4–5 hours, MEDIUM RISK)

**R5 mitigation:** the existing `RecurringExpense` + `RecurringIncome` models keep their database IDs. Notification IDs in `NotificationHelper` (10000–19999 for bill reminders, 20000–29999 for budget alerts) must NOT shift. Do not renumber.

### B.7.1 — Create the merged screen (2 hours)
- New file: `lib/screens/recurring_items_screen.dart`
- Class: `RecurringItemsScreen`
- Composition:
  - `GlassTopAppBar(title: 'Recurring Items', leading: BackButton(...))`
  - `GlassSegmentedControl<String>(values: ['expense', 'income'], labels: ['Expenses', 'Income'], selected: _selected, onChanged: ...)`
  - Conditional list:
    ```dart
    if (_selected == 'expense') _RecurringExpensesList()
    else _RecurringIncomeList()
    ```
- The two list widgets are extracted from the existing `recurring_expenses_screen.dart` / `recurring_income_screen.dart` bodies (their build methods minus the Scaffold/AppBar).

### B.7.2 — Update callers (30 min)
Callers (from session-6 grep):
- `lib/main.dart:534` — `RecurringExpensesScreen` → `const RecurringItemsScreen(initialType: 'expense')`.
- `lib/screens/add_hub_screen.dart:88` — same (this file dies in B.5, but until then, update it for correctness).
- `lib/screens/settings_screen.dart:175` — `RecurringExpensesScreen` → `RecurringItemsScreen(initialType: 'expense')`.
- `lib/screens/settings_screen.dart:188` — `RecurringIncomeScreen` → `RecurringItemsScreen(initialType: 'income')`.

### B.7.3 — Move old files to TRASH (10 min)
```bash
mv lib/screens/recurring_expenses_screen.dart TRASH/recurring_expenses_screen.dart_merged_into_items
mv lib/screens/recurring_income_screen.dart TRASH/recurring_income_screen.dart_merged_into_items
# Append to TRASH-FILES.md with the reason.
```

### B.7.4 — Tests (1 hour)
- New `test/screens/recurring_items_screen_test.dart` with 2 widget tests:
  - GlassTopAppBar + segmented control render.
  - Toggling between Expense and Income changes the visible list.
- Verify existing integration tests still pass (notification scheduling, `onRecurringBatch` stream — these test AppState/DatabaseHelper directly, not the screen).

### B.7.5 — Smoke test (15 min)
- Add a recurring expense via the new merged screen → notification fires at the configured time.
- Switch to Income tab → existing recurring income shown.
- Settings → Recurring Expenses → opens new screen with Expense tab selected.
- Settings → Recurring Income → opens new screen with Income tab selected.

**Commit:** `feat(phase-5.7): merge recurring expenses/income into unified RecurringItemsScreen`.

**B.7 gate:** notifications still fire from existing recurring rows. `bash scripts/preflight.sh` green.

---

## 5. Stage B.5 — Add Transaction merge (1 day, HIGHEST RISK)

**Why last in Stage B:** deletes three screens (`add_hub`, `add_expense`, `add_income`) and rewires 7+ caller sites. R4 risk: users who learned the v4 hub-then-form flow may be confused by the unified form.

### B.5.1 — Design the unified form (30 min, no code)

`AddTransactionScreen` is one form with a type-toggle at the top:

```
┌─ GlassTopAppBar("Add Transaction") ──────────────────────────┐
│  [Expense  Income]   ← GlassSegmentedControl                  │
├──────────────────────────────────────────────────────────────┤
│  Amount    │ $___________________________________            │
│  Category  │ [bento grid of category icons — CategoryBentoGrid] │
│  Date      │ [date picker chip]                               │
│  Description│ [_____________________________________]        │
│  Payment   │ [Cash | Card | Bank | Mobile | Other]           │
│  Notes     │ [_____________________________________]         │
│  Tags      │ [+ chips]                                        │
│  Quick templates │ [horizontal scroll of template chips]      │
├──────────────────────────────────────────────────────────────┤
│              [ Save ]                                         │
└──────────────────────────────────────────────────────────────┘
```

**Toggling type preserves description / amount / date** — only the category list and the income-specific fields (or expense-specific fields like "Amount Paid") swap.

### B.5.2 — Create the unified screen (4 hours)

New file: `lib/screens/add_transaction_screen.dart`

```dart
enum TransactionType { expense, income }

class AddTransactionScreen extends StatefulWidget {
  final TransactionType initialType;
  final Expense? expense;        // for edit mode
  final Income? income;          // for edit mode

  const AddTransactionScreen({
    super.key,
    this.initialType = TransactionType.expense,
    this.expense,
    this.income,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}
```

Field migration:
- **Amount, description, date, payment method, notes, tags, category** — shared fields.
- **Amount paid** — expense-only; hidden when type=income.
- **Recurring frequency** — both, but option set differs.

Atomic submission:
- Expense: `DatabaseHelper.createExpenseWithCarryover(...)` (Phase 1.6).
- Income: `DatabaseHelper.createIncomeWithCarryover(...)` (Phase 1.6).
- Both pre-compute carryover via `AppState._prepareCarryoverUpserts` — no behavior change.

Quick template integration: tapping a template chip fills the form via `AppState.useTemplate(template)` (Phase 1.1 — already correct).

### B.5.3 — First-launch tooltip (R4 mitigation, 30 min)

- `lib/services/onboarding_service.dart`: add `bool seenAddTransactionTooltip` field + getter/setter using `SharedPreferences`.
- On first AddTransactionScreen entry (after onboarding):
  - If `!seenAddTransactionTooltip`, overlay a `Tooltip`-style coach mark: "Tap to add a transaction. Toggle between Expense and Income at the top."
  - Mark `seenAddTransactionTooltip = true` on dismiss.

### B.5.4 — Update every caller (1 hour)

Callers (from session-6 grep — verify with `grep -rn "AddExpenseScreen\|AddIncomeScreen\|AddHubScreen" lib/`):

| File | Line | From | To |
|---|---|---|---|
| `lib/main.dart` | 371 | `const AddHubScreen()` | `const AddTransactionScreen()` |
| `lib/screens/history_screen.dart` | 181 | `AddExpenseScreen(expense: expense)` | `AddTransactionScreen(initialType: TransactionType.expense, expense: expense)` |
| `lib/screens/history_screen.dart` | 189 | `AddIncomeScreen(income: income)` | `AddTransactionScreen(initialType: TransactionType.income, income: income)` |
| `lib/screens/history_screen.dart` | 2264 | `const AddExpenseScreen()` | `const AddTransactionScreen(initialType: TransactionType.expense)` |
| `lib/screens/history_screen.dart` | 2280 | `const AddIncomeScreen()` | `const AddTransactionScreen(initialType: TransactionType.income)` |
| `lib/screens/home_screen.dart` | 297 | `const AddExpenseScreen()` | `const AddTransactionScreen(initialType: TransactionType.expense)` |
| `lib/screens/home_screen.dart` | 795 | `AddExpenseScreen(expense: expense)` | `AddTransactionScreen(initialType: TransactionType.expense, expense: expense)` |

(Note: history_screen.dart line numbers reflect pre-B.6 state. Adjust if B.6 already moved code.)

### B.5.5 — Move old files to TRASH (5 min)
```bash
mv lib/screens/add_hub_screen.dart TRASH/add_hub_screen.dart_merged
mv lib/screens/add_expense_screen.dart TRASH/add_expense_screen.dart_merged
mv lib/screens/add_income_screen.dart TRASH/add_income_screen.dart_merged
# Append to TRASH-FILES.md.
```

### B.5.6 — Tests (1 hour)

New `test/screens/add_transaction_screen_test.dart` with 4 widget tests:
1. **Submit expense** — pumping with `initialType: TransactionType.expense`, fill fields, tap Save, assert AppState received an addExpense call (via mock or seeded FFI DB).
2. **Submit income** — same with `initialType: TransactionType.income`.
3. **Toggle preserves shared fields** — fill description + amount + date as expense, toggle to income, assert those fields still hold their values (category swaps).
4. **useTemplate fills form** — tap a template chip, assert form fields update via `AppState.useTemplate`.

Also: update `test/lint/no_unregistered_pushnamed_test.dart` if it has any references to the old screen names.

### B.5.7 — Smoke test (30 min)
- Add a $50 grocery expense via the new screen → appears on Home.
- Toggle to Income, add a $3000 salary → appears on Home.
- Edit a recent expense → form pre-fills correctly.
- Use a quick template → form pre-fills.
- Tap "Recurring" toggle → schedules a notification (verify via Settings → Notifications → Test Notification).

**Commit:** `feat(phase-5.5): merge add_hub + add_expense + add_income into AddTransactionScreen`.

**B.5 gate:** all 4 widget tests pass. Device smoke confirms no regressions. `grep -rn "AddExpenseScreen\|AddIncomeScreen\|AddHubScreen" lib/` returns 0 (except this commit's docstring references).

---

## 6. Stage C — Phase 6.1 SQLCipher migration (1.5 days, HIGH RISK)

**Risk:** mid-flight rekey failure leaves the user without their data. Mitigation: `.pre-sqlcipher-backup` written immediately before the rekey, deleted only after verification.

### C.1 — Add the dependency (30 min)
- `pubspec.yaml`:
  ```yaml
  dependencies:
    sqflite_sqlcipher: ^3.0.0
    # Keep sqflite_common_ffi for tests:
    sqflite_common_ffi: ^2.3.3
  ```
- Remove `sqflite: ^2.3.3` (replaced by sqflite_sqlcipher).
- Update both import sites:
  - `lib/database/database_helper.dart`: `package:sqflite/sqflite.dart` → `package:sqflite_sqlcipher/sqflite.dart`.
  - `lib/utils/backup_helper.dart` (if it imports sqflite): same swap.
- `flutter pub get` → resolve.
- `flutter analyze` → should still be clean (the public API is identical except for the `password:` parameter on `openDatabase`).

### C.2 — Key generation + storage (1 hour)
- New helper: `lib/utils/db_encryption.dart`
  ```dart
  class DbEncryption {
    static const _key = 'db_encryption_key';

    static Future<String> getOrCreateKey() async {
      final existing = await SecurePrefs.readString(_key);
      if (existing != null) return existing;
      final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
      final newKey = base64Encode(bytes);
      await SecurePrefs.writeString(_key, newKey);
      return newKey;
    }
  }
  ```
- Tests: `test/utils/db_encryption_test.dart` with 3 tests (get returns same value across calls, key is 256-bit, key persists across `SecurePrefs` instances).

### C.3 — Migration of existing plaintext DB to encrypted (3 hours)
At `DatabaseHelper._initDatabase()`:

```dart
final dbPath = await getDatabasesPath();
final dbFile = '$dbPath/expense_tracker_v4.db';
final encFile = '$dbPath/expense_tracker_v4.db.enc';
final backupFile = '$dbPath/expense_tracker_v4.db.pre-sqlcipher-backup';

final hasKey = await SecurePrefs.readString('db_encryption_key') != null;
final plaintextExists = await File(dbFile).exists();

if (!hasKey && plaintextExists) {
  // First launch of SQLCipher-enabled build. Migrate.
  await File(dbFile).copy(backupFile);   // safety net

  final key = await DbEncryption.getOrCreateKey();

  // Open plaintext DB with no password.
  final src = await openDatabase(dbFile);

  // Attach encrypted DB.
  await src.execute("ATTACH DATABASE '$encFile' AS encrypted KEY '$key'");
  await src.execute("SELECT sqlcipher_export('encrypted')");
  await src.execute("DETACH DATABASE encrypted");

  await src.close();

  // VERIFY: open encrypted DB and check row counts match the plaintext file's
  // pre-migration counts. Only delete plaintext if counts match.
  final preCounts = await _rowCounts(dbFile);  // helper that opens plaintext
  final encDb = await openDatabase(encFile, password: key);
  final postCounts = await _rowCounts(encDb);

  if (_countsMatch(preCounts, postCounts)) {
    await File(dbFile).delete();
    await File(encFile).rename(dbFile);
    // Backup file deleted after the next successful launch
    // (via _cleanPreSqlcipherBackupAfterSuccess()).
  } else {
    // Verification failed. Log to CrashLog, surface snackbar, fall back.
    await CrashLog.write('SQLCipher migration verification failed; row counts differ');
    if (await File(encFile).exists()) await File(encFile).delete();
    // Continue using plaintext DB. SecurePrefs key already exists — that's fine.
  }
}
```

Then:
```dart
final key = await DbEncryption.getOrCreateKey();
final db = await openDatabase(dbFile, password: key, ...);
```

### C.4 — Tests (2 hours)

New `test/integration/sqlcipher_migration_test.dart` (uses `sqflite_common_ffi` for the plaintext side and the real plugin for the encrypted side):
1. **Migration from plaintext** — seed plaintext DB with 5 expenses + 3 income, run the rekey, assert encrypted DB opens with the password and has the same row counts.
2. **Verification failure path** — corrupt the encrypted file mid-rekey, assert plaintext DB is preserved + CrashLog entry written + snackbar shown.
3. **Subsequent launches** — second `openDatabase` call with the stored key returns the encrypted DB; key is not re-generated.

Plus `_isPlaintextDatabase(File)` unit test — true for unencrypted, false for encrypted.

### C.5 — Device smoke (30 min)
1. Install on a device that already has v4.4.0 data.
2. Open app → expect 1–3 seconds startup delay (the export).
3. Add a transaction → confirm save works.
4. `adb shell run-as com.moneytracker.app sqlite3 databases/expense_tracker_v4.db ".tables"` → should return "file is not a database" (encrypted, not openable without key).

**Commit:** `feat(phase-6.1): SQLCipher migration with verified-rekey safety net`.

**Stage C gate:** all 3 integration tests + 1 device smoke pass. APK size delta within +5 MB.

---

## 7. Stage D — Test coverage rebuild (1.5–3 days)

### D.1 — Remaining AppState CRUD mutators (1 day)
New `test/integration/app_state_crud_test.dart`. Each test seeds a fresh FFI DB via `makeFreshDb()`, then exercises one mutator end-to-end. Use `FakeClock.fixed(DateTime(2026, 5, 12))` so date-dependent mutators are deterministic.

Mutators to cover (grep `lib/providers/app_state.dart` for `Future<void> ` and `Future<int> ` returns):
- `addExpense` — happy path, FK fail rolls back, atomic carryover.
- `addIncome` — same.
- `useTemplate` (already tested in Phase 1.1, but extend to cover edit case).
- `addBudget`, `setBudget` (already partial).
- `addAccount`, `switchAccount` (already partial), `setDefaultAccount`, `deleteAccount`.
- `markExpensePaid`, `markIncomePaid`.
- `deleteExpense`, `restoreDeletedExpense`, `permanentlyDeleteExpense`.
- `deleteIncome`, `restoreDeletedIncome`, `permanentlyDeleteIncome`.
- `emptyTrash`, `clearOldDeleted`.
- `addCategory`, `updateCategory`, `deleteCategory`, `deleteTransactionsAndCategory`, `reassignCategoryAndDelete`.
- `addTemplate`, `updateTemplate`, `deleteTemplate`.
- `addRecurringExpense`, `updateRecurringExpense`, `deleteRecurringExpense`.
- `addRecurringIncome`, `updateRecurringIncome`, `deleteRecurringIncome`.

Pattern (one test per mutator):
```dart
test('addExpense persists row and fires notifyListeners exactly once', () async {
  final db = await makeFreshDb();
  final state = AppState();
  await state.loadData();
  var notifies = 0;
  state.addListener(() => notifies++);

  await state.addExpense(
    amount: 50.00, category: 'Food', date: DateTime(2026, 5, 12),
    description: 'lunch', paymentMethod: 'Cash',
  );

  expect(state.expenses, hasLength(1));
  expect(state.expenses.first.amount, 50.00);
  expect(notifies, 1);
  final rows = await db.query('expenses');
  expect(rows, hasLength(1));
});
```

### D.2 — Hero-screen widget tests with seeded data (1 day)
**Blocked on Stage B.** Re-do for the 8 hero screens with seeded `AppState` data so per-state assertions become possible:
- Settings: with PIN enabled vs disabled (seed `secureBacking`).
- Wallet: with multiple accounts + a deleted account in trash.
- Budgets: under-budget (50%), at-100%, over-budget (130%) — one budget per state.
- Analytics: with seeded expense data so charts render (also fixes the timer-leak issue).
- Add Transaction: with templates + categories seeded, toggle preserves fields.
- History: with 100 expenses + 50 income across 3 months, filter combos.
- Recurring Items: with 2 recurring expenses + 1 recurring income.
- Home: with budgets + recent transactions + current-account balance.

Each test: ~3 assertions per state, ~5 states × 8 screens = ~40 new tests.

### D.3 — Goldens (1 day, lowest priority)
**Blocked on Stage B + D.2.** For each of the 8 hero screens:
```bash
flutter test --update-goldens test/screens/<name>_test.dart
```
Lock goldens to Windows (the dev platform) and document in `test/golden/README.md`. CI runs at 2% pixel-diff tolerance.

**Stage D gate:** behavioral coverage ≥ 70% (measure: `flutter test --coverage && genhtml coverage/lcov.info -o coverage/html`).

---

## 8. Stage E — Ship pipeline (1 day, device required)

### E.1 — DevTools perf pass (2 hours)
On Pixel 4a class device with DevTools Performance overlay:
- Home scroll with 100 expenses — every frame ≤ 16.7 ms steady-state.
- History scroll with 500 expenses — same.
- Tab switching rapid (Home ↔ History ↔ Add ↔ Analytics ↔ Wallet) — no jank.
- Analytics chart rendering — no dropped frames on first paint.

**On regression:** profile with `dart:developer.Timeline`, identify offender, fix before tagging.

### E.2 — Version bump + CHANGELOG + tag (1 hour)
- `pubspec.yaml`: `version: 4.4.0+6` → `version: 5.0.0+1`.
- `CHANGELOG.md`: add v5.0.0 entry summarizing every phase (use `MASTER_PLAN.md §"Definition of done"` per-phase descriptions).
- Commit:
  ```
  chore(release): bump version to 5.0.0+1

  CHANGELOG.md entry for v5.0.0 release. See docs/MASTER_PLAN.md
  for the full per-phase breakdown.
  ```
- Tag:
  ```bash
  git tag v5.0.0+1
  git push origin release/v5.0.0 --tags
  ```

### E.3 — Ship pipeline (30 min)
Full pipeline per `CLAUDE.md` § "Shipping the APK":
```bash
flutter build apk --release && \
cp build/app/outputs/flutter-apk/app-release.apk \
   /c/Users/leooa/Documents/personal-projects/expense-tracker-landing/public/downloads/money-tracker.apk && \
git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing add public/downloads/money-tracker.apk && \
git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing commit -m "chore: ship v5.0.0+1 — FinanceFlow Luminous" && \
git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing push && \
(cd /c/Users/leooa/Documents/personal-projects/expense-tracker-landing && vercel --prod --yes)
```

Verify SHA-1:
```bash
curl -sL https://leo-money-tracker.vercel.app/downloads/money-tracker.apk | sha1sum
sha1sum build/app/outputs/flutter-apk/app-release.apk
```
Both must match.

**Note:** Vercel Git integration is **disconnected** for `expense-tracker-landing` (per user's auto-memory). `vercel --prod --yes` is the *required* deploy command; `git push` alone is not enough.

### E.4 — GitHub release (15 min)
```bash
gh release create v5.0.0+1 \
  --title "v5.0.0+1 — FinanceFlow Luminous" \
  --notes-file CHANGELOG.md \
  build/app/outputs/flutter-apk/app-release.apk
```

### E.5 — Merge `release/v5.0.0` → `main` (10 min)
```bash
git checkout main
git merge --ff-only release/v5.0.0   # FF only — history is linear
git push origin main
git checkout release/v5.0.0
```

### E.6 — Post-ship verification (15 min)
- Download APK from `https://leo-money-tracker.vercel.app/downloads/money-tracker.apk`.
- Install on a previously-unupgraded test device.
- 5-minute manual smoke (per `MASTER_PLAN.md §8.3`):
  1. Onboarding → Get Started.
  2. Add expense (Food, $25, today).
  3. Add income (Salary, $3000, today).
  4. Set a budget (Food, $200).
  5. Backup → Save → with passphrase.
  6. Restore → from same file → enter passphrase → confirm data restored.
  7. Settings → Security → enable PIN (1234).
  8. Background app → resume → unlock with PIN.
  9. Force-stop → reopen → unlock with PIN.

**Stage E gate (= v5.0.0 ship gate):**
- Tag `v5.0.0+1` exists on origin and points at the same SHA on `main`.
- Landing page serves the APK at the documented SHA-1.
- GitHub release exists.
- 5-minute device smoke passes end-to-end.

---

## 9. Cross-cutting clean-ups (do anytime)

- **Old `dist/baseline/` artifacts.** `dist/baseline/v4.4.0+6.db` and `dist/baseline/perf/` were skipped in session 1. Either populate (export a dev DB from Stage A.2's test device) or remove the placeholder entries from `docs/CHECKLIST.md`.
- **Stale `.v18-backup` files.** Phase 4.1's pre-migration backup auto-cleans after a successful migration. Verify the cleanup path in `DatabaseHelper._cleanV18BackupAfterMigrationSuccess` actually runs in Stage A.1.
- **`pubspec.lock` audit.** After Stage C lands `sqflite_sqlcipher`, run `flutter pub upgrade --major-versions` once and audit the diff. Don't auto-accept — some transitive bumps will break things.
- **Re-enable skipped widget tests.** Two screens have skipped widget tests sitting in `TRASH/`:
  - `analytics_screen_test.dart_skipped` — chart `AnimationController` tickers leak under `flutter test`. D.2 with seeded chart data + explicit `dispose()` should unblock.
  - `notification_settings_screen_test.dart_skipped` — `FlutterLocalNotificationsPlatform.instance` is a `late final` static. Either mock the platform interface or extract the `_helper` into a swappable injection point.

---

## 10. Definition of Done for `v5.0.0+1`

All of the following must be true before tagging:

1. **Every checklist item in `docs/CHECKLIST.md` ticked** (except explicit deferrals — 3.8 AppPhase, D.1 rename if not paired with D.2).
2. **`bash scripts/preflight.sh` green** on `release/v5.0.0` (test-count gate ≥ 1750; ratchet to baseline+50 after D.2 lands).
3. **APK builds clean** (`flutter build apk --release` exits 0, size ≤ 70 MB).
4. **5-minute device smoke test passes** end-to-end (per `MASTER_PLAN.md §8.3`).
5. **`pubspec.yaml` version is `5.0.0+1`.**
6. **CHANGELOG.md** has a v5.0.0 entry.
7. **`v5.0.0+1` tag exists** on `origin/release/v5.0.0`.
8. **Landing page serves the APK** at `https://leo-money-tracker.vercel.app/downloads/money-tracker.apk` with a matching SHA-1.
9. **GitHub release exists** at `Leo-Atienza/Money-Tracker` tagged `v5.0.0+1`.
10. **`release/v5.0.0` merged into `main`** (fast-forward).

---

## 11. Risk register (delta from session 6)

| ID | Risk | Status | Mitigation |
|---|---|---|---|
| R1 | Migration v19 fails on a user's device | ✅ Mitigated | Phase 4.1 pre-migration backup |
| R2 | SQLCipher rekey fails mid-flight | ⏳ Open (Stage C) | C.3 verification step + `.pre-sqlcipher-backup` |
| R3 | Variable-font wght axis renders incorrectly on legacy Android | ⏳ Open | Add `fontFamilyFallback` if any device shows wrong weight |
| R4 | Merged Add hub confuses existing users | ⏳ Open (Stage B.5) | First-launch tooltip via `OnboardingService.seenAddTransactionTooltip` |
| R5 | Recurring merge breaks notifications | ⏳ Open (Stage B.7) | Don't touch DB IDs; notification ID ranges 10000–29999 unchanged |
| R6 | Performance budget not met | ⏳ Open (Stage E.1) | Phase 8.2 perf gate; rollback option = bump blur back to 10 |
| R7 | Wall-clock flakes | ✅ Mitigated | Clock injection landed session 3 |
| R8 | PIN secure-storage migration locks user out | ⏳ Open (Stage A.2) | Stage A.2 device test before any new work |
| R9 | Removing `google_fonts` breaks something | ✅ Mitigated | `test/lint/no_forbidden_patterns_test.dart` enforces |
| R10 | Vercel deploy step fails | ✅ Mitigated | `vercel --prod --yes` documented in CLAUDE.md |
| R11 | SQLCipher migration corrupts on a partially-encrypted file | ⏳ Open (Stage C) | C.3 step 6 verifies row counts before destroying plaintext |
| R12 | Backup encryption passphrase forgotten | ✅ Mitigated | UX warning copy + min-6-char + "cannot recover" message landed session 4 |
| R13 | `PinSecurityHelper.isPinEnabled()` aborts publish pipelines in tests | ✅ Mitigated | Tests seed `SharedPreferences.setMockInitialValues` |
| **R14 (new)** | **History split's 4-file structure leaks state across widgets** | ⏳ Open (Stage B.6) | Keep filter/list as dumb StatelessWidgets; state stays in `HistoryScreen` parent. `test/lint/no_global_appstate_watch_test.dart` enforces narrow selects. |
| **R15 (new)** | **AddTransaction toggle loses user-entered shared fields** | ⏳ Open (Stage B.5) | Field state survives type toggle; only category-specific UI swaps. Widget test #3 in B.5.6 pins this. |

---

## 12. First commands the next session should run

```bash
# 1. Land in repo, confirm sync.
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git fetch --all
git status                            # should be clean
git log --oneline -3                  # last commit is b753604 (chore(gitignore))

# 2. Verify the safety net.
bash scripts/preflight.sh             # green, 1798 pass, gate ≥ 1750

# 3. Read this plan + the handoff.
cat docs/SESSION_7_PLAN.md            # this file
cat SESSION_HANDOFF.md
cat docs/CHECKLIST.md

# 4. If device available, start with Stage A.
#    Otherwise, start with Stage B.6 (pure refactor, no device needed).
```

If device available and time-boxed (≤ 2 hours): do Stage A (A.1 through A.6). On failure, revert and replan.

If device NOT available: do Stage B.6 (history split — pure refactor) in one session, then commit. Move to B.7 in the next session.

---

## 13. Order-of-operations cheat sheet

| Step | What | Where | When |
|---|---|---|---|
| 1 | Push if needed (origin already at HEAD at session-6 close) | git | First |
| 2 | `bash scripts/preflight.sh` | terminal | First |
| 3 | Stage A (device smokes) | device | If device available |
| 4 | Stage B.6 — History split | code | Before B.5/B.7 |
| 5 | Stage B.7 — Recurring merge | code | After B.6, before B.5 |
| 6 | Stage B.5 — Add Transaction merge | code | After B.7 |
| 7 | Stage C — SQLCipher | code + device | After Stage B settles |
| 8 | Stage D.1 — CRUD mutator tests | code | After Stage C |
| 9 | Stage D.2 — Hero widget tests with seeded data | code | After Stage B + D.1 |
| 10 | Stage D.3 — Goldens | code | After D.2 |
| 11 | Stage E.1 — Perf pass | device | After Stage D |
| 12 | Stage E.2 — Version bump + tag | git | After E.1 |
| 13 | Stage E.3 — Ship APK to landing | build + Vercel | After E.2 |
| 14 | Stage E.4 — GitHub release | gh CLI | After E.3 |
| 15 | Stage E.5 — Merge to main | git | After E.4 |
| 16 | Stage E.6 — Post-ship device smoke | device | Final gate |

**Tag `v5.0.0+1` only after step 16 passes.**

---

**End of plan. Last touched 2026-05-12 (drafted at session-6 close, for session 7+).**
