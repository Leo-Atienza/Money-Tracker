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

## Still open
- **Flutter ≥ 3.41.6 SDK bump** (unblocks `file_picker` 12, `share_plus` 13,
  `package_info_plus` 10, `pdf` 3.13, `sqflite` 2.4.3). Machine-wide change, no FVM in the
  repo — deliberately left for Leo.
- `warningOrange` (orange 800) is 2.9–3.1:1 on the light surfaces in both Light and Purple;
  pre-existing, only used for 12 px "Pay Bill"/"left" tags and the 75 % budget tier.
- Cook-log row for the tactile skill only after Leo's feedback on Purple (craft.md 5b).

## Release record
Filled in at ship time — see the bottom of this file.
