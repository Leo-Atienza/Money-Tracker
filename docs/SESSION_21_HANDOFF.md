# Session 21 handoff — Home-screen widget, Add screen, full-code audit (2026-10-12)

Picked up from `docs/SESSION_20_HANDOFF.md`; **v5.3.1+14 is still the live release**. Nothing
from this session is released. The work sits on branch `fix/session-21-widget-and-hardening`
(three commits on `main` `ef80c90`), plus three helper branches that are **not merged**.

## What was asked
1. Load context from project memory.
2. Read all of the code for anything to fix or improve.
3. Fix the two Add Transaction screenshots.
4. Make the home-screen widget usable ("Currently, I can't use the home widget").

Goal, in Leo's words: "Complete the app… ready to be used by anyone." At the end of the session
Leo added: **"I want it to have a beautiful purple theme like the light/dark modes"** — this is
the design task for next session; see *Purple* below.

## On the branch (not released)
| Commit | What |
|--------|------|
| `967eb02` | Add screen layout, rebuilt home-screen widget, snackbar timeouts |
| `41b0249` | Recurring schedule, account switching, undo, payments, budgets, reminders, lock gate |
| `ee29cd5` | Analytics trends refresh, quick-add guard, load-error card, launch-tap routing |

Every finding, with its severity and commit: `docs/AUDIT_FINDINGS_2026-10.md` (items 1–22).

### Home-screen widget
**Why it never worked:** `budget_widget.xml` used a plain `<View>` as a divider. RemoteViews
only inflate a fixed list of framework classes, so every launcher showed "Can't load widget".
The widget was rebuilt:
- **Layouts.** `BudgetWidgetProvider.kt` returns size-mapped `RemoteViews(Map<SizeF, RemoteViews>)`
  on API 31+, with `onAppWidgetOptionsChanged` for older launchers. The full layout shows at
  185dp tall and above (`FULL_LAYOUT_MIN_HEIGHT_DP`); the compact one below that.
- **Numbers.** Balance is income + carried-in − paid, the same figure as Home's
  `totalAvailableCash`. Income, expenses and the month name are shown too.
- **Month rollover.** `HomeWidgetHelper.updateWidget` publishes this month and next (`next_`
  prefix), both keyed by `month_key`. The widget therefore turns over on the 1st without the
  app running, and shows `—` when neither key matches.
- **Quick add.** "+ Expense" and "+ Income" open `financeflow://add?type=…` through
  `HomeWidgetLaunchIntent`. `MainActivity` hands the launch over the `budget_tracker/widget_launch`
  channel: Dart pulls it with `takeLaunch` at startup, and Android pushes `launched` from
  `onNewIntent`. This makes a cold start after process death still open Add. The shell waits
  for `lockStateReady`, so with a PIN set it shows the PIN screen first, then Add.
- **Privacy.** With a PIN set, amounts read `•••` (`WidgetData.redactIfLocked`).
- **Deep links.** The manifest sets `flutter_deeplinking_enabled=false`, because Flutter's
  default deep linking would also try to route `financeflow://add`.
- **Appearance.** Day/night colour resources (`values/` and `values-night/widget_colors.xml`),
  the launcher label "Monthly balance", a `previewLayout`, and a 4×2 default size.

Verified on the emulator:
- The preview in the widget picker.
- Values that match Home.
- Quick add when the app is warm, cold, and after process death.
- The PIN gate and amount redaction.
- The month rollover, the compact size, and dark mode.

After `adb shell am force-stop`, a tap does nothing. That is Android behaviour: force-stop
cancels the app's PendingIntents.

### Add Transaction (the screenshots)
- **Empty band under CATEGORY.** The `GridView` inherited the MediaQuery top inset. The picker
  is now a `Wrap` of chips (`lib/widgets/luminous/category_bento_grid.dart`): full names,
  48dp targets, and the selected chip is announced.
- **"$" in the amount field.** The symbol is now a `prefixIcon`, so the focus outline no longer
  cuts through it.
- **SnackBar over Save.** Since Flutter 3.38, a SnackBar with an action stays until dismissed,
  so it covered the Save button. All five sites now pass
  `persist: MediaQuery.accessibleNavigationOf(context)`.
- **Delete → Undo** restores the deleted row: `undoDeleteTransaction(originalId:, isIncome:)`.
  The old `restoreLastDeleted` brought back the newest deleted *expense*.

## Helper branches — NOT merged
These are worktrees under `.claude/worktrees/`, which is gitignored. All three fork from
`967eb02`, so each must be merged with `41b0249` and `ee29cd5` first. Expect conflicts in
`app_state.dart`, `database_helper.dart` and possibly `main.dart`. The suite counts below are
from each branch on its own base, not from a merged tree.

