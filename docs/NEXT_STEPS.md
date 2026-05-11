# Next Steps Plan — From Here to `v5.0.0+1` Ship

**Origin:** synthesis after session 2 (2026-05-11) of the `release/v5.0.0` arc.
**Revision:** rewritten after session 3 (2026-05-11) — reflects the current branch state, the work that landed in session 3, and the precise remaining work.
**Companions:** `docs/MASTER_PLAN.md` (full "why"), `docs/CHECKLIST.md` (per-task tickboxes), `SESSION_HANDOFF.md` (snapshot of session 3 close).
**Purpose:** spell out, with file paths and acceptance criteria, the exact remaining work between commit `789c59c` and a tagged `v5.0.0+1` on the landing page. Anything not in this file is out of scope for this release (see `MASTER_PLAN.md` §"Out of v5.0.0").

---

## 0. Current state (2026-05-11, after `789c59c`)

| Surface | State |
|---|---|
| Branch | `release/v5.0.0`, **pushed to origin** (session 3) |
| `main` | At `789c59c` — fast-forward-merged from `release/v5.0.0` (session 3) |
| `origin/main` | Same SHA — `git push origin main` completed (session 3) |
| HEAD | `789c59c docs(handoff): close-out for session 3 — brand, 6.3/6.4 crypto, 7.3/5/7/9/10` |
| Commits since the old `main` diverged | 28 |
| `flutter analyze` | No issues found |
| `flutter test` | 1,764 pass (was 1,720 at session 2 close) |
| `flutter build apk --release` | succeeded, 59.2 MB (verified session 3) |
| `bash scripts/preflight.sh` | green, test-count gate ≥ 1,750 |
| DB schema version | 19 |
| `pubspec.yaml` version | `4.4.0+6` (will become `5.0.0+1` at Stage E **after** Stage B Phase 5 lands) |
| New deps since session 2 | `cryptography ^2.7.0` (for Phase 6.3 backup envelope) |

**Headline truth: `main` and `release/v5.0.0` are at the same SHA on both local and origin.** Future work continues on `release/v5.0.0`; merge to `main` again at the end of each session that lands ship-worthy work.

### Phase status legend
- ✅ **Done** — landed, tested, committed.
- 🟡 **Partial** — some sub-tasks landed; others tracked below.
- ⏳ **Pending** — nothing started.
- ⏸ **Deferred** — explicitly out of v5.0.0 scope (see `MASTER_PLAN.md` §"Out of v5.0.0") or out of session-3 scope (resume per per-item notes).

| Phase | Status | What's left |
|---|---|---|
| 0 — Pre-flight | ✅ | — |
| 1 — Stop the Bleeding | ✅ | — |
| 2 — Architectural Foundations | ✅ | — |
| 3 — Race & Lifecycle | 🟡 (3.8 ⏸) | 3.8 `AppPhase` state machine — deferred to v5.1 per master plan. |
| 4 — Schema v19 + Data Integrity | ✅ | — |
| 5 — Luminous Design Integration | 🟡 (5.10 ✅; starter ✅) | 5.1–5.9 hero-screen redesigns; 5.11 Spacing removal. See §3 below. |
| 6 — Security Hardening | 🟡 (6.2/3/4/5/6 ✅; 6.3 UX wiring landed session 4) | 6.1 SQLCipher only. See §4 below. |
| 7 — Test Coverage | 🟡 (7.3/4/5/7/9/10 ✅) | 7.1 rename; 7.2 AppState mutator tests; 7.6 hero-screen widget tests; 7.8 goldens. See §5 below. |
| 8 — Polish & Ship | 🟡 (8.1/3 ✅) | 8.2 perf pass; 8.4 version bump + tag; 8.5 ship pipeline. See §6 below. |

---

## 1. Sequencing rationale

The plan is sequenced so that:

1. **De-risk first.** Phase 6.2's PIN migration is unit-tested but unproven on a real Keystore. Confirm or revert before any new work piles on top. **Same for Phase 6.4 widget redaction (new this session) and Phase 6.5 FLAG_SECURE.**
2. **Visual work next.** Phase 5 needs Hanken Grotesk in place (done) and a stable codebase to anchor against. It's the biggest chunk and the headline change for the major-version bump.
3. **Security in parallel with Phase 5.** 6.3 UX wiring landed session 4; the remaining device smokes (encrypted save round-trip, plaintext-legacy fallback) pair with the Phase 5.9h backup/restore redesign. 6.1 (SQLCipher) is highest data-loss risk and earns its own session at the end of the chain so other code is stable for the smoke test.
4. **Test coverage last but not least.** Phase 7 is additive — running it before Phase 5 means writing tests against screens about to be deleted. Save 7.6 + 7.8 for after Phase 5's structure settles.
5. **Ship is a gate, not a step.** Tag `v5.0.0+1` only after every preceding stage is green AND a 5-minute device smoke test passes.

