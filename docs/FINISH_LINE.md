# Finish Line — getting `v5.0.0+1` shipped

**Drafted:** 2026-05-12, at the close of session 7. Updated 2026-05-12 at the close of session 8.
**Branch at session-8 close:** `release/v5.0.0` @ `691ffc6` (in sync with `origin/release/v5.0.0` and `origin/main`).
**Test count:** 1,862 (+29 over session-7). **Preflight:** green. **Analyze:** clean.
**Companions:** `docs/MASTER_PLAN.md` (why), `docs/SESSION_7_PLAN.md` (prior plan — superseded by this doc), `docs/CHECKLIST.md` (per-task ticks), `SESSION_HANDOFF.md` (last close).

This is a **self-contained playbook** for everything still needed to ship `v5.0.0+1`. If you're picking this up cold, read this file top-to-bottom plus `SESSION_HANDOFF.md`; you can skip `SESSION_7_PLAN.md` (the stages it pre-planned have been re-sequenced here with the post-session-7 deltas baked in).

There is no time pressure. Do each stage properly. Every commit must pass `bash scripts/preflight.sh`. Every commit must not regress the test count.

---

## 0. Quick orientation

### What's already done (don't re-do these)
- **Phases 0–4** (pre-flight, stop-the-bleeding, architectural foundations, race/lifecycle, schema v19): ✅ complete.
- **Phase 5 Luminous redesign: 20 of 20 sub-phases done.** Settings, Wallet, Budgets, Analytics, Home polish, all 10 secondaries (5.9a–j), brand alignment, Spacing retirement, History split (`lib/screens/history/` with 4 files), Recurring merge (`RecurringItemsScreen` + `recurring/recurring_*_view.dart`), and **Add Transaction merge (`AddTransactionScreen` — session 8, `196b3ab`)**.
- **Phase 6 security: 5 of 6.** PIN secure storage migration, AES-GCM backup encryption + UX, FLAG_SECURE, widget redaction, crash PII redactor. **Only 6.1 SQLCipher is left.**
- **Phase 7 test coverage: 7 of 10, with D.1 complete (session 8, `691ffc6`).** Onboarding, cascade-delete, PIN lockout, Clock injection, CI gate, 22-test settings/filters mutator suite, and now 40-pass + 3-skip CRUD mutator suite covering every non-notification-gated mutator on AppState.
- **Phase 8 polish: 2 of 5.** Preflight + lint guard (with session-8 regex tolerance for skipped tests), APK build verified at 59.4 MB.

### What's left (in order)
| Stage | What | Risk | Effort | Device? | Blocks |
|---|---|---|---|---|---|
| **A** | Device smoke tests for Phase 6 work (PIN migration / FLAG_SECURE / PII redactor / widget redaction / backup round-trip) | Medium | 1–2 hours | ✅ Yes | Nothing — independent gate |
| **B.6.5+** | (Optional) extract `_buildExpenseItem` / `_buildIncomeItem` from `lib/screens/history/history_screen.dart` into a tile widget file. Mechanical refactor; deferred from session 7 because it would balloon a low-risk commit into a high-risk one. | Low | 4 hours | No | Nothing |
| **C** | Phase 6.1 SQLCipher migration with `.pre-sqlcipher-backup` safety net | High (R2/R11: data loss) | 1.5 days | ✅ Yes | E |
| **D.2** | Hero-screen widget tests with seeded data — 8 screens × ~5 states each, ~40 tests | Low | 1 day | No | D.3 |
| **D.3** | Goldens for 8 hero screens | Low | 1 day | No | Nothing |
| **E** | DevTools perf pass → version bump 4.4.0+6 → 5.0.0+1 → CHANGELOG → tag → APK ship → landing-page push → GitHub release → fast-forward main | Medium | 1 day | ✅ Yes | The ship itself |

**Wall-clock to live `v5.0.0+1`:** ~4–6 days of focused work (was 6–9 at session-7 close). **Session 8 closed B.5 + D.1 remainder**, reducing the no-device backlog to B.6.5 (optional), D.2, and D.3. Stage A device smokes and Stage C SQLCipher migration still gate the ship.

### Sequencing rationale
1. **Stage A first if device available.** Phase 6 commits across sessions 2–5 deferred their production-validation. Run the smokes before stacking more risk. If any fail, revert the offending commit before continuing.
2. **B.5 before C** so SQLCipher rekey runs against a stable codebase. A rekey failure mid-B.5 would be hard to attribute.
3. **D.2 + D.3 after B.5** because writing widget tests against soon-to-be-deleted screens is waste.
4. **D.1 remainder can slot in anywhere** — it touches `test/integration/` only.
5. **E is a gate, not a step.** Tag `v5.0.0+1` only after every stage above is green AND a 5-minute device smoke (per `MASTER_PLAN.md §8.3`) passes end-to-end.

### Three lessons from sessions 6–7 to apply going forward
- **Always `pumpAndSettle` (not `pump`) in widget tests for any screen that contains `FadeInOnLoad` / `BounceAnimation`** (from `lib/utils/premium_animations.dart`). The 200ms initial-delay timer otherwise registers as "pending after dispose" and fails the test.
- **For integration tests that touch `DatabaseHelper.deleteAccount`, mock the `plugins.flutter.io/path_provider` channel.** Returning `'.dart_tool/test_path_provider'` is enough.
- **Strict-mode `flutter analyze` (preflight) flags `no_leading_underscores_for_local_identifiers` even on test-local helper closures.** Use plain camelCase (`makeExpense`) rather than `_expense`.

---

## 1. Stage A — Device smoke tests (1–2 hours, device required)

**Goal:** validate every Phase 6 commit on a real device. If anything regresses, revert the offending commit, file an issue with device + Android version + symptom, then replan.

### A.0 — Confirm sync (5 min)
```bash
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git fetch --all
git status                       # should be clean
git log --oneline -3             # last commit is 373b3fd (session 7 lint fix)
git rev-parse HEAD               # 373b3fd
git rev-parse origin/main        # should match release/v5.0.0
```

