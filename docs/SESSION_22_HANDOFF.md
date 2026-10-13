# Session 22 handoff — complete record (2026-10-12)

Written so a fresh session can re-check everything. Every claim below names the commit, file,
test or command that proves it. Session 21's record is `docs/SESSION_21_HANDOFF.md`; every audit
finding with its commit is in `docs/AUDIT_FINDINGS_2026-10.md`.

## State at the end of the session

| What | Where it stands |
|------|-----------------|
| **v5.4.0+15** | **Released.** PR #16 squash-merged → `main` `61ecc0c`; annotated tag `v5.4.0` → `61ecc0c` (tag only, like 5.2.0–5.3.1; GitHub "releases" stop at v5.1.2). |
| Live APK | https://leo-money-tracker.vercel.app/downloads/money-tracker.apk — SHA-1 `e7714931dffb242a646346d44def84fd0d5323c0`, 59,703,395 B, versionName 5.4.0 / versionCode 15, ABIs arm64-v8a + armeabi-v7a. Landing repo commit `eb2e362`, deployed with a manual `vercel --prod --yes`. |
| **PR #17** (`fix/low-audit-leftovers`) | **Open, CI green on `2eba62e`, NOT merged** — left for review. Code `8d8898f`, audit doc `2eba62e`, plus this handoff. Not a release. |
| Tests | `main`: 2708 pass / 0 skip. PR #17 branch: **2713 pass / 0 skip** (ratchet 2713). |
| Audit | The October Open table is down to June L60/L61 (optional test-only helper cleanup, no defect). |

## What Leo asked

1. **Resume prompt (start):** merge the three helper branches one at a time (review each diff,
   preflight + ratchet after each, remove the worktrees); work the audit's Open table in waves of
   about 5, asking about the "Clear All Data" wording and the PIN fail-open decision; Purple "like
   the light/dark modes" (option board first, contrast-gated); device-verify S21's "Not
   verified" list, the merged fixes and Purple; open the PR; ask before releasing 5.4.0+15.
2. **Mid-session:** "use what we have in the global claude folder like the app-dev system … only
   what is necessary and applies" → the tactile skill (option-board protocol, craft flow,
   `app-preflight.mjs`), `shot.mjs`, the `mobile` MCP, the cook-log.
3. **End:** answers to the last three questions (below); then "Do this task here: Clear
   Money-Tracker's Low audit leftovers" (→ PR #17); then this handoff and `/done`.

## Leo's decisions (all through the question prompts)

| Question | Answer |
|----------|--------|
| Purple look | **1b Violet hero** |
| Purple dark | **Follows the phone** — one Purple choice: lavender by day, violet at night |
| "Clear All Data" | **Keep the wipe, shorter text** — `Deletes everything in "<account>" and switches it to <code>. This can't be undone.` |
| PIN when secure storage can't be read | **Fail closed** |
| Home "Recent Transactions" | **Include income** |
| Status SnackBars (light text on green/red, 3.6–4.4:1) | **Plain M3 SnackBars** (drop the fills) |
| Release 5.4.0+15 | **After those fixes** (CI green → squash merge → ship) |

## What was done, in order, and how

