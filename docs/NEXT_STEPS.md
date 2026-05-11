# Next Steps Plan — From Here to `v5.0.0+1` Ship

**Author:** Synthesis after session 2 (2026-05-11) of the `release/v5.0.0` arc.
**Companion:** `docs/MASTER_PLAN.md` (full "why"), `docs/CHECKLIST.md` (per-task tickboxes), `SESSION_HANDOFF.md` ("where we are right now").
**Purpose:** spell out, with file paths and acceptance criteria, the exact remaining work between commit `4f1d62f` and a tagged `v5.0.0+1` on the landing page. Anything not in this file is out of scope for this release (see `MASTER_PLAN.md` §"Out of v5.0.0").

---

## 0. Current state snapshot (2026-05-11, after `4f1d62f`)

| Surface | State |
|---|---|
| Branch | `release/v5.0.0`, **never pushed to origin** |
| HEAD | `4f1d62f docs(handoff): close-out for session 2` |
| Commits since `main` diverged | 16 |
| `flutter analyze` | No issues found |
| `flutter test` | 1,720 pass |
| `flutter build apk --release` | succeeded, 59.2 MB (verified session 2) |
| `bash scripts/preflight.sh` | green |
| DB schema version | 19 |
| `pubspec.yaml` version | `4.4.0+6` (will become `5.0.0+1` at Stage E) |

**What still has to land** (mapped to checklist):

- **Phase 5** — 9 screen redesigns + brand alignment + `Spacing.*` removal. (0/10 done — starter commit `a231db4` only wired the 5-tab nav skeleton.)
- **Phase 6.1, 6.3, 6.4** — SQLCipher, backup AES-GCM + passphrase, widget redaction. (3/6 done.)
- **Phase 7** — Test coverage rebuild. (0/10 done.)
- **Phase 8.2, 8.4, 8.5** — Perf pass, version bump, ship pipeline. (2/5 done.)

Plus the cross-cutting clean-ups in §6.

---

## 1. Sequencing rationale

The plan is sequenced so that:

1. **De-risk first.** Phase 6.2's PIN migration is unit-tested but unproven on a real Keystore. Confirm or revert before any new work piles on top.
2. **Visual work next.** Phase 5 needs Hanken Grotesk in place (done) and a stable codebase to anchor against. It's the biggest chunk and the headline change for the major-version bump.
3. **Security in parallel with Phase 5.** 6.3 + 6.4 are mechanical and touch surfaces (backup screen, widget) that Phase 5 won't fight with. 6.1 (SQLCipher) is highest data-loss risk and earns its own session at the end of the chain so other code is stable for the smoke test.
4. **Test coverage last but not least.** Phase 7 is additive — running it before Phase 5 means writing tests against screens about to be deleted. Save it for after Phase 5's structure settles.
5. **Ship is a gate, not a step.** Tag `v5.0.0+1` only after every preceding stage is green AND a 5-minute device smoke test passes.

The default linear order is **A → B → C → D → E**. A subset (C.2, C.3, D.1, D.7, D.9, D.10) can be picked up in parallel sessions if multiple agents / windows are available.

---

## 2. Stage A — De-risk what session 2 just landed (≈ 1–2 hours)

**Goal:** prove the Phase 6.2 PIN migration is safe on real Keystore. If it's not, this stage rolls back `3a290ed` and we re-plan before any new code.

### A.1 — Push the branch to origin (5 min)

The branch has 16 commits but has never been pushed. Lose this laptop and lose the work.

```bash
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git push -u origin release/v5.0.0
```

**Acceptance:** `git status` shows "Your branch is up to date with 'origin/release/v5.0.0'". GitHub web UI lists the branch.

### A.2 — Build a fresh debug APK and install it side-by-side (10 min)

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**Acceptance:** APK installs cleanly. App opens. SHA-1 of the installed APK can be verified later against the landing copy.

### A.3 — Live-fire Phase 6.2 migration test (20 min)

This is the test the master plan called out and that session 2's commit message documented as "device validation required":

1. Open the app on the test device.
2. Settings → Security → enable PIN; enter a 4-digit PIN you'll remember (e.g. `1397`).
3. Force-stop the app: `adb shell am force-stop com.moneytracker.app`.
4. **Verify legacy data was NOT present from a prior install** (clean device case):
   ```bash
   adb shell run-as com.moneytracker.app cat shared_prefs/FlutterSharedPreferences.xml
   ```
   `app_pin_hash`, `app_pin_salt`, `pin_enabled` should be **absent** — they live in Keystore now.
5. Re-open the app. PIN lock screen should appear. Enter PIN → unlocks.
6. **Migration-from-legacy case (separate test session):**
   - Install a v4.4.0+6 APK from the landing (or `git stash` away the Phase 6.2 changes, build, install, set PIN, then re-apply the changes, rebuild, sideload).
   - Set PIN under the legacy build.
   - `cat shared_prefs/FlutterSharedPreferences.xml` — `app_pin_hash` + `app_pin_salt` should be present.
   - Sideload the Phase 6.2 build over top (`adb install -r`).
   - Open app, enter PIN — must verify on first attempt.
   - `cat shared_prefs/FlutterSharedPreferences.xml` again — `app_pin_hash` and `app_pin_salt` should now be **absent** (migrated to Keystore).

