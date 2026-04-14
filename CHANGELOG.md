# Changelog

> Note: Earlier commits in this release cycle referenced an incorrect `4.1.0+5`
> version string. That number was numerically behind the public `v4.3.0` release
> (L100 Quality Upgrade) and was never shipped. The actual public release of
> this bug-fix + crash-log pass is `4.4.0+6`.

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