### A.1 — Fresh release APK install (10 min)
```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.moneytracker.app/.MainActivity
```
**Acceptance:** app opens. Home shows the current account + empty transaction list (fresh install) or existing data.

### A.2 — PIN migration smoke (20 min)
1. Settings → Security → enable PIN → enter `1397`.
2. `adb shell am force-stop com.moneytracker.app`.
3. **Clean-install case:** `adb shell run-as com.moneytracker.app cat shared_prefs/FlutterSharedPreferences.xml` — `app_pin_hash`, `app_pin_salt`, `pin_enabled` must be **absent** (they live in Keystore).
4. Reopen → PIN unlock screen → enter `1397` → unlocks.
5. **Legacy migration case** (separate device or wipe data):
   - Install a v4.4.0+6 APK from the landing page first.
   - Set PIN under the legacy build.
   - Verify the legacy entries exist in `FlutterSharedPreferences.xml`.
   - Sideload the v5.0.0 build on top (`adb install -r ...`).
   - Open → enter PIN → must verify on first try.
   - Re-check `FlutterSharedPreferences.xml` — `app_pin_hash` / `app_pin_salt` should now be **absent** (migrated).

**Acceptance:** both flows pass. User never has to re-set the PIN.
**On failure:** `git revert 3a290ed` (the PIN secure-storage commit). File an issue. Do not proceed.

### A.3 — FLAG_SECURE in Recents (5 min)
1. PIN enabled → tap device's Recents button → FinanceFlow thumbnail must show a black/blank surface.
2. PIN disabled → Recents → thumbnail now shows the real screen.

**Acceptance:** thumbnail visibility toggles with PIN state.

### A.4 — Crash PII redactor (5 min)
1. Temporarily add `throw Exception(r'fake $123 leak C:\Users\leooa\fake.db');` to `AppState.loadData()` (just before `_isInitialized = true`).
2. `flutter build apk --release && adb install -r ...`.
3. Open app → expect a crash-log entry written.
4. Settings → Advanced → Crash Log → latest entry should contain `[user]` and `[amount]`, not the literal `leooa` or `$123`.
5. Revert the temporary throw and rebuild.

**Acceptance:** redactor fires on real-device records.

### A.5 — Widget PIN redaction (5 min)
1. Long-press launcher home → Widgets → FinanceFlow → drop on home.
2. PIN OFF → widget shows balances / month / income / expenses normally.
3. PIN ON → every monetary field shows `•••`, month label shows `Locked`. Currency symbol remains (e.g. `$ •••`).
4. Force a launcher refresh.

**Acceptance:** widget content matches PIN state on every refresh.

### A.6 — Backup AES-GCM round-trip (10 min)
1. Backup & Restore → Save Backup → passphrase `testpass1` → confirm.
2. Open saved `.etbackup` in a text editor — opaque JSON envelope, not plaintext.
3. Restore Backup → pick the file → enter `wrongpass` → expect "Wrong passphrase — try again" banner.
4. Enter `testpass1` → restore completes.
5. Restore a legacy v2/v3 plaintext backup → must restore transparently without a passphrase prompt.

**Acceptance:** correct passphrase decrypts; wrong rejects; cancel aborts cleanly; legacy plaintext passes through.

**Stage A gate:** all 5 smokes pass. Proceed to next stage. If anything fails, revert + plan a fix session.

---

## 2. Stage B.5 — Add Transaction merge (1 day, HIGHEST RISK, no device)

**Goal:** replace `AddHubScreen` + `AddExpenseScreen` + `AddIncomeScreen` with a single `AddTransactionScreen` that has an Expense/Income toggle and reuses shared form fields.

**Why high risk:** `add_expense_screen.dart` is 1,380 lines, `add_income_screen.dart` is 1,033 lines. Both are deeply stateful (amount focus, validators, payment-status, recurring frequency, tag pickers, autocomplete). The merge must preserve every behavior and rewire 7+ caller sites, plus add a first-launch tooltip to mitigate R4 (user behaviour change).

### B.5.0 — Pattern library research (20 min, no code)
Skim the recurring merge (commit `1445371`) as the template:
- `lib/screens/recurring_items_screen.dart` — outer scaffold + `GlassTopAppBar` + `GlassSegmentedControl<String>` + tab-conditional body + tab-aware FAB.
- `lib/screens/recurring/recurring_expenses_view.dart` / `recurring_income_view.dart` — the underlying form/list widgets (publicized from `_RecurringList` etc.).
- The `showAddRecurringExpenseDialog(BuildContext)` top-level function pattern.

Apply the **same shape** to AddTransaction:
- New screen wraps a segmented control + a single underlying form widget that takes a `TransactionType` enum and adjusts.

### B.5.1 — Design the unified form on paper (30 min)
```
┌─ GlassTopAppBar("Add Transaction", leading: BackButton) ──────────────┐
│  [Expense  Income]   ← GlassSegmentedControl<TransactionType>          │
├──────────────────────────────────────────────────────────────────────┤
│  Amount       │ $___________________________________                  │
│  Category     │ [bento grid of category icons — CategoryBentoGrid]     │
│  Date         │ [date picker chip]                                     │
│  Description  │ [_____________________________________]                │
│  Payment      │ [Cash | Card | Bank | Mobile | Other]                  │
│  Notes        │ [_____________________________________]                │
│  Tags         │ [+ chips]                                              │
│  Quick chips  │ [horizontal scroll of templates]                       │
├──────────────────────────────────────────────────────────────────────┤
│                          [ Save ]                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Shared across both types:** amount, description, date, payment method, notes, tags, category.
**Expense-only:** amount-paid field (the partial-payment slider).
**Income-only:** none currently. (If a future income-specific field appears, hide it on toggle.)
**Recurring frequency:** both, but the option set differs (`RecurringExpenseFrequency` vs `RecurringIncomeFrequency` enums). Pass the frequency via a polymorphic helper.

**Field migration table (drives the form state class):**

| Field | Expense state | Income state | Notes |
|---|---|---|---|
| `_amount: TextEditingController` | shared | shared | preserved on toggle |
| `_description: TextEditingController` | shared | shared | preserved on toggle |
| `_date: DateTime` | shared | shared | preserved |
| `_paymentMethod: String` | shared | shared | preserved |
| `_notes: TextEditingController` | shared | shared | preserved |
| `_tags: List<Tag>` | shared | shared | preserved |
| `_category: String?` | type-specific | type-specific | **resets on toggle** (Food doesn't make sense for income) |
| `_amountPaid: TextEditingController` | expense-only | hidden | reset when toggled away |
| `_isRecurring: bool` | shared | shared | preserved |
| `_recurringFrequency` | `RecurringExpenseFrequency?` | `RecurringIncomeFrequency?` | re-resolve on toggle |

**R15 mitigation:** field state survives type toggle except for `_category` (category lists differ) and `_amountPaid` (expense-only field has no income analog). Document this in code comments.

### B.5.2 — Build the unified screen (4 hours)

New file: `lib/screens/add_transaction_screen.dart`

```dart
enum TransactionType { expense, income }