**Acceptance:** both flows work. PIN never has to be re-set. Legacy prefs entries are gone after first verify.

**On failure:** `git revert 3a290ed` (the secure-storage commit). Open an issue documenting the device + Android version + actual symptom. Stage B does NOT start until 6.2 is either fixed or removed from the release.

### A.4 — Smoke-test Phase 6.5 FLAG_SECURE (5 min)

1. With PIN enabled, hit the Recents button on the device.
2. The thumbnail of Money Tracker should show a black/blank surface, **not** the actual screen contents.
3. Disable PIN in Settings → Security → no PIN required.
4. Hit Recents again — thumbnail should now show the real screen.

**Acceptance:** Recents thumbnail toggles based on PIN state. Screenshot attempt with hardware buttons either fails or produces a blank capture while PIN is on.

### A.5 — Smoke-test Phase 6.6 crash redaction (5 min)

1. Trigger a controlled crash (e.g. add a temporary `throw Exception(r'fake $123 leak C:\Users\leooa\fake.db');` to `AppState.loadData()`, build, run, observe).
2. Open Settings → Crash Log. The latest entry should contain `[user]`, `[amount]`, but **not** the literal username or dollar amount.
3. Remove the temporary throw, rebuild.

**Acceptance:** PII redactor fires on a real crash record on device.

### A.6 — Push de-risk commit (if any fixes landed) (5 min)

```bash
git push origin release/v5.0.0
```

**Stage A gate:** session 2's three security commits are validated on real hardware. If any of them failed, the offender is reverted and a follow-up issue is filed.

---

## 3. Stage B — Phase 5 Luminous Design Integration (≈ 5–8 days)

**Goal:** every screen renders with the Luminous Glass design system from `lib/widgets/luminous/`, `Spacing.*` is deleted, and the brand label is consistent "FinanceFlow" everywhere.

**Source of design truth:** `C:/tmp/stitch_review/v1/stitch_money_tracker_redesign/`. Each subfolder has a `screen.png` (the visual target) and a `notes.md` (interaction notes). Phase 5 commits should reference the matching folder name.

**Per-screen commit policy:** one commit per screen. Commit message format:

```
feat(phase-5.N): <screen name> Luminous redesign

- Replaces <old screen file> with components from lib/widgets/luminous/.
- Inlines tokens (Spacing.X → LuminousTokens.Y; <list specific values>).
- <Structural notes — file renames, route changes, model changes.>
- <Visual deviations from Figma/PNG if any, with rationale.>

flutter analyze: No issues found.
flutter test: <count> pass (+<delta>).
Device smoke (Pixel 4a class): scroll, tap, dark/light mode all 60 fps.
```

