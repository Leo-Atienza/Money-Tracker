# Session 23 handoff — complete record (2026-10-12 → 13)

Written so a fresh session can re-check everything. Every claim names the commit, file, test or
command that proves it. Session 22's record is `docs/SESSION_22_HANDOFF.md`; the October audit with
every finding's commit is `docs/AUDIT_FINDINGS_2026-10.md`.

Leo's brief for the session: finish the three items S22 left (review and merge PR #17, the optional
June L60/L61 cleanup, the AGP 9 / Gradle 9.3.1 / Kotlin 2.4 move on its own branch), double-check
everything, no questions. Nothing here is a release; **v5.4.0+15 stays live**.

## State at the end of the session

| What | Where it stands |
|------|-----------------|
| Live APK | Unchanged: v5.4.0+15, SHA-1 `e7714931dffb242a646346d44def84fd0d5323c0`, 59,703,395 B. Re-checked at the start of the session against the local build (`sha1sum build/app/outputs/flutter-apk/app-release.apk`). |
| `main` | `211998a` (#19 toolchain) ← `38c4189` (#18 L60/L61) ← `566e9a9` (#17 Low leftovers) ← `61ecc0c` (5.4.0, tag `v5.4.0`). |
| PR #17 | Reviewed and squash-merged → `566e9a9`. |
| PR #18 | June L60/L61 cleanup, squash-merged → `38c4189`. |
| PR #19 | Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0, squash-merged → `211998a`. |
| PR #20 | This handoff plus the changelog backfill (5.4.0+15 had no `CHANGELOG.md` entry; an `Unreleased` section now lists #17–#19). |
| Tests | **2672 pass / 0 skip**; preflight ratchet 2672 (down from 2713 with the deleted test-only helpers, see §2). |
| Audit | The October Open table is empty. |
| Toolchain | Flutter 3.47.2 / Dart 3.13.2; Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0 (`android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`); `android.builtInKotlin=false`, `android.newDsl=false` on purpose (`android/gradle.properties` says why). |

## What was done, in order, and how

### 1. S22 handoff verified, then PR #17 reviewed and merged (`566e9a9`)

Before trusting anything: `bash scripts/preflight.sh` on `fix/low-audit-leftovers` → "No issues
found!", `+2713: All tests passed!`, ratchet 2713, `preflight green`; `git rev-parse 'v5.4.0^{commit}'`
and `origin/main` both `61ecc0c`; the live download's SHA-1 matched the local release build; CI green
on the PR head `6622b62`.

Review of `8d8898f` (the only code commit): the three History chips are plain `FilterChip`s (one
semantics node each, hints became tooltips, `deleteButtonTooltipMessage: 'Clear date range'`);
`AnimatedCounter` takes a `locale` and rebuilds both cached `NumberFormat`s when it or
`decimalPlaces` changes; Home passes `CurrencyHelper.currencyLocales[currencyCode]` and selects
`currencyCode` so same-symbol currencies switch; Upcoming bills format with `_amountDigits`
(0 digits when whole, else 2); `advanced_filter_dialog.dart` had no importer in `lib/` or `test/`.
The new tests exercise exactly those paths; the bill-cents test books its bill on the last day of the
current month, which `getUpcomingBillsThisMonth` includes (due dates are inclusive). Merged with
`gh pr merge 17 --squash --delete-branch`.

### 2. June L60/L61 — PR #18 (`3600f9e` code, `b118630` audit doc; squash `38c4189`)

Grep of `lib/` (static methods have no implicit call sites) before each deletion:

- `AccessibilityHelper` lost `meetsMinimumTouchTarget`, `ensureMinTouchTarget`, `getBudgetStatusIcon`,
  `meetsContrastRequirement`, `getAccessibleTextColor`, `makeFocusable`, `accessibleChip`, `announce`,
  `getPaymentProgressLabel`. Kept with their callers: `minTouchTargetSize`, `semanticIconButton`
  (Home, Budgets), `getBudgetStatusLabel` (Analytics, Budgets), `accessibleProgressIndicator`
  (Analytics). Two of the June doc's "keep" names (`getBudgetStatusIcon`, and `meetsMinimumTouchTarget`
  which it did not list) had no production caller either, so they went too.
