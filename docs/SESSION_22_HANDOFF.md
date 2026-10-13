# Session 22 handoff — helper merges, Purple that follows the phone, audit Open table, device walk (2026-10-12)

Picked up from `docs/SESSION_21_HANDOFF.md`. **v5.3.1+14 is still the live release**; nothing
from Sessions 21–22 is released. Everything is on branch `fix/session-21-widget-and-hardening`
(pushed). Findings and their commits: `docs/AUDIT_FINDINGS_2026-10.md`.

## What was asked
1. Merge the three helper branches one at a time, reviewing each diff; preflight and ratchet after each.
2. Work the audit's Open table, highest severity first, in waves of about 5. Ask about the
   "Clear All Data" wording and the PIN fail-open decision.
3. Purple "like the light/dark modes": option board first, then build the pick, contrast-gated.
4. Device-verify everything under S21's "Not verified", the merged fixes and Purple.
5. Open the PR; ask before releasing 5.4.0+15.

## Leo's decisions
- Purple look: **1b Violet hero**. Purple dark: **follows the phone** (one Purple choice:
  lavender by day, violet at night).
- "Clear All Data": **keep the wipe, shorter text** — `Deletes everything in "<account>" and
  switches it to <code>. This can't be undone.`
- PIN when secure storage can't be read: **fail closed**.

## Commits (on `main` `ef80c90` + S21's five)
| Commit | What |
|--------|------|
| `6429b40` | Merge storage: never replace or orphan the SQLCipher key |
| `6f1bb5a` | Merge screens: Wallet, Settings, Backup & Restore, lists |
| `df419b3` `742303a` | Merge history/export; History all-time work finished |
| `3a9ebca` | A failed database open no longer raises an unhandled async error |
| `6e80da9` | Purple follows the phone: violet-night sibling, violet balance card, purple widget |
| `ec0cfd3` | Wave 1 — PIN fails closed, one record, waits for its length, refuses weak PINs |
| `75ee319` | Wave 2 — settings backup, one budget per category per month (schema v20), big-currency totals, DST-safe reminders |
| `e91e0c2` | Wave 3 — 360dp at 1.3× text, sheets clear of the nav bar, TalkBack labels |
| `ef18848` | Wave 4 — route-scoped progress dialogs, this month's budget alerts, honest empty state |
| `a126510` | Wave 5 — "1,500" types as 1500, `-$1,234`, seven-figure payments fit |
| `cd71eb1` | Wave 6 — dead export code, private boot receiver, three un-skipped tests |
| `c86af48` | Wave 7 — category dialog errors inline, scrollable form dialogs, labelled icon buttons, widget preview image, June M4 / L36 |

## Still open — needs Leo
1. **Home "Recent Transactions" shows expenses only** (income never appears there). Include
   income, or rename the section?
2. **Status snackbars** (27 set a green/red fill directly) put light text on green/red fills: 3.6–3.7:1 on green and
   4.4:1 on red in light, 3.8–3.9:1 on red in dark. Plain M3 snackbars (drop the fills), or
   darker fill tokens that keep the colour?
3. Release 5.4.0+15.

## Device walk (Budget_Tracker_Emulator, debug build of `cd71eb1`)
Purple was walked when it was built (both themes, both widget sizes, day and night, the
widget turning over without the app running). This walk covered S21's "Not verified" list,
the merged helper fixes and waves 4–6.

**Verified**
- **3-minute inactivity lock** presents the unlock screen while the app is open. *(S21 open)*
- **Bill reminder from a killed app:** the alarm survived `am kill`; "💡 Bill Reminder —
  Reminder test bill ($15.49) due tomorrow" posted at 19:52 with no process; the tap
  cold-launched to the PIN gate, then Recurring Items after unlocking. *(S21 open)*
- **Analytics refreshes after a write:** a $20 expense moved this month $15 → $35 and the
  6-month trend $165 → $185. *(S21 open)*
- **PIN:** 1234 refused ("Avoid simple sequential patterns."); wrong PIN → "Incorrect PIN.
  4 attempts remaining."; right PIN unlocks in place; FLAG_SECURE on while a PIN is set and
  off once disabled; disabling asks for the PIN.
- **Merged screens fixes:** the Wallet switch lands on Home (no blank app); Clear All Data
  shows Leo's copy, wipes, closes its progress dialog ("Data cleared and currency changed"),
  currency is per account; Delete Account closes its progress and Wallet's Recently deleted
  refreshes by itself; Restore closes its progress and switches to the restored account;
  a recurring amount typed "15,49" saves as $15.49 and editing it re-books the reminder
  (exact `RTC_WAKEUP`); renaming a category onto an existing name is refused.
- **Merged history fix:** All time lists August/September with no search term.
- **Waves 4–6:** "1,500" types as 1500; "No expenses this month"; at 360dp / 1.3× the History
  tabs show whole and the Add payment dialog fits with "Stay within income" and its note.
- **Widgets** follow the theme (neutral after Follow System) and match Home's figures; the
  picker renders the preview.
- **Boot receiver** (`exported="false"`): after a reboot both pending alarms (Nov 1 09:00
  summary, Nov 12 19:52 bill reminder) were re-registered once BOOT_COMPLETED finished
  dispatching (64 s on the emulator).
- **Wave 7 on the device:** the category dialog shows its error under the name field and
  scrolls above Gboard; the currency warning reads "$100 becomes €100"; Settings' account
  options button is announced "Options for Scratch".

**Found on the walk and fixed (wave 7, `c86af48`):** the category dialog's errors appeared in a
SnackBar behind its scrim, so Save looked dead (now under the name field); with Gboard up that
dialog overflowed by 22px (it and six other form dialogs scroll now); the currency-change
warning always said "$100 becomes ₹100" (now the real pair); seven icon buttons had no spoken
label (sheet close buttons, Budgets' year arrows, Settings' account options) and History's
clear-search button sat under a labelled wrapper. Lint tests now guard both rules.

**Not verified on a device:** the load-error card (needs an unreadable DB key); restoring from
a backup file and CSV/PDF share (system pickers); the onboarding double tap (needs a fresh
install); a budget alert raised while an older month is on screen; PIN fail-closed paths
(secure-storage failures can't be induced on the emulator); `previewImage` on a pre-12
launcher (no such emulator). Each has unit or widget coverage.

**Low, left open (documented):** History's filter chips expose two TalkBack nodes each (a
labelled wrapper plus the chip); for EUR, Home's spoken total says "€0,00" while the screen
shows "€0.00" (two formatters); Upcoming bills round to whole units ($15 for a $15.49 bill)
while the reminder says $15.49.

## Gates
Preflight green at every wave; last: **2707 pass / 0 skip**, ratchet 2707 (wave 6 removed nine
tests that exercised a copy of deleted code and restored three skipped ones). Debug build OK
after each wave; the walk ran on the `cd71eb1` build and wave 7 was re-checked on `c86af48`.

## Emulator state
Purple theme, system light mode, PIN **disabled**, font scale 1.0, density 420. Test data on
Main Account: "Reminder test bill" is now Bills, day 13, $15.49; reminder time 7:52 PM; a $20
Food expense today; the $120 Salary income. A second account "Scratch" (EUR, empty) exists.
Two widgets on the home screen. Old package `com.example.budget_tracker` is also installed.

## Release
Not released. Leo's OK is required for 5.4.0+15. Pipeline: Money-Tracker `CLAUDE.md` →
"Shipping the APK" (manual `vercel --prod --yes`; verify the live SHA-1).
