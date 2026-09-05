# Session 20 handoff — Purple theme, type ladder, reminder fixes (2026-09-04)

Picked up from `docs/SESSION_19_HANDOFF.md`. Everything below shipped as **v5.3.0+13**
(see the Release record at the end, filled in at ship time).

## What was asked
Continue the S19 handoff (CI check, typography ladder, bill-reminder verification), add a
**Purple / lavender theme as a third option beside Dark and Light**, and leave the app with no
known problems.

## Purple theme
A third, *fixed* appearance — it never follows the OS. `theme_mode = 'purple'` is persisted like
the other values; `themeModeFor()` (`lib/theme/luminous_app_theme.dart`) maps `light`/`purple`
to `ThemeMode.light`, `dark` to dark, anything unrecognised to system. `main.dart` hands
`luminousPurpleScheme()` to `buildLuminousTheme(colorScheme:)` for the `theme` slot when purple
is selected; `darkTheme` stays the neutral dark scheme. Settings › Theme now lists **Light,
Dark, Purple ("Lavender, always light"), Follow System**, with the Purple swatch drawn from the
real scheme.

The scheme is hand-built (no `fromSeed`, per `.tactile.md`): lavender surfaces (`#F8F6FE` …
`#E2DBEF`), one violet for chrome (`#5B44A6`), violet-cast ink (`#1E1A2E`). Income green /
expense red / warning / info are the light-theme `AppColors` unchanged; category identity
colours are untouched. Contrast is asserted, not eyeballed: `test/theme/luminous_theme_test.dart`
checks every ink role on every surface role (4.5:1), outline (3:1), `primary` on its own
12–14 % tints (nav indicator, list-tile icon well), the money colours within 10 % of their
neutral-light ratios, and that a brightness-mismatched scheme is refused.

**Fills moved from `onSurface` to `primary`.** Twelve CTA/FAB/chip/badge sites painted with
`onSurface` + `surface` ink. In the neutral schemes `primary == onSurface`, so it was
invisible; in Purple it produced near-black buttons inside violet chrome. They now use
`primary` / `onPrimary` — no visible change in Light or Dark, violet in Purple.

**Cold-start flash.** `main()` now reads `theme_mode` before `runApp` and seeds
`AppState(initialThemeMode:)`, so the first frame is already the chosen appearance. Previously
every cold start painted the light scheme until `_loadSettings` finished.

Device walk in Purple (`Budget_Tracker_Emulator`, debug build): Settings, theme sheet, Home,
History (All + Expenses), Add, Analytics, Wallet, Budgets, Categories, Quick Templates, Trash,
Backup & Restore, Export, Notifications, Recurring Items, Add Recurring Income. Light and Dark
re-walked on History, Wallet and Categories after the type changes.

## Typography ladder (S19 leftover)
History (`history_screen`, `history_filter_bar`, `history_list`), Category Manager and Wallet
carried 61 raw `fontSize:` literals; all are now theme roles (`titleMedium` for row titles and
amounts, `bodySmall` for secondary text, `labelMedium`/`labelSmall` for tags and dates,
`labelLarge` for buttons and tabs, `titleSmall`/`titleLarge` for dialog headings). The History
header dropped from a one-off 32 px to `headlineMedium`, matching every other screen title.
`grep -c fontSize:` on those five files is 0.

## Fixes found on the way
- **Reminder time never re-booked reminders.** `AppState.setReminderTime` persisted the time
  but scheduled nothing; the new time only applied at the next launch. It now re-runs
  `_scheduleAllBillReminders()` (best-effort, like `toggleBillReminders`).
- **A new recurring bill never booked its reminder.** `addRecurringExpense` inserted the row
  and reloaded; only `updateRecurringExpense` scheduled. It now books the reminder for the
  inserted id.