Everything up to the release happened on `fix/session-21-widget-and-hardening` (S21's branch);
the leftovers on `fix/low-audit-leftovers`. PR #16's commit list
(`gh pr view 16 --json commits`) is the authoritative history; the squash put it on `main` as one
commit, `61ecc0c`.

### 1. Helper branches merged one at a time
| Commit | Branch | How it was checked |
|--------|--------|--------------------|
| `6429b40` | storage (`f32d9cd`, `e348214`): the SQLCipher key is never replaced or orphaned (`resetOnError: false`); plaintext DB copies reaped | diff reviewed; preflight + ratchet |
| `6f1bb5a` | screens (`705b760`): Wallet switch, Settings reset/delete/Clear All Data, restore confirmation, recurring amount commas, category delete/rename | diff reviewed; preflight + ratchet |
| `df419b3` + `742303a` | history/export (4 `wip:` commits + the uncommitted History work): search tokenizer, CSV numbers, export ranges, PDF font, History all-time/date-range filters, refresh after writes | finished in `742303a`; its `linux/`/`windows/` registrant changes **not** taken; preflight + ratchet 2610 → 2637 |

Worktrees moved to `/c/tmp/trash` (never `rm`). `3a9ebca` fixed a failed database open raising an
unhandled async error (found while merging; its regression test was shown to fail first).

### 2. Purple (`6e80da9`)
- **Option board** (tactile `mobile-option-boards.md`): app + home-screen widget, light and dark,
  rendered headlessly with `shot.mjs`; contrast computed per pair on the board (the 1b dark widget
  arrow measured 2.85:1, so the dark `primaryContainer` became `#3B2E7A` before any Dart).
- **Build:** `luminousPurpleDarkScheme()` (surface `#131118`, primary `#CDBEFF`, primaryContainer
  `#3B2E7A`, onPrimaryContainer `#E8DEFF`); `themeModeFor` maps purple → system so the phone picks
  the day or night sibling; the `LuminousHeroColors` ThemeExtension (`.plain` / `.tonal`) paints
  the balance card violet; `buildLuminousTheme(tonal:)`.
- **Widget:** `BudgetWidgetProvider.kt` `paint(full, purple)` sets **both** palettes on every
  update (launchers re-apply RemoteViews onto views they already inflated, so "only what changed"
  left the widget purple after switching to Light); night-aware purple colours in
  `values(-night)/widget_colors.xml`; purple drawables.
- **Gates:** `test/theme/luminous_theme_test.dart`, `home_screen_test.dart` (Purple hero),
  `home_widget_helper_test.dart`; on the device: both themes, both widget sizes, the day/night
  flip with the app closed, Light ⇄ Purple.

### 3. Audit waves (each: fixes → targeted tests → full preflight → debug build → commit → push)
| Wave | Commit | What changed (each commit message lists the tests that fail without it) |
|------|--------|---------------------------------------------|
| 1 | `ec0cfd3` | PIN fails closed (`PinStorageUnavailableException`); one atomic record `pbkdf2_sha256$iters$salt$key$len`; lockout on `SystemClock.elapsedRealtime`; `checkPinStrength` enforced; unlock waits for the real length; Settings and verify dialogs show storage errors |
| 2 | `75ee319` | Settings backed up/restored (`SettingsHelper.exportForBackup` / `restoreFromBackup`); schema **v20** (UNIQUE budget per account/category/month, merged on rename); one 13-digit ceiling `DecimalHelper.maxSafeValue`; `tz.local` from the phone's zone over the `device_info` channel; v19 orphan rows deleted before rebuilds |
| 3 | `e91e0c2` | 360dp at 1.3× text (Home, History, Analytics, Budgets, PIN pads via `FillOrScroll`, dialog titles); sheets padded by the nav-bar inset; TalkBack (segments read once, Amount label, 48dp budget controls). `compact_large_text_test.dart` uses the real Hanken font; 6/6 failed on the previous commit |
| 4 | `ef18848` | `ProgressIndicatorHelper.show` returns a route-scoped closer (no blind pops) in History, Wallet, Backup export/share and Settings; Share's fake 3-minute timeout removed; budget alerts measure this month; Home empty state; onboarding sample-data double tap; income-category rename reloads recurring incomes |
| 5 | `a126510` | "1,500" types as 1500 (a lone comma stays as typed until resolved); `formatWithSymbol` puts the sign first (`-$1,234`); Add payment fits seven-figure amounts; "Pay from Income" → "Stay within income" (it only guards) |
| 6 | `cd71eb1` | Dead export code + `PremiumAnimations`/`pushPremium` deleted (grepped first); 9 tests that exercised a *copy* of the deleted code removed; boot receiver `exported="false"`; History tabs scale down; 3 skipped crud tests restored |
| 7 | `c86af48` | Category dialog errors under the field (were a SnackBar behind the scrim); form dialogs scroll above the keyboard (the 22px overflow reproduced in a test with the emulator's real insets); the currency warning's example uses the real pair; icon buttons labelled; widget `previewImage`; June M4 (crash log drops SQL `args`) and L36 (a version-0 `.db` is refused). Lint tests: icon buttons need `tooltip:`, form dialogs must scroll |
| 8 | `c846580` | Recent Transactions includes income (`_newestFirst`, `_GlassHomeIncomeTile`); all 52 SnackBar status fills removed (lint test); pubspec 5.4.0+15; the onboarding test waits on a real-time deadline |
| Low | `8d8898f` (PR #17) | History chips are one TalkBack node each; `AnimatedCounter(locale:)` so EUR counters read like their labels; Upcoming bills keep cents; dead `advanced_filter_dialog.dart` removed |

Docs and wiki commits: `063c597` and `f16bd96` (earlier versions of this handoff), `df74040`
(`wiki/log.md`), `2eba62e` (audit doc for PR #17).

### 4. Device walk (Budget_Tracker_Emulator; debug builds; adb + `mobile` MCP)
**Verified:** the 3-minute inactivity lock presents the unlock screen while the app is open; a
bill reminder posted with the app process killed ("💡 Bill Reminder — Reminder test bill ($15.49)
due tomorrow" at 19:52), tap → PIN gate → Recurring Items; Analytics refreshes after a write
($15 → $35, trend $165 → $185); PIN: 1234 refused, a wrong PIN counts down, the right PIN unlocks,
FLAG_SECURE on and off; the Wallet switch lands on Home; Clear All Data (Leo's copy, the wipe, the
progress dialog closes); delete and restore an account; All-time History; a recurring "15,49"
saves as $15.49 and its reminder is re-booked (exact `RTC_WAKEUP`); 360dp/1.3× layouts; widgets
match Home; the boot receiver re-registered both alarms after a reboot (~64 s after boot); the
wave 7–8 and PR #17 changes (inline dialog error above Gboard, "$100 becomes €100", "Options for
Scratch", income in Recent Transactions, the plain SnackBar, single-node chips, "$15.49 due",
"€0,00").

**Not verified on a device** (each has unit or widget coverage): the load-error card; restoring
from a backup file; CSV/PDF share; the onboarding double tap on a fresh install; PIN fail-closed
paths (secure-storage failures can't be induced on the emulator); `previewImage` on a
pre-Android-12 launcher; a budget alert raised while an older month is on screen.

### 5. Release (Leo approved "after these fixes")
1. CI green on PR #16's head (`f16bd96`): "analyze + test + lint sweep" and "release APK builds".
2. `gh pr merge 16 --squash --delete-branch` → `61ecc0c`; `git tag -a v5.4.0 61ecc0c`; pushed.
3. `flutter build apk --release --target-platform android-arm64,android-arm` (fresh mtime
   checked) → `scripts/verify-release-apk.sh` ("release APK verified — safe to publish";
   debug-signed on purpose, see `docs/RELEASE_SIGNING.md`) → `aapt2 dump badging` (5.4.0 / 15).
4. Copied to `expense-tracker-landing/public/downloads/money-tracker.apk`, committed `eb2e362`,
   pushed (Leo's untracked `.mcp.json` and `raw/` left alone), `vercel --prod --yes`.
5. Downloaded the live URL: HTTP 200, the same size and the same SHA-1 as the build.

### 6. Records kept outside the repo
- Project memory `~/.claude/projects/C--Users-leooa-Documents-personal-projects-Money-Tracker/memory/`:
  `MEMORY.md` (current state), `topics/emulator-capture-gotchas.md` (adb choreography, insets),
  `topics/purple-theme.md`, `topics/home-widget.md`.
- Vault: `~/Documents/Wiki/wiki/app-dev/cook-log.md` row for the Purple craft and the walk.

## How to double-check (in a new session)

```bash
cd C:/Users/leooa/Documents/personal-projects/Money-Tracker
git fetch --tags && git log --oneline -3 origin/main          # 61ecc0c on top
git rev-parse 'v5.4.0^{commit}'                                # 61ecc0c…
gh pr view 16 --json commits --jq '.commits[].oid'             # the 29 commits squashed into 61ecc0c
gh pr view 17                                                  # open; review, then squash if happy
git switch fix/low-audit-leftovers && bash scripts/preflight.sh 2>&1 | tail -5   # "preflight green", 2713
curl -sL https://leo-money-tracker.vercel.app/downloads/money-tracker.apk | sha1sum   # e7714931…
```
- **Per-wave proof:** each commit message names the tests that fail on the commit before it;
  re-run one by checking out the parent and running that test file.
- **Lint guards** live in `test/lint/`: icon tooltips, scrollable form dialogs, no SnackBar
  fills, no global `context.watch<AppState>`, forbidden patterns, registered routes.
- **Device spot checks:** install a debug build (`flutter build apk --debug`, then
  `adb install -r build/app/outputs/flutter-apk/app-debug.apk`); release APKs are arm-only and
  won't install on the x86_64 emulator.

## Still open
- **PR #17** — review and squash-merge (CI green on `2eba62e`; this handoff adds a docs commit,
  so CI runs once more).
- June L60/L61 — optional removal of test-only helpers (no defect).
- AGP 9 / Gradle 9.3.1 / Kotlin 2.4 upgrade on its own branch (Flutter warns the 8.x toolchain
  will be dropped).
- Worth knowing: AppState's filter setters (`setFilterCategory` …) have no UI now that the dialog
  is gone; `getUpcomingBillsThisMonth()` builds a new list for every `select`, so the bills banner
  rebuilds on each notify (harmless, not changed).

## Emulator state (Budget_Tracker_Emulator)
Purple theme, system light mode, PIN **disabled**, font scale 1.0, density 420, the debug build of
`8d8898f` installed. Main Account: "Reminder test bill" (Bills, day 13, $15.49), reminder time
7:52 PM, $20 + $5 Food expenses and a $120 Salary income on Oct 12. A second account "Scratch"
(EUR, empty). Two widgets on the home screen. The old package `com.example.budget_tracker` is
also installed.

## Gotchas met this session (also in memory)
- The `crun` digest misreported failures twice — grep the full log for `preflight green` and `[E]`.
- Bash heredocs halve backslashes — write anything with `\` through the Write/Edit tools.
- Emulator: `input keyevent 111` (ESC) and BACK dismiss Flutter dialogs; taps right after a
  navigation land on the old screen; Gboard returns after a reboot; `am kill` (not `force-stop`)
  keeps alarms; BOOT_COMPLETED reaches the app ~60 s after boot.
- `gh run list` is the truth for CI; the app's PR cache lagged by a run twice.