class AddTransactionScreen extends StatefulWidget {
  final TransactionType initialType;
  final Expense? expense;   // edit mode (expense)
  final Income? income;     // edit mode (income)

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

The state class holds:
- `_type: TransactionType` (mutated on segmented-control change)
- All shared controllers (`_amount`, `_description`, `_notes`, `_amountPaid`)
- All shared scalars (`_date`, `_paymentMethod`, `_isRecurring`, etc.)
- `_category: String?` (cleared on toggle)
- `_recurringFrequencyExpense: RecurringExpenseFrequency?`
- `_recurringFrequencyIncome: RecurringIncomeFrequency?`

On `_toggleType(TransactionType v)`:
```dart
setState(() {
  _type = v;
  _category = null;            // categories differ
  if (v == TransactionType.income) {
    _amountPaid.clear();       // income doesn't have partial pay
  }
});
```

On `_save()`:
```dart
if (_type == TransactionType.expense) {
  final expense = Expense(...);
  // edit mode:
  if (widget.expense != null) {
    await context.read<AppState>().updateExpense(...);
  } else {
    await context.read<AppState>().addExpense(expense);
  }
} else {
  final income = Income(...);
  if (widget.income != null) {
    await context.read<AppState>().updateIncome(...);
  } else {
    await context.read<AppState>().addIncome(income);
  }
}
```

Both `addExpense` and `addIncome` already pre-compute carryover via `AppState._prepareCarryoverUpserts` (Phase 1.6), so the atomic-write contract is preserved — no behavior change.

Quick-template integration: tapping a template chip calls `appState.useTemplate(template)`. The existing `useTemplate` (Phase 1.1) handles both expense and income templates already.

**Important — don't rebuild the form from scratch.** Read `add_expense_screen.dart` end-to-end first, then reproduce its widget tree in the new screen, factoring out type-specific sections behind `if (_type == TransactionType.expense)` guards. Then read `add_income_screen.dart` for the income-only delta (mostly just the absence of the amount-paid section).

### B.5.3 — First-launch tooltip (R4 mitigation, 30 min)
In `lib/services/onboarding_service.dart` add:
```dart
static const _kAddTransactionTooltipSeen = 'add_transaction_tooltip_seen';
Future<bool> get seenAddTransactionTooltip async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kAddTransactionTooltipSeen) ?? false;
}
Future<void> markAddTransactionTooltipSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kAddTransactionTooltipSeen, true);
}
```

On `AddTransactionScreen.initState`:
```dart
final svc = OnboardingService();
if (!await svc.seenAddTransactionTooltip) {
  // Show a one-time coach mark over the segmented control:
  // "Tap to add a transaction. Toggle between Expense and Income at the top."
  // On dismiss, call svc.markAddTransactionTooltipSeen().
}
```

Use the same Luminous coach-mark style as the rest of the app — a `GlassPanel` overlay with a one-line message and an "Got it" button, dismissing on tap-outside or button-tap. Don't reinvent: copy from `onboarding_screen.dart`'s glass-panel pattern.

### B.5.4 — Update every caller (1 hour)

Run from repo root:
```bash
grep -rn "AddExpenseScreen\|AddIncomeScreen\|AddHubScreen" lib/
```

Expected sites (verify line numbers — they may shift after Phase 5.6 reshuffled `history/history_screen.dart`):

| File | Line | From | To |
|---|---|---|---|
| `lib/main.dart` | ~371 | `const AddHubScreen()` | `const AddTransactionScreen()` |
| `lib/screens/history/history_screen.dart` | ~181 | `AddExpenseScreen(expense: expense)` | `AddTransactionScreen(initialType: TransactionType.expense, expense: expense)` |
| `lib/screens/history/history_screen.dart` | ~189 | `AddIncomeScreen(income: income)` | `AddTransactionScreen(initialType: TransactionType.income, income: income)` |
| `lib/screens/history/history_list.dart` | empty-state callbacks | `const AddExpenseScreen()` / `const AddIncomeScreen()` | `const AddTransactionScreen(initialType: TransactionType.expense)` / `(initialType: TransactionType.income)` |
| `lib/screens/home_screen.dart` | ~297 | `const AddExpenseScreen()` | `const AddTransactionScreen(initialType: TransactionType.expense)` |
| `lib/screens/home_screen.dart` | ~795 | `AddExpenseScreen(expense: expense)` | `AddTransactionScreen(initialType: TransactionType.expense, expense: expense)` |

**Caveats:**
- The `HistoryEmptyState` widget already receives `onAddExpense` / `onAddIncome` callbacks from `history_screen.dart` (session 7 — commit `3544eb1`). The screen builds these closures; update them in the screen, not in `history_list.dart`.
- `add_hub_screen.dart` will die in this stage. Update its callers first (just `lib/main.dart`) so nothing reaches the now-dead screen.

### B.5.5 — Move old files to TRASH (5 min)
```bash
mkdir -p TRASH
mv lib/screens/add_hub_screen.dart TRASH/add_hub_screen.dart_merged
mv lib/screens/add_expense_screen.dart TRASH/add_expense_screen.dart_merged
mv lib/screens/add_income_screen.dart TRASH/add_income_screen.dart_merged
# Append a note to TRASH-FILES.md with each path + reason + replacement.
```

### B.5.6 — Tests (1 hour)

New file: `test/screens/add_transaction_screen_test.dart`. Use the recurring-items test as scaffold (`test/screens/recurring_items_screen_test.dart`).

Required tests:
1. **Renders header + segmented control + FAB** — `GlassTopAppBar` with "Add Transaction", segmented control with "Expense" / "Income" labels, save button.
2. **Submits expense end-to-end** — pump with `initialType: TransactionType.expense`, enter amount, category, description, tap Save, assert AppState's `expenses` list grew by one with the right values.
3. **Submits income end-to-end** — same with `initialType: TransactionType.income`.
4. **Toggle preserves shared fields** — fill description + amount + date as expense, tap "Income" segment, assert those three fields still hold their values but `_category` is `null`. (R15 pin.)
5. **Toggle to expense and back preserves amount-paid** — fill amount paid as expense, toggle to income (clears it), toggle back, expect `_amountPaid` to be empty (one-way clear is intentional — document this in the test).
6. **useTemplate fills the form** — seed an `AppState` with one quick template, tap the chip, assert form fields update via the template.
7. **First-launch tooltip shows once** — pump with `seenAddTransactionTooltip = false`, assert tooltip widget present; tap dismiss; re-pump; assert it's gone.

Also update `test/lint/no_unregistered_pushnamed_test.dart` if it has references to the old screen names.

**Test pattern (use this exact harness):**
```dart
Future<void> pumpHarness(
  WidgetTester tester, {
  TransactionType initialType = TransactionType.expense,
  Size surface = const Size(420, 1400),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final state = AppState();
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: buildLuminousTheme(
          brightness: Brightness.light,
          appColorsExtension: AppColors.fromBrightness(Brightness.light),
        ),
        home: AddTransactionScreen(initialType: initialType),
      ),
    ),
  );
  await tester.pumpAndSettle();   // <-- drain FadeInOnLoad timers
}
```

Don't forget the channel mocks in `setUp` — copy from `test/screens/recurring_items_screen_test.dart` lines 30–40.

### B.5.7 — Verification
- `flutter analyze` clean.
- `bash scripts/preflight.sh` green.
- `grep -rn "AddExpenseScreen\|AddIncomeScreen\|AddHubScreen" lib/` returns 0 (except docstring references in this commit).
- `flutter test test/screens/add_transaction_screen_test.dart` 7 pass.
- All other tests still green.

**Commit:** `feat(phase-5.5): merge add_hub + add_expense + add_income into AddTransactionScreen`.

**B.5 gate:** all 7 widget tests pass. Preflight green. Trash files committed. Next stage unlocked.

---

## 3. Stage B.6 follow-up — extract history tile widgets (4 hours, OPTIONAL, no device)

**Why optional:** session 7's B.6.3 commit (`3544eb1`) extracted the list shell but kept `_buildExpenseItem` (~370 lines) and `_buildIncomeItem` (~210 lines) inline because they're deeply state-coupled. If you want a cleaner final shape before Stage E, this is the time.

### B.6.5.1 — Move tile builders into their own file
New file: `lib/screens/history/history_transaction_tile.dart` with:
```dart
class HistoryExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onEdit;          // pushes AddTransactionScreen edit mode
  final Future<void> Function() onDelete;
  final VoidCallback onPay;           // shows AddPaymentDialog
  final VoidCallback onLongPress;
  final bool showTransactionColors;
  final double transactionColorIntensity;
  final cat_model.Category? category;
  final String currency;
  ...
}
class HistoryIncomeTile extends StatelessWidget {
  // analogous
}
```

The screen builds the callbacks (which still touch `setState`, `_searchAllTime`, `_allTimeExpenses`, etc.) and passes them to the tile. Same pattern as `HistoryList` already uses for the tile-builder callbacks — just push one level deeper.

### B.6.5.2 — Wire callbacks from the screen
Replace `_buildExpenseItem(context, expense, appState, theme)` with:
```dart
HistoryExpenseTile(
  expense: expense,
  category: appState.categories.firstWhereOrNull(...),
  currency: appState.currency,
  showTransactionColors: appState.showTransactionColors,
  transactionColorIntensity: appState.transactionColorIntensity,
  onEdit: () => _showEditExpenseDialog(context, expense),
  onDelete: () => _deleteExpense(context, expense, appState),
  onPay: () => _showAddPaymentDialog(context, expense),
  onLongPress: () => _showAddPaymentDialog(context, expense),
)
```

Same for income.

### B.6.5.3 — Verification
- Preflight green.
- `lib/screens/history/history_screen.dart` should drop to ~1,000 lines.

**Commit:** `refactor(phase-5.6.5): extract HistoryExpenseTile + HistoryIncomeTile widgets`.

This stage is **optional** but cleans up the history feature before goldens (D.3) lock screen pixels.

---

## 4. Stage C — Phase 6.1 SQLCipher migration (1.5 days, device required)

**Goal:** encrypt the on-disk database at rest with a 256-bit key stored in Android Keystore via `flutter_secure_storage`. Mid-flight rekey failure leaves the user without their data → mitigation: `.pre-sqlcipher-backup` written immediately before the rekey, deleted only after row-count verification.

### C.1 — Add the dependency (30 min)
`pubspec.yaml`:
```yaml
dependencies:
  sqflite_sqlcipher: ^3.0.0
  sqflite_common_ffi: ^2.3.3   # keep for tests
  # remove: sqflite: ^2.3.3
```

Update both import sites:
- `lib/database/database_helper.dart`: `package:sqflite/sqflite.dart` → `package:sqflite_sqlcipher/sqflite.dart`.
- `lib/utils/backup_helper.dart` (if it imports sqflite): same swap.

`flutter pub get`, `flutter analyze` (should still be clean — public API is identical except for the `password:` argument on `openDatabase`).

### C.2 — Key generation + storage (1 hour)
New file: `lib/utils/db_encryption.dart`
```dart
import 'dart:convert';
import 'dart:math';

import 'secure_prefs.dart';

class DbEncryption {
  static const _key = 'db_encryption_key';

  /// Returns the existing 256-bit key (base64) from SecurePrefs, or
  /// generates + stores a new one on first call.
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

Tests: `test/utils/db_encryption_test.dart` with 3 tests:
1. `getOrCreateKey()` returns the same value across calls.
2. The key decodes to 32 bytes.
3. The key persists across `SecurePrefs` instances (mock the backing channel to simulate restart).

### C.3 — Migration logic (3 hours)

In `DatabaseHelper._initDatabase()`:
```dart
final dbPath = await getDatabasesPath();
final dbFile = '$dbPath/expense_tracker_v4.db';
final encFile = '$dbPath/expense_tracker_v4.db.enc';
final backupFile = '$dbPath/expense_tracker_v4.db.pre-sqlcipher-backup';

final hasKey = await SecurePrefs.readString('db_encryption_key') != null;
final plaintextExists = await File(dbFile).exists();

if (!hasKey && plaintextExists) {
  // First launch of the SQLCipher-enabled build. Migrate.
  await File(dbFile).copy(backupFile);   // safety net

  final preCounts = await _rowCounts(dbFile);  // helper: open + count every table

  final key = await DbEncryption.getOrCreateKey();

  final src = await openDatabase(dbFile);
  await src.execute("ATTACH DATABASE '$encFile' AS encrypted KEY '$key'");
  await src.execute("SELECT sqlcipher_export('encrypted')");
  await src.execute("DETACH DATABASE encrypted");
  await src.close();

  final encDb = await openDatabase(encFile, password: key);
  final postCounts = await _rowCounts(encDb);
  await encDb.close();

  if (_countsMatch(preCounts, postCounts)) {
    await File(dbFile).delete();
    await File(encFile).rename(dbFile);
    // Leave the `.pre-sqlcipher-backup` in place until the next successful
    // launch — _cleanPreSqlcipherBackupAfterSuccess() handles cleanup.
  } else {
    await CrashLog.write(
      'SQLCipher migration verification failed; row counts differ',
    );
    if (await File(encFile).exists()) await File(encFile).delete();
    // Continue using plaintext DB. SecurePrefs key already exists — that's fine.
  }
}

// Normal open path:
final key = await DbEncryption.getOrCreateKey();
final db = await openDatabase(dbFile, password: key, ...);
```

Helper to write:
```dart
Future<Map<String, int>> _rowCounts(dynamic dbOrPath) async {
  final db = dbOrPath is Database ? dbOrPath : await openDatabase(dbOrPath);
  final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
  final counts = <String, int>{};
  for (final t in tables) {
    final name = t['name'] as String;
    final r = await db.rawQuery('SELECT COUNT(*) AS c FROM $name');
    counts[name] = Sqflite.firstIntValue(r) ?? 0;
  }
  if (dbOrPath is String) await db.close();
  return counts;
}

bool _countsMatch(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final k in a.keys) {
    if (b[k] != a[k]) return false;
  }
  return true;
}
```

### C.4 — Tests (2 hours)
New `test/integration/sqlcipher_migration_test.dart`:
1. **Migration from plaintext** — seed plaintext DB with 5 expenses + 3 income + 1 budget, run the rekey, open the encrypted file with the stored password, assert all row counts match.
2. **Verification failure path** — inject a row-count divergence (mock the second `_rowCounts` call to return one fewer row), assert plaintext DB is preserved + CrashLog entry written + no encrypted file present.
3. **Subsequent launches** — second `openDatabase` call returns the encrypted DB; the key is not regenerated.

Plus a unit test for `_isPlaintextDatabase(File)` — true for unencrypted, false for encrypted (passwordless `openDatabase` on an encrypted file throws).

**Note on integration test setup:** `sqflite_sqlcipher` does not have an FFI binding analogous to `sqflite_common_ffi`. For integration tests you'll need to either:
- Open the plaintext side with `sqflite_common_ffi` and the encrypted side with the real plugin (won't work on test runner — no plugin).
- Or use `sqlcipher_flutter_libs` + a small FFI shim. Easiest path: skip C.4's "encrypted-open" assertions in unit tests and verify on-device in C.5.

### C.5 — Device smoke (30 min)
1. Install on a device that already has v4.4.0 data (or seed a few rows in v5.0.0-pre-C build first).
2. Open app → expect 1–3 second startup delay (the export).
3. Add a transaction → confirm save works.
4. `adb shell run-as com.moneytracker.app sqlite3 databases/expense_tracker_v4.db ".tables"` → should return `Error: file is not a database` (no password = unreadable).

### C.6 — Cleanup the pre-sqlcipher-backup file
Add `_cleanPreSqlcipherBackupAfterSuccess()` to DatabaseHelper:
```dart
Future<void> _cleanPreSqlcipherBackupAfterSuccess() async {
  final dbPath = await getDatabasesPath();
  final backup = File('$dbPath/expense_tracker_v4.db.pre-sqlcipher-backup');
  if (await backup.exists()) await backup.delete();
}
```

Call it from the second-launch path inside `_initDatabase()` (after a successful encrypted open). Make this idempotent.

**Commit:** `feat(phase-6.1): SQLCipher migration with verified-rekey safety net`.

**Stage C gate:** all 3 integration tests pass + device smoke passes. APK size delta within +5 MB.

---

## 5. Stage D.1 remainder — additional CRUD mutator coverage (1 day, no device)

Session 7 landed 16 tests in `test/integration/app_state_crud_test.dart` covering `addExpense`, `addIncome`, delete-trash, account CRUD, category CRUD round-trip, `setBudget`. The plan calls for full coverage of every mutator on `AppState`.

### D.1.R — Remaining mutators

Add tests to the same file (`test/integration/app_state_crud_test.dart`). Use the same harness — channel mocks already set up.

| Mutator | Test cases |
|---|---|
| `updateExpense` | edit description → persists; edit date → carryover recomputes |
| `updateIncome` | edit description → persists |
| `markExpensePaid` | partial → full → notifyListeners count = 1 |
| `markIncomePaid` | toggles state; notify once |
| `restoreDeletedExpense` | delete then restore; row reappears in `expenses` |
| `restoreDeletedIncome` | analogous |
| `permanentlyDeleteExpense` | hard delete; not in trash, not in active |
| `permanentlyDeleteIncome` | analogous |
| `emptyTrash` | populated trash → after call, both deleted tables empty |
| `clearOldDeleted` | rows older than threshold purged; recent rows retained |
| `addRecurringExpense` | persists in `recurring_expenses` table; cached `recurringExpenses` updated; notification ID stays in 10000–19999 range |
| `updateRecurringExpense` | edit frequency → persists; notification re-scheduled |
| `deleteRecurringExpense` | gone from cache + table |
| `addRecurringIncome` | analogous, notification ID range 20000–29999 |
| `updateRecurringIncome` | analogous |
| `deleteRecurringIncome` | analogous |
| `addTemplate` | persists in `quick_templates`; cached list updated |
| `updateTemplate` | edit fields persist |
| `deleteTemplate` | gone from cache + table |
| `updateCategory` | rename propagates to existing expenses/income (or check the rename strategy in code first) |
| `deleteTransactionsAndCategory` | atomic: transactions + category gone in one tx |
| `reassignCategoryAndDelete` | reassigned transactions point at new category; old category gone |
| `setAlertThreshold` | per-category threshold persists, fires alert at threshold% (test that `_checkBudgetAlerts` is invoked) |

For each: seed → call mutator → assert in-memory + on-disk. Pattern is in `app_state_crud_test.dart` lines 95–115 (the `addExpense` test).

**Acceptance:** add ~25 tests, full suite stays green, preflight stays green.

**Commit:** `test(phase-7.d1): complete AppState CRUD mutator coverage`.

---

## 6. Stage D.2 — Hero-screen widget tests with seeded data (1 day, no device, blocked on B.5)

**Goal:** behavioural coverage on the 8 hero screens with per-state assertions, replacing the "renders without throwing" smoke tests from session 6.

### Seeded states per screen

| Screen | Seeded states |
|---|---|
| Settings | PIN enabled vs disabled (seed `secureBacking` Map for `flutter_secure_storage` mock) |
| Wallet | Multiple accounts + one deleted account in trash |
| Budgets | Under-budget (50%), at-100%, over-budget (130%) — one budget per state |
| Analytics | Seeded expense data so charts render (also fixes the timer-leak in `analytics_screen_test.dart_skipped`) |
| Add Transaction (B.5) | Templates + categories seeded; toggle preserves fields |
| History | 100 expenses + 50 income across 3 months, filter combos |
| Recurring Items | 2 recurring expenses + 1 recurring income |
| Home | Budgets + recent transactions + current-account balance |

Each test: ~3 assertions per state, ~5 states × 8 screens = **~40 new tests**.

### Pattern
```dart
testWidgets('Budget screen — over-budget state shows red progress bar', (t) async {
  final state = AppState();
  await state.loadData();
  await state.setBudget('Food', 100);
  await state.addExpense(makeExpense(state, amount: 130, category: 'Food'));

  await pumpHarness(t, state: state);
  await t.pumpAndSettle();

  expect(find.byType(GlassProgressBar), findsOneWidget);
  // Assert color, value, semantics label
});
```

The seeded `AppState` must reach a stable state before pumping — `await state.loadData()` then any mutators, then pump.

**Re-enable skipped tests in this stage:**
- `TRASH/analytics_screen_test.dart_skipped` — chart `AnimationController` tickers leak. Seed chart data + use `await t.pumpAndSettle(const Duration(seconds: 2))` to drain the animation; `addTearDown` to dispose controllers. Move back to `test/screens/analytics_screen_test.dart`.
- `TRASH/notification_settings_screen_test.dart_skipped` — `FlutterLocalNotificationsPlatform.instance` is a `late final` static. Either mock the platform interface or extract `_helper` into a swappable injection point on `NotificationHelper`. Re-introduce as `test/screens/notification_settings_screen_test.dart`.

**Commit:** `test(phase-7.d2): hero-screen widget tests with seeded data` (or split per-screen if it ends up >500 lines).

**D.2 gate:** behavioural coverage ≥ 70% on hero screens (measure: `flutter test --coverage && genhtml coverage/lcov.info -o coverage/html`, inspect per-screen %).

---

## 7. Stage D.3 — Goldens for 8 hero screens (1 day, no device, blocked on D.2)

For each hero screen:
```bash
flutter test --update-goldens test/screens/<name>_test.dart
```

Lock goldens to Windows (the dev platform). Document the platform constraint in `test/golden/README.md`. CI runs at 2% pixel-diff tolerance (matcher: `matchesGoldenFile(name, tolerance: 0.02)`).

**Caveats:**
- Don't golden screens with time-of-day or relative-time strings ("2h ago"). Use `withClock(FakeClock.fixed(...), () => ...)` to lock those.
- Skip notifications-permission screen — platform popups aren't golden-able.

**Commit:** `test(phase-7.d3): golden tests for 8 hero screens`.

---

## 8. Stage E — Ship pipeline (1 day, device required)

### E.1 — DevTools perf pass (2 hours, device)
On a Pixel 4a class device with DevTools Performance overlay:
- Home scroll with 100 expenses — every frame ≤ 16.7 ms steady-state.
- History scroll with 500 expenses — same.
- Rapid tab switching (Home ↔ History ↔ Add ↔ Analytics ↔ Wallet) — no jank.
- Analytics first paint — no dropped frames.

**On regression:** profile with `dart:developer.Timeline`, identify the offender, fix before tagging. Acceptable rollback: bump blur radius back to 10 (was reduced for perf in Phase 1.7).

### E.2 — Version bump + CHANGELOG + tag (1 hour)
`pubspec.yaml`:
```yaml
version: 5.0.0+1   # was 4.4.0+6
```

`CHANGELOG.md`: insert a new top entry. Use the per-phase per-commit summaries in `MASTER_PLAN.md §"Definition of done"` plus the session-7 commits. Cover:

- **Added** — Luminous redesign across every screen, FinanceFlow branding, encrypted backup files, encrypted database at rest, FLAG_SECURE protected widget, crash-log PII redaction, recurring-items unified screen, history split into per-concern files, segmented type toggle on Add Transaction.
- **Changed** — Schema migration v18→v19 (trash-table FK cascades, transaction_tags triggers, YYYY-MM month-key normalisation), all heavy mutators atomic (`createExpenseWithCarryover`, `createIncomeWithCarryover`), narrow `context.select` replacing global `context.watch` on hero screens, Hanken Grotesk variable font bundled (`google_fonts` removed).
- **Fixed** — Race in `loadData` coalescing, debug-mode loop in `pruneDistantMonths`, navigator pushNamed fallback, HomeWidget update race, force-close on backgrounded write.
- **Security** — PIN secrets migrated from SharedPreferences to Android Keystore; AES-GCM backup envelopes with min-6-char passphrase + retry UX; SQLCipher 256-bit database encryption; constant-time PIN comparison.

Commit:
```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(release): bump version to 5.0.0+1