- **Dialogs disposed their `TextEditingController` mid-exit-transition.** "Disable PIN",
  "Verify Current PIN" and the encrypted-backup passphrase prompt disposed method-scoped
  controllers the moment `showDialog` returned, while the fading-out dialog still rebuilt its
  `TextField` — the device Crash Log had "A TextEditingController was used after being
  disposed" from every dismissal. Each is now a small `StatefulWidget` that owns its
  controllers (`_PinVerifyDialog`, `_BackupPassphraseDialog`); the PIN one also guards against
  a double-tap popping twice.

## Bill reminders verified on a device (S18/S19 open item)
On the emulator: granted `POST_NOTIFICATIONS` + exact alarms, added "Reminder test bill" ($15,
Bills, monthly, day 5), then changed **Default reminder time** to 10:29. `dumpsys alarm`
showed an exact `RTC_WAKEUP` for `2026-09-04 10:29:00` the moment the time changed (the
rescheduling fix above), and at **10:29:04** `dumpsys notification` held
`💡 Bill Reminder — Reminder test bill ($15.00) due tomorrow` on the `bill_reminders` channel
(importance 4, `vis=PRIVATE`). The test bill is still on the emulator.

## Gates
- `flutter analyze`: clean. `scripts/preflight.sh`: green at **2507 pass / 3 skip**; ratchet
  raised 2489 → 2506 → 2507 (`.sh` + `.ps1`).
- First CI run on `origin/main` (the S19 workflow commit): both jobs green.
- Rendered walk: Purple on 16 screens, Light + Dark on the three re-typed screens.

## Emulator notes (also in project memory)
- Screenshots come back black while a PIN is configured — that is `FLAG_SECURE`, not a
  rendering bug. The seeded PIN is 1234; disable it through the app to capture.
- `uiautomator dump /sdcard/ui.xml` in Git Bash **needs `MSYS_NO_PATHCONV=1`** on both the
  dump and the `cat`, or the dump lands in `/Files/Git/sdcard/` and you read a stale file.
  That produced a phantom "PIN shows disabled" finding this session before it was caught.
- Settings has no back arrow; leave it with the system BACK key. The Add tab opens with the
  keyboard up, so a bottom-nav tap while on it hits the keyboard.

## Part 2 — Flutter 3.47.2 SDK bump (v5.3.1+14, same day)
Leo asked to finish everything, which included the two items the first part left open.

- **SDK:** `flutter upgrade` moved the machine to **3.47.2 / Dart 3.13.2** (was 3.38.5 /
  3.10.4; rollback is `git -C C:/Users/leooa/develop/flutter checkout 3.38.5` plus
  `flutter doctor`). CI pin bumped to match in `.github/workflows/ci.yml`.
- **Packages:** `file_picker` 12.2.0, `share_plus` 13.3.0, `package_info_plus` 10.2.1,
  `pdf` 3.13.0, `sqflite` 2.4.3 (+ `sqflite_common` 2.5.11, `sqflite_common_ffi` 2.4.2+1),
  `win32` 6.4.0. `flutter_secure_storage` stays at 10.x on purpose (v11 destroys user data —
  see `docs/DEPENDENCY_STATUS.md`).
- **Android toolchain:** Flutter 3.47 refuses Gradle < 8.14, so Gradle 8.11.1 → **8.14.3**,
  AGP 8.9.1 → **8.13.2**, Kotlin 2.1.0 → **2.2.20** — the smallest versions inside the Flutter
  tool's documented ranges. The SDK's own template is now Gradle 9.3.1 / AGP 9.1.0 / Kotlin
  2.4.0 (AGP 9 = new Gradle DSL); deliberately not taken in the same pass.
- **file_picker 12 migration** (`lib/utils/backup_helper.dart`): static `FilePicker.pickFile()`
  / `saveFile()` (returns `Uri?`); a SAF pick has no file path, so restore reads it with
  `readAsBytes()`. The JSON `importBackup` path and its confirmation/restore helpers had no
  callers anywhere and were deleted rather than migrated.