The default linear order is **A → B → C → D → E**. A subset (C.3, D.2, D.6, D.8) can be picked up in parallel sessions if multiple agents / windows are available.

---

## 2. Stage A — De-risk what session 2 + session 3 just landed (≈ 1–2 hours)

**Goal:** prove on real Keystore + Recents that the Phase 6 work doesn't regress UX or lock anyone out. If it does, the offending commit is reverted and the release plan is replanned.

### A.1 — Push the branch to origin (DONE in session 3) ✅
`git push -u origin release/v5.0.0` already ran (session 3). `main` is also at the same SHA on origin. **No-op for the next session.**

### A.2 — Build a fresh release APK and install it side-by-side (10 min) ⏳
```bash
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**Acceptance:** APK installs cleanly. App opens. SHA-1 of the installed APK can be verified later against the landing copy.

### A.3 — Live-fire Phase 6.2 PIN migration test (20 min) ⏳

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

### A.4 — Smoke-test Phase 6.5 FLAG_SECURE (5 min) ⏳

1. With PIN enabled, hit the Recents button on the device.
2. The thumbnail of FinanceFlow should show a black/blank surface, **not** the actual screen contents.
3. Disable PIN in Settings → Security → no PIN required.
4. Hit Recents again — thumbnail should now show the real screen.

**Acceptance:** Recents thumbnail toggles based on PIN state. Screenshot attempt with hardware buttons either fails or produces a blank capture while PIN is on.

### A.5 — Smoke-test Phase 6.6 crash redaction (5 min) ⏳

1. Trigger a controlled crash (e.g. add a temporary `throw Exception(r'fake $123 leak C:\Users\leooa\fake.db');` to `AppState.loadData()`, build, run, observe).
2. Open Settings → Crash Log. The latest entry should contain `[user]`, `[amount]`, but **not** the literal username or dollar amount.
3. Remove the temporary throw, rebuild.

**Acceptance:** PII redactor fires on a real crash record on device.

### A.6 — Smoke-test Phase 6.4 widget PIN redaction (NEW this session, 5 min) ⏳

1. Add the home-screen widget to a launcher (long-press → Widgets → FinanceFlow → drop on home).
2. Toggle PIN OFF — widget shows current balance / month / income / expenses normally.
3. Toggle PIN ON — widget should now show `•••` in every monetary field and `Locked` for the month label. Currency symbol stays (e.g. `$ •••` not just `•••`).
4. Force a widget refresh (the launcher's update-now action, or wait the system refresh interval).

**Acceptance:** widget content matches PIN state on every refresh. No layout shift (width / accent color stable across toggle).

### A.7 — Push de-risk fixes (if any) and stay in sync (5 min) ⏳

```bash
git push origin release/v5.0.0
# Merge fixes to main now so other surfaces stay synced:
git checkout main
git merge --ff-only release/v5.0.0
git push origin main
git checkout release/v5.0.0
```

**Stage A gate:** session 2 + 3's four security commits validated on real hardware. If any failed, the offender is reverted and a follow-up issue is filed. Push and re-sync to main.

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

### B.0 — Pre-flight (one-time setup, 30 min) ⏳

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

### B.1 — Settings & Security screen (≈ 4 hours) ⏳
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

### B.2 — Wallet & Accounts (≈ 5 hours) ⏳
- **Files:** `lib/screens/account_manager_screen.dart` → **rename** to `lib/screens/wallet_screen.dart`. Update every import (grep `account_manager_screen` in `lib/` + `test/`).
- **Components:** `GlassTopAppBar`, `GlassListSection`, `GlassListTile`, `GlassPanel` (account card), `GlassPillChip` (account-type filter).
- **Structural notes:** the class name should become `WalletScreen`. Update `main.dart`'s `_screens` list. Update `MainNavigationScreen._navDestinations[4].label` to "Wallet" (it already is).
- **Acceptance:**
  - All existing account CRUD still works (add, edit, archive, switch).
  - `onAccountSwitch` stream still emits when the active account changes — `MainNavigationScreen._onAccountSwitch` resets `_currentIndex = 0`.
- **Tests:** add `test/screens/wallet_screen_test.dart` (rename existing if any) with one widget test per CRUD.
- **Verification mode:** `visual` — account cards must show balance in `displayLarge` style.

### B.3 — Budgets & Planning (≈ 5 hours) ⏳
- **Files:** `lib/screens/budget_screen.dart`
- **Components:** `GlassTopAppBar`, `GlassListSection`, `GlassProgressBar` (the hero — one per budget), `GlassPillChip` (period filter).
- **Acceptance:**
  - Budget add/edit/delete unchanged.
  - Progress bar's `value` parameter matches `Budget.percentUsed` (clamp at 1.0 for visual but report raw value via semantics — `GlassProgressBar` already does this).
  - Tapping a budget pushes the existing detail / edit dialog via `PremiumPageRoute`.
- **Tests:** 1 widget test per budget state (under-budget, at-100%, over-budget).
- **Verification mode:** `visual` — confirm progress bars animate smoothly when budgets update.

### B.4 — Analytics & Insights (≈ 6 hours) ⏳
- **Files:** `lib/screens/analytics_screen.dart`
- **Components:** `GlassTopAppBar`, `GlassSegmentedControl` (period: Week/Month/Year), `GlassDonutChart` (category breakdown hero), `GlassBarChart` (monthly comparison), `GlassListSection` (top categories).
- **Structural notes:** retire the legacy `fl_chart` PieChart + BarChart wrappers. Keep `fl_chart` in `pubspec.yaml` only if any other screen uses it; if not, drop the dep.
- **Acceptance:**
  - Top categories list reflects the same selection as the donut chart (single source of truth = the segmented control's selected period).
  - Tapping a donut slice highlights the matching list item.
- **Tests:** 1 widget test per period selection; 1 test that the donut sum matches `Expense.total` for the selected period.
- **Verification mode:** `visual` — chart legibility against the glass surface needs eyeballing.

### B.5 — Add Transaction (STRUCTURAL CHANGE, ≈ 8 hours) ⏳
- **Files:**
  - **Delete after migration:** `lib/screens/add_hub_screen.dart` (166 lines), `lib/screens/add_expense_screen.dart` (1,381 lines), `lib/screens/add_income_screen.dart` (1,034 lines).
  - **Create:** `lib/screens/add_transaction_screen.dart` (single screen with type segmented control).
- **Components:** `GlassTopAppBar`, `GlassSegmentedControl` (Expense / Income at the top), `CategoryBentoGrid` (the 4-col category picker — replaces the old vertical category list), `GlassPanel` (form sections), text fields styled by the global `InputDecorationTheme`.
- **Acceptance:**
  - Toggle between Expense and Income preserves description / amount / date if user filled them; only the category list swaps.
  - Submit goes through `DatabaseHelper.createExpenseWithCarryover` / `createIncomeWithCarryover` (Phase 1.6 atomic helpers).
  - Quick template chips appear above the category grid; tapping one fills the form (`useTemplate` from Phase 1.1 — already correct).
- **Route migration (grep first to find call sites, then edit):**
  - Every `PremiumPageRoute(page: const AddExpenseScreen())` → `PremiumPageRoute(page: const AddTransactionScreen(initialType: TransactionType.expense))`.
  - Same for `AddIncomeScreen`.
  - Same for `AddHubScreen` (the bottom-nav Add tab destination — `lib/main.dart:371`).
  - **Known callers at session-3 close:** `lib/screens/history_screen.dart:182, 190, 2265, 2281` (edit + add expense/income); `lib/screens/home_screen.dart:298, 796` (add + edit expense); `lib/main.dart:371` (Add tab destination).
- **Tests:** 4 widget tests — submit expense, submit income, toggle preserves form, useTemplate fills form.
- **Verification mode:** `visual` (bento grid layout) + `mechanical` (atomic submission).
- **Risk note:** R4 in `MASTER_PLAN.md` Risk Register (merged hub may confuse existing users). Add a one-time tooltip on first launch of v5: "Tap to add a transaction" (stored in `OnboardingService` as `seenAddHubTooltip`).

### B.6 — Transaction History (STRUCTURAL CHANGE, ≈ 6 hours) ⏳
- **Files:**
  - **Split:** `lib/screens/history_screen.dart` (2,307 lines today) →
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

### B.7 — Recurring Items (STRUCTURAL CHANGE, ≈ 5 hours) ⏳
- **Files:**
  - **Delete after migration:** `lib/screens/recurring_expenses_screen.dart` (1,080 lines), `lib/screens/recurring_income_screen.dart` (1,027 lines).
  - **Create:** `lib/screens/recurring_items_screen.dart`.
- **Components:** `GlassTopAppBar`, `GlassSegmentedControl` (Expense / Income), `GlassListSection` (frequency groupings), `GlassListTile`, swipe-to-delete via the existing `Dismissible` pattern.
- **Acceptance:**
  - Existing recurring `RecurringExpense` + `RecurringIncome` models keep working; IDs stay stable so notifications scheduled against them (Phase 1.10) keep firing.
  - The `onRecurringBatch` stream subscription in `MainNavigationScreen` (Phase 3.2) still receives events.
- **Tests:** 2 widget tests (toggle Expense / Income view, swipe to delete).
- **Risk note:** R5 (merged recurring may break notifications). Mitigation: don't touch the IDs or the underlying tables.

### B.8 — Home Dashboard polish (≈ 4 hours) ⏳
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

### B.9 — Secondary screens (≈ 6 hours combined) ⏳
A grab-bag of less-trafficked screens. Each is a small commit; group them as `feat(phase-5.9.N): <screen> Luminous redesign` so they stay reviewable.

- **5.9a Onboarding** (`lib/screens/onboarding_screen.dart`) — `GlassPanel` slides + `GlassPillChip` page indicators.
- **5.9b PIN Setup** (`lib/screens/pin_setup_screen.dart`) — `GlassTopAppBar` + custom PIN grid.
- **5.9c PIN Unlock** (`lib/screens/pin_unlock_screen.dart`) — full-bleed glass surface, no app bar. **Note:** brand title is already "FinanceFlow" (session 3, line 111).
- **5.9d Crash Log viewer** (`lib/screens/crash_log_screen.dart`) — `GlassTopAppBar` + monospace text inside `GlassPanel`. **Note:** share subject is already "FinanceFlow Crash Log" (session 3).
- **5.9e Export Data** (`lib/screens/export_data_screen.dart`) — `GlassTopAppBar` + `GlassListTile`s for format options. **Note:** share subjects already rebranded (session 3).
- **5.9f Trash** (`lib/screens/trash_screen.dart`) — `GlassTopAppBar` + segmented Expense / Income + `GlassListTile`.
- **5.9g Category Manager** (`lib/screens/category_manager_screen.dart`) — `GlassTopAppBar` + grid of category icons in `GlassPanel`.
- **5.9h Backup/Restore** (`lib/screens/backup_restore_screen.dart`) — `GlassTopAppBar` + `GlassListSection`. **Note:** C.2 passphrase prompts already wired here (session 4); the Luminous redesign keeps `_promptForBackupPassphrase` + `_requestRestorePassphrase` intact and re-skins their `AlertDialog` shells.
- **5.9i Quick Templates** (`lib/screens/quick_templates_screen.dart`) — `GlassTopAppBar` + `GlassListTile`.
- **5.9j Notification Settings** (`lib/screens/notification_settings_screen.dart`) — `GlassTopAppBar` + `GlassListSection` + toggles.

**Acceptance per screen:** uses the components above, drops every `Spacing.*` call, every text style routes through `Theme.of(context).textTheme.*`. No new test required unless behavior changes.

### B.10 — Brand alignment "FinanceFlow" ✅ DONE (session 3)
Landed in commit `23413e6`. AndroidManifest label + every "Money Tracker" string in `lib/` rebranded. `grep -rn "Money Tracker" lib/` now returns 0. Test expectation in `crash_log_test.dart` updated.

### B.11 — `Spacing.*` removal (≈ 1–3 hours, scope-dependent) ⏳

After every Phase 5 screen has dropped its `Spacing.*` calls:

```bash
grep -rn "Spacing\." lib/
```

Should return 0 hits.

**Reality check at session 3 close:** 756 `Spacing.*` call sites remain in lib/. Per the per-screen B.1–B.9 commits, each redesign inlines its own. After Stage B is complete, run:

- Delete `lib/constants/spacing.dart`.
- Delete `test/constants/spacing_test.dart` if present.
- Verify `flutter analyze` clean, `flutter test` green.

**Pragmatic alternative if Stage B partial:** since `Spacing` already aliases `LuminousTokens` (see `lib/constants/spacing.dart:8-9`), leaving the file in place ships fine. The "zero hits" gate only matters at v5.0.0+1 tag time.

### B.12 — Phase 5 close-out commit (≈ 30 min) ⏳

```
chore(phase-5): close-out — clean analyze + <test count> tests pass

