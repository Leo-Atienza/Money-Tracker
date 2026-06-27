# Changelog

> Note: Earlier commits in this release cycle referenced an incorrect `4.1.0+5`
> version string. That number was numerically behind the public `v4.3.0` release
> (L100 Quality Upgrade) and was never shipped. The actual public release of
> this bug-fix + crash-log pass is `4.4.0+6`.

## 5.0.0+7 — 2026-06-27

The Luminous release: a full glass-design refresh plus a security, correctness,
accessibility and performance pass driven by a 62-finding audit.

### Security
- **PIN storage upgraded to PBKDF2-SHA256 (100,000 iterations).** The previous
  single-round SHA-256 hash was trivially brute-forceable offline. Existing PINs
  migrate transparently the next time you unlock — no re-enrolment needed.
- The app now re-locks whenever it returns from the background, not only at cold
  start, so your financial data isn't visible after a quick app switch.

### Fixed
- **Payments record exactly what you paid.** A payment that left a few cents
  remaining is no longer silently rounded up and marked "fully paid".
- **Amounts are grouped by locale everywhere** (e.g. `$2,845.00`), including the
  home balance hero, history, analytics, bills and quick-add chips.
- **Notifications work end to end:** tapping a reminder now opens the right
  screen, the chosen Reminder Time is honored (was always 09:00), toggling a
  reminder schedules or cancels it immediately, and a notification failure can
  no longer abort saving an expense or leave the home screen stale.
- A single corrupt row no longer drops an entire expense/income/recurring list —
  bulk reads skip only the bad row.
- **Data safety:** the v18→v19 database migration can no longer brick the
  database; restoring a raw `.db` from a newer app version is refused up front;
  stale pre-restore safety backups are now cleaned up; and the 30-day purge of
  deleted accounts runs during maintenance instead of when you open the list.

### Accessibility
- Bottom navigation, month chevrons, category actions and the PIN keypad now
  announce their roles and labels; large system font sizes no longer clip; and
  swipe-to-delete in History has an equivalent screen-reader action.

### Performance
- Analytics budget spend is computed in a single pass; the History list is
  virtualized with a capped entry animation; glass panels each get their own
  repaint boundary; and CSV/PDF export now runs off the UI thread.

### Changed
- Full **Luminous** glass redesign across the app (home, history, analytics,
  wallet, settings, budgets and dialogs).
- "Add account" on the Wallet tab moved into the header — it was previously
  hidden behind the floating navigation bar.

### Removed
- Several unreferenced premium-animation widgets and unused progress-indicator
  helpers (dead code).

## 4.4.0+6 — 2026-04-14

### Fixed
- **Critical**: Weekly and biweekly recurring transactions now auto-generate correctly — previously only monthly items were materialized, and weekly/biweekly rows stayed dormant in the database forever.
- **Critical**: Month balance totals now include transactions dated the 1st of the month.
- **Critical**: Backup restore now preserves the original account linkage and budget month for every row. Historical expenses no longer collapse into "today's account, today's month" on restore.
- **High**: Home screen widget no longer reports `0.00` after you browse historical months. Widget totals are now read directly from the database.
- **High**: No more "ChangeNotifier was used after being disposed" exceptions when the app is torn down during a database write.
- **High**: End-of-month bill reminders (days 29–31) now reschedule every month instead of firing once and going silent.
- **High**: The auto-created-recurring counter no longer accumulates across background runs — it now reflects only the most recent processing pass.
- **Medium**: The "Today" label stays consistent with the rest of the UI around midnight (both now use the same date source).
- **Medium**: Restoring a backup that was produced by a newer version of the app now surfaces a clear error instead of silently corrupting data.

### Security
- PIN hash comparison is now constant-time, closing a theoretical timing side channel.

### Added
- Global error handler and a local rolling crash log. Force-close crashes are written to a small set of rotating files in the app's documents directory and are viewable from **Settings → Advanced → Crash Log**, where you can also share or clear them.
- Integration test scaffold (`sqflite_common_ffi`) with end-to-end regression suites for every Fixed item above.

### Removed
- Biometric service stub (dead code — never wired into the lock screen).
- Stale fix-summary docs at the repo root (now captured in commit history).
- `test/logic/recurring_processing_test.dart` shadow copy of the pre-fix recurring algorithm (replaced by the new integration suite that exercises the real dispatcher).
