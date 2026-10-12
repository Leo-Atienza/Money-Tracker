# Audit findings — 2026-10 (Session 21)

Five parallel reviewers read every file under `lib/` plus the Android host
(data layer · state + shell · main screens · secondary screens · utils/security/native).
About 70 findings; the ones confirmed by 2–3 reviewers independently are marked ★.
Line numbers are approximate (pre-fix). Severity: C critical · H high · M medium · L low.

Status key: **FIXED** (commit on `fix/session-21-widget-and-hardening`) ·
**AGENT** (fixed on an unmerged helper branch — review before merging) · **OPEN**.

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

## Fixed on helper branches — NOT merged yet (review each diff first)

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
- In progress / not done: History all-time & date-range filters, stale all-time tiles refresh, "Edit Details" transparent sheet → full page, stuck progress dialogs, swipe not resetting filters, permanent skeleton after cancel, subtitle overflow at 360dp.

## Open

| Sev | Area | Finding |
|-----|------|---------|
| H | export | CSV rows split on amounts ≥1,000 (unquoted thousands separators) — in the WIP branch, unreviewed |
| M | data | ±999,999,999.99 clamp applied to aggregates — carry-over wrong for large-number currencies (IDR, VND, KRW) |
| M | data | Reassigning/renaming a category can duplicate budgets (no UNIQUE index; `setBudget` edits `.first`) — needs a migration |
| M | reminders | `tz.local` never set (stays UTC) → repeating reminders drift an hour across DST. Needs `flutter_timezone` (new dep; check AGP/Kotlin compat) |
| M | backup | Settings backup/restore use camelCase keys nothing reads → settings never backed up/restored; malformed settings roll back a valid DB restore |
| M | security | PIN fails OPEN when secure storage can't be read (deliberate per main.dart; decide). PIN hash+salt not written atomically. Lockout uses the wall clock (clock-forward bypass). `checkPinStrength` never called (1111 accepted). Unlock auto-submits at length 4 before the real length loads |
| M | UI | Overflow risks at 1.3× text on 360dp: budget_screen (~723-741, ~1170-1206), analytics (~850-867), add_payment_dialog (~256-300), PIN setup/unlock keypads, dialog_helpers title rows |
| M | UI | Modal sheets ignore the nav-bar inset (month pickers fixed 350dp; budget sheet Save under 3-button nav) |
| L | backup | Export & Share dialogs close by popping whatever is on top; Share's 3-min timeout throws uncaught |
| L | a11y | GlassSegmentedControl reads "Expense Expense" (label + text); Add amount field has no spoken label; budget_screen 24dp unlabeled edit/remove InkWells |
| L | data | Home "Recent Transactions" shows no income (seen on device — confirm intent); Home says "No transactions this month" when only income exists; `$-1,234` formatting in budget_screen |
| L | misc | `_checkBudgetAlerts` compares the selected month's spending with the current month's budget; income-category rename doesn't reload recurring incomes; onboarding "Load Sample Data" double tap duplicates; "Pay from Income" switch only gates validation; snackbar text on incomeGreen/expenseRed fills under 4.5:1 in light mode |
| L | dead code | `BackupHelper.exportBackup/exportCsv/_escapeCsvField`, `PremiumAnimations`, `pushPremium` extensions, `budget_tracker/device_info` channel — verify with grep before deleting; boot receiver `exported="true"` |
| L | input | Typing "1,500" in an amount shows "1.50" (visible, not silent) |
| L | widget | No `previewImage` for pre-Android-12 launchers (they show the app icon) |
| L | upgrade | v19 migration can fail forever on orphaned trash rows from pre-2026-03 builds (plausible) |
| — | old audit | June M4 (crash-log `args [...]` redaction), L36 (raw `.db` restore accepts user_version 0), L60/L61 test-only helpers |