- `ColorContrastHelper` lost `meetsAALarge` and `adjustForContrast`. Kept: `contrastRatio` / `meetsAA`
  (the Purple scheme and category palette gates in `test/theme/`), `getContrastingTextColor` (nine
  call sites — the June note that it had none is stale since the luminance code was consolidated
  onto it), `getStatusColors` (`AppColors`).
- 41 tests that only exercised the deleted statics went with them; the ratchet moved 2713 → 2672 in
  both `scripts/preflight.sh` and `scripts/preflight.ps1` with a dated note (the 2026-08-30 entry's
  reasoning: the gate must track real coverage, not pad it).
- Preflight on `3600f9e`: analyze clean, **2672 pass / 0 skip**, sweep clean. CI green on #18.

### 3. AGP 9 toolchain — PR #19 (`fd99b57`; squash `211998a`)

Done in a separate git worktree (`../Money-Tracker-agp`, branch `chore/agp-9`) so the Gradle builds
could run while the L60/L61 preflight ran in the main checkout; the worktree was removed afterwards.

Why these exact versions (every number checked against its source this session):

- Flutter 3.47.2's own template pins Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0
  (`flutter_tools/lib/src/android/gradle_utils.dart`: `templateDefaultGradleVersion`,
  `templateAndroidGradlePluginVersion`, `templateKotlinGradlePluginVersion`).
- Flutter's `DependencyVersionChecker.kt` warns below Gradle 9.1.0 / AGP 9.0.1 / Kotlin 2.3.20 and
  errors below 8.14.0 / 8.11.1 / 2.2.20 — the old set sat exactly on the error floors and printed the
  "will soon be dropped" warning on every build.
- AGP release notes: 9.1 needs Gradle ≥ 9.3.1 and JDK 17; 9.2 → 9.4.1, 9.3 → 9.5.0, 9.4 → 9.6.0.
- Kotlin's Gradle compatibility table: KGP 2.4.0–2.4.10 supports Gradle 7.6.3–9.5.0 and AGP
  8.5.2–9.1.0; 2.4.20 widens that to Gradle 9.7.0 / AGP 9.3.1. AGP 9.1.0 is therefore the newest
  line inside KGP 2.4.0's window, which is why 9.2+ was not taken.
- Built-in Kotlin stays off. `app_settings` 7.0.0 applies `kotlin-android` unconditionally (AGP 9
  refuses that under built-in Kotlin); `android_file_picker` 1.1.0, `home_widget` 0.9.4,
  `package_info_plus` 10.2.1 and `share_plus` 13.3.0 apply it only while built-in Kotlin is off (read
  from their `android/build.gradle*` in the pub cache). Flutter 3.47.2 also still checks its Kotlin
  minimum against AGP's bundled KGP 2.2.10 when built-in Kotlin is on (flutter/flutter#192167, fixed
  on master in September 2026 by PR #192206).

What changed: `settings.gradle.kts` (AGP 9.1.0, KGP 2.4.0), the wrapper (9.3.1),
`app/build.gradle.kts` follows the template — no `id("kotlin-android")` (Flutter's Gradle plugin
applies it while `builtInKotlin=false`, `FlutterPluginUtils.kt` line ~578), `kotlin { compilerOptions {
jvmTarget } }` instead of `android.kotlinOptions` — and `gradle.properties` keeps both flags off with
the reason. `docs/DEPENDENCY_STATUS.md` records the move; its remaining toolchain gate is now
built-in Kotlin.

Gate: `flutter build apk --debug` (380 s on a cold Gradle 9.3.1 cache) and
`flutter build apk --release --target-platform android-arm64,android-arm` both green;
`scripts/verify-release-apk.sh` passed (debug-signed on purpose, arm64-v8a + armeabi-v7a only);
release APK **59,736,459 B**, 33 KB over 5.4.0's. Debug build installed on Budget_Tracker_Emulator
(API 36) over the 5.4.0 data: Home rendered with the existing data (so the SQLCipher key came back
from the Keystore), Settings, both home-screen widgets re-rendered by the new `BudgetWidgetProvider`,
and the widget's Expense quick-add opened Add Transaction with Expense selected. CI's
`release APK builds` job on #19 is the Linux-runner proof.