All 9 hero screens redesigned (5.1–5.8, 5.9a–j), brand aligned to
FinanceFlow, Spacing.* removed. APK size: <delta vs Phase-4 baseline>.
```

Push the branch.

**Phase 5 gate:**
- Every screen uses Luminous components.
- `grep -rn "Spacing\." lib/` returns 0.
- `grep -rn "Money Tracker" lib/` returns 0 (already true at session 3 close).
- `bash scripts/preflight.sh` green.
- APK size delta within ±2 MB of Phase 4 baseline (the redesign should not bloat).

---

## 4. Stage C — Phase 6 security remainder (≈ 1.5–3 days remaining)

Two items remain after session 3.

### C.1 — 6.4 Home widget redaction ✅ DONE (session 3)
Landed in commit `5fcff2d`. `lib/utils/widget_payload.dart` + wiring through `home_widget_helper.dart`. 6 unit tests. **Device smoke test remains** — see §2 A.6.

### C.2 — 6.3 Backup AES-GCM ✅ DONE (sessions 3 + 4)

**Session 3:** `lib/utils/backup_crypto.dart` shipped with `package:cryptography ^2.7.0`. v4 envelope shape, PBKDF2-HMAC-SHA256 @ 100k iterations, GCM tag rejection. 15 tests.

**Session 4 (this session):** UX wiring landed. The wrap/unwrap pair lives on `BackupHelper` itself as `@visibleForTesting` static methods (`wrapBackupIfNeeded`, `unwrapBackupIfNeeded`), and the production save / share / restore methods now accept the passphrase contract:

- `BackupHelper.saveBackupToUserSelectedLocation({passphrase})` — encrypts before bytes hit disk or the system file picker. Encryption stays on the main isolate so `package:cryptography` doesn't have to cross the isolate boundary; the ~250 ms PBKDF2 step runs while the "Creating backup..." dialog is already shown.
- `BackupHelper.shareDatabase({passphrase})` — same contract for shared-via-system-share-sheet backups, which travel through third-party apps where plaintext exposure is highest.
- `BackupHelper.restoreDatabase({onPassphraseRequest})` — the callback is invoked only when the picked file is detected as a v4 envelope. The helper loops on wrong passphrases (`isRetry: true` after each miss) until correct or user cancels. Legacy v2/v3 plaintext backups never trigger the callback — `BackupCrypto.isEncryptedEnvelope` gates the branch.

`backup_restore_screen.dart` implements:
- `_promptForBackupPassphrase()` — confirmation dialog with two obscured TextFields, min-6-char validation, "Choose a passphrase. We cannot recover this file if you forget it." warning copy. Used by both `_exportBackup` and `_shareBackup`.
- `_requestRestorePassphrase({isRetry})` — single obscured TextField with show/hide toggle, prepends "Wrong passphrase — try again." banner on retry. Used as the callback for `_performRestore`.

**Tests added this session:** 11 in `test/integration/backup_restore_v4_test.dart` — wrap-passes-through-on-null/empty-passphrase, wrap-produces-envelope, wrap-hides-inner-keys, unwrap-plaintext-passthrough, unwrap-null-on-encrypted-with-null/empty/wrong-passphrase, full round-trip preserves comprehensive backup JSON byte-for-byte, two consecutive wraps produce distinct envelopes (proves fresh salt/IV per call survives the integration layer).

**Still requires device verification before v5.0.0+1 tag:**
- Save: passphrase dialog renders, `.etbackup` file viewed in a text editor shows only the envelope.
- Restore (encrypted): correct passphrase decrypts; wrong passphrase retries; cancel aborts cleanly.
- Restore (plaintext, legacy): existing backups in `backups/` restore transparently without the dialog.
- Share: encrypted file passes through SharePlus, recipient can decrypt with same passphrase.

**Pair with B.9h** — the backup/restore screen redesign happens in B.9h; the visual work and the device smokes for C.2 can be a single session.

### C.3 — 6.1 SQLCipher migration (≈ 1.5 days, high risk) ⏳

**Unchanged from prior plan.** This is the highest-impact, highest-risk item left in Phase 6. Treat the steps below as **non-negotiable** — skipping any of them risks an unrecoverable rekey failure on a user's device.

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

### C.4 — Stage C close-out ⏳
```bash
bash scripts/preflight.sh
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Then on device:
- C.1 widget redaction: already covered in §2 A.6.
- C.2 backup encryption round-trip: save a backup, open it in a text editor (should be opaque), restore it. Test wrong-passphrase rejection.
- C.3 SQLCipher migration on a device that already had data: open the app, scroll through history, confirm no data loss.