CHANGELOG.md entry for v5.0.0 release. See docs/MASTER_PLAN.md
for the full per-phase breakdown.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

Tag (do NOT push the tag until APK ships — line E.4):
```bash
git tag v5.0.0+1
```

### E.3 — Ship pipeline (30 min, requires landing repo + Vercel CLI ≥ 47.2.2)
Per `CLAUDE.md` § "Shipping the APK":
```bash
flutter build apk --release && \
cp build/app/outputs/flutter-apk/app-release.apk \
   /c/Users/leooa/Documents/personal-projects/expense-tracker-landing/public/downloads/money-tracker.apk && \
git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing add public/downloads/money-tracker.apk && \
git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing commit -m "chore: ship v5.0.0+1 — FinanceFlow Luminous" && \
git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing push && \
(cd /c/Users/leooa/Documents/personal-projects/expense-tracker-landing && vercel --prod --yes)
```

**Vercel Git integration is disconnected** for `expense-tracker-landing` (per the auto-memory). The `vercel --prod --yes` call is **required** — `git push` alone won't deploy.

Verify SHA-1 parity:
```bash
curl -sL https://leo-money-tracker.vercel.app/downloads/money-tracker.apk | sha1sum
sha1sum build/app/outputs/flutter-apk/app-release.apk
```
Both must match. If they don't, the landing-page CDN hasn't propagated yet — wait 30s and re-curl. If still mismatched, check the Vercel project deployment log.