### 4. Changelog backfill — PR #20

`CHANGELOG.md` stopped at 5.3.1+14; the 5.4.0+15 release had no entry. Added one from PR #16's
description and the S22 record, plus an `Unreleased` section for #17 (chip semantics, currency
counters, bill cents), #18/#17 (dead code) and #19 (toolchain).

## How to double-check (in a new session)

- `git log --oneline -5` on `main` shows the three squashes above in order.
- `bash scripts/preflight.sh` → "No issues found!", `+2672: All tests passed!`, ratchet 2672,
  `preflight green`.
- `flutter build apk --debug` → `√ Built build\app\outputs\flutter-apk\app-debug.apk` with a fresh
  mtime; the Flutter warning about `app_settings, home_widget` applying KGP is expected.
- `grep -n 'version' android/settings.gradle.kts android/gradle/wrapper/gradle-wrapper.properties`
  → AGP `9.1.0`, Kotlin `2.4.0`, `gradle-9.3.1-all.zip`.
- `curl -sL https://leo-money-tracker.vercel.app/downloads/money-tracker.apk | sha1sum` →
  `e7714931…` (5.4.0 is still what is live).
- `docs/AUDIT_FINDINGS_2026-10.md` § Open says "Nothing".

## Not verified

- Reminder notifications, CSV/PDF share and backup restore under the AGP 9 build (no Kotlin in
  those paths, plugin binaries unchanged; the S22 "not verified on a device" list still stands).
- The emulator-only or pre-Android-12 items from S22 (load-error card, onboarding double tap, PIN
  fail-closed paths, widget preview image on an old launcher).

## Still open

- **Built-in Kotlin** (`android.builtInKotlin=true` + `android.newDsl=true`): blocked on
  `app_settings` (8+ is behind the machine-wide Swift Package Manager switch,
  `docs/DEPENDENCY_STATUS.md`) and on a Flutter release carrying the #192167 fix. AGP 10 removes the
  `newDsl` opt-out, so this is the next toolchain step.
- Whether to cut **5.4.1** with #17's three user-visible fixes. Nothing else since 5.4.0 is user-facing.
- A stale remote branch `origin/claude/festive-germain` predates this session and was left alone.

## Emulator state (Budget_Tracker_Emulator)

Debug build of `fd99b57` (the AGP 9 branch; same app code as `main`) installed over the 5.4.0 data.
Purple theme, system light, PIN disabled, carry-over on; "Reminder test bill" $15.49 due Oct 13; the
two Food expenses and $120 income from S22; both widgets on the launcher's first page. The quick-add
test opened Add Transaction and was not saved.

## Gotchas met this session (also in memory)

- `adb shell am force-stop` cancels the app's PendingIntents, so a widget quick-add tap right after
  it does nothing until the next widget update. Use `am kill` (background-only) or just HOME.
- With `MSYS_NO_PATHCONV=1` set for `/sdcard` paths, the `adb pull` destination must be a Windows
  path (`C:/tmp/...`); `/c/tmp/...` is no longer translated and adb cannot create it.
- A debug cold start shows a white screen for about 10 s on the emulator (secure-storage class
  verification); screenshot after logcat prints "Database initialization complete".
- Flutter's "plugins that apply KGP" warning is textual: it names `home_widget` although 0.9.4 only
  applies `kotlin-android` when built-in Kotlin is off.
- `gh pr merge --delete-branch` plus `git fetch --prune` is what clears the merged branches locally;
  the stale `origin/fix/session-21-widget-and-hardening` ref from S22 went with the prune.

## Addendum, same night: nothing left pending, then 5.4.1+16

Leo's second brief: everything done with nothing pending, and only then the APK. Three things
happened after the sections above.

### A. Device verification of every "not verified" item

Budget_Tracker_Emulator (API 36), debug build of `main` at `211998a` (same app code as the
release); evidence read back with `adb` (`dumpsys notification`, `dumpsys alarm`, `uiautomator
dump`, `run-as`, screenshots).