**Stage C gate:**
- `preflight.sh` green.
- Three new functional smoke tests pass on device.
- `dist/baseline/size-post-phase-6.json` saved — APK size delta within ±5 MB of post-Phase-5.

---

## 5. Stage D — Phase 7 test coverage rebuild (≈ 1–2 days remaining)

5/10 items landed in session 3. The remaining 5 are either deferred (require Stage B) or worth their own focused session.

### D.1 — 7.1 Rename mislabeled `app_state_logic_test.dart` ⏳ (or skip)
**Discovery from session 3:** the file at `test/logic/app_state_logic_test.dart` actually tests `CurrencyHelper` + `DatabaseConstants` — not AppState at all. The spec's `app_state_smoke_test` rename is misleading. **Recommended approach:** rename to `test/logic/currency_helper_and_constants_test.dart` to match content, and only create a new `app_state_logic_test.dart` placeholder if you're about to do D.2 in the same session.

### D.2 — 7.2 Real AppState logic tests (≈ 1 day) ⏳
- One test per public mutator on `AppState`. The mutators (grep them — there are ~30) include `addExpense`, `addIncome`, `useTemplate`, `setActiveAccount`, `toggleDarkMode`, `addBudget`, `markExpensePaid`, etc.
- Each test: arrange via a fresh `AppState` + in-memory sqflite, act (call the mutator), assert the resulting `notifyListeners` fired AND the persisted DB state matches.
- **Discovery from session 3:** AppState now uses `Clock.instance.now()` (Phase 7.9), so tests can use `Clock.instance = FakeClock.fixed(...)` to control time-dependent mutator behaviour (template insertion date, prune logic, etc.).