### E.4 — Push tag + GitHub release (15 min)
```bash
git push origin release/v5.0.0
git push origin v5.0.0+1   # the tag

gh release create v5.0.0+1 \
  --title "v5.0.0+1 — FinanceFlow Luminous" \
  --notes-file CHANGELOG.md \
  build/app/outputs/flutter-apk/app-release.apk
```

### E.5 — Fast-forward `main` (10 min)
```bash
git checkout main
git merge --ff-only release/v5.0.0
git push origin main
git checkout release/v5.0.0
```

### E.6 — Post-ship verification on device (15 min)
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

**Stage E gate (= v5.0.0+1 ship gate):**
- Tag `v5.0.0+1` exists on origin and points at the same SHA on `main`.
- Landing page serves APK at the documented SHA-1.
- GitHub release exists.
- 5-minute device smoke passes end-to-end.

---

## 9. Cross-cutting cleanups (do anytime, none are blockers)

- **`dist/baseline/`.** `v4.4.0+6.db` and `dist/baseline/perf/` were skipped in session 1. Either populate (export a dev DB from a Stage A.2 device) or remove the placeholder entries from `docs/CHECKLIST.md`.
- **Stale `.v18-backup` files.** Phase 4.1's pre-migration backup auto-cleans after a successful upgrade. Verify `DatabaseHelper._cleanV18BackupAfterMigrationSuccess` actually runs in Stage A.1 (search the device's `databases/` directory).
- **`pubspec.lock` audit.** After Stage C lands `sqflite_sqlcipher`, run `flutter pub upgrade --major-versions` once and review the diff. Don't auto-accept — some transitive bumps will break things.
- **Re-enable skipped widget tests.** Two screens sit in `TRASH/` with `_skipped` suffix — see Stage D.2 above.
- **`pubspec.yaml` description.** Currently says "A new Flutter project." — update to a meaningful one-liner for the v5.0.0 cut.