**Verification mode per screen:** `mechanical` (passes tests, no visual sanity needed because no widget-tree changes) or `visual` (must be eyeballed on device, can't be unit-tested).

### B.0 — Pre-flight (one-time setup, 30 min)

Before B.1:

1. Open `C:/tmp/stitch_review/v1/stitch_money_tracker_redesign/` in a file explorer or VS Code split. Keep `screen.png` for the in-progress screen open beside your editor.
2. Confirm `lib/widgets/luminous/` builds and all components render in the smoke tests:
   ```bash
   flutter test test/widgets/luminous/
   ```
3. Snapshot the **starting** APK size to compare against post-Phase-5:
   ```bash
   flutter build apk --release --analyze-size > dist/baseline/size-pre-phase-5.json 2>&1
   ```

**Acceptance:** smoke tests green, `dist/baseline/size-pre-phase-5.json` saved.

### B.1 — Settings & Security screen (≈ 4 hours)
- **Files to touch:** `lib/screens/settings_screen.dart`
- **Components used:** `GlassTopAppBar`, `GlassListSection`, `GlassListTile`, `GlassPanel`
- **Structural notes:** none — keep the same file name and route.
- **Tokens to inline:**
  - `Spacing.screenPadding` → `LuminousTokens.containerPadding` (20)
  - `Spacing.cardPadding` → `LuminousTokens.glassPadding` (24)
  - `Spacing.sectionMargin` → `LuminousTokens.sectionMargin` (32)
- **Acceptance:**
  - All toggles still wire to `AppState` mutators.
  - PIN setup → `Navigator.push(PremiumPageRoute(page: PinSetupScreen()))` (already correct).
  - "Disable PIN" path still calls `appState.initializeLockState()` → `SecureWindow.setSecure(false)`.
  - Dark/light theme toggle still calls `AppState.setThemeMode`.
- **Tests:** 1 widget test asserts the top app bar title is "Settings & Security"; 1 widget test asserts PIN toggle calls `PinSecurityHelper.disablePin` when turned off.
- **Verification mode:** `visual` — confirm on device that the glass surfaces render with `glassBlurSigma = 15` and the new `GlassListTile` chevrons.

### B.2 — Wallet & Accounts (≈ 5 hours)
- **Files:** `lib/screens/account_manager_screen.dart` → **rename** to `lib/screens/wallet_screen.dart`. Update every import (grep `account_manager_screen` in `lib/` + `test/`).
- **Components:** `GlassTopAppBar`, `GlassListSection`, `GlassListTile`, `GlassPanel` (account card), `GlassPillChip` (account-type filter).
- **Structural notes:** the class name should become `WalletScreen`. Update `main.dart`'s `_screens` list. Update `MainNavigationScreen._navDestinations[4].label` to "Wallet" (it already is).
- **Acceptance:**
  - All existing account CRUD still works (add, edit, archive, switch).
  - `onAccountSwitch` stream still emits when the active account changes — `MainNavigationScreen._onAccountSwitch` resets `_currentIndex = 0`.
- **Tests:** add `test/screens/wallet_screen_test.dart` (rename existing if any) with one widget test per CRUD.
- **Verification mode:** `visual` — account cards must show balance in `displayLarge` style.

### B.3 — Budgets & Planning (≈ 5 hours)
- **Files:** `lib/screens/budget_screen.dart`
- **Components:** `GlassTopAppBar`, `GlassListSection`, `GlassProgressBar` (the hero — one per budget), `GlassPillChip` (period filter).
- **Acceptance:**
  - Budget add/edit/delete unchanged.
  - Progress bar's `value` parameter matches `Budget.percentUsed` (clamp at 1.0 for visual but report raw value via semantics — `GlassProgressBar` already does this).
  - Tapping a budget pushes the existing detail / edit dialog via `PremiumPageRoute`.
- **Tests:** 1 widget test per budget state (under-budget, at-100%, over-budget).
- **Verification mode:** `visual` — confirm progress bars animate smoothly when budgets update.

### B.4 — Analytics & Insights (≈ 6 hours)
- **Files:** `lib/screens/analytics_screen.dart`
- **Components:** `GlassTopAppBar`, `GlassSegmentedControl` (period: Week/Month/Year), `GlassDonutChart` (category breakdown hero), `GlassBarChart` (monthly comparison), `GlassListSection` (top categories).
- **Structural notes:** retire the legacy `fl_chart` PieChart + BarChart wrappers. Keep `fl_chart` in `pubspec.yaml` only if any other screen uses it; if not, drop the dep.
- **Acceptance:**
  - Top categories list reflects the same selection as the donut chart (single source of truth = the segmented control's selected period).
  - Tapping a donut slice highlights the matching list item.
- **Tests:** 1 widget test per period selection; 1 test that the donut sum matches `Expense.total` for the selected period.
- **Verification mode:** `visual` — chart legibility against the glass surface needs eyeballing.

### B.5 — Add Transaction (STRUCTURAL CHANGE, ≈ 8 hours)
- **Files:**
  - **Delete after migration:** `lib/screens/add_hub_screen.dart`, `lib/screens/add_expense_screen.dart`, `lib/screens/add_income_screen.dart`.
  - **Create:** `lib/screens/add_transaction_screen.dart` (single screen with type segmented control).
- **Components:** `GlassTopAppBar`, `GlassSegmentedControl` (Expense / Income at the top), `CategoryBentoGrid` (the 4-col category picker — replaces the old vertical category list), `GlassPanel` (form sections), text fields styled by the global `InputDecorationTheme`.
- **Acceptance:**
  - Toggle between Expense and Income preserves description / amount / date if user filled them; only the category list swaps.
  - Submit goes through `DatabaseHelper.createExpenseWithCarryover` / `createIncomeWithCarryover` (Phase 1.6 atomic helpers).
  - Quick template chips appear above the category grid; tapping one fills the form (`useTemplate` from Phase 1.1 — already correct).
- **Route migration:**
  - Every `PremiumPageRoute(page: const AddExpenseScreen())` → `PremiumPageRoute(page: const AddTransactionScreen(initialType: TransactionType.expense))`.
  - Same for `AddIncomeScreen`.
  - Same for `AddHubScreen` (the bottom-nav Add tab destination).
- **Tests:** 4 widget tests — submit expense, submit income, toggle preserves form, useTemplate fills form.
- **Verification mode:** `visual` (bento grid layout) + `mechanical` (atomic submission).
- **Risk note:** R4 in `MASTER_PLAN.md` Risk Register (merged hub may confuse existing users). Add a one-time tooltip on first launch of v5: "Tap to add a transaction" (stored in `OnboardingService` as `seenAddHubTooltip`).

### B.6 — Transaction History (STRUCTURAL CHANGE, ≈ 6 hours)
- **Files:**
  - **Split:** `lib/screens/history_screen.dart` (2,200+ lines today) →
    - `lib/screens/history/history_screen.dart` (composition + top-level state)
    - `lib/screens/history/history_filter_bar.dart` (search + type / category / date filter UI)
    - `lib/screens/history/history_list.dart` (the actual transaction list)
    - `lib/screens/history/history_grouping.dart` (pure functions for day / week / month grouping — testable in isolation)
- **Components:** `GlassTopAppBar` (with search action), `GlassSegmentedControl` (All / Expenses / Income), `GlassPillChip` (category + date filters in a horizontal scroll), `GlassListSection` (date headers), existing `_TransactionTile` (Phase 1 hardened it — keep).
- **Acceptance:**
  - All existing filters work identically.
  - The narrow `context.select` calls from Phase 2.5 carry forward; `test/lint/no_global_appstate_watch_test.dart` stays green.
  - Performance with 500 expenses: scroll is 60 fps (verify on Pixel 4a class device).
- **Tests:** 3 widget tests (filter combos), 5 unit tests on `history_grouping.dart`.
- **Verification mode:** `mechanical` (logic correctness — tests) + `visual` (scroll perf — device).

### B.7 — Recurring Items (STRUCTURAL CHANGE, ≈ 5 hours)
- **Files:**
  - **Delete after migration:** `lib/screens/recurring_expenses_screen.dart`, `lib/screens/recurring_income_screen.dart`.
  - **Create:** `lib/screens/recurring_items_screen.dart`.
- **Components:** `GlassTopAppBar`, `GlassSegmentedControl` (Expense / Income), `GlassListSection` (frequency groupings), `GlassListTile`, swipe-to-delete via the existing `Dismissible` pattern.
- **Acceptance:**
  - Existing recurring `RecurringExpense` + `RecurringIncome` models keep working; IDs stay stable so notifications scheduled against them (Phase 1.10) keep firing.
  - The `onRecurringBatch` stream subscription in `MainNavigationScreen` (Phase 3.2) still receives events.
- **Tests:** 2 widget tests (toggle Expense / Income view, swipe to delete).
- **Risk note:** R5 (merged recurring may break notifications). Mitigation: don't touch the IDs or the underlying tables.

### B.8 — Home Dashboard polish (≈ 4 hours)
- **Files:** `lib/screens/home_screen.dart`
- **Components:** Already redesigned in the WIP starter (`a231db4`). This task is **polish only**, not a rewrite. Audit:
  - Inline remaining `Spacing.*` → `LuminousTokens.*` calls.
  - Replace any leftover ad-hoc colors with `LuminousTokens` / `AppColors` values.
  - Verify `RepaintBoundary` placement around the transactions `GlassPanel` (Phase 1.7 — should still be there).
  - Verify "Add" FAB doesn't appear (the bottom-nav Add tab is now the entry point).
- **Acceptance:**
  - Home renders 100 expenses at 60 fps on Pixel 4a class device.
  - `test/lint/glass_blur_perf_test.dart` stays green.
- **Tests:** 1 widget test asserting `RepaintBoundary` wraps the transactions list (already exists via Phase 1.7 — verify it survives the polish).
- **Verification mode:** `visual` perf check on device.

### B.9 — Secondary screens (≈ 6 hours combined)
A grab-bag of less-trafficked screens. Each is a small commit; group them as `feat(phase-5.9.N): <screen> Luminous redesign` so they stay reviewable.

- **5.9a Onboarding** (`lib/screens/onboarding_screen.dart`) — `GlassPanel` slides + `GlassPillChip` page indicators.
- **5.9b PIN Setup** (`lib/screens/pin_setup_screen.dart`) — `GlassTopAppBar` + custom PIN grid.
- **5.9c PIN Unlock** (`lib/screens/pin_unlock_screen.dart`) — full-bleed glass surface, no app bar.
- **5.9d Crash Log viewer** (`lib/screens/crash_log_screen.dart`) — `GlassTopAppBar` + monospace text inside `GlassPanel`.
- **5.9e Export Data** (`lib/screens/export_data_screen.dart`) — `GlassTopAppBar` + `GlassListTile`s for format options.
- **5.9f Trash** (`lib/screens/trash_screen.dart`) — `GlassTopAppBar` + segmented Expense / Income + `GlassListTile`.
- **5.9g Category Manager** (`lib/screens/category_manager_screen.dart`) — `GlassTopAppBar` + grid of category icons in `GlassPanel`.
- **5.9h Backup/Restore** (`lib/screens/backup_restore_screen.dart`) — `GlassTopAppBar` + `GlassListSection`.
- **5.9i Quick Templates** (`lib/screens/quick_templates_screen.dart`) — `GlassTopAppBar` + `GlassListTile`.
- **5.9j Notification Settings** (`lib/screens/notification_settings_screen.dart`) — `GlassTopAppBar` + `GlassListSection` + toggles.

**Acceptance per screen:** uses the components above, drops every `Spacing.*` call, every text style routes through `Theme.of(context).textTheme.*`. No new test required unless behavior changes.

### B.10 — Brand alignment "FinanceFlow" (≈ 1 hour)

Final pass after all screens land:

- `lib/main.dart`: `MaterialApp(title: 'FinanceFlow', ...)` (already done in starter — verify).
- `android/app/src/main/AndroidManifest.xml`: `android:label="FinanceFlow"` (currently `"Money Tracker"`).
- `ios/Runner/Info.plist` (if it exists and matters): `CFBundleDisplayName = FinanceFlow`.
- Every "Money Tracker" string in `lib/` (grep first, then sed) → "FinanceFlow":
  ```bash
  grep -rn "Money Tracker" lib/
  ```
- `pubspec.yaml`: keep the package name as `budget_tracker` (changing it would force every import to update — out of scope for v5). Display label is the user-facing concern.
- Update `lib/utils/crash_log.dart` `_formatRecord` — `'App: Money Tracker $_appVersion'` → `'App: FinanceFlow $_appVersion'`. Update the matching expectation in `test/utils/crash_log_test.dart`.

**Acceptance:** `grep -rn "Money Tracker" lib/` returns 0 hits. Manifest label is "FinanceFlow". Test still green.

### B.11 — `Spacing.*` removal (≈ 1 hour)

After every Phase 5 screen has dropped its `Spacing.*` calls:

```bash
grep -rn "Spacing\." lib/
```

Should return 0 hits.

- Delete `lib/constants/spacing.dart`.
- Delete `test/constants/spacing_test.dart` if present.
- Update `analysis_options.yaml` — no change needed; the empty grep at Stage E preflight catches regressions.

**Acceptance:** `flutter analyze` clean, `flutter test` green, the file is gone.

### B.12 — Phase 5 close-out commit (≈ 30 min)

```
chore(phase-5): close-out — clean analyze + <test count> tests pass

All 9 hero screens redesigned (5.1–5.8, 5.9a–j), brand aligned to
FinanceFlow, Spacing.* removed. APK size: <delta vs Phase-4 baseline>.
```

Push the branch.

**Phase 5 gate:**
- Every screen uses Luminous components.
- `grep -rn "Spacing\." lib/` returns 0.
- `grep -rn "Money Tracker" lib/` returns 0.
- `bash scripts/preflight.sh` green.
- APK size delta within ±2 MB of Phase 4 baseline (the redesign should not bloat).

---

## 4. Stage C — Phase 6 security remainder (≈ 3–5 days)

These three items round out the Phase 6 security work. **6.1 is the largest and riskiest; sequence it after 6.3 and 6.4 so the device smoke test happens on a fully-up-to-date build.**

### C.1 — 6.4 Home widget redaction when PIN is enabled (≈ 3 hours, low risk)

- **File:** `lib/utils/home_widget_helper.dart`
- **Change:** before writing balance / recent-transaction strings to the widget surface, check `await PinSecurityHelper.isPinEnabled()`. If `true`, replace amounts with `'•••'` and descriptions with `'Locked'`. The widget XML resource (`android/app/src/main/res/xml/budget_widget_info.xml`) doesn't change — only the payload does.
- **Tests:** 2 unit tests on a new helper `WidgetPayload.redactIfLocked(WidgetData, {required bool pinEnabled})`. Run inside the existing `home_widget_helper_test.dart` (or a new file if none exists).
- **Acceptance:**
  - Widget shows `•••` for every monetary value when PIN is enabled, even on the lock screen.
  - When PIN is disabled, widget shows actual values (same as today).
- **Verification mode:** `visual` — pin a widget to the launcher, toggle PIN, observe.

### C.2 — 6.3 Backup file AES-GCM + passphrase (≈ 6 hours, medium risk)

- **Files:**
  - **Create:** `lib/utils/backup_crypto.dart` — `BackupCrypto.encrypt(String json, String passphrase)` returns base64-encoded `{salt, iv, ciphertext, tag}`. `decrypt` reverses.
  - **Modify:** `lib/screens/backup_restore_screen.dart` (or wherever the backup save / restore happens) to prompt for a passphrase before save and verify it before restore.
- **Crypto:** use `package:cryptography: ^2.x` (well-maintained, pub-published). 256-bit AES-GCM, PBKDF2-SHA256 with 100,000 iterations and a 16-byte salt.
- **Backup file format change:**
  - Today's backup is plaintext JSON with `version: 3` (Phase 4.9).
  - New: bump to `version: 4`. Wrap the existing JSON as:
    ```json
    {
      "version": 4,
      "encrypted": true,
      "salt": "<base64 16 bytes>",
      "iv": "<base64 12 bytes>",
      "ciphertext": "<base64 …>",
      "tag": "<base64 16 bytes>"
    }
    ```
  - Restore must accept both v3 (plaintext) and v4 (encrypted) — read `version` first, branch.
- **UX:**
  - Save: dialog "Choose a passphrase. We can't recover this file if you forget it." Two-input verification.
  - Restore: dialog "Enter the passphrase for this backup." If decrypt fails: "Wrong passphrase — try again."
- **Tests:**
  - Unit: `BackupCrypto.encrypt(...)` round-trips with the same passphrase; fails (returns `null`) with a wrong passphrase; produces different ciphertext on repeated encrypts (IV is fresh each time).
  - Integration: a v3 backup file still restores; a v4 backup file requires the passphrase.
- **Acceptance:**
  - A v4 backup file viewed in a text editor shows only the JSON envelope, never raw expense rows.
  - Restoring without the passphrase fails cleanly with the "Wrong passphrase" snackbar — no crash.
- **Verification mode:** `mechanical` (round-trip in unit tests) + `visual` (UX flow on device).

### C.3 — 6.1 SQLCipher migration (≈ 1.5 days, high risk)

This is the highest-impact, highest-risk item left in Phase 6. Treat the steps below as **non-negotiable** — skipping any of them risks an unrecoverable rekey failure on a user's device.

- **Files / deps:**
  - `pubspec.yaml`: add `sqflite_sqlcipher: ^3.x` and replace `sqflite: ^2.3.3` everywhere `sqflite` is imported. There are two imports: `package:sqflite/sqflite.dart` → `package:sqflite_sqlcipher/sqflite.dart`. The shape of the API is identical (`openDatabase`, `transaction`, etc.); the only addition is `password:` on `openDatabase`.
  - Keep `sqflite_common_ffi: ^2.3.3` for tests — it doesn't need to be SQLCipher-aware because tests don't encrypt.
- **Key generation and storage:**
  - On first launch of the SQLCipher-enabled build, generate a 256-bit random key (use `Random.secure` + `base64Encode`).
  - Store it under `SecurePrefs.writeString('db_encryption_key', key)`. Phase 6.2 already gave us a Keystore-backed home for this.
  - If the key already exists, reuse it.
- **Migration of the existing plaintext DB to encrypted:**
  - At `DatabaseHelper.database` getter, check if the existing file is plaintext (no `db_encryption_key` in SecurePrefs **and** the file at `getDatabasesPath()/database.db` opens without a password).
  - If plaintext, run the SQLCipher rekey dance:
    1. Open the plaintext DB.
    2. `ATTACH DATABASE 'database_enc.db' AS encrypted KEY '<key>';`
    3. `SELECT sqlcipher_export('encrypted');`
    4. `DETACH DATABASE encrypted;`
    5. Close the plaintext DB.
    6. **Verify** `database_enc.db` opens with the password and contains the expected row counts (compare against the plaintext file's counts taken *before* step 1).
    7. Only then: delete the plaintext file and rename `database_enc.db` → `database.db`.
  - If verification fails at step 6: **do not delete the plaintext file**. Log the failure to `CrashLog`, surface a "Encryption upgrade failed — please email support" snackbar, fall back to using the plaintext DB. Don't leave the user without their data.
- **Tests:**
  - Integration test (FFI): set up a plaintext DB with seeded rows, run the rekey path, assert the new file opens with the password and has the same rows.
  - Unit test: `_isPlaintextDatabase(File)` returns `true` for an unencrypted file, `false` for an encrypted one.
- **Acceptance:**
  - Existing users upgrade transparently — first launch takes 1–3 seconds extra (the export), every subsequent launch is normal speed.
  - `adb shell run-as com.moneytracker.app sqlite3 databases/database.db ".tables"` on a v5 build returns "file is not a database" (i.e. the file is now encrypted).
- **Risk:** R1 + R2 in the master plan's risk register. Mitigation already includes Phase 4.1's `.v18-backup`, but for 6.1 we add a `.pre-sqlcipher-backup` of the plaintext file written immediately before the rekey starts. It's deleted only after verification succeeds.

### C.4 — Stage C close-out

```bash
bash scripts/preflight.sh
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Then on device:
- Verify the widget redaction (C.1) by toggling PIN.
- Verify the encrypted backup (C.2) round-trips: save a backup, open it in a text editor (should be opaque), restore it.
- Verify the SQLCipher migration (C.3) on a device that already had data: open the app, scroll through history, confirm no data loss.

**Stage C gate:**
- `preflight.sh` green.
- Three new functional smoke tests pass on device.
- `dist/baseline/size-post-phase-6.json` saved — APK size delta within ±5 MB of post-Phase-5.

---

## 5. Stage D — Phase 7 test coverage rebuild (≈ 3–4 days)

These items are additive — they don't change runtime behavior, they expand confidence. They can run in parallel with Stage C if a second window is available.

### D.1 — 7.1 Rename mislabeled `app_state_logic_test.dart` (≈ 30 min)
- The current `test/logic/app_state_logic_test.dart` tests very little actual AppState logic. Rename to `test/logic/app_state_smoke_test.dart` to reflect what it does, then create a new (empty for now) `app_state_logic_test.dart` that D.2 will populate.

### D.2 — 7.2 Real AppState logic tests (≈ 1 day)
- One test per public mutator on `AppState`. The mutators (grep them — there are ~30) include `addExpense`, `addIncome`, `useTemplate`, `setActiveAccount`, `toggleDarkMode`, `addBudget`, `markExpensePaid`, etc.
- Each test: arrange via a fresh `AppState` + in-memory sqflite, act (call the mutator), assert the resulting `notifyListeners` fired AND the persisted DB state matches.

### D.3 — 7.3 Real `OnboardingService` tests (≈ 1 hour)
- Today's test (if any) is a stub. Cover: `isOnboardingComplete` → `true` after `markComplete`; key persists across `SharedPreferences.getInstance()` calls.

### D.4 — 7.4 Migration test
- **Already done** in Phase 4.12 (`test/integration/migration_v18_to_v19_test.dart`). Mark complete in checklist.

### D.5 — 7.5 Cascade delete integration test (≈ 2 hours)
- Seed an account with expenses + incomes + budgets + transaction_tags.
- Soft-delete the account; assert the trash tables now contain those rows AND `transaction_tags` is cleaned per Phase 4.4's triggers.
- Hard-delete (empty trash); assert all rows truly gone.

### D.6 — 7.6 8 hero-screen widget tests (≈ 1 day)
- One widget test per hero screen (the 8 screens redesigned in B.1–B.8): mount the screen with a fake `AppState`, assert key widgets render, exercise one happy-path interaction (tap → state change).

### D.7 — 7.7 PIN lockout screen test (≈ 1 hour)
- Mount `PinUnlockScreen` with `PinSecurityHelper` mocked to simulate 5 failed attempts → assert lockout UI shows + countdown ticks.

### D.8 — 7.8 Golden tests for 8 hero screens (≈ 1 day)
- For each hero screen, generate a golden via `flutter test --update-goldens`.
- CI gate: subsequent runs must pass with 2% pixel-diff tolerance.
- **Limitation:** goldens are platform-sensitive (font hinting differs on macOS vs Windows vs CI Linux). Lock the goldens to one platform (Windows, since that's where they're run) and document this in `test/golden/README.md`.

### D.9 — 7.9 `Clock` injection (≈ 4 hours)
- New file: `lib/utils/clock.dart` per `MASTER_PLAN.md` §7.9.
- Replace every `DateTime.now()` in:
  - `lib/utils/validators.dart`
  - `lib/providers/app_state.dart` (recurring logic + lockout)
  - `lib/utils/notification_helper.dart`
  - `lib/utils/home_widget_helper.dart`
  - `lib/utils/pin_security_helper.dart` (rate-limit timestamps)
- Tests can now control time with `Clock.instance = FakeClock(2026, 6, 1)`.
- Run `bash scripts/preflight.sh` — flush out any test that relied on wall clock.

### D.10 — 7.10 CI gates (≈ 1 hour)
- Update `scripts/preflight.sh` to assert pass count ≥ baseline + 50:
  ```bash
  PASS_COUNT=$(flutter test --reporter=expanded 2>&1 | grep -oE 'All tests passed!|\+\K[0-9]+(?=: All)' | tail -1)
  if [[ -z "$PASS_COUNT" || "$PASS_COUNT" -lt 1750 ]]; then
    fail "Test count $PASS_COUNT below baseline + 50 (1750)"
  fi
  ```
- Verify: `bash scripts/preflight.sh` still green.

**Stage D gate:**
- Behavioral coverage ≥ 70% (measure via `coverage` package + `lcov`: `flutter test --coverage && genhtml coverage/lcov.info -o coverage/html`).
- All goldens pass.

---

## 6. Stage E — Polish & ship (≈ 1 day)

### E.1 — 8.2 Final perf pass on real device (≈ 2 hours)
- Run DevTools Performance overlay on Pixel 4a (or equivalent) across:
  - Home scroll with 100 expenses
  - History scroll with 500 expenses
  - Tab switching (rapid Home ↔ History ↔ Add ↔ Analytics ↔ Wallet)
  - Analytics chart rendering
- **Pass criteria:** every frame ≤ 16.7 ms in steady state; first-frame ≤ 100 ms.
- **On a regression:** profile (open `dart:developer.Timeline`), identify the offender, fix. Likely candidates per `MASTER_PLAN.md`: blur sigma drift, missing `RepaintBoundary`, un-virtualized list.

### E.2 — 8.4 Version bump + CHANGELOG + tag (≈ 1 hour)
- `pubspec.yaml`: `version: 4.4.0+6` → `version: 5.0.0+1`.
- `CHANGELOG.md`: add an entry summarizing every phase (1–8). Use the per-phase descriptions from `MASTER_PLAN.md` §"Definition of done".
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

### E.3 — 8.5 Ship pipeline (≈ 30 min)
- Run the full pipeline from `CLAUDE.md` § "Shipping the APK":
  ```bash
  flutter build apk --release && \
  cp build/app/outputs/flutter-apk/app-release.apk /c/Users/leooa/Documents/personal-projects/expense-tracker-landing/public/downloads/money-tracker.apk && \
  git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing add public/downloads/money-tracker.apk && \
  git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing commit -m "chore: ship v5.0.0+1 — FinanceFlow Luminous" && \
  git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing push && \
  (cd /c/Users/leooa/Documents/personal-projects/expense-tracker-landing && vercel --prod --yes)
  ```
- Verify SHA-1 of the live file matches the local APK:
  ```bash
  curl -sL https://leo-money-tracker.vercel.app/downloads/money-tracker.apk | sha1sum
  sha1sum build/app/outputs/flutter-apk/app-release.apk
  ```
- **The user's auto-memory documents that Vercel Git integration is DISCONNECTED for `expense-tracker-landing`.** `vercel --prod --yes` is the *required* deploy command; `git push` alone is not enough.

### E.4 — Cut the GitHub release (≈ 15 min)
```bash
gh release create v5.0.0+1 \
  --title "v5.0.0+1 — FinanceFlow Luminous" \
  --notes-file CHANGELOG.md \
  build/app/outputs/flutter-apk/app-release.apk
```

### E.5 — Merge `release/v5.0.0` → `main` (≈ 10 min)
```bash
git checkout main
git merge --ff-only release/v5.0.0   # FF only; the branch should be a clean linear history
git push origin main
```

If a non-FF merge is needed (someone touched `main` in parallel), open a PR instead:
```bash
gh pr create --base main --head release/v5.0.0 \
  --title "v5.0.0+1 — FinanceFlow Luminous release" \
  --body-file CHANGELOG.md
```

### E.6 — Post-ship verification (≈ 15 min)
- Download the APK from the live URL.
- Install on a previously-unupgraded test device.
- Open → onboarding → add expense → backup → restore → set PIN → background → resume → unlock. End-to-end smoke per `MASTER_PLAN.md` §8.3.

**Stage E gate (and v5.0.0 definition of done):**
- Tag `v5.0.0+1` exists on origin and is the merge target on `main`.
- Landing page serves the APK at the documented SHA-1.
- GitHub release created.
- End-to-end smoke test passes.

---

## 7. Cross-cutting clean-ups

These don't block ship but should land somewhere in Stage B or D — they're untracked debris from prior work.

### 7.1 — Delete orphan `MainActivity.kt`
- `android/app/src/main/kotlin/com/example/budget_tracker/MainActivity.kt` is dead code (the manifest's `namespace = "com.moneytracker.app"` makes it unreachable).
- Action: `mv "android/app/src/main/kotlin/com/example/budget_tracker/MainActivity.kt" TRASH/MainActivity.kt.orphan` (per global rule: never `rm`, always `mv` to trash). Then remove the empty `com/example/budget_tracker/` directory tree if it ends up empty.
- Commit alongside Stage B (any phase 5 commit).

### 7.2 — Old `dist/baseline/` artifacts
- `dist/baseline/v4.4.0+6.db` was skipped in session 1 (no device attached). Either populate it now (export a dev DB) or remove the placeholder entry from `docs/CHECKLIST.md`.
- Same for `dist/baseline/perf/` (Performance Overlay screenshots) — skipped, mark complete or remove.

### 7.3 — Stale `.v18-backup` files
- Phase 4.1 leaves `.v18-backup` next to the active DB on a fresh upgrade. After a few launches it should auto-clean. Verify the cleanup path in `DatabaseHelper._cleanV18BackupAfterMigrationSuccess` actually runs on stage A.2's first launch.

### 7.4 — `pubspec.lock` upgrade
- After Stage C lands new deps (`sqflite_sqlcipher`, `cryptography`), run `flutter pub upgrade --major-versions` once and audit the diff. Don't auto-accept — some transitive bumps will break things.

---

## 8. Risk register (updates since master plan)

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Migration v19 fails on a user's device | Low | High | Phase 4.1 pre-migration backup (already in place) |
| R2 | SQLCipher rekey fails mid-flight | Low | High | Stage C.3 verification step + `.pre-sqlcipher-backup` |
| R3 | Variable-font wght axis renders incorrectly on legacy Android | Very Low | Medium | Fallback chain in `TextStyle.fontFamilyFallback` (not yet added — add it in Stage B if any device shows wrong weight) |
| R4 | Merged Add hub confuses existing users | Medium | Low | One-time "Tap to add a transaction" tooltip (B.5) |
| R5 | Recurring merge breaks notifications | Low | Medium | Don't touch IDs (B.7) |
| R6 | Performance budget not met | Medium | Medium | Phase 8.2 perf gate; rollback option = bump blur back to 10 |
| R7 | Wall-clock flakes | Medium | Low | Stage D.9 Clock injection |
| R8 | PIN secure-storage migration locks user out | Low | Medium | Stage A.3 device test before any further work; revert plan in place |
| R9 | Removing `google_fonts` breaks something | Very Low | Low | `test/lint/no_forbidden_patterns_test.dart` enforces it (already in place) |
| R10 | Vercel deploy step fails | Low | Low | `vercel --prod --yes` is the documented workaround in `CLAUDE.md` |
| **R11** (new) | **SQLCipher migration corrupts on a partially-encrypted file** | Low | High | C.3 step 6 verifies row counts before destroying plaintext |
| **R12** (new) | **Backup encryption passphrase forgotten** | Medium | High (user-side) | UX wording in C.2 makes this explicit; backup-restore screen warns up front |

---

## 9. Definition of Done for `v5.0.0+1`

All of the following must be true before tagging:

1. **Every checklist item in `docs/CHECKLIST.md` ticked** (except explicit deferrals — currently Phase 3.8 only).
2. **`bash scripts/preflight.sh` green** on `release/v5.0.0`.
3. **APK builds clean** (`flutter build apk --release` exits 0, size ≤ 70 MB).
4. **Device smoke test passes** end-to-end (see `MASTER_PLAN.md` §8.3 — 5-minute manual run).
5. **`pubspec.yaml` version is `5.0.0+1`.**
6. **CHANGELOG.md** has a v5.0.0 entry.
7. **`v5.0.0+1` tag exists** on `origin/release/v5.0.0`.
8. **Landing page serves the APK** at `https://leo-money-tracker.vercel.app/downloads/money-tracker.apk` with a matching SHA-1.
9. **GitHub release exists** at `Leo-Atienza/Money-Tracker` tagged `v5.0.0+1`.
10. **`release/v5.0.0` merged into `main`** (fast-forward or PR).

---

## 10. Effort + sequencing summary

| Stage | Tasks | Effort (linear) | Device required? | Parallelizable? |
|---|---|---|---|---|
| A — De-risk | A.1–A.6 | 1–2 hours | **Yes** (PIN + FLAG_SECURE + crash redaction) | No — gate for everything else |
| B — Phase 5 design | B.0–B.12 | 5–8 days | Yes (visual check per screen) | Internally sequential; B.10–B.12 strict last |
| C — Phase 6 security | C.1–C.4 | 3–5 days | Yes (widget redaction + SQLCipher) | C.1 + C.2 parallel; C.3 sequential after them |
| D — Phase 7 tests | D.1–D.10 | 3–4 days | No (except D.6 widget tests) | Fully parallel with B and C |
| E — Ship | E.1–E.6 | 1 day | Yes (final smoke) | Strict last |

**Realistic total wall-clock with one developer + agent pair:** 10–18 days from `4f1d62f` to a live `v5.0.0+1`.

**Faster path** (multiple parallel agent windows, hands-on developer for device checks): 6–10 days.

---

**End of plan. Updates to this file should land in the same commit as the work they describe.**