### D.3 — 7.3 Real `OnboardingService` tests ✅ DONE (session 3)
Landed at `test/services/onboarding_service_test.dart` (8 tests). Pattern for future tests:
```dart
setUp(() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
});
```

### D.4 — 7.4 Migration test ✅ DONE (Phase 4.12)

### D.5 — 7.5 Cascade delete integration test ✅ DONE (session 3)
Landed at `test/integration/cascade_delete_test.dart` (5 tests). Covers: soft-delete tag scrub, hard-delete triggers, account-scoped `emptyTrash`.

### D.6 — 7.6 8 hero-screen widget tests (≈ 1 day) ⏳
**Blocked on Stage B** — testing screens you're about to delete is wasted work. Sequence: Stage B lands → write widget tests against the final screens. One widget test per hero screen (the 8 screens redesigned in B.1–B.8): mount the screen with a fake `AppState`, assert key widgets render, exercise one happy-path interaction (tap → state change).

### D.7 — 7.7 PIN lockout test ✅ DONE (session 3)
Landed at `test/utils/pin_lockout_test.dart` (5 tests) — uses `Clock.instance = FakeClock.fixed(...)` to drive the 5-minute window in sub-second wall time. Covers correct PIN clears counter, 5 wrongs arm lockout, countdown reflects clock, isLockedOut self-heals after expiry, mid-streak correct PIN resets.