---

## 10. Definition of Done for `v5.0.0+1`

All of the following must be true before tagging:

1. **Every checklist item in `docs/CHECKLIST.md` ticked** — except the explicit Out-of-v5.0.0 items in §"Out of v5.0.0 (deferred to v5.1)".
2. **`bash scripts/preflight.sh` green** on `release/v5.0.0` with test-count gate **ratcheted** (currently 1750 — bump to baseline-50 after D.1 remainder lands, then again after D.2).
3. **APK builds clean** (`flutter build apk --release` exits 0, size ≤ 70 MB).
4. **5-minute device smoke passes** end-to-end (per `MASTER_PLAN.md §8.3`).
5. **`pubspec.yaml` version is `5.0.0+1`.**
6. **CHANGELOG.md** has a v5.0.0 entry covering Added/Changed/Fixed/Security.
7. **`v5.0.0+1` tag exists** on `origin/release/v5.0.0`.
8. **Landing page serves the APK** at `https://leo-money-tracker.vercel.app/downloads/money-tracker.apk` with a matching SHA-1.
9. **GitHub release exists** at `Leo-Atienza/Money-Tracker` tagged `v5.0.0+1` with the APK attached.
10. **`release/v5.0.0` merged into `main`** (fast-forward) and pushed.

---

## 11. Risk register (current state, with session-7 deltas)