- **Flutter 3.47 fallout, all real findings:** a new debug assertion for a `ListTile` under a
  decorated box with no `Material` (its ripple was hidden) fired in Wallet and Recurring —
  `GlassPanel` and `AnimatedPressCard` now carry a transparent `Material` inside their clip,
  and the recurring-income row moved its fill/border onto the tile. The new
  `unawaited_return_in_try_block` lint caught `db_open.dart` returning the integrity
  row-count future before `finally` closed the connection — now awaited.
- **`warningOrange`** (light set) → `#B45309`: 4.0:1 on the darkest light surface, 3.7:1 on
  the darkest lavender one (was 2.5–2.9:1). `luminous_theme_test` now holds all four money
  colours to 3:1 on every surface role in Light and Purple.
- Gates: `flutter analyze` clean; preflight green **2507 pass / 3 skip** on 3.47.2; debug
  build green on the new toolchain; emulator smoke on that build (DB opened with data intact,
  SAF picker opens from "Choose Backup File" and cancels to "Restore cancelled").
- Windows gotcha met on the way: a leftover Gradle/Kotlin daemon held a lint-cache jar and
  failed `:app:lintVitalAnalyzeRelease` twice ("being used by another process"). Fix was
  `taskkill` on every java.exe daemon, move `build/app/intermediates/lint-cache` to trash,
  rebuild. `verify-release-apk.sh` happily verified the *stale* APK in between — check the
  mtime, always.

### Release record (v5.3.1+14)
- PR #15 squash-merged to `main` as `58ebd11` (tree identical to branch commit `519136d`),
  tagged **`v5.3.1`** (`e3df6b9a`). CI on the PR under Flutter 3.47.2: preflight 3m25s,
  release-APK build 7m6s, both green.
- Release APK (arm64-v8a + armeabi-v7a, `verify-release-apk.sh` green): **57,174,234 B**
  (2.3 MB smaller than v5.3.0), SHA-1 **`cad23cb8095c8103d585bdbb4aad6c99e3eee96c`**.
- Landing repo commit `90fcc35`, `vercel --prod --yes`; the live download returned the same
  SHA-1 with HTTP 200 and matching Content-Length.

## Branch hygiene (end of session)
Deleted on the server: `security/untrack-leaked-firebase-config` (tip `11f1992`, May 2026 —
its real fix, untracking + ignoring `google-services.json`, is already on `main`, and the rest
was setup docs for Firebase, which the app no longer uses) and `release/v5.0.0` (tip `0eb62a7`,
fully merged; `v5.0.0` is tagged). `claude/festive-germain` is a merged desktop-app session
branch and was left alone. Both session branches from this record were deleted by their squash
merges.

## Still open
- **AGP 9 / Gradle 9 / Kotlin 2.4** (the current `flutter create` template) — not needed by
  anything yet; take it deliberately with the suite and a device walk as the gate.
- Cook-log row for the tactile skill only after Leo's feedback on Purple (craft.md 5b).

## Release record
- PR #14 squash-merged to `main` as `9ae3f12` (branch tree identical to the merge commit,
  `git diff 0047a21 9ae3f12` empty), tagged **`v5.3.0`** (`42f00fd2`). CI on the PR: preflight
  2m15s and release-APK build 6m43s, both green.
- Release APK built `--target-platform android-arm64,android-arm`, `verify-release-apk.sh`
  green (debug-signed on purpose, ABIs `arm64-v8a armeabi-v7a`), **59,445,517 B**,
  SHA-1 **`d09be8b836daac127d114b34b887231ae094e661`**.
- Landing repo commit `c7fc9b8`, `vercel --prod --yes` from the landing dir, then
  `curl -sL https://leo-money-tracker.vercel.app/downloads/money-tracker.apk | sha1sum`
  returned the same SHA-1 with HTTP 200 and matching Content-Length.