### D.8 — 7.8 Golden tests for 8 hero screens (≈ 1 day) ⏳
**Blocked on Stage B** — goldens against screens about to change is wasted work.
- For each hero screen, generate a golden via `flutter test --update-goldens`.
- CI gate: subsequent runs must pass with 2% pixel-diff tolerance.
- **Limitation:** goldens are platform-sensitive (font hinting differs on macOS vs Windows vs CI Linux). Lock the goldens to one platform (Windows, since that's where they're run) and document this in `test/golden/README.md`.

### D.9 — 7.9 `Clock` injection ✅ DONE (session 3)
Landed in commit `6c56fe2`. `lib/utils/clock.dart` + 20 `DateTime.now()` call sites migrated across the 5 files in spec.

### D.10 — 7.10 CI gates ✅ DONE (session 3)
`scripts/preflight.sh` + `.ps1` now parse the test-count trailer and fail if it drops below `$TEST_COUNT_MIN=1750`. **Bump the gate each release** — after Stage B lands its widget tests, raise to `baseline + 50` (whatever the new baseline is).

**Stage D gate:**
- Behavioral coverage ≥ 70% (measure via `coverage` package + `lcov`: `flutter test --coverage && genhtml coverage/lcov.info -o coverage/html`).
- All goldens pass.

---

## 6. Stage E — Polish & ship (≈ 1 day)

**Cannot start until Stage A, B, and C land.** Version stays at `4.4.0+6` until then — bumping to `5.0.0+1` without the Luminous redesign would misrepresent the release.

### E.1 — 8.2 Final perf pass on real device (≈ 2 hours) ⏳
- Run DevTools Performance overlay on Pixel 4a (or equivalent) across:
  - Home scroll with 100 expenses
  - History scroll with 500 expenses
  - Tab switching (rapid Home ↔ History ↔ Add ↔ Analytics ↔ Wallet)
  - Analytics chart rendering
- **Pass criteria:** every frame ≤ 16.7 ms in steady state; first-frame ≤ 100 ms.
- **On a regression:** profile (open `dart:developer.Timeline`), identify the offender, fix. Likely candidates per `MASTER_PLAN.md`: blur sigma drift, missing `RepaintBoundary`, un-virtualized list.

### E.2 — 8.4 Version bump + CHANGELOG + tag (≈ 1 hour) ⏳
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

### E.3 — 8.5 Ship pipeline (≈ 30 min) ⏳
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

### E.4 — Cut the GitHub release (≈ 15 min) ⏳
```bash
gh release create v5.0.0+1 \
  --title "v5.0.0+1 — FinanceFlow Luminous" \
  --notes-file CHANGELOG.md \
  build/app/outputs/flutter-apk/app-release.apk
```

