# Session 19 handoff — audit, month-to-month carry-over, device-driven polish (2026-09-03)

**Branch `feat/month-rollover-and-polish`, version bumped to `5.2.0+12`, not yet
released.** Gate at the end of the session: `flutter analyze` clean, preflight green at
**2489 pass / 3 skip** (ratcheted from 2477 in `scripts/preflight.{sh,ps1}`).

## What was asked
Audit the app, fix/upgrade/improve, make it feel premium and frictionless, and add the
feature "whatever money is left, income or expenses, transfers to the next month".

## The feature: Carry Over Balance

The data model already had `monthly_balances.carryover_from_previous`, computed as a
**stored chain** (`net(M-1) + storedCarryover(M-1)`), and it was shown only on the
Budgets screen. The chain had three real defects (details in
`docs/../memory topic carryover-rollover-design`, summarised here):

1. A month the app was never opened in had no stored row, read as zero, and everything
   older silently dropped out of the total.
2. Only "next month of the edit" and the selected month were recomputed after a change,
   and navigation trusted the cache — a back-dated edit left later months stale.
3. `addExpense`/`addIncome` wrote the atomic upsert from **pre-insert** sums, so the value
   persisted next to the new row excluded that row.

Also found on the way: recomputing a month's carry-over rebuilt its `MonthlyBalance`
without `overall_budget`, wiping any overall monthly budget set for that month.

**New design.** `DatabaseHelper.calculateNetBalanceBefore(accountId, monthStart)` sums
every income and expense row dated before the month in one aggregate query;
`AppState._computeCarryoverForMonth` folds that (plus the row about to be inserted, when
called from the atomic add path) into the `MonthlyBalance`, preserving the overall budget.
Navigation and `getCarryoverForMonth` always recompute. Nothing chains, so nothing drifts.

Surfaces: the **Home hero** is now `totalAvailableCash` (income + carried + not-yet-paid
view unchanged) with a line "`+$120.00 carried over from August`" beneath it when non-zero;
**Budgets** shows the carried figure with the sign before the symbol; the **launcher
widget** includes it. **Settings › Preferences › Carry Over Balance** (default on) gates
every derived figure; balances keep computing while off so switching back is instant.

Tests: `test/integration/app_state_carryover_rollover_test.dart` (+ Home and Settings
widget tests). Semantics choice worth remembering: the carry-over uses full expense
amounts (a closed month's unpaid bill is committed), while the current month's own term on
Home still uses *paid* amounts, as before.

## Device-found defects (fixed)

Walked every tab and Settings/Budgets on `Budget_Tracker_Emulator` in light and dark
before touching code. The suite (2477 green) and `flutter analyze` saw none of these:

| # | Screen | Defect | Fix |
|---|---|---|---|
| 1 | Budgets | Carried amount printed **"$-78"** | sign before symbol, abs() formatted |
| 2 | Budgets | Income tile arrow pointed **down** (S18 fixed Home only) | `arrow_upward` |
| 3 | Budgets | "Total Available" tinted red for a positive number | neutral container |
| 4 | Analytics | Donut/legend used an index palette — Groceries blue there, olive everywhere else | category identity colour, palette only as fallback |
| 5 | Analytics | "$3000" unformatted beside "$3,000.00" elsewhere | grouped formatting |
| 6 | Add tab | **Stale back arrow** on the root tab; pressing it switched to Home *and* showed "Discard changes?" on an empty form | see below |
| 7 | Home/Budgets | Header icon buttons announced **twice** by TalkBack (two semantics nodes) | IconButton tooltip only + regression test |
| 8 | Settings | Switch rows: unlabelled switch, section heading leaking into it, only the switch itself tappable | `MergeSemantics` per row + row `onTap` |
| 9 | Home | Transaction divider was raw white (invisible light / bright dark) | outline token |

**#6 root cause** (not a navigation-stack bug): `AddTransactionScreen` decided "was I
pushed?" with `Navigator.canPop(context)` *inside build*. The nav shell's root
`PopScope(canPop: false)` plus any route pushed above the tab (Settings was open when the
theme changed) makes that true while the tab rebuilds underneath, and the tab kept the
arrow. Pressing it fired the shell's go-Home pop **and** the Add screen's discard dialog,
because a vetoed pop invokes every `PopScope` callback on the route. Now
`ModalRoute.of(context)?.isFirst == false` decides, and the tab instance never guards
edits (its state lives on in the `IndexedStack`).

## Code-level fixes (grep sheet, Flutter-adapted tactile AR-T rules)

- White ink on `incomeGreen` / `expenseRed` fills (2.36:1 in dark): Recurring Income save
  button + spinner + selected day chip, Recurring "+" FAB, both swipe-to-delete icons,
  colour-picker check, Add-screen success snackbar icon → `ColorContrastHelper.getContrastingTextColor`.
- `analytics_screen` re-implemented black-or-white text (audit L58) → the helper.
- `Colors.amber` fourth budget tier (twice) → three token tiers (green / warning ≥75% / red ≥95%).
- Raw hex theme-preview swatches in Settings → the real `luminousLight/DarkScheme` values.
- `loading_skeleton` raw greys → surface-container roles.
- **Typography:** the theme defined only 7 text roles; `bodySmall` (36 sites), `labelLarge`
  (12), `titleSmall` (5) fell back to **Roboto**. All roles are now Hanken Grotesk with
  explicit weights, and `ThemeData.fontFamily` is set as a backstop.
- Budgets summary card moved off raw `TextStyle(fontSize:)` onto theme roles.

## Hygiene
- `pubspec.lock` is now committed (CI resolves the same set that passed locally).
- Trashed (indexed in `TRASH-FILES.md`): `firebase.json`, `.firebaserc`,
  `FIREBASE_SETUP.md`, two `.iml`, `dist/baseline/*`, in-repo `landing/`, five
  `flutter_0N.log`; untracked two files committed under the ignored `TRASH/`.
- `jni_flutter` 1.0.2 → 1.0.3 (the only in-range bump; everything else is gated on
  Flutter ≥3.41.6 or the `flutter_secure_storage` v11 data-loss rule — see
  `docs/DEPENDENCY_STATUS.md`).

## Gates that ran
- `scripts/preflight.sh`: green, 2489 / 3 skipped.
- tactile `app-preflight.mjs`: SHIP-READY on completeness — but 24 of its checks SKIP
  on a Flutter project (they are Expo/Tauri-aware), so treat it as the placeholder-copy /
  design-context check only. `check-contrast.mjs` cannot read a Dart theme (exit 2); the
  app's own `ColorContrastHelper` tests and `test/theme/category_palette_test.dart` are
  the contrast gate here.
- AR-T grep sheet (canary passed): 0 raw hex in screen code; the only remaining raw
  Material swatches are the documented analytics fallback palette.

## Still open / for next session
- **Push needs the `workflow` OAuth scope.** `main` carries the unpushed CI-workflow
  commit; `gh auth refresh -h github.com -s workflow` in plain PowerShell, then push.
- **Typography ladder.** History (8 raw sizes), Category Manager (7), Wallet (6) still
  use raw `fontSize:` literals; tactile's three-sizes rule is unmet there.
- **Flutter ≥3.41.6** unblocks `file_picker` 12, `share_plus` 13, `package_info_plus` 10,
  `pdf` 3.13, `sqflite` 2.4.3 at once (own branch; machine-wide SDK change — Leo's call).
- Bill-reminder firing and the secure-storage v9→v10 migration remain unverified on a
  device with real data (unchanged from S18).