| Item | Result |
|------|--------|
| Test notification | Notifications → Send Test Notification → "📊 Monthly Summary" posted on channel `monthly_reports`. |
| Scheduled bill reminder | Default reminder time set to 11:25 PM → the exact `RTC_WAKEUP` alarm re-booked for 23:25:00 (`dumpsys alarm`) → "💡 Bill Reminder — Reminder test bill ($15.49) due tomorrow" posted at 23:25 on `bill_reminders`. |
| CSV share | Export Data → Export to CSV → system share sheet "Sharing 1 file", `transactions_20261012_232235.csv`. |
| PDF share | Export to PDF → share sheet with `monthly_summary_….pdf`. |
| Backup to a file | Save Backup → passphrase → SAF "Save as" → `expense_tracker_20261012_232427.etbackup` (306 KB) in the device's Downloads. |
| Load-error card | DB copied aside with `run-as`, first 4 KB overwritten with random bytes, relaunch → `SQLiteLog: file is not a database` → Home shows "Couldn't open your data — Nothing has been deleted … Try again" with the file untouched; bytes restored (md5 `2943e60b…` matches), "Try again" reloaded $2,970.00 without a restart. |
| Fresh install, onboarding double tap | `pm clear`, launch → onboarding; two taps on Get Started 50 ms apart → one Home (one summary card, no Flutter exception), BACK goes to the launcher (no second Home underneath). |
| Restore from a backup file | Choose Backup File → SAF picker → the `.etbackup` → Restore → passphrase → Decrypt → data back ($2,970.00 with the September carry-over, Upcoming bills), settings back (Theme Purple, carry-over on, currency), both launcher widgets re-rendered. |
| Budget alert with an older month on screen | Food budget $30; Home on September; Add with the date picker set to Oct 12, $1 Food → "🚨 Budget Exceeded! Food budget exceeded! Spent: $31.00 of $30.00": October measured, not September. (`pm clear` had revoked `POST_NOTIFICATIONS`, so the first attempt posted nothing until `pm grant`; that is the OS permission, not the app.) |
| Widget preview on a pre-Android-12 launcher | New AVD `Api30_Widget` (`system-images;android-30;google_apis;x86_64`, downloaded this session), debug build installed, long-press → Widgets → "FinanceFlow / Monthly balance 4 × 2" shows the rendered preview card, not the app icon. AVD kept, emulator shut down. |
| PIN fail-closed paths | The one item no device can show: a secure-storage read failure cannot be induced without breaking the Keystore. Covered by `test/utils/pin_security_storage_test.dart`, `test/screens/pin_screens_test.dart` and `test/integration/app_state_nav_settings_pin_gaps_test.dart`. |

Test data this left on the emulator (kept): a $5 Food expense dated 2026-09-01 (the Add form
defaults to the 1st of a non-current month, so an earlier attempt with September selected landed
there), $5 and $1 Food expenses on Oct 12, a $30 Food budget for October, default reminder time
11:25 PM, `POST_NOTIFICATIONS` re-granted by adb. The carry-over into October now reads
$2,845.00 (it was $2,850.00): the Sep 1 $5 row is the whole difference, by design (carry-over
counts full expense amounts, see `docs/` carry-over notes and `calculateNetBalanceBefore`).

### B. Housekeeping

`origin/claude/festive-germain` (2026-03-16, fully merged into `main`) deleted. No other branch
but `main` remains.

### C. Release 5.4.1+16

`main` had three merged PRs the live APK did not, so the Unreleased section became a release:
PR #21 (`release/5.4.1`): pubspec 5.4.0+15 → **5.4.1+16**, CHANGELOG "Unreleased" →
"5.4.1+16 — 2026-10-13", this addendum. Squash-merged, tag `v5.4.1` on the squash commit, then
the CLAUDE.md pipeline: arm-only release APK, `scripts/verify-release-apk.sh`, copy into the
landing repo, commit, push, manual `vercel --prod --yes`, live SHA-1 compared with the build. The
exact hashes and sizes are in the final docs commit that follows the release (the handoff cannot
know its own merge hash). Leo's copy: `C:\Users\leooa\Downloads\money-tracker-5.4.1+16.apk`.