### E.5 — Merge `release/v5.0.0` → `main` (≈ 10 min) ⏳
**At session 3 close, `main` is already at the same SHA as `release/v5.0.0`.** Future sessions land work on `release/v5.0.0` first, then fast-forward-merge to `main` at the end (same dance session 3 did). At E.5 time the merge is likely already up-to-date; if not:
```bash
git checkout main
git merge --ff-only release/v5.0.0   # FF only; the branch should be a clean linear history
git push origin main
git checkout release/v5.0.0
```

If a non-FF merge is needed (someone touched `main` in parallel), open a PR instead:
```bash
gh pr create --base main --head release/v5.0.0 \
  --title "v5.0.0+1 — FinanceFlow Luminous release" \
  --body-file CHANGELOG.md
```

### E.6 — Post-ship verification (≈ 15 min) ⏳
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

### 7.1 — Delete orphan `MainActivity.kt` ✅ DONE (session 3)
Moved to `TRASH/MainActivity.kt.orphan` in commit `23413e6`. The orphaned `com/example/budget_tracker/` directory was also removed (only `com/moneytracker/app/` remains).

### 7.2 — Old `dist/baseline/` artifacts ⏳
- `dist/baseline/v4.4.0+6.db` was skipped in session 1 (no device attached). Either populate it now (export a dev DB from the test device used for A.2) or remove the placeholder entry from `docs/CHECKLIST.md`.
- Same for `dist/baseline/perf/` (Performance Overlay screenshots) — skipped, mark complete or remove.

### 7.3 — Stale `.v18-backup` files ⏳
- Phase 4.1 leaves `.v18-backup` next to the active DB on a fresh upgrade. After a few launches it should auto-clean. Verify the cleanup path in `DatabaseHelper._cleanV18BackupAfterMigrationSuccess` actually runs on stage A.2's first launch.

### 7.4 — `pubspec.lock` upgrade ⏳
- After Stage C lands `sqflite_sqlcipher`, run `flutter pub upgrade --major-versions` once and audit the diff. Don't auto-accept — some transitive bumps will break things. **Session-3 note:** `cryptography ^2.7.0` was added cleanly; no transitive surprises in that one.

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
| R7 | Wall-clock flakes | Medium | Low | ✅ Stage D.9 Clock injection landed (session 3). Future test failures: prefer `FakeClock` over wall-clock waits. |
| R8 | PIN secure-storage migration locks user out | Low | Medium | Stage A.3 device test before any further work; revert plan in place |
| R9 | Removing `google_fonts` breaks something | Very Low | Low | `test/lint/no_forbidden_patterns_test.dart` enforces it (already in place) |
| R10 | Vercel deploy step fails | Low | Low | `vercel --prod --yes` is the documented workaround in `CLAUDE.md` |
| R11 | SQLCipher migration corrupts on a partially-encrypted file | Low | High | C.3 step 6 verifies row counts before destroying plaintext |
| R12 | Backup encryption passphrase forgotten | Medium | High (user-side) | UX wording in C.2 makes this explicit; backup-restore screen warns up front. **Crypto layer ready (session 3); UX wiring landed (session 4) with min-6-char passphrase + "we cannot recover this file" copy on both Save and Share.** |
| **R13** (new) | **`PinSecurityHelper.isPinEnabled()` aborts publish pipelines in tests** | — | — | Tests using `home_widget_helper` or anything else that consults `PinSecurityHelper` must seed `SharedPreferences.setMockInitialValues(<String, Object>{})` in `setUp`. See the fix landed in `test/integration/home_widget_helper_test.dart` (commit `6c56fe2`). |

---

## 9. Definition of Done for `v5.0.0+1`

All of the following must be true before tagging:

1. **Every checklist item in `docs/CHECKLIST.md` ticked** (except explicit deferrals — currently 3.8, 7.1/2/6/8).
2. **`bash scripts/preflight.sh` green** on `release/v5.0.0` (test-count gate ≥ 1750, ratchet after Stage B).
3. **APK builds clean** (`flutter build apk --release` exits 0, size ≤ 70 MB).
4. **Device smoke test passes** end-to-end (see `MASTER_PLAN.md` §8.3 — 5-minute manual run).
5. **`pubspec.yaml` version is `5.0.0+1`.**
6. **CHANGELOG.md** has a v5.0.0 entry.
7. **`v5.0.0+1` tag exists** on `origin/release/v5.0.0`.
8. **Landing page serves the APK** at `https://leo-money-tracker.vercel.app/downloads/money-tracker.apk` with a matching SHA-1.
9. **GitHub release exists** at `Leo-Atienza/Money-Tracker` tagged `v5.0.0+1`.
10. **`release/v5.0.0` merged into `main`** (fast-forward or PR). **Session 3 already did this for the current SHA; redo at ship time.**