| ID | Risk | Status | Mitigation |
|---|---|---|---|
| R1 | Migration v19 fails on a user's device | ✅ Mitigated | Phase 4.1 pre-migration backup |
| R2 | SQLCipher rekey fails mid-flight | ⏳ Open (Stage C) | C.3 verification step + `.pre-sqlcipher-backup` |
| R3 | Variable-font wght axis renders incorrectly on legacy Android | ⏳ Open | Add `fontFamilyFallback` if any device shows wrong weight |
| R4 | Merged Add hub confuses existing users | ⏳ Open (Stage B.5) | First-launch tooltip via `OnboardingService.seenAddTransactionTooltip` |
| R5 | Recurring merge breaks notifications | ✅ Mitigated (session 7 — `1445371`) | DB row IDs untouched; notification ID ranges 10000–29999 unchanged; behavioural integration tests cover scheduling |
| R6 | Performance budget not met | ⏳ Open (Stage E.1) | Phase 8.2 perf gate; rollback option = bump blur radius back to 10 |
| R7 | Wall-clock flakes | ✅ Mitigated | Clock injection landed session 3 |
| R8 | PIN secure-storage migration locks user out | ⏳ Open (Stage A.2) | Stage A.2 device test |
| R9 | Removing `google_fonts` breaks something | ✅ Mitigated | `test/lint/no_forbidden_patterns_test.dart` enforces |
| R10 | Vercel deploy step fails | ✅ Mitigated | `vercel --prod --yes` documented; CLI ≥ 47.2.2 required |
| R11 | SQLCipher migration corrupts on a partially-encrypted file | ⏳ Open (Stage C) | C.3 row-count verification before destroying plaintext |
| R12 | Backup encryption passphrase forgotten | ✅ Mitigated | UX warning + min-6-char + "cannot recover" message landed session 4 |
| R13 | `PinSecurityHelper.isPinEnabled()` aborts publish pipelines in tests | ✅ Mitigated | Tests seed `SharedPreferences.setMockInitialValues` |
| R14 | History split's 4-file structure leaks state across widgets | ✅ Mitigated (session 7 — `3544eb1`) | Filter/list/empty-state are dumb `StatelessWidget`s; state stays in `HistoryScreen` parent; `test/lint/no_global_appstate_watch_test.dart` enforces narrow selects (and is green) |
| R15 | AddTransaction toggle loses user-entered shared fields | ⏳ Open (Stage B.5) | Field state survives type toggle; only `_category` + `_amountPaid` swap. Widget test #4 in B.5.6 pins this |
| **R16 (new)** | **`pumpAndSettle` in widget tests for Luminous screens may mask animation-driven jank** | ⏳ Open | Use it only to drain `FadeInOnLoad` 200ms initialisation, not to swallow ongoing animation work. If a test passes only after a long pump, profile rather than extending the pump duration |
| **R17 (new)** | **`path_provider` mock pattern is duplicated across test files** | Low | Consider promoting the channel-mock harness to a shared helper in `test/integration/_test_helpers.dart` once 3+ files duplicate it |

