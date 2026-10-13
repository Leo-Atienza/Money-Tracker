# Audit findings — 2026-10 (Session 21)

Five parallel reviewers read every file under `lib/` plus the Android host
(data layer · state + shell · main screens · secondary screens · utils/security/native).
About 70 findings; the ones confirmed by 2–3 reviewers independently are marked ★.
Line numbers are approximate (pre-fix). Severity: C critical · H high · M medium · L low.

Status key: **FIXED** (commit on `fix/session-21-widget-and-hardening`) ·
**OPEN**. Session 22 merged the three helper branches and worked the Open
table; what is still open is at the end.

## Fixed on the session branch

| # | Sev | Finding | Commit |
|---|-----|---------|--------|
| 1 | C | Home-screen widget showed "Can't load widget": plain `<View>` divider in `budget_widget.xml` (RemoteViews refuse it). Rebuilt widget: full + compact layouts, day/night, quick add, PIN redaction, next-month rollover, Home-matching numbers | 967eb02 |
| 2 | H | Add screen: empty band under CATEGORY (GridView inherited status-bar padding); names truncated by 4-column grid; amount focus outline through the "$" | 967eb02 |
| 3 | M | Flutter 3.38+: SnackBars with an action never auto-dismiss — sat over the Save button (5 sites) | 967eb02 |
| 4 | C★ | Recurring bills skipped/late months: `lastCreated` stored the run day; weekly drifted to open day; end date / max occurrences ignored; only current account processed | 41b0249 |
| 5 | C★ | `restoreDeletedAccount` deadlocked (switchAccount inside the non-reentrant write mutex) | 41b0249 |
| 6 | H | Every resume switched back to the default account (next expense saved to the wrong account) | 41b0249 |
| 7 | H | Undo after deleting an income restored the newest deleted *expense* | 41b0249 |
| 8 | H | `addPayment` wrote back a stale row (History all-time/search) — earlier payments erased | 41b0249 |
| 9 | H | `Expense.paymentProgress` threw for ratios like 1/3 (History tile, Add Payment dialog) | 41b0249 |
| 10 | H★ | Viewed month went empty after any write or resume (reload kept only this month + last) | 41b0249 |
| 11 | H★ | Overall monthly budget erased by carry-over refresh on a cache miss (12-row cache) | 41b0249 |
| 12 | M | Deleted budgets resurrected by the month rollover on every resume | 41b0249 |
| 13 | M | Restored account lost its default categories | 41b0249 |
| 14 | L | `readAllBudgets` silently capped at 100 rows; expense-category rename retargeted income templates | 41b0249 |
| 15 | M★ | Bill reminders / "Upcoming bills" read a weekly bill's weekday as a day of month; day-1 bills repeated on the 28th–31st; today's reminder skipped; ended bills kept reminding | 41b0249 |
| 16 | H★ | Bill-reminder tap opened the bills screen above the PIN screen | 41b0249 |
| 17 | M★ | 3-minute inactivity lock never presented the unlock screen; enabling a PIN mid-session left the app "locked" with no gate | 41b0249 |
| 18 | M | Analytics 6-month trend never reloaded after edits / month / account change | ee29cd5 |
| 19 | L | Home quick-add chips: double tap saved twice, no error handling, no undo, cents rounded off | ee29cd5 |
| 20 | L | Reminder tap that launches a killed app was never routed (`getNotificationAppLaunchDetails`) | ee29cd5 |
| 21 | L | Carry-over/widget stale after recurring back-fill and category bulk delete | ee29cd5 |
| 22 | M | Load failure showed an empty ledger (risk: user reinstalls → real data loss). Home now shows "Couldn't open your data · Try again" | ee29cd5 |

## Fixed on helper branches — merged in Session 22

Merged one at a time, each diff reviewed, preflight green after each:
storage `6429b40`, screens `6f1bb5a`, history/export `df419b3` + `742303a`
(the History work the helper left unfinished was completed in `742303a`).

**`worktree-agent-ac4edf18281616931`** (storage; e348214 + f32d9cd; its suite 2547/3)
- C★ Keystore `resetOnError: true` default: one failed read deleted the SQLCipher key, a new key was minted → DB permanently unreadable. Now `resetOnError: false`, strict key read, never mint a key when the DB file is already encrypted, never open an encrypted file as plaintext (on Android that path **deleted** the file).
- H★ `.pre-sqlcipher-backup` (full plaintext DB copy) never deleted → swept after a verified encrypted open; failed/stale `ff-backup-plaintext-*` exports cleaned.
- M Orphan sweep could delete a just-deleted account's backup JSON (no age guard) → 1-hour guard.
- e348214 fixes raw NUL bytes in two comments that made git treat `db_open.dart` + its test as binary.

**`worktree-agent-a326ac42cc71b2cad`** (screens; 705b760; its suite 2550/3)
- C Wallet account switch popped the root route → blank app. H delete-account / history-style progress dialogs stuck forever. M "Recently deleted" never refreshed; dialog claimed "permanently deleted".
- H Settings Reset / Delete Account / "Clear All Data" never ran (unmounted sheet context). **Behaviour change: "Clear All Data" now really calls `resetAccount` — confirm the copy is explicit before shipping.**
- H "Choose Backup File" restored with no confirmation. M restore timeout covered picker/passphrase time and popped the wrong route.
- M recurring amount fields dropped commas ("15,49" → 1549/mo) and showed $15.99 as $16. M unused category couldn't be deleted; rename allowed duplicates.
- L padding bands (wallet, category lists, recurring, templates); wallet TalkBack actions; double-tap guards; trash 48dp targets; inverted arrows; Flutter 3.47 ListTile-in-coloured-container debug errors.

