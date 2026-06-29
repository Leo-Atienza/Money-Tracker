# Changelog

> Note: Earlier commits in this release cycle referenced an incorrect `4.1.0+5`
> version string. That number was numerically behind the public `v4.3.0` release
> (L100 Quality Upgrade) and was never shipped. The actual public release of
> this bug-fix + crash-log pass is `4.4.0+6`.

## 5.1.0+9 — 2026-06-29

At-rest database encryption (Phase 6.1). Your financial data is now stored
encrypted on disk, and existing data migrates automatically and safely on the
first launch after updating.

### Added
- **At-rest encryption (SQLCipher / AES-256).** The local database is now
  encrypted on disk. A 256-bit key is generated once and stored in the Android
  Keystore (hardware-backed where available); it never leaves the device and is
  independent of your PIN. This layers on top of the existing Keystore-backed
  PIN, AES-GCM encrypted backups, and screenshot blocking (`FLAG_SECURE`).
- **Automatic, fail-safe migration.** On the first launch after updating, an
  existing plaintext database is migrated to encrypted in place. The original is
  replaced only after the encrypted copy is written, re-opened with the key, and
  verified to hold every row — and a plaintext recovery copy is kept. If
  anything fails, your data is left untouched and the migration retries on the
  next launch, so updating can never lose data.

### Changed
- **Backups stay portable.** A `.etbackup` created from an encrypted database
  now embeds a decrypted copy of the data, so it still restores on a fresh
  install or a different device (optionally still wrapped in a passphrase
  envelope for transport).

## 5.0.1+8 — 2026-06-28

A correctness + robustness patch on top of the Luminous release. No new
features; this hardens money math, fixes two real bugs found by a large new
test pass, and polishes accessibility.

### Fixed
- **Search no longer errors on a match.** Unified search (the History search
  box) threw internally whenever it actually found a matching transaction, so
  results could fail to appear; it now returns expenses and income correctly.
- **Resetting or deleting the account you're viewing no longer hangs or shows
  stale data.** Resetting the current account could deadlock (the app would
  hang); deleting the current account left the old account's transactions on
  screen until a refresh. Both now switch to your default account and reload
  its data immediately.
- **CSV export totals match the in-app figures to the cent.** The export
  summary rows (Total Amount/Paid/Remaining, By Category, Net Balance) now fold
  in exact decimal arithmetic instead of drifting on large datasets.
- **Safer backup/restore:** a truncated or corrupt backup now reports a clear
  "invalid file" instead of a generic error; the restore rollback can no longer
  abort before restoring your data; a malformed month in a hand-edited backup
  is skipped instead of creating an invisible budget row; and the pre-v19
  migration safety copy now flushes the write-ahead log first so it's complete.

### Accessibility
- The Backup & Restore close / bulk-delete / per-row delete buttons now have
  tooltips and screen-reader labels (an unlabeled data-loss control before).
- Expense/Income/period segmented controls now meet the 48dp minimum touch
  target while keeping their compact look.

### Changed
- Dark-mode polish: the home avatar ring and summary inset tiles no longer wash
  out as bright patches over the dark glass; the Analytics loading card now
  matches the frosted glass of the loaded state; payment-method chips derive
  their colors from the theme so they shift between light and dark.

### Internal
- **+453 integration tests** closing the database and app-state per-function
  coverage gaps (2,099 → 2,552 total), authored via a self-verifying multi-agent
  workflow and integrated as full-suite-verified batches. Dates are now driven
  through an injectable clock for deterministic testing.
- Phase 6.1 (SQLCipher at-rest encryption) and the hero-screen golden tests
  remain deferred with written rationale (see docs/) — the app already ships
  PBKDF2 PIN hashing, encrypted backups, and FLAG_SECURE.

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