---

## 12. First commands the next session should run

```bash
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git fetch --all
git status                            # should be clean
git log --oneline -3                  # last commit is 373b3fd

# Run the safety net to confirm 1833/green.
bash scripts/preflight.sh

# Read this plan + the handoff.
cat docs/FINISH_LINE.md               # this file
cat SESSION_HANDOFF.md
cat docs/CHECKLIST.md
```

Then:

- If device available and time-boxed (≤ 2 hours): **do Stage A** (A.1 through A.6). On failure, revert + replan.
- If device NOT available: **do Stage B.5** (Add Transaction merge). Single biggest piece left. Pattern is in commit `1445371` (recurring merge); reuse the harness.

Whatever you do, every commit must run `bash scripts/preflight.sh` and pass. The test-count gate is currently `1750`; ratchet it up to `1830` after this session's commits land on origin (already pushed at `373b3fd`).

---

## 13. Order-of-operations cheat sheet

| Step | What | Where | When |
|---|---|---|---|
| 1 | `git fetch && git status` (clean, in sync) | git | First |
| 2 | `bash scripts/preflight.sh` (1833 green) | terminal | First |
| 3 | Stage A — device smokes | device | If device available |
| 4 | Stage B.5 — Add Transaction merge | code | After A (or instead, if no device) |
| 5 | Stage B.6.5 — extract history tiles (optional) | code | After B.5 — purely cosmetic for goldens |
| 6 | Stage C — SQLCipher migration | code + device | After Stage B |
| 7 | Stage D.1 remainder — CRUD coverage | code | Anytime; parallel-safe with B.5 |
| 8 | Stage D.2 — hero widget tests with seeded data | code | After B.5 (some screens didn't exist pre-B.5) |
| 9 | Stage D.3 — goldens | code | After D.2 |
| 10 | Stage E.1 — perf pass | device | After Stage D |
| 11 | Stage E.2 — version bump + CHANGELOG | git | After E.1 |
| 12 | Stage E.3 — ship APK to landing | build + Vercel | After E.2 |
| 13 | Stage E.4 — push tag + GitHub release | gh CLI | After E.3 |
| 14 | Stage E.5 — fast-forward `main` | git | After E.4 |
| 15 | Stage E.6 — post-ship device smoke | device | Final gate |

**Tag `v5.0.0+1` only after step 15 passes.**

---

## 14. After `v5.0.0+1` ships — v5.1 backlog (intentionally out of scope)

These are documented in `docs/MASTER_PLAN.md §13` as "After v5.0.0":

- AppState god-object split into `TransactionService`, `BudgetService`, `SettingsService`.
- DatabaseHelper per-domain repos.
- Money stored as INTEGER cents (schema v20).
- AppPhase state machine (replaces ad-hoc `_isInitialized` flag — Phase 3.8 deferred).
- Optional FTS5 for `searchExpenses` (history search).
- Rename mislabeled `app_state_logic_test.dart` (Phase 7.1 deferred).

Don't pull any of these into the v5.0.0 cut. They're explicitly out of scope.

---

**End of plan. Updated post-session-7 — supersedes `docs/SESSION_7_PLAN.md` for forward-looking guidance.**