| Branch | Tip | Scope | State |
|--------|-----|-------|-------|
| `worktree-agent-ac4edf18281616931` | `f32d9cd` (+ `e348214`) | Storage: Keystore `resetOnError:false`, never re-key or plaintext-open an encrypted DB, sweep plaintext DB copies, orphan-sweep age guard | Complete; 2547 pass / 3 skip. **Merge first** — it fixes a data-loss bug. `e348214` removes raw NUL bytes that made git treat `db_open.dart` as binary; check that `git diff` shows text afterwards. |
| `worktree-agent-a326ac42cc71b2cad` | `705b760` | Screens: Wallet blank-app pop, stuck dialogs, Settings Reset/Delete/Clear All Data, restore confirmation and timeout, recurring amount parsing, category delete/rename, padding bands, a11y | Complete; 2550 pass / 3 skip. **"Clear All Data" now really wipes the account (`resetAccount`) — confirm the copy with Leo.** |
| `worktree-agent-acfbb996064be719c` | `958803b` + uncommitted | History and export | **Stopped mid-work.** Four `wip:` commits are unreviewed. `history_screen.dart` (+337) and `history_screen_test.dart` (+274) are uncommitted. **Never take its `linux/` or `windows/` generated-registrant changes.** What is done and what is left: audit doc, "Fixed on helper branches". |

Merging these is not finished until the worktrees are removed: `git worktree remove`, then
`git branch -d`, once each branch is merged.

## Not verified
- **On a device:**
  - The 3-minute inactivity lock presenting the unlock screen.
  - A reminder tap that launches a killed app.
  - Analytics refreshing after an edit.
  - Every fix on the helper branches.
- **Load-error card.** Widget-tested only (`test/screens/home_screen_test.dart`). It needs an
  unreadable key to show for real.
- **Skipped restore test.** `test/integration/app_state_crud_test.dart:952` is still skipped
  ("path_provider mock races…"). That skip may have been hiding the restore deadlock fixed in
  `41b0249`; `test/integration/app_state_account_switching_test.dart` covers restore without a
  skip. Try removing it, and keep it only if it still flakes.
- **Test ratchet.** Now `TEST_COUNT_MIN=2561` (`scripts/preflight.sh:65` and
  `scripts/preflight.ps1:41`). Raise it again after each merge; the storage and screens branches
  report +23 and +26 tests, and the history branch adds more.

## Purple — Leo's request for next session
Leo, verbatim: *"include that i want it to have a beautiful purple theme like the light/dark
modes."*

**Today.** Purple (v5.3.0) is a fixed light-brightness appearance: lavender surfaces, one violet
(`#5B44A6`) for chrome, and everything else from the light set. The pieces:
- Scheme: `luminousPurpleScheme()` at `lib/theme/luminous_app_theme.dart:151`.
- Wiring: `lib/main.dart:240-256`.
- Picker: `lib/screens/settings_screen.dart:560`.
- Contrast gate: `test/theme/luminous_theme_test.dart`.
- Design rule: `.tactile.md:44`, "the violet is chrome, not status".

**Gaps against "like the light/dark modes":**
1. The home-screen widget ignores Purple and follows only the system's day/night setting. With
   Purple selected, the widget is neutral grey.
2. There is no dark Purple. Light and Dark are a pair; Purple is light only
   ("Lavender, always light").
3. Purple is deliberately restrained (one violet, chrome only), so "beautiful" may ask for more.

**Ask Leo first.** Before building, show an option board (tactile skill,
`reference/mobile-option-boards.md`, light and dark paired) and ask which reading he means:
- (a) the widget follows Purple;
- (b) Purple gets a dark sibling — a separate Purple Dark, or Purple that follows the system;
- (c) a richer purple palette for the app itself.

The default reading is (a) + (b), with (c) settled on the board.

**Implementation notes:**
- **Widget.** Add `theme_mode` to the `HomeWidgetHelper.updateWidget` payload, and call
  `updateWidget` from `AppState.setThemeMode`. RemoteViews cannot take a theme, so
  `BudgetWidgetProvider.kt` has to colour each view itself:
  - text with `setTextColor`;
  - icons with `setInt(id, "setColorFilter", …)`;
  - the body and the buttons with `setInt(id, "setBackgroundResource", …)` and purple
    drawables, including the ripples.

  Light and Dark keep coming from `values` / `values-night`.
- **Dark Purple.** Hand-build it (no `fromSeed`) and pass it as `darkTheme` when Purple is
  selected. Then change `themeModeFor('purple')` or add a new mode value. Extend the
  `luminous_theme_test` suite to it: every ink role on every surface role at 4.5:1 or better,
  outline at 3:1, and the money colours at 3:1.
- **Records.** After Leo picks, update `.tactile.md` and the `purple-theme` project memory.

## Emulator state
- **Device:** `Budget_Tracker_Emulator`, shut down — needs a cold boot.
- **App:** a debug build of this branch is installed. PIN is disabled; the system is in light
  mode.
- **Widgets:** two on the home screen. The second shows simulated $2,222 figures until the app
  next runs.
- **Test data:** "Reminder test bill" (Bills, day 5, $15; the October instance exists) and a
  $120 test income dated Oct 12.

## Gates (this session)
- `scripts/preflight.sh` on `ee29cd5`: **green** — `flutter analyze` clean,
  **2561 pass / 3 skip** (was 2507 at the end of S20).
- Ratchet raised 2507 → 2561 in `scripts/preflight.sh` and `scripts/preflight.ps1`.

## Release
Not released, and not built for release. Suggested version **5.4.0+15**, since the widget is a
feature. Leo's OK is required before the build/deploy pipeline in `CLAUDE.md` › "Shipping the
APK".