**`worktree-agent-acfbb996064be719c`** (history/export; STOPPED mid-work — 4 `wip:` commits + uncommitted `history_screen.dart` and its test; ignore its `linux/` + `windows/` generated-registrant changes)
- Done in WIP commits (unreviewed): search tokenizer (`'` `%` `_`), "time ago" on date-only values, CSV numbers without grouping + temp dir, PDF fallback font + title from the real range, export UTC month ranges, delete CSV after share.
- Finished in `742303a`: History all-time & date-range filters, stale all-time tiles refresh, "Edit Details" transparent sheet → full page, stuck delete progress dialog, swipe not resetting filters, permanent skeleton after cancel. Subtitle overflow at 360dp: `e91e0c2`.

## Fixed in Session 22 (the former Open table)

| Sev | Area | Finding | Commit |
|-----|------|---------|--------|
| H | export | CSV rows split on amounts ≥1,000 (unquoted thousands separators) | 20274ad (merged in 742303a) |
| M | data | ±999,999,999.99 clamp on aggregates — wrong for IDR, VND, KRW. One 13-digit ceiling (`DecimalHelper.maxSafeValue`) everywhere | 75ee319 |
| M | data | Category reassign/rename could duplicate budgets. Schema v20: UNIQUE (account, category, month), duplicates merged | 75ee319 |
| M | reminders | `tz.local` stayed UTC (DST drift). Set from the phone's zone over the `device_info` channel; no new dependency | 75ee319 |
| M | backup | Settings never backed up/restored; a malformed setting rolled back a valid restore | 75ee319 |
| M | security | PIN fails **closed** (Leo's call); one atomic record; monotonic lockout clock; weak PINs refused; unlock waits for the real length | ec0cfd3 |
| M | UI | Overflows at 1.3× on 360dp (Home, History, Analytics, Budgets, PIN pads, dialog titles; Add payment with seven-figure amounts) | e91e0c2, a126510 |
| M | UI | Sheets ignored the nav-bar inset | e91e0c2 |
| L | backup | Progress dialogs closed by a blind pop (now route-scoped app-wide); Share's 3-min "timeout" threw uncaught | ef18848 |
| L | a11y | Segments read twice; Add amount unlabeled; 24dp unlabeled budget controls | e91e0c2 |
| L | data | "No transactions this month" with income only → "No expenses this month"; `$-1,234` → `-$1,234` (every `formatWithCurrency`) | ef18848, a126510 |
| L | misc | Budget alerts measured the month on screen; income-category rename kept old names on recurring incomes; sample-data double tap; "Pay from Income" relabelled "Stay within income" (it only guards) | ef18848, a126510 |
| L | dead code | `BackupHelper.exportBackup/exportCsv/_escapeCsvField`, `PremiumAnimations`, `pushPremium` deleted; boot receiver `exported="false"`. The `device_info` channel is live again (time zone) | cd71eb1 |
| L | input | Typing "1,500" gave "1.50" ("1,500,000" gave "150.00") | a126510 |
| L | upgrade | v19 migration could fail on orphaned rows from pre-2026-03 builds | 75ee319 |
| L | widget | No `previewImage` for pre-Android-12 launchers (they showed the app icon) | c86af48 |
| — | old audit | June M4: crash log echoed SQL bound values (`args [...]`); L36: a version-0 `.db` (not written by the app) restored over the ledger | c86af48 |
| L | data | Home "Recent Transactions" listed expenses only (income never showed). Leo: include income | c846580 |
| L | contrast | 52 SnackBars put light text on incomeGreen/expenseRed fills (3.6–4.4:1, under 4.5:1). Leo: plain M3 SnackBars; a lint test keeps fills out | c846580 |

Found and fixed along the way: a failed database open raised an unhandled
async error (3a9ebca); History's "Expenses" tab faded out at 1.3× (cd71eb1);
three skipped crud tests run again (cd71eb1). From the device walk
(c86af48): the category dialog's errors sat in a SnackBar behind its scrim;
with the keyboard up that dialog overflowed by 22px (it and six other form
dialogs scroll now); the currency warning's example always said "$100
becomes ₹100"; seven icon buttons had no spoken label. Two lint tests keep
icon buttons labelled and form dialogs scrollable.

## Open

| Sev | Area | Finding |
|-----|------|---------|
| L | a11y | History's filter chips (All time, Date range, Sort) each expose two TalkBack nodes: a labelled wrapper and the chip itself (device walk) |
| L | format | For EUR, Home's spoken total says "€0,00" while the screen shows "€0.00" (two formatters); Upcoming bills round to whole units ($15 for a $15.49 bill) while the reminder says $15.49 (device walk) |
| — | old audit | June L60/L61: test-only helpers in AccessibilityHelper / ColorContrastHelper — optional cleanup, no defect |