---

## 10. Effort + sequencing summary (updated post-session-3)

| Stage | Tasks | Effort remaining | Device required? | Parallelizable? |
|---|---|---|---|---|
| A — De-risk | A.2–A.6 (A.1 ✅) | 45 min – 1 hour | **Yes** | No — gate for everything else |
| B — Phase 5 design | B.0–B.9, B.11, B.12 (B.10 ✅) | 5–8 days | Yes (visual check per screen) | Internally sequential; B.11/B.12 strict last |
| C — Phase 6 security | C.3 (≈ 1.5 d) only | 1.5 days | Yes | C.2 UX landed session 4; C.3 sequential after Stage B |
| D — Phase 7 tests | D.1 (skip), D.2 (≈ 1d), D.6 (≈ 1d), D.8 (≈ 1d) | 1.5–3 days | No (except D.6 widget tests) | D.6 + D.8 blocked on B; D.2 fully parallel |
| E — Ship | E.1–E.6 | 1 day | Yes (final smoke) | Strict last |

**Realistic total wall-clock remaining with one developer + agent pair:** 9–15 days from `789c59c` to a live `v5.0.0+1`.

**Faster path** (multiple parallel agent windows, hands-on developer for device checks): 5–8 days.

---

## 11. Where each session-3 piece lives (file map for the next agent)

| Concern | Path | Notes |
|---|---|---|
| Brand strings audit | `lib/`, `test/utils/crash_log_test.dart` | `grep -rn "Money Tracker" lib/` = 0 |
| Orphan native code | `TRASH/MainActivity.kt.orphan` | Only `com/moneytracker/app/MainActivity.kt` is live |
| Backup crypto | `lib/utils/backup_crypto.dart` | v4 envelope; 15 tests in `test/utils/backup_crypto_test.dart` |
| Backup helper wrap/unwrap | `lib/utils/backup_helper.dart` (`wrapBackupIfNeeded`, `unwrapBackupIfNeeded`, `PassphraseRequest` typedef) | Helper-layer pair-up with the crypto module; 11 tests in `test/integration/backup_restore_v4_test.dart` |
| Backup screen passphrase prompts | `lib/screens/backup_restore_screen.dart` (`_promptForBackupPassphrase`, `_requestRestorePassphrase`) | Confirmation + retry dialogs; min-6-char validation; "we cannot recover this file" copy |
| Widget payload + redactor | `lib/utils/widget_payload.dart` | Pure functions; 6 tests in `test/utils/widget_payload_test.dart` |
| Widget wiring | `lib/utils/home_widget_helper.dart:90-108` | Calls `PinSecurityHelper.isPinEnabled()` before publishing |
| Clock abstraction | `lib/utils/clock.dart` | `Clock` (real) + `FakeClock.fixed` + `FakeClock.sequence` |
| Clock call sites | `lib/utils/validators.dart`, `lib/utils/notification_helper.dart`, `lib/utils/home_widget_helper.dart`, `lib/utils/pin_security_helper.dart`, `lib/providers/app_state.dart` | UI/export files intentionally left on `DateTime.now()` |
| PIN lockout coverage | `test/utils/pin_lockout_test.dart` | 5 tests; uses `FakeClock` |
| Cascade-delete coverage | `test/integration/cascade_delete_test.dart` | 5 tests; uses `makeFreshDb()` from `_test_helpers.dart` |
| Onboarding coverage | `test/services/onboarding_service_test.dart` | 8 tests; supersedes `services_test.dart` compile-checks |
| CI test-count gate | `scripts/preflight.sh` + `.ps1` | Hardcoded `$TEST_COUNT_MIN=1750`; bump per release |
| `cryptography` dep | `pubspec.yaml:48-50` | `^2.7.0` |

---

## 12. First commands the next session should run

```bash
# 1. Land in the repo and confirm sync.
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
git fetch --all
git status                           # should be clean
git log --oneline -5                 # last commit is 789c59c

# 2. Verify the safety net before doing anything risky.
bash scripts/preflight.sh            # green at gate >= 1750

# 3. Read the orientation docs in order.
cat SESSION_HANDOFF.md
cat docs/CHECKLIST.md
cat docs/NEXT_STEPS.md               # this file
```

If Stage A is feasible this session (device available), start there. Otherwise pick from the mechanical-only remainder (D.2 AppState mutator tests, B.11 Spacing audit if you have a plan for the 756 call sites, or 7.2/7.3 cross-cutting cleanups).

---

**End of plan. Updates to this file should land in the same commit as the work they describe.**
