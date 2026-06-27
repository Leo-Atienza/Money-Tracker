# Money Tracker (FinanceFlow) — Next-Session Handoff: Finish & Ship v5.0.0+1

> **Mission for the next session:** take the app to *completely finished* and shipped as `v5.0.0+1`. That means: close the remaining audit findings, fill every test gap in this document, land Phase 6.1 (SQLCipher), add golden tests, run the on-device perf pass, bump the version + CHANGELOG, and run the ship pipeline. **An Android emulator is available** this session, so every device-gated step is now doable.

> **This document is self-contained.** Read it top to bottom. It supersedes the older `docs/FINISH_LINE.md` / `docs/NEXT_STEPS.md` for sequencing (those remain accurate for the SQLCipher/ship mechanics and are cross-referenced). Companion: `docs/AUDIT_FINDINGS_2026-06.md` (the 62-finding audit) and `SESSION_HANDOFF.md` (§ Session 10).

---

## 0. How this document is organized

1. **§1 Current state** — exactly where the repo is, the 8 commits from the last session, metrics.
2. **§2 Environment & tooling** — emulator/adb/MCP, build/run/test commands, and every gotcha that wasted time last session.
3. **§3 Architecture quick-map** — the non-obvious design facts you must know before changing anything.
4. **§4 Known traps** — landmines already discovered (so you don't re-hit them).
5. **§5 Execution order** + **§6 Definition of Done**.
6. **"Remaining Work to Ship v5.0.0+1"** — the full ordered fix/ship plan (from the audit + roadmap).
7. **Per-layer test plan** — exhaustive, per-function test specs for the ENTIRE app (models, utils, database, AppState, screens, widgets), each marked ✅ Covered / 🟡 Partial / ❌ Missing. **Filling every ❌ and 🟡 is the test mandate.**

---

## 1. Current state (start here)

- **Repo:** `C:/Users/leooa/Documents/personal-projects/Money-Tracker` — Flutter app, package `budget_tracker`, branded "FinanceFlow".
- **Branch:** `release/v5.0.0`. **HEAD `c248ad2`.** **NOT pushed to origin this session** (8 local commits ahead — push is an explicit, gated step; see ship plan).
- **Tests:** `1893 pass / 3 skipped`, `flutter analyze` clean, preflight green (gate ≥ 1750 — ratchet up as you add tests).
- **Version:** `pubspec.yaml` still `4.4.0+6`. Bumps to `5.0.0+1` at ship time (do NOT bump early).
- **DB schema:** v19. **APK:** ~59 MB last measured (rebuild + re-measure at ship).
- **Phases:** 0–5 complete; Phase 6 = 5/6 (only **6.1 SQLCipher** left); Phase 7 D.2 hero widget tests landed; Phase 8 = 8.1/8.3 done (8.2 perf / 8.4 version / 8.5 ship remain).

### The 8 commits landed last session (2026-06-26 → 06-27)
| SHA | What |
|---|---|
| `20a5d57` | fix(test): de-rot wall-clock-fragile `app_state_crud_test.dart` date-move test (suite was RED at 1892/1-fail). |
| `6a14555` | fix(ui): paint `OrganicBlobBackground` globally via `MaterialApp.builder` — ~14 pushed/onboarding/PIN screens were rendering on a **black background** (transparent Scaffold + opaque PremiumPageRoute, no global blob). Device-verified light+dark. |
| `3fddb52` | fix(security): **H1** — app never re-locked on resume; PIN gate ran only at cold start → financial data visible without PIN. Added resume re-check + re-entrancy guard. Device-verified. |
| `c0d76e1` | docs: audit findings + session-10 handoff. |
| `fe13147` | fix(security): harden `_handlePaused` PIN check (was outside try → could skip DB-close maintenance on error). |
| `1d7cf3c` | fix(onboarding): **"Load Sample Data" never worked** — `addCategory('Transport')` threw (Transport is a default category) and aborted the load. Now tolerates pre-existing categories. Device-verified. |
| `c248ad2` | docs: record double-check pass. |

### The audit (read it)
`docs/AUDIT_FINDINGS_2026-06.md` — 62 refute-verified findings: **2 HIGH, 19 MEDIUM, 41 LOW**. The blob regression, H1, and the wall-clock test are already fixed and excluded. The remaining HIGH (**H2 PIN→PBKDF2**) and the impactful MEDIUMs (**M17/M18/M19 notifications, M1 payment rounding, M14 currency formatting, M8–M12 accessibility, M3–M7 performance**) are the priority work, detailed in "Remaining Work" below.

---

## 2. Environment & tooling (read before doing anything device-related)

### Emulator + device control
- **Emulator `emulator-5554`** (Pixel-class, **API 36**, resolution **1080×2400**) is bootable. Launch: `flutter emulators --launch Medium_Phone_API_36.0` then wait for `adb shell getprop sys.boot_completed` == `1`.
- **`adb` is NOT on PATH.** Full path: `C:/Users/leooa/Documents/...` → use `/c/Users/leooa/AppData/Local/Android/Sdk/platform-tools/adb.exe`.
- **Drive the UI via the `mobile` MCP** (`mcp__mobile__*`): `mobile_take_screenshot`, `mobile_list_elements_on_screen` (gives device-pixel coordinates + accessibility labels — use these for taps, don't guess from screenshots), `mobile_click_on_screen_at_coordinates`, `mobile_swipe_on_screen`. For ordered multi-tap (e.g. PIN entry) use chained `adb shell input tap X Y` (MCP calls in one message run in parallel — not ordered).

### Build / run / install
```bash
cd "C:/Users/leooa/Documents/personal-projects/Money-Tracker"
flutter build apk --debug        # ~135s cold, faster incremental
ADB=/c/Users/leooa/AppData/Local/Android/Sdk/platform-tools/adb.exe
"$ADB" install -r build/app/outputs/flutter-apk/app-debug.apk
"$ADB" shell monkey -p com.moneytracker.app -c android.intent.category.LAUNCHER 1   # cold launch
"$ADB" shell am start -n com.moneytracker.app/.MainActivity                          # resume live process (tests resume path)
```
- Release: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.
- App id: `com.moneytracker.app` (namespace `com.moneytracker.app`; canonical `MainActivity` at `android/app/src/main/kotlin/com/moneytracker/app/MainActivity.kt`).

### Preflight / tests
```bash
bash scripts/preflight.sh     # flutter analyze + flutter test (gate >=1750) + forbidden-pattern grep. MUST be green per commit.
```
- **Capturing test failures:** the `--reporter=expanded` output uses `\r` overwrites that hide the `[E]` failure block. Capture with `flutter test ... 2>&1 | tr '\r' '\n' > log` then `grep -nE "\[E\]|Expected:|Actual:|Some tests failed"`. With `--concurrency=4`, the test name on the `-1` line may not be the failing one — re-run the suspect FILE in isolation to pin it.
- After adding tests, **ratchet `TEST_COUNT_MIN`** in `scripts/preflight.sh` (and `.ps1`) up toward the new baseline.

### Device gotchas that wasted time last session (IMPORTANT)
- **FLAG_SECURE makes screenshots BLACK when a PIN is enabled** (this is correct Phase 6.5 behavior). When verifying PIN/locked screens, use `mobile_list_elements_on_screen` (the a11y tree still reports content) instead of screenshots.
- **The PIN survives `adb shell pm clear`** because `flutter_secure_storage` is Keystore-backed. To FULLY reset (no PIN, fresh data): `adb uninstall com.moneytracker.app && adb install ...`. The emulator may currently have **PIN = `1234`** set from H1 verification.
- `pm clear` DOES wipe SharedPreferences (so onboarding re-appears) but not Keystore — these can desync.

### Widget/integration test harness patterns (already in the repo — reuse)
- In-memory DB: `await makeFreshDb();` (from `test/integration/_test_helpers.dart`) sets a unique `DatabaseHelper.databaseNameOverride` per test to avoid parallel-isolate collisions.
- Mock channels in `setUp`: `plugins.it_nomads.com/flutter_secure_storage`, `home_widget`, `dexterous.com/flutter/local_notifications`, `plugins.flutter.io/path_provider` (return `'.dart_tool/test_path_provider'`), and `SharedPreferences.setMockInitialValues(<String,Object>{})`.
- Time: `Clock.instance = FakeClock.fixed(DateTime.utc(...))` for time-dependent logic; reset in tearDown.
- Widget screens: build your own `MaterialApp(theme: buildLuminousTheme(...), home: Screen())` + `ChangeNotifierProvider<AppState>.value`. Set `tester.binding.setSurfaceSize(const Size(420,1400))` (or 800×1600 for tall slivers) and reset in tearDown. Use `pumpAndSettle` (or `pumpAndSettle(600ms)`) to drain `FadeInOnLoad`/`BounceAnimation`; avoid plain `pump` (leaves pending timers → test fails at teardown). For DB-loading initState screens, `pump()` + `runAsync(() => Future.delayed(200ms))` + `pump()`.
- The `FlutterLocalNotificationsPlatform.instance` is a `late final` static — screens that touch it (notification settings) need a `MockPlatformInterfaceMixin` fake (deps already declared: `flutter_local_notifications_platform_interface`, `plugin_platform_interface`).

---

## 3. Architecture quick-map (non-obvious facts)

- **State:** single `AppState` (Provider `ChangeNotifier`, ~96 public members, `lib/providers/app_state.dart`). All DB-mutating methods run inside `_writeMutex.synchronized(...)` (`lib/utils/async_mutex.dart`) and call `_safeNotify()` (no-op after dispose).
- **2-month in-memory window:** `_expenses`/`_incomes` (= `allExpenses`/`allIncomes`) hold ONLY the previous + current month, reloaded by `_loadExpensesInternal`/`_loadIncomesInternal`, pruned by `_pruneDistantMonths` (cap `_maxMonthsInMemory = 6`). **`_loadExpensesInternal` is keyed off `DateHelper.today()` (real wall clock), but `_selectedMonth` uses `Clock.instance.now()` — a time-source inconsistency** (see traps). `state.expenses` is filtered to `selectedMonth`; `state.allExpenses` is the window. Other months: `ensureMonthLoaded(month)`.
- **Money:** `Decimal` (`package:decimal`) everywhere in Dart; stored as `REAL` in SQLite (the "INTEGER cents" migration is explicitly **v5.1, out of scope**). Format via `lib/utils/currency_helper.dart` (cached `NumberFormat`).
- **Time:** `lib/utils/clock.dart` (`Clock.instance` real / `FakeClock.fixed`/`.sequence`). Logic code uses Clock; UI/export deliberately use `DateTime.now()`. Dates normalized to `DateTime.utc(y,m,d)` via `DateHelper.normalize`.
- **DB:** `DatabaseHelper` singleton (`lib/database/database_helper.dart`), schema v19, FKs ON (`PRAGMA foreign_keys=ON` in `onConfigure`). Single open path: `_initDatabase` → `openDatabase(dbPath, version, onConfigure, onCreate, onUpgrade)`. `databaseNameOverride` for tests. Atomic adds: `createExpenseWithCarryover`/`createIncomeWithCarryover`.
- **Design:** "Luminous" glassmorphism (`lib/widgets/luminous/`) over `OrganicBlobBackground`. As of `6a14555` the blob is painted **globally** in `MyApp.build` via `MaterialApp.builder` (below Navigator, inside Theme) — every transparent-Scaffold screen renders over it. Theme: `lib/theme/luminous_app_theme.dart` (`buildLuminousTheme`), tokens `lib/theme/luminous_tokens.dart`, semantic colors `lib/theme/app_colors.dart` (`AppColors` ThemeExtension). Font: bundled Hanken Grotesk variable TTF (no `google_fonts`).
- **Security:** PIN via `PinSecurityHelper` (+ `SecurePrefs` Keystore wrapper); FLAG_SECURE via `SecureWindow` method channel `budget_tracker/secure_window`; backups AES-GCM via `BackupCrypto`; crash PII redaction `CrashLog.redactPii`; home-widget redaction `WidgetPayload.redactIfLocked`.
- **Notifications:** `NotificationHelper` (singleton via `AppState.notificationHelper`), ID ranges: bill reminders 10000–19999, recurring income 20000–29999. Tap payloads via `NotificationPayloadStore` queue. **Known broken — M17/M18/M19 (see Remaining Work).**
- **Forbidden patterns (enforced by `test/lint/` + preflight grep):** no `withOpacity(` (use `withValues(alpha:)`), no `print(` (use `debugPrint`/`CrashLog`), no `GoogleFonts`, no `import '../main.dart'`, no `package:budget_tracker/` self-import in `lib/`, no `Navigator.pushNamed` to unregistered routes, no `context.watch<AppState>` outside the allow-list.

---

## 4. Known traps (already discovered — don't re-hit)

1. **Wall-clock-rot tests:** never hardcode recent calendar dates that interact with the 2-month window — anchor to `DateHelper.today()`/`subtractMonths`. (Caused the RED baseline last session.)
2. **`addCategory` throws on duplicate** (`ArgumentError`) — default categories are `Food, Transport, Shopping, Entertainment, Health, Education, Bills, Other` (expense) + `Salary, Freelance, Investment, Gift, Other` (income). Any seeding must tolerate existing names.
3. **`isLocked == true` must imply a PIN exists** — `_handlePaused` now gates `lock()` on `isPinEnabled`. Preserve this invariant if you touch lock logic, or you'll trap PIN-less users on the unlock screen.
4. **Blob is global now** — don't re-add a local `OrganicBlobBackground` to a screen; transparent Scaffolds already get it from `MaterialApp.builder`.
5. **Loading-spinner Scaffold** (`MyApp.build` FutureBuilder waiting state) uses a fixed light `LuminousTokens.background` → brief light flash on a dark-mode cold start. Minor; fix opportunistically (make it theme-aware).
6. **Currency display divergence (M14):** visible `Text` amounts skip thousands grouping (`$2845.00`) while the a11y labels use the formatter (`$2,845.00`). Route visible amounts through `CurrencyHelper`.

---

## 5. Recommended execution order

1. `git fetch && git status` (clean), `bash scripts/preflight.sh` (confirm 1893 green), boot emulator.
2. **H2** PIN→PBKDF2 (HIGH) — implement + device-test set/verify/legacy-upgrade. Add tests.
3. **Notifications M17/M18/M19** — wire tap routing, thread reminder time, schedule-on-toggle. Add tests + device smoke.
4. **M1, M14, M15, M16** money/correctness fixes + tests.
5. **A11y cluster M8–M12** + tests.
6. **Performance M3–M7** + tests.
7. **Fill the test gaps** in the per-layer plan below (work file-by-file; ratchet the gate after each batch). Re-enable/verify the 3 skipped tests.
8. **Phase 6.1 SQLCipher** (high data-loss risk — follow the procedure exactly; device-test on a data-bearing install).
9. **D.3 golden tests** for hero screens.
10. **8.2 device perf pass** (DevTools, 60fps targets).
11. **8.4 version bump 4.4.0+6 → 5.0.0+1 + CHANGELOG.**
12. **8.5 ship pipeline** (build → landing repo → `vercel --prod --yes` → SHA-1 verify → `gh release` → fast-forward `main`).
13. Final 5-minute on-device smoke. Tag only after everything green.

Work in ~5-item waves; `bash scripts/preflight.sh` must pass after each wave; never regress the test count.

## 6. Definition of Done for `v5.0.0+1`

1. Every audit finding in `docs/AUDIT_FINDINGS_2026-06.md` is fixed or explicitly deferred-to-v5.1 with rationale.
2. Every ❌/🟡 in the per-layer test plan below is closed (or justified). `flutter test` green; `flutter analyze` clean; preflight green with a ratcheted gate.
3. Phase 6.1 SQLCipher landed + device-verified (encrypted DB unreadable without key; data preserved).
4. Golden tests pass; on-device perf pass meets 60fps targets.
5. `pubspec.yaml` = `5.0.0+1`; `CHANGELOG.md` has a v5.0.0 entry (Added/Changed/Fixed/Security).
6. APK builds clean (≤ 70 MB); 5-minute device smoke passes end-to-end.
7. Tag `v5.0.0+1` on `origin/release/v5.0.0`; landing page serves the APK at matching SHA-1; GitHub release created; `release/v5.0.0` fast-forwarded into `main`.

---


# Remaining Work to Ship v5.0.0+1

This is the single consolidated backlog from the close of Session 10 to a tagged, live `v5.0.0+1`. It folds the 62-finding adversarial audit (`docs/AUDIT_FINDINGS_2026-06.md`) into the pre-existing ship roadmap (`docs/FINISH_LINE.md`, `docs/NEXT_STEPS.md`, `docs/CHECKLIST.md`). Work the groups top-to-bottom: HIGH security first, then the notification cluster, then a11y, money correctness, performance, the long LOW tail, then the four ship gates (SQLCipher, goldens, perf, version bump, ship pipeline).

**Already fixed in Session 10 — do NOT redo:** systemic black-background regression (global `OrganicBlobBackground` via `MaterialApp.builder`, `6a14555`); H1 re-lock-on-resume + re-entrancy guard; `_handlePaused` `isPinEnabled` gate hardened to fail-open (`fe13147`); "Load Sample Data" default-category tolerance (`1d7cf3c`); wall-clock-fragile CRUD test anchored to `today()` (`20a5d57`). Branch `release/v5.0.0` is preflight-green at **1893 pass / 3 skipped**, `flutter analyze` clean, but **NOT pushed to origin** since Session 10 — push + fast-forward `main` before starting.

**Device:** `emulator-5554` (Pixel-class, API 36) is live this session via the `mobile` MCP and `adb` at `C:/Users/leooa/AppData/Local/Android/Sdk/platform-tools/adb.exe`. The app is installed (debug) with **App PIN `1234`** set — disable it in Settings or `adb uninstall com.moneytracker.app` for a clean visual pass. This removes the 9-session "no device" blocker, so every device-gated item below is now actionable in this session.

**Standing gates for every commit:** `bash scripts/preflight.sh` green (test-count gate currently `>=1750`; ratchet up per release), `flutter analyze` clean, test count never regresses. Work in ~5-item waves, build + test after each.

---

## Group 1 — HIGH-severity audit fix: H2 PIN → PBKDF2

### H2. PIN stored as single-round unsalted-stretch SHA-256 — trivially brute-forceable offline
- **File:line:** `lib/utils/pin_security_helper.dart:230` (`_hashPinWithSalt`), legacy `_hashPin` at `:223`, verify path uses `_constantTimeEquals` at `:247`.
- **Risk:** HIGH (security). A 4–6 digit PIN is at most 10^6 candidates; one round of SHA-256 over `salt+pin` falls to a GPU in well under a second if the Keystore value or the `encryptedSharedPreferences` fallback file is ever extracted. The project already ships `package:cryptography` with PBKDF2 @ 100k iterations in `lib/utils/backup_crypto.dart:35` — the slow KDF is right there, unused for the PIN.
- **Device needed:** YES — set/verify/legacy-upgrade must be smoke-tested on `emulator-5554` against the real Keystore.
- **Steps:**
  1. Make `_hashPinWithSalt` async and PBKDF2-based. Replace the `sha256.convert` body with the derivation used by `BackupCrypto`: `Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256)`, using the base64-decoded per-PIN salt as the PBKDF2 nonce; base64- or hex-encode the derived 256-bit key for storage. Signature becomes `Future<String> _hashPinWithSalt(...)`.
  2. Propagate `async` up through `setPin` and `verifyPin` (already `async`) and any other caller — `flutter analyze` will flag the now-`Future` returns.
  3. Keep `_constantTimeEquals` (`:247`) for the compare — unchanged.
  4. **Migrate-on-verify.** In `verifyPin`, when the stored hash is the legacy single-SHA-256 format (the `storedSalt == null` branch, see also L37 below) AND the input matches, call `setPin(pin)` on success to transparently re-derive and persist the PBKDF2 hash. Plaintext is only available at verify time, so this is the only upgrade point that doesn't force a PIN reset.
  5. Add/keep one assert-style self-check or unit test: legacy hash verifies once, then the stored format is PBKDF2 on the next read (use `FakeClock` if any timestamp is involved; this path has none).
- **Device-test procedure (emulator-5554):**
  1. `flutter build apk --release && adb install -r build/app/outputs/flutter-apk/app-release.apk`.
  2. New-PIN path: Settings → Security → enable PIN `1397` → force-stop (`adb shell am force-stop com.moneytracker.app`) → reopen → enter `1397` → unlocks. Confirm `adb shell run-as com.moneytracker.app cat shared_prefs/FlutterSharedPreferences.xml` shows NO `app_pin_hash`/`app_pin_salt` (they live in Keystore).
  3. Legacy-upgrade path: install a v4.4.0+6 APK from the landing page, set the PIN under it, confirm the legacy SHA-256 hash is present; sideload the new build over the top (`adb install -r`); open → enter PIN → must verify first try; re-read the secure store and confirm the stored hash is now the PBKDF2 form.
- **Acceptance:** both flows pass; user never re-sets the PIN; stored hash is PBKDF2 after first verify; ~250 ms derivation is acceptable on unlock (matches the backup PBKDF2 cost). On failure, revert the commit and file an issue with device + Android version + symptom.

---

## Group 2 — Notifications actually work (M17 / M18 / M19, plus the M20/M21 cluster)

These four findings (M19, M20, M21 + the M18 resilience fix) are why notifications are effectively non-functional today. Do them together — they all touch `lib/utils/notification_helper.dart` and `lib/providers/app_state.dart`.

### M19. Notification taps are never routed — entire payload-store/navigation pipeline is dead code
- **File:line:** `lib/utils/notification_helper.dart:89` (the `_notifications.initialize(initSettings)` call — confirmed: no response callbacks today).
- **Risk:** MEDIUM (notifications-bg, confidence 0.95). The top-level `@pragma('vm:entry-point') notificationTapBackground` in `main.dart` and the whole `NotificationPayloadStore` + `_checkPendingNotification()` routing are unreachable — tapping a bill reminder or budget alert just opens the last screen.
- **Device needed:** YES (tap routing only verifiable on device).
- **Steps:**
  1. Wire both callbacks at `:89`: `await _notifications.initialize(initSettings, onDidReceiveNotificationResponse: (r) => NotificationPayloadStore.storePendingPayload(r.payload), onDidReceiveBackgroundNotificationResponse: notificationTapBackground);` (`notificationTapBackground` is the existing top-level handler in `main.dart`).
  2. Attach payloads to each dispatch: `payload: 'recurring_expenses'` on the two bill-reminder `zonedSchedule` calls (`notification_helper.dart:237, 257`); `payload: 'budget_alert:${budget.id}'` on the budget `show` call (`:352`).
- **Acceptance:** tapping a bill reminder routes to the recurring-items screen; tapping a budget alert routes to budgets. Surgical — no rewrite.

### M20. "Reminder Time" setting is cosmetic — bill reminders hardcoded to 09:00
- **File:line:** `lib/utils/notification_helper.dart:222, 261` (both `reminderDate.copyWith(hour: 9, minute: 0)`).
- **Risk:** MEDIUM (confidence 0.95). User sets 8 PM, still gets 9 AM. Silently misleading.
- **Device needed:** Optional (schedule inspection is enough; a real fire is slow to observe).
- **Steps:** Add `TimeOfDay reminderTime = const TimeOfDay(hour: 9, minute: 0)` param to `scheduleBillReminder`; replace BOTH hardcoded `copyWith` calls with `hour: reminderTime.hour, minute: reminderTime.minute`. Pass `reminderTime:` from the two AppState call sites (`app_state.dart:456, 1742`) and from `rescheduleEndOfMonthBillReminders` (`notification_helper.dart:309`), sourcing `AppState._reminderTime`. Both branches must change or end-of-month vs regular bills honor the setting inconsistently.
- **Acceptance:** a reminder scheduled after changing the setting fires at the chosen time.

### M21. Toggling a notification on never schedules anything until the next loadData/background pass
- **File:line:** `lib/providers/app_state.dart:2181, 2183` (`toggleBillReminders` / `toggleMonthlySummary`).
- **Risk:** MEDIUM (confidence 0.9). Enabling a toggle schedules nothing until next backgrounding; disabling never cancels, so stale notifications keep firing.
- **Steps:** In `toggleBillReminders`: after persisting, if `value && await _notificationHelper.areNotificationsEnabled()` call `_scheduleAllBillReminders()`; else call the per-feature cancel for bill-reminder IDs. In `toggleMonthlySummary`: if `value && enabled` call `_notificationHelper.scheduleMonthlyReports()`; else `cancelMonthlyReports()`. **Use per-feature cancel IDs, not `cancelAllNotifications()`** — the shared blanket cancel would let one toggle wipe the other's scheduled notifications.
- **Acceptance:** enabling a toggle schedules immediately; disabling cancels immediately; the two toggles don't clobber each other.

### M18. Budget-alert notification failure aborts addExpense after the DB commit
- **File:line:** `lib/providers/app_state.dart:717-729` (`_checkBudgetAlerts` → `showBudgetAlert` runs after the atomic write, before `_safeNotify()`).
- **Risk:** MEDIUM (error-resilience, confidence 0.8). Expense IS persisted, but if the notifications plugin throws (permission revoked, OEM quirk), the whole `addExpense` future rejects → UI never refreshes, Add screen shows a false failure, user may re-enter a duplicate.
- **Steps (preferred):** Move `_checkBudgetAlerts(expense.category)` to AFTER `_safeNotify();` and `_updateHomeWidget();`, and wrap it in `try/catch` that logs in debug — mirroring the existing `_updateHomeWidget` guard at `app_state.dart:358-364`. Optionally also guard `showBudgetAlert`/`initialize` internally for defense in depth.
- **Acceptance:** an expense saves and the UI refreshes even when the notification dispatch throws.

### M17. `_loadDataInternal` has no try/catch — a failing loader leaves the UI stale and never notifies
- **File:line:** `lib/providers/app_state.dart:317-355`.
- **Risk:** MEDIUM (error-resilience, confidence 0.85). `loadData()` is fire-and-forget from `main.dart` and the resume handler; if any loader/`_autoRolloverBudgets`/`_calculateAndStoreCarryover` throws, `_safeNotify()` never runs → empty/stale Home, no error, no retry; the throw lands only in `runZonedGuarded → CrashLog`.
- **Steps:** Wrap the post-`_loadSettings` body so `_safeNotify()` runs in a `finally`; add a `bool _loadError` / `Object? lastLoadError` set in the `catch` so the home screen can surface a "failed to load, tap to retry" affordance (this also closes L53's observability concern). Note `isInitialized` is unused by the UI today, so the real win is "still notify with whatever loaded + surface the error", not a loading gate.
- **Acceptance:** with a loader forced to throw, Home renders whatever loaded and shows a retry path instead of a blank screen.

---

## Group 3 — Accessibility cluster (M8–M12, plus M13/M14 a11y items)

Play-Store accessibility-bar fixes. The project already ships `AccessibilityHelper.semanticIconButton` and the `Semantics(button:, selected:)` pattern in `glass_segmented_control.dart` / `glass_pill_chip.dart` — reuse, don't reinvent. Device not strictly required, but a TalkBack pass on `emulator-5554` is the real acceptance.

### M8. Every history tile wrapped in `StaggeredListItem` → per-item `AnimationController` + `Future.delayed`
- **File:line:** `lib/screens/history/history_list.dart:148-158` (this is a performance finding tagged accessibility-adjacent; see also Group 5).
- **Risk:** MEDIUM (perf, 0.8). Opening a busy month spawns dozens-to-hundreds of controllers + pending timers in one frame.
- **Steps:** Only wrap tiles in `StaggeredListItem` while the running index is below a small threshold (e.g. `< 12`); render the rest as the plain tile builder. Most impactful on the category-sort/all-time path. No correctness change.

### M9. `GlassPanel` BackdropFilter blur has no per-panel `RepaintBoundary`
- **File:line:** `lib/widgets/luminous/glass_panel.dart:31-54`.
- **Risk:** MEDIUM (perf, 0.78). Analytics stacks 5 live 15-sigma blurs; any panel repaint re-samples the whole backdrop.
- **Steps:** Bake a `RepaintBoundary` around the `ClipRRect`/`BackdropFilter` inside `GlassPanel` (and `GlassHeaderStrip`). Leave the existing manual boundaries at `home_screen.dart:347` and `main.dart:588` in place (not redundant). Separately, at `analytics_screen.dart:194-196` hoist the static `GlassPanel`/`Semantics`/labels into the `AnimatedBuilder` `child:` so the chart tween rebuilds only the `BarChart` — the larger per-frame win.

### M10. Bottom navigation bar never announces selected tab or button role
- **File:line:** `lib/widgets/luminous/floating_glass_nav_bar.dart:73-105`.
- **Risk:** MEDIUM (a11y, 0.85). The most-used control: bare `InkWell`s, no `button`/`selected` semantics — TalkBack can't say which tab is active.
- **Steps:** Wrap each destination `InkWell` (`:74`) in `Semantics(button: true, selected: selected, label: d.label, child: InkWell(...))`. Pass `d.label` (not the uppercased `Text`) so the reader doesn't spell "H-O-M-E".

### M11. Category-manager edit/delete are icon-only with no accessible label
- **File:line:** `lib/screens/category_manager_screen.dart:401-417`.
- **Risk:** MEDIUM (a11y, 0.9). Two adjacent unlabeled `IconButton`s, one destructive.
- **Steps:** Add `tooltip: 'Edit $category category'` (`:401-407`) and `tooltip: 'Delete $category category'` (`:410-416`) — on `IconButton` the tooltip doubles as the semantic label. `category` is a `String`, so use `$category`.

### M12. No `textScaler` clamp + fixed-height bars → clipping at large system font sizes
- **File:line:** `lib/main.dart:241-304` (single `MaterialApp`).
- **Risk:** MEDIUM (a11y, 0.8). At ~2.0 system font scale the `GlassTopAppBar` (height 64), home header `SizedBox(height: 56)`, and `GlassSegmentedControl` (height 40) clip.
- **Steps:** Add a `builder` to the `MaterialApp` at `:241`: `builder: (ctx, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!)`. One surgical change resolves the reported clipping. (Note: the blob-painting `builder` from Session 10's `6a14555` already lives here — compose the two, don't overwrite.)

### M13. Home month-navigation chevrons unlabeled and below 48dp
- **File:line:** `lib/screens/home_screen.dart:147-201` (40×40 `InkWell`s wrapping bare `Icon`s).
- **Risk:** MEDIUM (a11y, 0.92, verdict real). The center month label is correctly wrapped; the arrows are the inconsistent gap.
- **Steps:** Replace the two raw `InkWell`s (`:147-162`, `:186-201`) with `AccessibilityHelper.semanticIconButton(icon: Icons.chevron_left, label: 'Previous month', onPressed: () => context.read<AppState>().goToPreviousMonth())` and the `chevron_right` / 'Next month' counterpart — matching `budget_screen.dart:43-77`. Helper is already imported.

### M14. Swipe-to-delete in History has no equivalent action for screen-reader users
- **File:line:** `lib/screens/history/history_screen.dart:1214-1307` (expense ~1214, income ~1563).
- **Risk:** MEDIUM (a11y, 0.9, verdict real). Label promises "swipe left to delete" but a directional `Dismissible` swipe isn't performable via TalkBack; the interactive subtree is wrapped in `ExcludeSemantics`.
- **Steps:** Lift ALL handlers onto the outer `Semantics` node, not just delete: `onTap` (expense → `_showAddPaymentDialog`, income → `_showEditIncomeDialog`), `onLongPress` (→ edit), and a delete action via `onDismiss` or `CustomSemanticsAction('Delete')` that calls `_confirmDelete(...)` then `deleteExpense`/`deleteIncome`. Fixing delete alone leaves tap/long-press inaccessible.
- **Acceptance for the cluster:** Accessibility Scanner / TalkBack reports no unlabeled actionable elements on nav bar, category manager, home chevrons, history tiles, and PIN keypad backspace (L42); segmented-control and chevron targets >= 48dp.

---

## Group 4 — Money / correctness (M1/M3, M14 display, M15, M16)

### M1 / M3. `addPayment` auto-rounds sub-10¢ remaining to "fully paid" — records money never paid
- **File:line:** `lib/providers/app_state.dart:802-812` (auto-round-up branch `:807-809`; validator pre-blesses overshoot at `add_payment_dialog.dart:394`).
- **Risk:** MEDIUM (money-math, 0.9). Up to 9¢ fabricated per bill, invisible to the user; corrupts `getAvailableIncomeForMonth` (`:2210`), `totalPaid` (`:2205`), and CSV/PDF exports. **Confirm intent before fixing** (per Session 10 note + handoff).
- **Steps:** Remove the auto-round-up branch (`:807-809`) entirely. Keep the overpayment cap (`:804`) and the exact-amount else branch so `finalAmountPaid = newAmountPaidDecimal` records exactly what was paid. The "Pay All" button (`add_payment_dialog.dart:404`) already lets users clear a bill intentionally.
- **Acceptance:** a partial payment leaving 3¢ stores `amountPaid` short by 3¢; "Pay All" still clears to full. Add one unit test pinning both.

### M16. Visible currency amounts bypass locale-aware formatting (no thousands grouping)
- **File:line:** `lib/screens/home_screen.dart:850`; `history_screen.dart:1420/1437/1732`; `analytics_screen.dart:587/853/1013`. **Confirmed real on-device in Session 10** (visible `$2845.00` vs a11y label `$2,845.00`).
- **Risk:** MEDIUM (ui-ux-m3, 0.9). `AppState.formatWithCurrency()` is used for the Semantics labels (`home_screen.dart:630/665`) but visible amounts concatenate the raw symbol with `toStringAsFixed(2)` — the same number formatted two ways in one widget.
- **Steps:** Replace the inline `'${appState.currency}${x.toStringAsFixed(2)}'` patterns with `appState.formatWithCurrency(x)`, preserving leading `-`/`+` sign chars (the helper emits no sign for positives). For `analytics_screen.dart:853` (zero-decimal summary) use `formatWithCurrency(x, decimalDigits: 0)` per operand. `analytics_screen.dart:587` is a Semantics label (no visible mismatch) but use the same helper for consistency.
- **Acceptance:** a EUR/INR user sees grouped `1,234.56`/`1,23,456.78` on Home, History, Analytics matching the a11y label.

### M15. Wallet-tab FAB occluded by the global floating glass nav bar
- **File:line:** `lib/screens/wallet_screen.dart:55-60`; nav bar overlay at `main.dart:580-589`.
- **Risk:** MEDIUM (ui-ux-m3, 0.82, verdict real). Default-positioned FAB sits under the nav pill; on most phones the add-account "+" is partially/fully covered and untappable as the bottom safe-area grows.
- **Device needed:** YES (occlusion is device/safe-area dependent).
- **Steps:** Either move the add-account action into the `GlassTopAppBar` trailing slot (consistent with other Luminous headers — preferred), OR keep the FAB and add clearance via a `floatingActionButtonLocation` offset of ~`LuminousTokens.navBarHeightTotal` (80) + `MediaQuery.paddingOf(context).bottom`. The clearance MUST account for `paddingOf(context).bottom`, not a fixed literal.
- **Acceptance:** the add-account control is fully tappable on `emulator-5554` (and a tall + a zero-safe-area config).

---

## Group 5 — Performance (M3–M7)

All MEDIUM, all "compute off the hot path / virtualize". M3 here = the PDF/CSV isolate finding (the audit numbers M3 as performance; M1 above is the money one — see the audit doc's own numbering). Device verification folds into Stage 8.2 perf pass (Group 9).

### M5 (audit-labeled M5). PDF/CSV export runs full doc gen + zlib compression synchronously on the UI isolate
- **File:line:** `lib/utils/pdf_exporter.dart:355` (also `633, 877`); `csv_exporter.dart:131/244/338`. Pattern proven in `backup_helper.dart:482/622/1051`.
- **Risk:** MEDIUM (0.8). Multi-hundred-ms UI freeze for a few-hundred-to-1000-row report; the export spinner itself can't animate. Data source is the unbounded `getAll...ForBackup()` fetch (`export_data_screen.dart:528-529`).
- **Steps:** Move CPU-bound serialization into `compute()`. PDF: build the `pw.Document` + `pdf.save()` in a top-level isolate fn returning `Uint8List`, then `writeAsBytes` on the main isolate. CSV: run the `StringBuffer` loop in a top-level fn via `compute()` returning the final `String`, then `writeAsString`. Pass materialized `List<Expense>`/`List<Income>` + scalar params (symbol, code, separator, dates) — all isolate-transferable.

### M6. Analytics `BudgetProgress` is O(budgets × allExpenses + recurring) per rebuild
- **File:line:** `lib/screens/analytics_screen.dart:817-818` → `getSpentForCategory` → `getBudgetSpentBreakdown` (`app_state.dart:1076`).
- **Risk:** MEDIUM (0.82). `getExpensesForSelectedMonth()` is uncached (`app_state.dart:823`); per-budget `.map()` re-scans every expense + loops all recurring, on every rebuild.
- **Steps:** Compute spend once before the `budgets.map()` loop: build the actual-spend map in a single pass (`getCategorySpending()`) AND project recurring per category once outside the loop (mirroring `app_state.dart:1078-1092`) — `getCategorySpending()` alone omits projected recurring. Then look up `spent = (actual[cat] ?? 0) + (projected[cat] ?? 0)` inside `map()`. More robust: add `getBudgetSpentBreakdownAll()` returning a per-category map in one pass, called via `context.select`.

### M7. History grouped list builds an entire group's items eagerly in one non-virtualized `ListView` item
- **File:line:** `lib/screens/history/history_list.dart:131-159`.
- **Risk:** MEDIUM (0.85). `ListView.builder` virtualizes only at the group-header level; a category-sort buckets up to 1000 items into a few giant `Column`s, defeating virtualization.
- **Steps:** In `_buildGrouped`, replace the per-group `Column` with a flattened index space — precompute a flat list of header rows interleaved with item rows from `sortedKeys + grouped`, then drive the outer `ListView.builder`'s `itemCount`/`itemBuilder` over that flat index so each header and tile is its own lazily-built child. `_buildFlat` already does this and is the structural template. (Pairs with M8's controller cap above.)

### M8. (perf half — see Group 3 for the listing) — cap `StaggeredListItem` count.

- **Acceptance for Group 5:** DevTools timeline on `emulator-5554` shows export no longer blocks the UI thread; Analytics rebuild does a single category scan; History scroll with 500 expenses holds 60fps (verified in Group 9 perf pass).

---

## Group 6 — Remaining MEDIUM + the LOW tail (summarize; full detail in the audit doc)

Every finding below has a file:line + surgical fix in `docs/AUDIT_FINDINGS_2026-06.md`. Many are explicitly "optional cleanup / leave-as-is" per the refute pass — do them opportunistically when already in the file, not as standalone commits, except where flagged load-bearing.

**Money (LOW):** L22 budget-progress ratio in `double` not `Decimal` (`app_state.dart:1163,1178`); L23 CSV export totals drift via `double +=` (`csv_exporter.dart:99-103,219-221,286-300` — accumulate in `Decimal`); L24 edit-screen amount seed from `double.toString()` (`add_transaction_screen.dart:115,117,130` — cosmetic, use `toStringAsFixed(2)`).

**State-lifecycle (LOW):** L25 `switchAccount`/`loadData` not mutually serialized (`app_state.dart:1489-1508` / `312-355` — add a dedicated mutex, NOT `_writeMutex`); L26 `registerInteractivityCallback` dead — widget taps never routed (`home_widget_helper.dart:154-170` — confirm intent, wire or delete); L27 unguarded leading `setState` in analytics `_loadTrends` (`analytics_screen.dart:135-138` — add `if (!mounted) return;`).

**Database (LOW):** L28 `deleteAccount` non-atomic tag purge (`database_helper.dart:1401-1483` — delete the redundant `transaction_tags` block `:1429-1468`, triggers already cover it); L29 v19 pre-migration backup copies open WAL (`database_helper.dart:762-772` — `PRAGMA wal_checkpoint(TRUNCATE)` before `live.copy`); L30 `getDeletedAccounts()` has destructive 30-day purge on a read path (`database_helper.dart:1560-1597` — extract `purgeExpiredDeletedAccounts()` into `performMaintenance`); L31 budget restore accepts unvalidated month strings (`database_helper.dart:3684-3713` — add `RegExp(r'^\d{4}-\d{2}')` guard); L32/L36 raw `.db` restore skips schema-version trust check (**actual location `lib/utils/backup_helper.dart`**, after `_validateSqliteHeader` ~L765, before `rename` L784 — read `user_version` at byte offset 60, reject if > `DatabaseConstants.databaseVersion`); L33 `_rebuildTableWithAccountCascade` raw-SQL identifier interpolation (`database_helper.dart:942-955` — no functional fix needed; optional `assert` + explicit `CREATE` build); L34 `.pre_restore` cleanup via in-memory `Future.delayed(7 days)` never fires (**actual location `backup_helper.dart:792-796` + `1156-1160`** — sweep from `cleanOrphanedBackupFiles()` instead); L52 `PRAGMA foreign_keys=OFF` is a no-op inside the migration transaction (`database_helper.dart:783-786,917` — replace with `txn.execute('PRAGMA defer_foreign_keys = ON')` as the first statement inside the `db.transaction` callback — **load-bearing: a pre-v19 DB with orphaned rows can fail the upgrade and brick the app**); L54 comprehensive-restore unguarded rollback (`backup_helper.dart:1111-1177` — wrap rollback steps `1166-1176` in their own try/catch); L55 comprehensive-backup `as String` cast with no type guard (`backup_helper.dart:101-103` — typed guard + map `FormatException` to `RestoreResult.invalidFile`).

**Security (LOW):** L35 PIN lockout in-app only / no backoff (`pin_security_helper.dart:94-129` — optional escalating backoff; NOT a substitute for H2); L37 unsalted legacy hash never force-migrated on unlock (`pin_security_helper.dart:110-117` — **fold into H2's migrate-on-verify**, re-derive via PBKDF2 when `storedSalt == null` and PIN verifies).

**Accessibility (LOW):** L42 PIN keypad backspace + PIN-dot indicator no semantics (`pin_unlock_screen.dart:258-308,136-161` — `Semantics(button:true,label:'Delete')` on backspace, optional `liveRegion` value on dots); L43 backup/restore close + bulk-delete + per-row delete icon-only (`backup_restore_screen.dart:1187,1203,1624` — add tooltips); L44 segmented-control segment 40dp < 48dp (`glass_segmented_control.dart:115-124` — `BoxConstraints(minHeight:48)` around the InkWell, keep 40dp painted pill); L45 donut legend color-only (`glass_donut_chart.dart:150-177` — pre-emptive only; live analytics donut already labeled).

**UI/UX-M3 (LOW):** L46 nav-bar selected label never gets active color (`floating_glass_nav_bar.dart:98` — `color: selected ? active : inactive`, verdict real); L47 home inset tiles + avatar ring hardcoded white wash out in dark mode (`home_screen.dart:599-602,70-71` — branch on `brightness`); L48 history delete-error snackbar uses `Colors.red` not `appColors.expenseRed` (`history/history_screen.dart:1254,1282`); L49 home empty-state can hide behind nav bar (`home_screen.dart:286-333` — add `navBarHeightTotal + paddingOf().bottom` bottom inset); L50 analytics loading placeholder is opaque box not `GlassPanel` (`analytics_screen.dart:161-172`, verdict real); L51 payment-method tag colors hardcoded Material swatches (`history/history_screen.dart:1752-1762` — map to `colorScheme` roles, verdict real).

**Error-resilience (LOW):** L53 startup `loadData()`/`initializeLockState()` not awaited (`main.dart:140-145` — drop the security claim; app fails closed via `_isLocked` default; only add an optional `.catchError` for retry UX — **folds into M17**).

**Dead-code / deps (LOW):** L56 five dead premium-animation widgets (`premium_animations.dart:202,494,627,679,731` — delete `ScaleTapAnimation`, `ShimmerLoading`, `AnimatedProgressBar`, `PulsingDot`, `AnimatedThemeWrapper`; keep the referenced ones); L57 `ProgressIndicatorHelper.showWithProgress`/`showDuring` never called (`progress_indicator_helper.dart:29,99` — delete); L58 triplicated contrast-text logic (`analytics_screen.dart:747-755` — low priority; consolidating is a visual change, re-screenshot if done); L59 `DecimalHelper` 17 unused arithmetic helpers (`decimal_helper.dart:96-195` — **do NOT remove `clamp` at :191**, it's used by `parse()` → `quick_templates_screen.dart:500`); L60 `AccessibilityHelper` 7 prod-unused statics (`accessibility_helper.dart` — optional); L61 `ColorContrastHelper` WCAG helpers prod-unused (`color_contrast_helper.dart:46,51,56,73` — optional; don't bundle with the analytics redirect).

**Cross-cutting cleanups (from FINISH_LINE §9 / NEXT_STEPS §7, none blocking):** populate or remove `dist/baseline/v4.4.0+6.db` + `dist/baseline/perf/`; verify `.v18-backup` auto-clean ran on a Stage-A device; `pubspec.lock` audit after SQLCipher lands; re-enable the two `_skipped` widget tests (`TRASH/analytics_screen_test.dart_skipped`, `TRASH/notification_settings_screen_test.dart_skipped`) during D.2; update the `pubspec.yaml` "A new Flutter project." description.

---

## Group 7 — Phase 6.1 SQLCipher migration (HIGH data-loss risk)

- **CHECKLIST item 6.1 (the only open Phase-6 item).** Encrypt the on-disk DB at rest with a 256-bit Keystore-backed key. Mid-flight rekey failure would leave the user without their data — the `.pre-sqlcipher-backup` + row-count verification is the non-negotiable safety net.
- **Risk:** HIGH (R2/R11 in the risk register — data loss).
- **Device needed:** YES (`sqflite_sqlcipher` has no FFI analog; the encrypted-open assertions are device-only).
- **Steps:**
  1. **Dep swap** (`pubspec.yaml`): add `sqflite_sqlcipher: ^3.0.0`, keep `sqflite_common_ffi: ^2.3.3` for tests, remove `sqflite: ^2.3.3`. Swap both import sites: `lib/database/database_helper.dart` and `lib/utils/backup_helper.dart` → `package:sqflite_sqlcipher/sqflite.dart`. `flutter pub get`, `flutter analyze` (API is identical except the `password:` arg on `openDatabase`).
  2. **Key gen/storage** — new `lib/utils/db_encryption.dart`: `DbEncryption.getOrCreateKey()` returns the existing base64 key from `SecurePrefs.readString('db_encryption_key')` or generates 32 bytes via `Random.secure()` and stores it. 3 unit tests (`test/utils/db_encryption_test.dart`): same value across calls, decodes to 32 bytes, persists across SecurePrefs instances.
  3. **Migration** in `DatabaseHelper._initDatabase()`: when `!hasKey && plaintextExists`, (a) `File(dbFile).copy(backupFile)` to `expense_tracker_v4.db.pre-sqlcipher-backup`; (b) `preCounts = _rowCounts(dbFile)`; (c) generate key; (d) `ATTACH DATABASE '<enc>' AS encrypted KEY '<key>'` → `SELECT sqlcipher_export('encrypted')` → `DETACH`; (e) open the encrypted file with `password:` and take `postCounts`; (f) if `_countsMatch` → delete plaintext, rename enc → `dbFile`, leave the `.pre-sqlcipher-backup` until next successful launch; ELSE → `CrashLog.write('SQLCipher migration verification failed; row counts differ')`, delete the enc file, **keep the plaintext DB** (fall back). Helpers `_rowCounts(dynamic)` and `_countsMatch(a,b)` per FINISH_LINE §C.3.
  4. **Cleanup**: `_cleanPreSqlcipherBackupAfterSuccess()` deletes the `.pre-sqlcipher-backup` from the second-launch path after a successful encrypted open; idempotent.
  5. **Tests** (`test/integration/sqlcipher_migration_test.dart`): migration from plaintext (5 expenses + 3 income + 1 budget → row counts match); verification-failure path (inject divergence → plaintext preserved + CrashLog entry + no enc file); subsequent launch returns the encrypted DB, key not regenerated; plus a `_isPlaintextDatabase(File)` unit test. Encrypted-open assertions skip in unit tests (no plugin on the test runner) and move to device.
- **Device smoke (emulator-5554):** install on a build that already has v4.4.0 data (or seed rows in a pre-C build); open → expect a 1–3s startup delay (the export); add a transaction → save works; `adb shell run-as com.moneytracker.app sqlite3 databases/expense_tracker_v4.db ".tables"` → must return `Error: file is not a database`.
- **Acceptance:** all 3 integration tests pass + device smoke passes; APK size delta within +5 MB; no data loss when scrolling history after upgrade. After it lands, run `flutter pub upgrade --major-versions` once and review (don't auto-accept).

---

## Group 8 — D.3 golden tests for the 8 hero screens

- **CHECKLIST 7.8 / FINISH_LINE Stage D.3.** D.2 (hero-screen widget tests with seeded data) is **already done** (Session 9, `1efcd72`), so goldens are now unblocked.
- **Risk:** LOW.
- **Device needed:** NO (Windows-locked goldens).
- **Steps:** For each hero screen (Settings, Wallet, Budgets, Analytics, Add Transaction, History, Recurring Items, Home) run `flutter test --update-goldens test/screens/<name>_test.dart`. Lock goldens to Windows (the dev platform); document in `test/golden/README.md`. CI at 2% pixel-diff tolerance (`matchesGoldenFile(name, tolerance: 0.02)`).
- **Caveats:** don't golden relative-time strings — wrap in `withClock(FakeClock.fixed(...), () => ...)`. Skip the notifications-permission screen (platform popups aren't golden-able). Use `pumpAndSettle` (or bounded pump) to drain `FadeInOnLoad`/`BounceAnimation` so no timer is pending after dispose.
- **Acceptance:** goldens committed; a second run passes within tolerance; preflight green.
- **Commit:** `test(phase-7.d3): golden tests for 8 hero screens`.

---

## Group 9 — 8.2 device performance pass

- **CHECKLIST 8.2 / FINISH_LINE Stage E.1.** Validates the Group 5 perf fixes landed.
- **Risk:** MEDIUM.
- **Device needed:** YES (`emulator-5554`, or a Pixel 4a-class device for a truer read).
- **Steps:** DevTools Performance overlay across: Home scroll w/ 100 expenses (every frame <= 16.7 ms steady-state); History scroll w/ 500 expenses; rapid tab switching Home <-> History <-> Add <-> Analytics <-> Wallet (no jank); Analytics first paint (no dropped frames). On regression: profile with `dart:developer.Timeline`, fix before tagging; documented rollback = bump blur radius back to 10 (was reduced for perf in Phase 1.7).
- **Acceptance:** steady-state 60fps on all four flows after the Group 5 fixes; first frame <= 100 ms.

---

## Group 10 — 8.4 version bump 4.4.0+6 → 5.0.0+1 + CHANGELOG

- **CHECKLIST 8.4 / audit L62.** `pubspec.yaml:6` is still `4.4.0+6` (confirmed); CHANGELOG top entry is `4.4.0+6 — 2026-04-14`. Eight phases of work have landed since. The build-number increment is load-bearing (`+6` would collide with the already-shipped artifact; Play Store/sideload would treat it as the same build); `main.dart` already resolves the version dynamically from the bundle, so no runtime code change.
- **Risk:** LOW (do as the final pre-tag commit, not mid-work).
- **Device needed:** NO.
- **Steps:**
  1. `pubspec.yaml:6`: `version: 5.0.0+1` (was `4.4.0+6`).
  2. Add a `## 5.0.0` CHANGELOG entry covering **Added** (Luminous redesign across every screen, FinanceFlow branding, encrypted backup files, encrypted DB at rest [SQLCipher], FLAG_SECURE widget, crash-log PII redaction, recurring-items unified screen, history split, segmented Add-Transaction toggle, notification tap routing + honored reminder time), **Changed** (schema v18→v19 cascades/triggers/month-key normalization, atomic carryover mutators, narrow `context.select` on hero screens, Hanken Grotesk variable font / `google_fonts` removed), **Fixed** (loadData coalescing race, pruneDistantMonths loop, pushNamed fallback, HomeWidget race, force-close-on-backgrounded-write, **black-background regression**, **H1 re-lock-on-resume**, locale currency grouping [M16], addPayment sub-10¢ over-record [M1], notification scheduling [M20/M21]), **Security** (PIN secrets → Keystore, **PIN PBKDF2 100k [H2]**, AES-GCM backup envelopes + passphrase UX, SQLCipher 256-bit DB encryption, constant-time PIN compare).
  3. Commit `chore(release): bump version to 5.0.0+1` (Co-Authored-By trailer). Tag `git tag v5.0.0+1` but **do NOT push the tag until the APK ships** (Group 11).
- **Acceptance:** `package_info_plus` reports 5.0.0 in-app; CHANGELOG has the v5.0.0 section; CHECKLIST 8.4 ticked.

---

## Group 11 — 8.5 ship pipeline (build → landing → push → vercel → SHA-1 → release → fast-forward main)

- **CHECKLIST 8.5 / FINISH_LINE Stage E.3–E.5.** The ship gate. **Vercel Git integration is DISCONNECTED for `expense-tracker-landing`** — `vercel --prod --yes` is required; `git push` alone does NOT deploy (project `money-tracker-app`, requires Vercel CLI >= 47.2.2).
- **Risk:** MEDIUM.
- **Device needed:** YES for the final post-ship smoke.
- **Steps (run from the Money-Tracker dir):**
  1. Build + copy + commit + push + deploy:
     ```bash
     flutter build apk --release && \
     cp build/app/outputs/flutter-apk/app-release.apk \
        /c/Users/leooa/Documents/personal-projects/expense-tracker-landing/public/downloads/money-tracker.apk && \
     git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing add public/downloads/money-tracker.apk && \
     git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing commit -m "chore: ship v5.0.0+1 — FinanceFlow Luminous" && \
     git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing push && \
     (cd /c/Users/leooa/Documents/personal-projects/expense-tracker-landing && vercel --prod --yes)
     ```
  2. **SHA-1 parity** (mandatory `/ship-verify` gate — never trust UP-TO-DATE): `curl -sL https://leo-money-tracker.vercel.app/downloads/money-tracker.apk | sha1sum` must equal `sha1sum build/app/outputs/flutter-apk/app-release.apk`. If mismatched, wait 30s for CDN propagation and re-curl; if still off, check the Vercel deployment log.
  3. Push branch + tag, then cut the release:
     ```bash
     git push origin release/v5.0.0
     git push origin v5.0.0+1
     gh release create v5.0.0+1 --title "v5.0.0+1 — FinanceFlow Luminous" \
       --notes-file CHANGELOG.md build/app/outputs/flutter-apk/app-release.apk
     ```
  4. Fast-forward `main`: `git checkout main && git merge --ff-only release/v5.0.0 && git push origin main && git checkout release/v5.0.0`. If a non-FF is needed (someone touched `main`), open a PR to `main` instead.
  5. **Post-ship device smoke (emulator-5554):** download the live APK, install on a previously-unupgraded device, run the 5-minute MASTER_PLAN §8.3 flow — onboarding → add expense → add income → set budget → backup-with-passphrase → restore → enable PIN → background→resume unlock → force-stop→reopen unlock.
- **Acceptance (= ship gate / Definition of Done):** tag `v5.0.0+1` on origin and on `main` (same SHA); landing page serves the APK at the verified SHA-1; GitHub release exists with the APK attached; 5-minute device smoke passes end-to-end; `release/v5.0.0` fast-forward-merged into `main`.

---

### Execution sequencing
H2 (Group 1) → notifications (Group 2) → a11y (Group 3) → money/correctness (Group 4) → perf fixes (Group 5) → opportunistic LOW tail (Group 6) → **SQLCipher (Group 7, device, highest data-loss risk — do against a stable codebase)** → goldens (Group 8) → perf pass (Group 9, validates Group 5) → version bump (Group 10) → ship (Group 11). Groups 1–6 are largely parallel-safe and device-optional except H2/M15 device smokes; Groups 7/9/11 require the emulator; Group 10 is the final pre-tag commit. Tag `v5.0.0+1` only after Group 11's post-ship smoke passes.


---

# Comprehensive Per-Function Test Plan

> **Test mandate:** close every ❌ Missing and 🟡 Partial entry below (or justify a deferral in the PR). These specs were generated by mapping the actual source against the existing test suite, file by file. Reuse the harness patterns in §2 of the preamble. Ratchet `scripts/preflight.sh` `TEST_COUNT_MIN` after each batch. Several entries also surface real source defects (e.g. nav-bar Semantics, unguarded `fromMap` TypeErrors) — fix the source as you add the pinning test.

## Data Models (lib/models/)

Cross-cutting notes that apply to every model below:
- **No model overrides `==` / `hashCode`.** All ten classes use Dart identity equality. Existing tests correctly compare field-by-field rather than asserting `a == b`. There is no equality/hashCode to cover, so it is not listed as a gap — but any future `Set<Model>` / `contains` / de-dup logic will silently rely on identity. Flagged once here, not repeated per file.
- **Money is `package:decimal` `Decimal`.** Amounts are stored in a private `_amount` field; the public `amount` getter returns `double` via `DecimalHelper.toDouble`, and `amountDecimal` returns the exact `Decimal`. `toMap` writes a `double` (SQLite REAL); `fromMap` reads via `DecimalHelper.fromDoubleSafe((map['x'] as num?)?.toDouble())`.
- **Decimal precision ceiling = 2 dp on any DB round-trip.** `DecimalHelper.fromDouble` does `Decimal.parse(clamped.toStringAsFixed(2))` and clamps to ±999999999.99. So a `Decimal.parse('100.999')` passed to a constructor survives *in memory* (`amountDecimal` == `100.999`) but is truncated to `101.00`/`100.99`-style 2dp after `toMap`→`fromMap`. No model test asserts this lossy boundary explicitly — listed as a shared gap under each Decimal-bearing model's round-trip entry.
- **Dates are UTC-midnight ISO strings.** `toMap` uses `DateHelper.toDateString` (YYYY-MM-DD) for day-dates and `DateHelper.toMonthString` (YYYY-MM) for `MonthlyBalance.month`. `fromMap` uses `DateHelper.parseDate`, which `DateTime.parse`s then `normalize`s to `DateTime.utc(y,m,d)`. Invalid/empty strings → `null` → model-specific fallback (usually `today()` / start-of-month).
- **snake_case DB keys**: `account_id` everywhere; but `isDefault`, `currencyCode`, `amountPaid`, `paymentMethod`, `dayOfMonth`, `isActive`, `lastCreated`, `maxOccurrences`, `occurrenceCount`, `frequency`, `startDate`, `endDate`, `sortOrder` are **camelCase** in the maps (legacy column names). This asymmetry is load-bearing and a frequent foot-gun; round-trip tests cover it implicitly.

---

### `lib/models/account_model.dart`

- **`Account({id, required name, icon, color, isDefault = false, currencyCode = 'USD'})`** — ✅ Covered
  - Default unnamed constructor; `name` required, rest optional with defaults.
  - Test cases:
    1. All fields set → each getter returns the supplied value
    2. Only `name` → `id`/`icon`/`color` null, `isDefault` false, `currencyCode` 'USD'
    3. (n/a — `name` has no compile-time guard; empty-string name is allowed by the constructor, only `fromMap` rejects it)
  - Existing coverage: `account_model_test.dart` group `constructor` covers all-fields + each individual default.

- **`Map<String,dynamic> toMap()`** — ✅ Covered
  - Serializes all six fields; `isDefault` → 1/0.
  - Test cases:
    1. Full object → map has `id,name,icon,color,isDefault(1),currencyCode`
    2. `isDefault:false` → 0; `isDefault:true` → 1
    3. null id/icon/color preserved as null; default currencyCode 'USD'
  - Existing coverage: group `toMap()` covers all of the above.

- **`factory Account.fromMap(Map)`** — ✅ Covered
  - Validates `name` (non-null, non-empty) → else `ArgumentError`; `isDefault == 1` → bool; `currencyCode ?? 'USD'`.
  - Test cases:
    1. Complete map → all fields; `isDefault:1`→true
    2. Missing/null `currencyCode` → 'USD'; missing `isDefault` → false; null/missing id → null
    3. null name / missing name / empty-string name → throws `ArgumentError` (message mentions "name")
  - Existing coverage: groups `fromMap()` + `fromMap() validation` cover happy path, defaults, and all three throw cases plus message assertion.

- **`Account copyWith({id, name, icon, color, isDefault, currencyCode})`** — ✅ Covered
  - Field-wise override with `?? this.x`.
  - Test cases:
    1. Each field overridden individually, others preserved
    2. `copyWith()` with no args → exact field copy
    3. (edge) copyWith cannot set a non-null field back to null — by design; no test needed (no clear flags on this model)
  - Existing coverage: group `copyWith()` overrides every field + no-arg preservation.

- **Round-trip (`toMap`→`fromMap`)** — ✅ Covered
  - Test cases: full object incl. non-ASCII currency; null-optional object; non-USD currency.
  - Existing coverage: group `round-trip serialization`, 3 tests.

#### File summary: 4 public members (+round-trip). All ✅.

---

### `lib/models/category_model.dart`

- **`Category({id, required name, required accountId, isDefault = false, type = 'expense', color, icon})`** — ✅ Covered
  - `type` is a free-form String ('expense'/'income'); no enum guard.
  - Test cases:
    1. All fields; 2. defaults (id null, isDefault false, type 'expense', color/icon null); 3. `type:'income'` accepted.
  - Existing coverage: group `constructor`, 7 tests.

- **`Map toMap()`** — ✅ Covered
  - `account_id` snake_case; `isDefault` 1/0; `type`/`color`/`icon` verbatim.
  - Test cases: full; isDefault 1/0; null id/color/icon; `account_id` key present.
  - Existing coverage: group `toMap()`, 8 tests.

- **`factory Category.fromMap(Map)`** — ✅ Covered
  - Validates `name` (non-null/non-empty) AND `accountId` (non-null) → `ArgumentError`; `type ?? 'expense'`.
  - Test cases:
    1. Complete map; income type; defaults for missing type/isDefault
    2. null/missing id, null color+icon
    3. null/missing/empty name → throw; null/missing account_id → throw; messages mention "name"/"account_id"
  - Existing coverage: groups `fromMap()` + `fromMap() validation`, comprehensive (both required-field throws + message checks).

- **`Category copyWith({id, name, accountId, isDefault, type, color, icon})`** — ✅ Covered
  - Test cases: each field overridden; no-arg preservation.
  - Existing coverage: group `copyWith()`, 8 tests.

- **Round-trip** — ✅ Covered
  - Test cases: full; null-optional; income type.
  - Existing coverage: group `round-trip serialization`, 3 tests.

#### File summary: 4 public members (+round-trip). All ✅.

---

### `lib/models/tag_model.dart`

- **`Tag({id, required name, color, required accountId})`** — ✅ Covered
  - Test cases: all fields; id null default; color null default.
  - Existing coverage: group `constructor`, 3 tests.

- **`Map toMap()`** — ✅ Covered
  - Four keys: `id, name, color, account_id`.
  - Test cases: full; null id; null color; `account_id` key present.
  - Existing coverage: group `toMap()`, 4 tests.

- **`factory Tag.fromMap(Map)`** — ✅ Covered
  - Validates `name` + `accountId`; explicit `as int?` / `as String?` casts.
  - Test cases:
    1. Complete map; 2. null/missing id, null/missing color; 3. null/missing/empty name → throw, null/missing account_id → throw, message assertions.
  - Existing coverage: groups `fromMap()` + `fromMap() validation`, comprehensive.

- **`Tag copyWith({id, name, color, accountId})`** — ✅ Covered
  - Test cases: each field; no-arg preservation.
  - Existing coverage: group `copyWith()`, 5 tests.

- **Round-trip** — ✅ Covered
  - Test cases: full; null-optional.
  - Existing coverage: group `round-trip serialization`, 2 tests.

#### File summary: 4 public members (+round-trip). All ✅.

---

### `lib/models/income_model.dart`

- **`Income({id, required Decimal amount, required category, required description, required date, required accountId})`** — ✅ Covered
  - Stores `_amount`; no amountPaid (cf. Expense).
  - Test cases: all fields; id null default; `amount` getter is `double`; `amountDecimal` is exact `Decimal`.
  - Existing coverage: group `constructor`, 4 tests.

- **`double get amount`** — ✅ Covered (returns `DecimalHelper.toDouble(_amount)`). Asserted in constructor group + every toMap test.

- **`Decimal get amountDecimal`** — ✅ Covered. Asserted to equal `Decimal.parse('5000.00')` and in copyWithDecimal.

- **`Map toMap()`** — ✅ Covered
  - `amount` → double, `date` → 'YYYY-MM-DD', `account_id` snake_case (and asserts `accountId` key absent).
  - Test cases: full; null id; zero amount; ISO date string; snake_case key + camelCase absent.
  - Existing coverage: group `toMap()`, 5 tests.

- **`static Income? tryFromMap(Map)`** — 🟡 Partial
  - Wraps `fromMap` in try/catch, returns null on `ArgumentError`.
  - Test cases:
    1. Valid map → non-null Income (NOT TESTED — only the null branch is)
    2. Empty map / missing category / missing account_id → null (missing)
    3. Map that triggers a non-`ArgumentError` (e.g. `account_id` present but a `String` → `TypeError` from `as int`) → does it propagate or swallow? `tryFromMap` only catches `ArgumentError`, so a type-mismatch row would still throw and kill the bulk read (missing)
  - Existing coverage: **none in `income_model_test.dart`** — there is no `tryFromMap` test for Income at all (the Expense test file has one for `Expense.tryFromMap`, but Income's is uncovered). GAP.

- **`factory Income.fromMap(Map)`** — 🟡 Partial
  - Validates `category` + `accountId`; `description ?? ''`; `date` fallback to `today()`; `amount` via `fromDoubleSafe`.
  - Test cases:
    1. Complete map; integer amount via num; null id
    2. null/empty category → throw (with exact message 'Income category is required'); null account_id → throw ('Income account_id is required'); null amount → 0; null/invalid date → today
    3. **`accountId` present but wrong type (String/double)** → `as int` cast throws `TypeError` not `ArgumentError` (missing); **`category` present but a non-String** (e.g. int) → `category is String && isEmpty` is false so it passes validation then `as String` throws `TypeError` (missing)
  - Existing coverage: groups `fromMap()` + `fromMap() validation` cover happy/defaults/required-throws/messages. Missing: malformed-type rows (TypeError path).

- **`Income copyWith({id, amount(double), category, description, date, accountId})`** — ✅ Covered
  - `amount` is `double?`; if non-null wraps via `fromDouble` (2dp truncation applies).
  - Test cases: each field; no-arg preservation.
  - Existing coverage: group `copyWith()`, 7 tests.

- **`Income copyWithDecimal({id, amount(Decimal), category, description, date, accountId})`** — ✅ Covered
  - Test cases: Decimal amount preserved exactly; no-arg preservation.
  - Existing coverage: group `copyWithDecimal()`, 2 tests.

- **Round-trip** — 🟡 Partial
  - Test cases: full object; large amount (999999999.99 within clamp).
  - Missing: 3-dp Decimal (`Decimal.parse('100.999')`) → assert it truncates to 2dp after round-trip (lossy boundary undocumented by a test); negative amount round-trip.
  - Existing coverage: group `edge cases` round-trip + large-amount.

#### File summary: 8 public members. 6 ✅, 2 🟡 (`tryFromMap`, `fromMap`). Highest-priority gaps: `Income.tryFromMap` has zero tests; `fromMap` untested for malformed-type rows (TypeError leaks past `tryFromMap`'s ArgumentError-only catch).

---

### `lib/models/expense_model.dart`

- **`Expense({id, required Decimal amount, required category, required description, required date, required accountId, Decimal? amountPaid, paymentMethod = 'Cash'})`** — ✅ Covered
  - `_amountPaid` defaults to `Decimal.zero`.
  - Test cases: all fields; amountPaid default 0; paymentMethod default 'Cash'; id null; Decimal getters exact.
  - Existing coverage: group `constructor`, 5 tests.

- **`double get amount` / `double get amountPaid`** — ✅ Covered (asserted in constructor + toMap).
- **`Decimal get amountDecimal` / `Decimal get amountPaidDecimal`** — ✅ Covered.

- **`bool get isPaid`** — ✅ Covered
  - `_amountPaid >= _amount` (exact Decimal comparison).
  - Test cases:
    1. paid == amount → true; 2. overpaid → true; underpaid (99.99 vs 100.00) → false; zero paid → false; both zero → true
    3. precision boundary (99.999 never == 100.00) — covered by the dedicated "avoids floating-point bug" test
  - Existing coverage: group `computed properties > isPaid`, 6 tests.

- **`double get remainingAmount` / `Decimal get remainingAmountDecimal`** — ✅ Covered
  - Test cases: partial (50.25); fully paid → 0; nothing paid → full; overpaid → negative; Decimal variant exact.
  - Existing coverage: group `remainingAmount`, 5 tests.

- **`double get paymentProgress`** — ✅ Covered
  - Guards `_amount < 0.01` → 0; else clamps `(_amountPaid/_amount)` to [0,1].
  - Test cases: half→0.5; full→1.0; overpaid clamps 1.0; nothing→0.0; amount zero→0.0; amount 0.005 (<0.01)→0.0
  - Existing coverage: group `paymentProgress`, 6 tests. (Note: negative `_amountPaid` clamp-to-0 branch is logically covered by the clamp but not separately tested — low priority.)

- **`Map toMap()`** — ✅ Covered
  - `amount`+`amountPaid` doubles; `date` 'YYYY-MM-DD'; `account_id` snake_case; `amountPaid`/`paymentMethod` camelCase.
  - Test cases: full; null id; zero amount+amountPaid; ISO date; empty description.
  - Existing coverage: group `toMap()` + edge case.

- **`static Expense? tryFromMap(Map)`** — 🟡 Partial
  - Catches `ArgumentError`, returns null.
  - Test cases:
    1. Valid map → non-null (NOT explicitly tested — only null branches)
    2. Empty map → null; map missing category but has amount/date → null (both tested)
    3. Type-mismatch row (`account_id` as String) → `TypeError` escapes (not caught) — untested
  - Existing coverage: group `fromMap() > tryFromMap returns null on missing required fields` covers the two null cases. Missing: positive case + TypeError-leak case.

- **`factory Expense.fromMap(Map)`** — 🟡 Partial
  - Phase-4.10: validates `category` + `accountId`; `description ?? ''`; `date` → today fallback; `amountPaid` → 0; `paymentMethod ?? 'Cash'`.
  - Test cases:
    1. Complete map; integer amount; null id
    2. missing category → throw; missing account_id → throw; null amount→0; null/invalid date→today; null amountPaid→0; null paymentMethod→Cash; empty map → throw
    3. malformed-type rows (account_id as String, category as int) → `TypeError` (missing); amountPaid present but negative — allowed, surfaces via isPaid (covered indirectly)
  - Existing coverage: group `fromMap()`, thorough on required/defaults/empty. Missing: TypeError path; error-message text assertion (Income has it, Expense doesn't).

- **`Expense copyWith({...double amount/amountPaid...})`** — ✅ Covered
  - Test cases: every field individually; no-arg preservation.
  - Existing coverage: group `copyWith()`, 9 tests.

- **`Expense copyWithDecimal({...Decimal amount/amountPaid...})`** — ✅ Covered
  - Test cases: Decimal amount; Decimal amountPaid; no-arg preservation.
  - Existing coverage: group `copyWithDecimal()`, 3 tests.

- **Round-trip** — 🟡 Partial
  - Test cases: full object preserved.
  - Missing: 3-dp amount truncation assertion; round-trip where `amountPaid > amount` then re-check `isPaid` survives.
  - Existing coverage: group `edge cases > roundtrip`.

#### File summary: 13 public members (counting getters). 10 ✅, 3 🟡 (`tryFromMap`, `fromMap`, round-trip). Highest-priority gaps: `tryFromMap`/`fromMap` malformed-type (TypeError leaks past ArgumentError-only catch — the documented bulk-read safety contract is therefore incomplete); `tryFromMap` positive case unasserted.

---

### `lib/models/budget_model.dart`

- **`Budget({id, required category, required Decimal amount, required accountId, required month})`** — ✅ Covered
  - Test cases: all fields; id null; `amount` getter double; `amountDecimal` exact.
  - Existing coverage: group `constructor`, 4 tests.

- **`double get amount` / `Decimal get amountDecimal`** — ✅ Covered.

- **`Map toMap()`** — ✅ Covered
  - `amount` double; `account_id` snake_case; `month` via `toDateString` (YYYY-MM-DD — note: Budget keeps full date, unlike MonthlyBalance which uses YYYY-MM).
  - Test cases: full; null id; zero amount; snake_case key; month ISO string.
  - Existing coverage: group `toMap()`, 5 tests.

- **`factory Budget.fromMap(Map)`** — ✅ Covered
  - `month`: null→start-of-current-month, String→parseDate, int→epoch+normalize, other→start-of-month. `category ?? 'Uncategorized'`. **Phase 4.11: `account_id` required (no camelCase fallback)** → `ArgumentError`. `amount` via fromDoubleSafe.
  - Test cases:
    1. Complete (string date); int amount via num
    2. null id; missing category→'Uncategorized'; null amount→0; month null/missing/invalid/wrong-type→current month start; month int epoch (incl. epoch 0); full ISO datetime string
    3. camelCase `accountId` rejected (throwsArgumentError); empty map rejected; `account_id` preferred when both keys present
  - Existing coverage: groups `fromMap()` + `fromMap() date parsing` + edge `rejects empty map` — exhaustive on the month-type matrix and the Phase-4.11 snake_case-only contract.

- **`Budget copyWith({id, category, double amount, accountId, month})`** — ✅ Covered
  - Test cases: each field; no-arg preservation.
  - Existing coverage: group `copyWith()`, 6 tests.

- **`Budget copyWithDecimal({id, category, Decimal amount, accountId, month})`** — ✅ Covered
  - Test cases: Decimal amount preserved; no-arg preservation.
  - Existing coverage: group `copyWithDecimal()`, 2 tests.

- **Round-trip** — 🟡 Partial
  - Test cases: full object (`edge cases > roundtrip`).
  - Missing: 3-dp amount truncation; large amount round-trip is constructor-only (not round-tripped).
  - Existing coverage: group `edge cases`.

#### File summary: 6 public members. 5 ✅, 1 🟡 (round-trip precision). Highest-priority gaps: minor — Decimal 2dp-truncation boundary unasserted on round-trip.

---

### `lib/models/monthly_balance_model.dart`

- **`MonthlyBalance({id, required Decimal carryoverFromPrevious, Decimal? overallBudget, required accountId, required month})`** — ✅ Covered
  - Test cases: all fields incl. negative carryover; overallBudget null; id null.
  - Existing coverage: group `constructor and getters`, 4 tests.

- **`double get carryoverFromPrevious` / `Decimal get carryoverFromPreviousDecimal`** — ✅ Covered.
- **`double? get overallBudget` / `Decimal? get overallBudgetDecimal`** — ✅ Covered (null when unset).

- **`bool get hasOverallBudget`** — ✅ Covered
  - true iff `_overallBudget != null && > 0`.
  - Test cases: positive→true; null→false; zero→false; small positive 0.01→true.
  - Existing coverage: group `hasOverallBudget`, 4 tests.

- **`Map toMap()`** — ✅ Covered
  - `carryover_from_previous`, `overall_budget` (null when unset), `account_id`, `month` as **YYYY-MM** (Phase 4.8 month-key, NOT full date).
  - Test cases: full (month=='2024-06'); null id; null overall_budget; negative carryover; zero carryover.
  - Existing coverage: group `toMap()`, 5 tests.

- **`factory MonthlyBalance.fromMap(Map)`** — ✅ Covered
  - month: String length-7 'YYYY-MM' expanded to 'YYYY-MM-01' before parseDate; full date accepted unchanged; int→epoch; null/other→start-of-month. `overall_budget`: zero treated as null. **Phase 4.11: `account_id` required** → ArgumentError.
  - Test cases:
    1. Complete map; integer carryover via num
    2. null overall_budget→null; zero overall_budget→null+hasOverallBudget false; null carryover→0; month ISO/epoch/null/missing/bool-unrecognized→start-of-month
    3. camelCase accountId rejected; missing account_id rejected
  - Existing coverage: groups `fromMap() deserialization` + `fromMap() month parsing` — exhaustive incl. the YYYY-MM expansion path and zero-as-null rule. (Edge not tested: a 7-char string that is NOT a month like 'abcdefg' — would expand to 'abcdefg-01', fail parse, fall to null→start-of-month; low priority.)

- **`MonthlyBalance copyWith({id, double carryoverFromPrevious, double overallBudget, clearOverallBudget=false, accountId, month})`** — ✅ Covered
  - `clearOverallBudget` flag forces null regardless of `overallBudget` arg.
  - Test cases: id; carryover; overallBudget set; clearOverallBudget→null; accountId; month; no-arg preservation.
  - Existing coverage: group `copyWith()`, 7 tests. (Untested interaction: passing both `clearOverallBudget:true` AND `overallBudget:X` — clear wins; low priority.)

- **`MonthlyBalance copyWithDecimal({..., clearOverallBudget=false, ...})`** — ✅ Covered
  - Test cases: Decimal carryover; Decimal overallBudget; clearOverallBudget→null; no-arg preservation.
  - Existing coverage: group `copyWithDecimal()`, 4 tests.

- **Round-trip** — ✅ Covered
  - Test cases: full (carryover 1500.75, budget 4000); null budget preserved; negative carryover preserved.
  - Existing coverage: group `round-trip serialization`, 3 tests. (Note: the YYYY-MM month-key means round-trip *loses the day* — a balance constructed with month=2024-06-15 round-trips to 2024-06-01. Not asserted as a test, but the doc-comment + toMap test cover the intent; minor gap.)

#### File summary: 11 public members (counting getters). All ✅ (with 2–3 low-priority edge interactions noted inline). Highest-priority gaps: none material; consider asserting the YYYY-MM day-collapse on round-trip.

---

### `lib/models/quick_template_model.dart`

- **`QuickTemplate({id, required name, required Decimal amount, required category, paymentMethod='Cash', type='expense', required accountId, sortOrder=0})`** — ✅ Covered
  - Test cases: all fields; defaults (paymentMethod Cash, type expense, sortOrder 0, id null); amountDecimal exact.
  - Existing coverage: group `constructor and getters`, 5 tests.

- **`double get amount` / `Decimal get amountDecimal`** — ✅ Covered.

- **`Map toMap()`** — ✅ Covered
  - `amount` double; `account_id` snake_case; `paymentMethod`/`type`/`sortOrder` camelCase.
  - Test cases: full; null id; income type; zero amount.
  - Existing coverage: group `toMap()`, 4 tests.

- **`factory QuickTemplate.fromMap(Map)`** — ✅ Covered
  - Validates `name` + `category` + `accountId` (all required) → ArgumentError. `paymentMethod ?? 'Cash'`, `type ?? 'expense'`, `sortOrder ?? 0`, amount via fromDoubleSafe.
  - Test cases:
    1. Complete map; integer amount via num
    2. defaults for missing paymentMethod/type/sortOrder; null amount→0; null id
    3. null/empty/missing name → throw; null/empty/missing category → throw; null/missing account_id → throw
  - Existing coverage: groups `fromMap() deserialization` + `fromMap() validation`, comprehensive on all three required-field throws.

- **`QuickTemplate copyWith({...double amount...})`** — ✅ Covered
  - Test cases: every field; no-arg preservation.
  - Existing coverage: group `copyWith()`, 9 tests.

- **`QuickTemplate copyWithDecimal({...Decimal amount...})`** — ✅ Covered
  - Test cases: Decimal amount; no-arg preservation.
  - Existing coverage: group `copyWithDecimal()`, 2 tests.

- **Round-trip** — ✅ Covered
  - Test cases: full object preserved.
  - Existing coverage: group `round-trip serialization`, 1 test. (Minor: no error-message-text assertion, no 3dp truncation; low priority.)

#### File summary: 6 public members. All ✅.

---

### `lib/models/recurring_expense_model.dart`

- **`enum RecurringExpenseFrequency { monthly, biweekly, weekly }`** — ✅ Covered (index 0/1/2 asserted via toMap/fromMap and clamping tests).

- **`RecurringExpense({id, required description, required Decimal amount, required category, required dayOfMonth, isActive=true, lastCreated, required accountId, paymentMethod='Cash', endDate, maxOccurrences, occurrenceCount=0, frequency=monthly, startDate})`** — ✅ Covered
  - Test cases: all fields incl. dates/maxOccurrences/occurrenceCount; defaults (isActive true, paymentMethod Cash, occurrenceCount 0, frequency monthly).
  - Existing coverage: group `constructor and getters`, 5 tests.

- **`double get amount` / `Decimal get amountDecimal`** — ✅ Covered.

- **`String get dayName`** — ✅ Covered
  - monthly → 'Day N'; else `days[dayOfMonth.clamp(0,6)]`.
  - Test cases: monthly 'Day 15'; weekly idx 0→Monday, 4→Friday, 6→Sunday; biweekly idx 2→Wednesday; clamp negative→Monday, >6→Sunday.
  - Existing coverage: group `dayName`, 7 tests (incl. both clamp boundaries).

- **`String get frequencyDescription`** — ✅ Covered
  - Test cases: monthly/weekly/biweekly phrasings.
  - Existing coverage: group `frequencyDescription`, 3 tests.

- **`Map toMap()`** — ✅ Covered
  - All fields; `isActive` 1/0; dates via toDateString or null; `frequency` → `.index`; `account_id` snake_case (rest camelCase).
  - Test cases: full (frequency biweekly→1); isActive false→0; null dates→null; null maxOccurrences→null.
  - Existing coverage: group `toMap()`, 4 tests.

- **`factory RecurringExpense.fromMap(Map)`** — 🟡 Partial
  - Inner `parseDateTime` (null-safe, debugPrint on invalid in debug); **frequency index clamped to [0, len-1]** (the documented P0-3 fix). BUT: `description`, `category`, `dayOfMonth`, `account_id` are assigned **directly with no null guard** — a row missing any of these throws `TypeError`/null-assign at runtime (e.g. `dayOfMonth: map['dayOfMonth']` where the field is null → assigning null to non-nullable int → throws). There is **no `tryFromMap`** for this model.
  - Test cases:
    1. Complete map; isActive 0→false; defaults paymentMethod/occurrenceCount
    2. null & invalid date strings → null (all three date fields); frequency clamping matrix: idx 0/1/2 valid, -1→monthly, 99→weekly, null→monthly, missing→monthly
    3. **missing/null `description` → throws (untested); missing/null `dayOfMonth` → throws (untested); missing/null `account_id` → throws (untested); missing/null `category` → throws (untested)** — none of the required-field failure modes are covered, and unlike Expense/Income they throw `TypeError` not `ArgumentError`
  - Existing coverage: groups `fromMap() deserialization` + `fromMap() frequency enum clamping` cover happy path, dates, and the full frequency-clamp matrix. GAP: zero coverage of malformed/missing required scalar fields (description/category/dayOfMonth/account_id) and no `tryFromMap` equivalent exists.

- **`RecurringExpense copyWith({..., clearLastCreated, clearEndDate, clearMaxOccurrences, clearStartDate, ...})`** — ✅ Covered
  - double `amount`; four clear-flags for nullable fields.
  - Test cases: override description/amount/isActive/frequency/endDate; each clear flag individually; no-arg preservation of all 14 fields.
  - Existing coverage: group `copyWith()`, 11 tests (all four clear flags + full preservation).

- **`RecurringExpense copyWithDecimal({...same clear flags...})`** — 🟡 Partial
  - Test cases: Decimal amount; all four clear flags together.
  - Missing: per-field non-clear overrides on the Decimal variant (e.g. override `frequency`/`isActive` alone), and no-arg full-preservation assertion (only the double variant asserts full preservation).
  - Existing coverage: group `copyWithDecimal()`, 2 tests.

- **`bool get shouldBeActive`** — ✅ Covered
  - false if !isActive; false if endDate `isPast`; false if `occurrenceCount >= maxOccurrences`; else true.
  - Test cases: active no-constraints→true; inactive→false; past endDate→false; future endDate→true; endDate==today→true (boundary); maxOccurrences reached→false; exceeded→false; under→true; null maxOccurrences→true; inactive+future→false.
  - Existing coverage: group `shouldBeActive`, 11 tests (incl. the today boundary).

- **Round-trip** — ✅ Covered
  - Test cases: full object (biweekly, all dates+counts); all-nulls preserved.
  - Existing coverage: group `round-trip serialization`, 2 tests.

#### File summary: 11 public members (incl. enum, getters). 9 ✅, 2 🟡 (`fromMap` missing-required-field path, `copyWithDecimal` thin). Highest-priority gaps: `fromMap` throws an unguarded `TypeError` (not `ArgumentError`) on rows missing `description`/`category`/`dayOfMonth`/`account_id` and has NO test for it and NO `tryFromMap` — so a single corrupt recurring-expense row can crash the whole read path (inconsistent with the Expense/Income safety contract).

---

### `lib/models/recurring_income_model.dart`

(Structurally identical to RecurringExpense; field order differs — `frequency`/`startDate` precede `endDate` — and the enum is `RecurringFrequency`.)

- **`enum RecurringFrequency { monthly, biweekly, weekly }`** — ✅ Covered.

- **`RecurringIncome({id, required description, required Decimal amount, required category, required dayOfMonth, isActive=true, lastCreated, required accountId, frequency=monthly, startDate, endDate, maxOccurrences, occurrenceCount=0})`** — ✅ Covered
  - Test cases: all fields; defaults (isActive true, frequency monthly, occurrenceCount 0).
  - Existing coverage: group `constructor and getters`, 3 tests.

- **`double get amount` / `Decimal get amountDecimal`** — ✅ Covered.

- **`String get dayName`** — ✅ Covered
  - Test cases: monthly 'Day 25'; weekly 0/4/6 → Mon/Fri/Sun; biweekly 3→Thursday; clamp -3→Monday, 100→Sunday.
  - Existing coverage: group `dayName`, 7 tests.

- **`String get frequencyDescription`** — ✅ Covered
  - Test cases: monthly/weekly/biweekly.
  - Existing coverage: group `frequencyDescription`, 3 tests.

- **`Map toMap()`** — ✅ Covered
  - Test cases: full (biweekly→1); isActive false→0; null dates→null; null maxOccurrences→null.
  - Existing coverage: group `toMap()`, 4 tests.

- **`factory RecurringIncome.fromMap(Map)`** — 🟡 Partial
  - Same shape as RecurringExpense.fromMap: frequency clamp + null-safe `parseDateTime`, but `description`/`category`/`dayOfMonth`/`account_id` assigned directly → `TypeError` on missing/null. No `tryFromMap`.
  - Test cases:
    1. Complete map (weekly); isActive 0→false; default occurrenceCount
    2. null & invalid date strings→null; frequency clamp matrix 0/1/2/-5/50/null/missing
    3. **missing/null description/category/dayOfMonth/account_id → throws (untested), and as TypeError not ArgumentError**
  - Existing coverage: groups `fromMap() deserialization` + `fromMap() frequency enum clamping` — happy/dates/clamp matrix only. Same GAP as RecurringExpense: required-scalar-field failure modes uncovered.

- **`RecurringIncome copyWith({...four clear flags...})`** — ✅ Covered
  - Test cases: override description/amount/isActive/frequency/endDate; all four clear flags; full no-arg preservation.
  - Existing coverage: group `copyWith()`, 11 tests.

- **`RecurringIncome copyWithDecimal({...four clear flags...})`** — 🟡 Partial
  - Test cases: Decimal amount; all four clear flags together.
  - Missing: per-field non-clear override coverage + no-arg full preservation on the Decimal variant.
  - Existing coverage: group `copyWithDecimal()`, 2 tests.

- **`bool get shouldBeActive`** — ✅ Covered
  - Test cases: active→true; inactive→false; past endDate→false; future→true; today→true; maxOccurrences reached/exceeded→false; under→true; null max→true (even occurrenceCount 1000); inactive+future→false.
  - Existing coverage: group `shouldBeActive`, 11 tests.

- **Round-trip** — ✅ Covered
  - Test cases: full (weekly, all dates+counts); all-nulls preserved.
  - Existing coverage: group `round-trip serialization`, 2 tests.

#### File summary: 11 public members (incl. enum, getters). 9 ✅, 2 🟡 (`fromMap` missing-required-field path, `copyWithDecimal` thin). Highest-priority gaps: identical to RecurringExpense — `fromMap` unguarded `TypeError` on missing `description`/`category`/`dayOfMonth`/`account_id`, untested, no `tryFromMap`.

---

#### Coverage summary
73 public functions/getters/factories/enums across 10 files; 60 ✅, 11 🟡, 2 ❌-equivalent (the two `tryFromMap` Income/Expense malformed-type leaks are folded into 🟡 since the null-on-missing branch IS tested). Net: **60 ✅, 13 🟡, 0 fully ❌.**

Highest-priority gaps to fill, in order:
1. **`RecurringExpense.fromMap` / `RecurringIncome.fromMap` — missing-required-field crash path (largest gap).** `description`, `category`, `dayOfMonth`, `account_id` are assigned with no null guard, so a corrupt row throws `TypeError` mid-read; there is no `tryFromMap` and zero tests. Add tests proving the throw, then decide whether to (a) add `ArgumentError` validation + a `tryFromMap` to match Expense/Income's documented bulk-read safety contract, or (b) document the divergence.
2. **`Income.tryFromMap` has no test at all** (Expense's is covered); and both `tryFromMap`s only catch `ArgumentError`, so a type-mismatch row (`account_id` as String) still throws past them — add a positive-case test + a malformed-type test for both.
3. **Decimal 2-dp truncation boundary** is asserted nowhere: add one round-trip test per Decimal model (Budget/Expense/Income/QuickTemplate/MonthlyBalance) proving `Decimal.parse('100.999')` collapses to 2 dp after `toMap`→`fromMap`, documenting the lossy ceiling.
4. **`MonthlyBalance` round-trip day-collapse**: assert that a month with day≠1 round-trips to day 1 (YYYY-MM key), making the Phase-4.8 behavior explicit.
5. **`copyWithDecimal` thinness on both recurring models**: add per-field override + no-arg full-preservation assertions to match the double `copyWith` coverage.


## Utility Helpers - formatting & logic (lib/utils/)

### `lib/utils/decimal_helper.dart`

All-static money-math facade over `package:decimal`. Hard cap `maxSafeValue = 999999999.99`; everything routes through `fromDouble` which forces 2-dp rounding and clamping. Existing tests: `test/utils/decimal_helper_test.dart` (very thorough, ~120 cases).

- **`static Decimal fromDouble(double value)`** — ✅ Covered
  - Clamps to ±999999999.99, rounds to 2 dp via `toStringAsFixed(2)`, maps non-finite to zero.
  - Test cases:
    1. positive/negative/zero conversions — `expect(fromDouble(42.0), Decimal.parse('42.00'))`
    2. rounds 3rd decimal (1.999→2.00), keeps exact (12.34), tiny value floors (0.001→0.00)
    3. infinity/-infinity/NaN → `Decimal.zero`; overflow clamps both signs; boundary 999999999.99 and .98 preserved
  - Existing coverage: `decimal_helper_test.dart` group `fromDouble` covers all the above (13 tests incl. boundaries + non-finite).

- **`static double toDouble(Decimal value)`** — ✅ Covered
  - Converts back to double, clamps, returns 0.0 on non-finite or exception.
  - Test cases:
    1. positive/negative/zero round-trip
    2. oversized Decimal clamps to ±999999999.99; boundary returns boundary; 0.01 precision preserved
    3. (gap) the `catch` fallback path (a Decimal whose `.toDouble()` throws) is not exercised — low value, hard to construct
  - Existing coverage: `decimal_helper_test.dart` group `toDouble` (7 tests). Missing only the catch branch.

- **`static Decimal parse(String value)`** — ✅ Covered
  - Trims, swaps comma→dot, parses, validates finite, clamps, rounds to 2 dp; returns zero on failure/empty.
  - Test cases:
    1. simple/negative/comma-decimal/integer/leading-zeros parse
    2. empty/whitespace/non-numeric/lone-dot → zero; rounds 1.999→2.00 and 1.005→1.01 (half-up); overflow clamps both signs
    3. non-finite-after-parse branch (string that parses to ±inf) — only indirectly covered
  - Existing coverage: `decimal_helper_test.dart` group `parse` (14 tests) + integration cases (leading zeros, lone dot).

- **`static Decimal fromDoubleSafe(double? value)`** — ✅ Covered
  - Null→zero, else delegates to `fromDouble`.
  - Test cases:
    1. null → zero
    2. normal/negative delegate equals `fromDouble`
    3. infinity/NaN → zero; `double.maxFinite` clamps to boundary
  - Existing coverage: `decimal_helper_test.dart` group `fromDoubleSafe` (5) + integration `fromDoubleSafe handles max double`.

- **`static bool isValidDecimal(Decimal value)`** — ✅ Covered
  - True iff finite and `abs() <= maxSafeValue`.
  - Test cases:
    1. zero / normal pos / normal neg → true
    2. exact boundaries → true; just over (1000000000) → false both signs
    3. catch branch (toDouble throws) — not exercised (low value)
  - Existing coverage: `decimal_helper_test.dart` group `isValidDecimal` (7 tests).

- **`static double add/subtract/multiply(double a, double b)`** — ✅ Covered
  - Decimal-precise arithmetic; non-finite operands neutralize to zero.
  - Test cases:
    1. pos/pos, pos/neg, neg/neg, with-zero
    2. floating-point precision (0.1+0.2==0.3, 0.3-0.1==0.2); repeated-add-0.1×10==1.0
    3. infinity/NaN operands collapse to 0 (e.g. `add(inf,5)==5`, `multiply(inf,5)==0`)
  - Existing coverage: `decimal_helper_test.dart` groups `add`/`subtract`/`multiply` + integration (both-operands-inf/NaN).

- **`static double divide(double a, double b)`** — ✅ Covered
  - Guards b==0 before and after `fromDouble`; `scaleOnInfinitePrecision: 10`.
  - Test cases:
    1. even division, negative/positive, zero dividend
    2. non-terminating 10/3 ≈ 3.33; division by zero → 0; 0/0 → 0
    3. infinity/NaN dividend → 0 (post-conversion zero-divisor guard)
  - Existing coverage: `decimal_helper_test.dart` group `divide` (7) + integration.

- **`static double percentage(double value, double total)`** — ✅ Covered
  - `multiply(divide(value,total),100)`; total==0 → 0.
  - Test cases:
    1. 50/100→50, 100/100→100, 1/100→1
    2. >100% (200/100→200), negative value (-25), non-terminating 1/3→33.0
    3. total==0 → 0; infinity total → 0
  - Existing coverage: `decimal_helper_test.dart` group `percentage` (7) + integration.

- **`static double round(double value)`** — ✅ Covered
  - `toDouble(fromDouble(value))`.
  - Test cases:
    1. 1.999→2.0, 1.234→1.23, already-2dp kept
    2. zero, negative (-1.999→-2.0)
    3. infinity/NaN → 0; equivalence-to-fromDouble→toDouble asserted
  - Existing coverage: `decimal_helper_test.dart` group `round` (7) + integration.

- **`static bool equals(double a, double b)`** — ✅ Covered
  - Compares after `fromDouble` (2-dp tolerance).
  - Test cases:
    1. equal/unequal, zeros equal
    2. 0.1+0.2 vs 0.3 → true; differ-at-3rd-decimal → true; differ-at-2nd → false
    3. sign mismatch → false
  - Existing coverage: `decimal_helper_test.dart` group `equals` (7).

- **`static int compare(double a, double b)`** — ✅ Covered
  - `fromDouble(a).compareTo(fromDouble(b))`.
  - Test cases:
    1. a<b, a==b, a>b
    2. negatives, precision-equal (0.1+0.2 vs 0.3) → 0
    3. neg-vs-pos
  - Existing coverage: `decimal_helper_test.dart` group `compare` (6).

- **`static Decimal addDecimal/subtractDecimal/multiplyDecimal(Decimal a, Decimal b)`** — ✅ Covered
  - Direct operator passthrough (no clamping/rounding).
  - Test cases:
    1. straight add/sub/mul of parsed decimals
    2. with zero; negative operands
    3. (n/a — pure arithmetic, no error path)
  - Existing coverage: `decimal_helper_test.dart` groups `addDecimal`/`subtractDecimal`/`multiplyDecimal`.

- **`static Decimal divideDecimal(Decimal a, Decimal b)`** — ✅ Covered
  - b==Decimal.zero → zero; else `scaleOnInfinitePrecision: 10`.
  - Test cases:
    1. even division
    2. divide-by-zero → zero; zero/non-zero → zero
    3. negative/positive
  - Existing coverage: `decimal_helper_test.dart` group `divideDecimal` (4).

- **`static int compareDecimal(Decimal a, Decimal b)`** — ✅ Covered
  - Test cases: a<b, ==, a>b. Existing coverage: group `compareDecimal` (3).

- **`static bool isZero(Decimal value)`** — ✅ Covered
  - Test cases: Decimal.zero/parsed-zero → true; non-zero pos/neg, large → false. Existing coverage: group `isZero` (5).

- **`static Decimal max(Decimal a, Decimal b)` / `min(...)`** — ✅ Covered
  - Test cases: larger/smaller picked; equal returns either; neg-vs-pos; more/less-negative. Existing coverage: groups `max`/`min` (4 each).

- **`static Decimal clamp(Decimal value, Decimal min, Decimal max)`** — ✅ Covered
  - Test cases: in-range passthrough; below→min, above→max; at-min/at-max boundaries; negative range. Existing coverage: group `clamp` (6).

### `lib/utils/currency_helper.dart`

Locale-aware formatting + international decimal parsing. Static maps `currencyLocales`, `currencies` (25), `_formatterCache`. Existing tests: `test/utils/currency_helper_test.dart` (very thorough, ~110 cases).

- **`static String formatAmount(double amount, String currencyCode, {int decimalDigits = 2})`** — ✅ Covered
  - Picks locale, uses cached `NumberFormat.decimalPatternDigits`, falls back to `toStringAsFixed`.
  - Test cases:
    1. USD/EUR/JPY(0dp)/INR(lakh grouping)/CHF/BRL locale-specific grouping
    2. zero, negative, very large (1234567890.12), very small (0.01), custom decimalDigits 0/1/3
    3. unknown code → en_US fallback; the catch-block `toStringAsFixed` fallback (invalid locale) is not directly hit — locales here are all valid
  - Existing coverage: `currency_helper_test.dart` group `formatAmount` (13). Cache-hit path implicitly exercised by repeated calls; no explicit assert on cache reuse (minor).

- **`static String formatWithSymbol(double amount, String symbol, String currencyCode, {int decimalDigits = 2})`** — ✅ Covered
  - Prepends symbol to `formatAmount`.
  - Test cases:
    1. USD `$`, EUR `€`, INR `₹`
    2. zero, negative, custom decimalDigits, multi-char symbol (HK$)
    3. (n/a)
  - Existing coverage: `currency_helper_test.dart` group `formatWithSymbol` (7) + integration.

- **`static String formatCompact(double amount, String currencyCode)`** — 🟡 Partial
  - `NumberFormat.compact`; manual K/M fallback in catch.
  - Test cases:
    1. millions→M, thousands→K, small→no suffix, billions→B
    2. zero, unknown code → en_US fallback
    3. Missing: the `catch` fallback branch (manual `/1000000` M, `/1000` K, else `toStringAsFixed(2)`) is never reached because all real locales succeed — negative amounts in fallback not tested
  - Existing coverage: `currency_helper_test.dart` group `formatCompact` (6). Gap = fallback branch.

- **`static String getSymbol(String code)`** — ✅ Covered
  - Test cases: known symbols incl. multi-char; CHF string; unknown/empty → `$`; case-sensitive; every map key non-empty. Existing coverage: group `getSymbol` (8).

- **`static String getName(String code)`** — ✅ Covered
  - Test cases: known names; unknown → code itself; empty → empty; case-sensitive. Existing coverage: group `getName` (4) + integration (name≠code).

- **`static List<String> get currencyList`** — ✅ Covered
  - Test cases: non-empty; contains expected codes; length matches map; new instance each call; all 3-letter uppercase. Existing coverage: group `currencyList` (5).

- **`static String stripThousandsSeparators(String input)`** — ✅ Covered
  - Heuristic comma-vs-dot disambiguation + space/apostrophe stripping.
  - Test cases:
    1. space / nbsp / narrow-nbsp / apostrophe stripping; US `1,234.56`; EU `1.234,56`
    2. single-comma-3-digits→thousands vs single-comma-2-digits→decimal; multi-dot thousands pattern `1.234.567` vs ambiguous `12.34.56`
    3. empty string; plain integer; mixed space+comma
  - Existing coverage: `currency_helper_test.dart` group `stripThousandsSeparators` (~20 across sub-groups).

- **`static String normalizeDecimalInput(String input)`** — ✅ Covered
  - Strips currency codes (before symbols), symbols (longest-first), thousands, normalizes decimal separators, collapses multi-dot.
  - Test cases:
    1. strip `$`/`€`/`£`/`¥`/`₹`/`A$`/`HK$`/`R$`; strip USD/EUR codes
    2. Arabic separators U+066B/U+060C; multi-dot collapse (12.34.56→1234.56, 1.2.3.4→123.4)
    3. empty/whitespace→empty; complex pasted banking values both styles
  - Existing coverage: `currency_helper_test.dart` group `normalizeDecimalInput` (~25). The `R` (ZAR) single-char vs `EUR` code ordering edge is implicitly covered by code-first stripping but no dedicated ZAR test.

- **`static double? parseDecimal(String input)`** — ✅ Covered
  - `double.tryParse(normalizeDecimalInput(...))`.
  - Test cases:
    1. US/EU/Swiss/integer/zero/small decimal parse
    2. negative after normalization; very large (999999999.99)
    3. empty/whitespace/non-numeric/lone-symbol → null
  - Existing coverage: `currency_helper_test.dart` group `parseDecimal` (15) + integration round-trips.

- **`static TextInputFormatter decimalInputFormatter()`** — ✅ Covered
  - Allows `^\d*\.?\d{0,2}$` after normalization; rewrites cursor when thousands stripped; rejects otherwise.
  - Test cases:
    1. empty/digit/integer/`12.34`/`12.3`/`.5`/`12.` accepted
    2. comma→dot normalize accept; pasted `1,234.56`→`1234.56`; `12.34.5`→`1234.5`
    3. >2 decimals, alpha, special chars rejected (keep old value)
  - Existing coverage: `currency_helper_test.dart` group `decimalInputFormatter` (13).

- **`static String sanitizeText(String input, {int maxLength = 200})`** — ✅ Covered
  - Trims, strips `[\x00-\x1F\x7F]`, truncates.
  - Test cases:
    1. empty, trim, normal/Unicode passthrough
    2. removes null/tab/newline/CR/ESC/DEL/multiple control chars
    3. default-200 and custom-maxLength truncation; maxLength 0/1; all-control→empty; trim-before-truncate
  - Existing coverage: `currency_helper_test.dart` group `sanitizeText` (~18). (Note: near-duplicate of `Validators.sanitizeText`.)

- **Static maps `currencies` / `currencyLocales`** — ✅ Covered
  - Test cases: keys 3-letter-upper, values non-empty, count==25, JPY&CNY both ¥, locales superset of currencies. Existing coverage: groups `currencies map` + `currencyLocales map`.

### `lib/utils/date_helper.dart`

All dates normalized to UTC midnight. Existing tests: `test/utils/date_helper_test.dart` (very thorough, ~80 cases, including century leap rules).

- **`static DateTime normalize(DateTime date)`** — ✅ Covered
  - `DateTime.utc(y,m,d)` — strips time, forces UTC.
  - Test cases:
    1. strips time, preserves y/m/d from local and UTC inputs
    2. idempotent on already-normalized; leap day (Feb 29); exact midnight
    3. (timezone) UTC flag asserted; note: a local input near a DST/midnight boundary keeps wall-clock y/m/d, not an instant conversion — covered behaviorally
  - Existing coverage: `date_helper_test.dart` group `normalize()` (6).

- **`static DateTime today()`** — 🟡 Partial
  - `DateTime.utc` of `DateTime.now()` y/m/d. Does NOT use `Clock.instance` — uncontrollable in tests.
  - Test cases:
    1. equals normalize(now), UTC midnight
    2. y/m/d match `DateTime.now()`
    3. Missing: deterministic test via injected clock — impossible since this reads `DateTime.now()` directly (Clock not wired here). Flaky-at-midnight risk untested.
  - Existing coverage: `date_helper_test.dart` group `today()` (2). Gap = no clock injection (design limitation).

- **`static DateTime startOfMonth(DateTime date)`** — ✅ Covered
  - Test cases: day 1 UTC midnight; already-first; December; leap-year Feb. Existing coverage: group `startOfMonth()` (4).

- **`static DateTime endOfMonth(DateTime date)`** — ✅ Covered
  - Exclusive end = first of next month.
  - Test cases: mid-month→next month 1st; Dec→Jan next year; Feb leap & non-leap. Existing coverage: group `endOfMonth()` (4).

- **`static DateTime lastDayOfMonth(DateTime date)`** — ✅ Covered
  - `DateTime.utc(y, m+1, 0)`.
  - Test cases:
    1. 31-day months, 30-day months
    2. Feb leap (29) / non-leap (28)
    3. century rule: 2000→29, 1900→28; December; UTC midnight asserted
  - Existing coverage: `date_helper_test.dart` group `lastDayOfMonth()` (7).

- **`static bool isSameDay(DateTime a, DateTime b)`** — ✅ Covered
  - Compares y/m/d getters directly (no normalization).
  - Test cases:
    1. same date different times → true
    2. different day/month/year → false
    3. UTC-vs-local same wall-clock day → true; identical → true. (Caveat: compares raw getters, so a UTC instant vs local instant that fall on different *wall* days would mismatch — not separately tested, but `today()`-based callers normalize first.)
  - Existing coverage: `date_helper_test.dart` group `isSameDay()` (6).

- **`static bool isPast(DateTime date)` / `isFuture(DateTime date)` / `isToday(DateTime date)`** — 🟡 Partial
  - Delegate through `normalize` + `today()`.
  - Test cases:
    1. past date / future date / today / yesterday / tomorrow / same-day-last-year
    2. boundary at "today" (returns false for both isPast/isFuture)
    3. Missing: deterministic assertions (all use real `DateTime.now()` via `today()`); the exact-midnight-rollover race is untested. Same Clock-not-wired limitation as `today()`.
  - Existing coverage: `date_helper_test.dart` groups `isPast()`/`isFuture()`/`isToday()` (4–5 each). Adequate but time-dependent.

- **`static String toDateString(DateTime date)`** — ✅ Covered
  - ISO `YYYY-MM-DD` of normalized date.
  - Test cases: standard; zero-padding; Dec 31 / Jan 1; ignores time; leap day. Existing coverage: group `toDateString()` (6).

- **`static DateTime? parseDate(String? dateString)`** — ✅ Covered
  - `DateTime.parse` then normalize; null on null/empty/throw.
  - Test cases:
    1. valid ISO; with-time normalized to midnight; with `Z` timezone normalized
    2. null/empty → null; leap day; round-trips with `toDateString`
    3. invalid/malformed (`not-a-date`, `99/99/99`, `2024/03/15`) → null
  - Existing coverage: `date_helper_test.dart` group `parseDate()` (9).

- **`static String toMonthString(DateTime date)`** — ✅ Covered
  - `YYYY-MM` from raw getters (note: NOT normalized — uses input's y/m directly).
  - Test cases: standard; zero-pad month; December; different years; ignores day. Existing coverage: group `toMonthString()` (5).

- **`static DateTime addMonths(DateTime date, int months)`** — ✅ Covered
  - Day-overflow clamps to last day of target month; year wrap both directions.
  - Test cases:
    1. +1 / +5 / +12 / +24 simple
    2. Jan31+1→Feb28(non-leap)/Feb29(leap); Aug31+1→Sep30; Jan30+1→Feb28; +0 normalizes
    3. negative months (subtract, year-underflow); Mar31-1→Feb29/Feb28; chaining preserves clamped day; result always UTC
  - Existing coverage: `date_helper_test.dart` group `addMonths()` (18) — exhaustive.

- **`static DateTime subtractMonths(DateTime date, int months)`** — ✅ Covered
  - `addMonths(date, -months)`.
  - Test cases: -1; year boundary; day overflow leap/non-leap; -12; -0 normalizes. Existing coverage: group `subtractMonths()` (6).

- **`static DateTime addDays(DateTime date, int days)`** — ❌ Missing
  - `normalize(date).add(Duration(days: days))` — used for weekly/biweekly recurring.
  - Test cases:
    1. +7 days advances one week, result UTC midnight — `addDays(DateTime.utc(2024,1,1), 7)` → 2024-01-08
    2. crosses month boundary (Jan 30 + 5 → Feb 4) and year boundary (Dec 30 + 5 → Jan 4)
    3. negative days subtract; +14 biweekly; DST-immune because operand is normalized UTC (assert no hour drift across a would-be DST date like Mar 10)
  - Existing coverage: none. **GAP** — `addDays` has zero direct tests despite being a recurring-transaction primitive.

- **`static int daysBetween(DateTime start, DateTime end)`** — ✅ Covered
  - Diff of normalized dates in whole days.
  - Test cases:
    1. forward positive, reversed negative, same date → 0
    2. same-date-different-times → 0; month/year boundary; leap Feb 28→Mar 1 (2 vs 1 day)
    3. full year 365 (non-leap) / 366 (leap)
  - Existing coverage: `date_helper_test.dart` group `daysBetween()` (8).

- **`static String getRelativeTime(DateTime date)`** — ✅ Covered
  - "Just now" / "Xm ago" / "Xh ago" / "Today" / "Yesterday" / "N days ago" / "Mon DD" / "Mon DD, YYYY".
  - Test cases:
    1. just-now, minutes-ago, hours-ago (today)
    2. yesterday, 2–6 days ago, 7+ days same year ("Jan 1"), different year ("Jun 15, 2020"), all-12-months formatting
    3. future dates → formatted date (this year "Dec 31" / other year "Jul 4, 2099")
  - Existing coverage: `date_helper_test.dart` group `getRelativeTime()` (9). Note: time-dependent via `DateTime.now()`; the hours-ago test self-guards against midnight crossing. The "Today" branch (>=24h but same calendar day — impossible) is dead-ish.

### `lib/utils/validators.dart`

Form validators returning error string or null; date-range helpers driven by `Clock.instance`. Existing tests: `test/utils/validators_test.dart` (thorough, ~90 cases).

- **`static String? validateAmount(String? value, {bool allowZero = false})`** — ✅ Covered
  - Test cases:
    1. null/empty → "Please enter an amount"; non-numeric → "valid number"
    2. negative → "greater than 0"; zero with/without allowZero; exact max OK; just-over max error; comma & European formats; 0.01
    3. allowZero+negative → "cannot be negative"; -0 treated as 0; 0.1+0.2 float repr valid
  - Existing coverage: `validators_test.dart` group `validateAmount` (17).

- **`static String? validateAmountPaid(String? value, double totalAmount)`** — ✅ Covered
  - Integer-cents comparison to dodge float error.
  - Test cases:
    1. null/empty (optional) → null; valid < total; equal total → null
    2. negative → error; 1-cent overpay (100.01 vs 100) → error; 33.33*3 vs 99.99 → null (float-edge)
    3. non-numeric → "valid number"; zero paid OK
  - Existing coverage: `validators_test.dart` group `validateAmountPaid` (12).

- **`static String? validateDescription(String? value, {bool required = false})`** — ✅ Covered
  - Test cases: required null/empty/whitespace → error; not-required null/empty/whitespace → null; >200 → "too long"; exact 200 OK; Unicode OK. Existing coverage: group `validateDescription` (11).

- **`static String? validateCategoryName(String? value, List<String> existingCategories, {String? originalName})`** — ✅ Covered
  - Test cases:
    1. null/empty/whitespace → "enter a category name"; valid name → null
    2. >50 → "too long"; exact 50 OK; case-insensitive duplicate; originalName self-allow; trim-before-dupe-check; Unicode OK
    3. invalid chars `<>{}[]\\\`|` and `\x00` → "invalid characters"; normal specials (`&`) allowed
  - Existing coverage: `validators_test.dart` group `validateCategoryName` (~20) — exhaustive on the security regex.

- **`static String? validateTagName(String? value, List<String> existingTags)`** — 🟡 Partial
  - Test cases:
    1. null/empty/whitespace → error; valid → null
    2. >50 → "too long"; exact 50 OK; case-insensitive dupe; trim-before-dupe; Unicode
    3. Missing: tag names have NO invalid-character check (unlike category) — no test documents that `<script>` is *accepted* as a tag, which is the security-relevant asymmetry worth pinning.
  - Existing coverage: `validators_test.dart` group `validateTagName` (10). Gap = the deliberate absence of char-blocking is undocumented by test.

- **`static String? validateBudgetAmount(String? value)`** — ✅ Covered
  - Test cases: null/empty → "budget amount"; non-numeric; negative/zero → "greater than 0"; >max error; exact max OK; valid + 0.01. Existing coverage: group `validateBudgetAmount` (10).

- **`static bool isDateInValidRange(DateTime date)`** — ✅ Covered
  - 5y past..1y future, inclusive, via `Clock.instance.now()`.
  - Test cases:
    1. today/yesterday/1y-ago → true
    2. exactly-5y-ago and exactly-1y-future boundaries → true; 4y-ago, 6mo-future → true
    3. >5y past and >1y future → false
  - Existing coverage: `validators_test.dart` group `isDateInValidRange` (9). (Uses real clock; could be FakeClock-pinned but boundaries computed relative to now so stable.)

- **`static DateTime getTransactionMinDate()` / `getTransactionMaxDate()`** — ✅ Covered
  - Test cases: 5y-ago / 1y-future y/m/d; midnight (no time component). Existing coverage: groups `getTransactionMinDate`/`getTransactionMaxDate` (2 each).

- **`static DateTime getFilterMinDate()`** — ✅ Covered
  - Aliases `getTransactionMinDate`. Test: equals it. Existing coverage: group `getFilterMinDate`.

- **`static DateTime getFilterMaxDate()`** — ✅ Covered
  - `Clock.instance.now()` (includes time). Test: between before/after now. Existing coverage: group `getFilterMaxDate`.

- **`static DateTime getRecurringEndMinDate()`** — ✅ Covered
  - `Clock.instance.now()`. Test: ≈ now. Existing coverage: group `getRecurringEndMinDate`.

- **`static DateTime getRecurringEndMaxDate()`** — ✅ Covered
  - now + 3650 days. Test: diff closeTo(3650, 1). Existing coverage: group `getRecurringEndMaxDate`.

- **`static bool isFutureDate(DateTime date)`** — ✅ Covered
  - Date-only comparison via `Clock.instance.now()`.
  - Test cases: today → false; tomorrow → true; yesterday → false. Existing coverage: group `isFutureDate` (3). Could add FakeClock-pinned determinism but logic stable.

- **`static String sanitizeText(String input, {int maxLength = 200})`** — ✅ Covered
  - Near-identical to `CurrencyHelper.sanitizeText` (no empty-input short-circuit).
  - Test cases: control chars/newline/tab/CR/DEL removed; trim; default-200/custom truncation; unchanged-within-limit; empty; Unicode; all-control→empty; trim-before-truncate; 10k-char input. Existing coverage: group `sanitizeText` (~13).

- **`static String getCharacterCount(String text, int maxLength)`** — ✅ Covered
  - Test cases: "5/200"; "0/200" empty; "50/50" at limit. Existing coverage: group `getCharacterCount` (3).

- **`static bool willBeTruncated(String text, int maxLength)`** — ✅ Covered
  - Test cases: shorter → false; equal → false; over → true. Existing coverage: group `willBeTruncated` (3).

- **`static String? validateDateRange(DateTime? startDate, DateTime? endDate)`** — ✅ Covered
  - Test cases: either/both null → null; end before start → error; end==start (same day & same instant) → null; end after start; one-second-before same-day → error. Existing coverage: group `validateDateRange` (8).

- **`static String? validateMaxOccurrences(String? value)`** — ✅ Covered
  - Test cases: null/empty (optional) → null; non-numeric/decimal → "valid number"; 0/negative → "at least 1"; 1001/999999 → "Maximum 1000"; 1 and 1000 boundaries OK; typical/mid values. Existing coverage: group `validateMaxOccurrences` (12).

- **Constants `maxAmount`, `maxDescriptionLength`, `maxCategoryNameLength`, `maxTagNameLength`** — ✅ Covered
  - Test: 999999999.99 / 200 / 50 / 50. Existing coverage: group `constants` (4).

### `lib/utils/settings_helper.dart`

SharedPreferences-backed key/value settings, all `static Future`. Existing tests: `test/utils/settings_helper_test.dart` (thorough, ~30 cases; `SharedPreferences.setMockInitialValues({})` per test).

- **`static Future<bool> getDarkMode()` / `setDarkMode(bool)`** — ✅ Covered
  - Legacy bool. Test cases: default false; persists true. Existing coverage: group `legacy dark mode` (2).

- **`static Future<String> getThemeMode()`** — ✅ Covered
  - Tri-state with one-time migration from legacy `dark_mode`.
  - Test cases:
    1. default "system" when empty
    2. migrate dark_mode=true→"dark" / false→"light" AND persists new key
    3. explicit theme_mode wins over legacy when both present
  - Existing coverage: `settings_helper_test.dart` group `theme mode` (5).

- **`static Future<void> setThemeMode(String)`** — ✅ Covered
  - Test: persists and round-trips. Existing coverage: group `theme mode`.

- **`static Future<String> getCurrencyCode()` / `setCurrencyCode(String)`** — ✅ Covered
  - Test: default "USD"; persists "JPY". Existing coverage: group `currency` (2).

- **`static Future<bool> getBillReminders()/getBudgetAlerts()/getMonthlySummary()` + setters** — ✅ Covered
  - Test cases: all default true; all persist false. Existing coverage: group `notification toggles default ON` (4).

- **`static Future<int> getReminderHour()/getReminderMinute()` + setters** — ✅ Covered
  - Test: default 9/0; persist 18/45. Existing coverage: group `reminder time` (2).

- **`static Future<String> getCsvSeparator()` / `setCsvSeparator(String)`** — ✅ Covered
  - Test: default "comma"; persists "semicolon". Existing coverage: group `csv separator` (2).

- **`static Future<double> getBudgetWarningThreshold()` / `setBudgetWarningThreshold(double)`** — ✅ Covered
  - Setter clamps to 0..1.
  - Test cases: default 0.75; negative→0.0; >1→1.0; in-range 0.42 passes. Existing coverage: group `budget warning threshold` (4).

- **`static Future<int> getSearchDebounce()` / `setSearchDebounce(int)`** — ✅ Covered
  - Clamp 0..2000. Test: default 300; -100→0; 5000→2000. Existing coverage: group `search debounce` (3). (In-range passthrough implied, not explicitly asserted — minor.)

- **`static Future<int> getPaginationLimit()` / `setPaginationLimit(int)`** — ✅ Covered
  - Clamp 10..200. Test: default 50; 1→10; 9999→200; 75 passthrough. Existing coverage: group `pagination limit` (4).

- **`static Future<bool> getShowTransactionColors()` / setter** — ✅ Covered
  - Test: default false; persists true. Existing coverage: group `transaction colors`.

- **`static Future<double> getTransactionColorIntensity()` / setter** — ✅ Covered
  - Clamp 0..1. Test: default 0.5; -0.3→0.0; 1.5→1.0. Existing coverage: group `transaction colors`.

- **`static Future<void> clearAll()`** — ✅ Covered
  - Test: after setting several, clearAll resets all getters to defaults. Existing coverage: group `clearAll` (1).

### `lib/utils/color_contrast_helper.dart`

WCAG 2.1 contrast math + status-color palette. Existing tests: `test/utils/color_contrast_helper_test.dart` (thorough, ~30 cases incl. known-luminance assertions).

- **`static double contrastRatio(Color color1, Color color2)`** — ✅ Covered
  - `(L_light+0.05)/(L_dark+0.05)`.
  - Test cases:
    1. black/white → 21:1; order-independent; same color → 1:1
    2. all-pairs ≥ 1.0; white-on-blue > 4
    3. known luminance checks: pure red→5.252, green→15.304, blue→2.444 vs black (validates 0.2126/0.7152/0.0722 weights and the sRGB→linear curve)
  - Existing coverage: `color_contrast_helper_test.dart` groups `contrastRatio()` + `relativeLuminance (via contrastRatio)` (~12).

- **`static bool meetsAA(Color foreground, Color background)`** — ✅ Covered
  - ≥ 4.5. Test: black/white → true both orders; same color → false; light-gray-on-white fails; threshold const 4.5. Existing coverage: group `meetsAA()` (5).

- **`static bool meetsAALarge(Color foreground, Color background)`** — ✅ Covered
  - ≥ 3.0. Test: black/white true; threshold 3.0; a pair in [3.0,4.5) passes-large/fails-normal; same color false. Existing coverage: group `meetsAALarge()` (4).

- **`static Color getContrastingTextColor(Color background)`** — ✅ Covered
  - White if it meets AA, else black if it meets AA, else higher-contrast of the two.
  - Test cases:
    1. dark bg → white; light bg → black
    2. very-dark-blue → white; yellow → black
    3. always returns black or white (10 backgrounds)
  - Existing coverage: group `getContrastingTextColor()` (5). The "neither meets AA" fallback branch is covered implicitly by the all-backgrounds sweep.

- **`static Color adjustForContrast(Color color, Color background, {double targetRatio = 4.5})`** — ✅ Covered
  - 10-step binary search, darkens on light bg / lightens on dark bg.
  - Test cases:
    1. already-passing color returned unchanged
    2. low-contrast on light → resulting ratio ≥ 4.5; on dark → ≥ 4.5; custom targetRatio 3.0
    3. darkens-on-light (channel ≤ original) and lightens-on-dark (channel ≥ original) direction asserted. (Edge: a color the 10-step loop *cannot* reach target is not asserted — returns best effort silently; low risk.)
  - Existing coverage: group `adjustForContrast()` (6).

- **`static StatusColors getStatusColors(Brightness brightness)`** — ✅ Covered
  - Test: dark & light return non-null success/warning/error/info; dark≠light. Existing coverage: group `getStatusColors()` (3). (Does not assert the returned shades actually meet AA against a typical surface — the comments claim it but no test verifies; minor.)

- **`class StatusColors` (const ctor, 4 final fields)** — ✅ Covered (indirectly)
  - Constructed and field-accessed in `getStatusColors` tests. No standalone test; trivial value holder.

### `lib/utils/accessibility_helper.dart`

Touch-target + semantic-label helpers; some return Widgets. Existing tests: `test/utils/accessibility_helper_test.dart` (pure-logic methods only, ~20 cases).

- **`static const double minTouchTargetSize`** — ✅ Covered (== 48.0).

- **`static bool meetsMinimumTouchTarget(double width, double height)`** — ✅ Covered
  - Test cases: (48,48)/(50,50)/(100,100) true; (47,48)/(48,47)/(0,0) false. Existing coverage: group `meetsMinimumTouchTarget` (6).

- **`static Widget ensureMinTouchTarget(Widget child, {double currentWidth=0, double currentHeight=0})`** — ❌ Missing
  - Pads symmetrically to reach 48 dp; returns child unchanged if already big enough.
  - Test cases:
    1. small child (10×10) wrapped in Padding with (48-10)/2 = 19 each side — pumpWidget + inspect EdgeInsets
    2. already-large (60×60) returns the same child instance (no Padding)
    3. one dimension small, other large → asymmetric padding (only the deficient axis padded)
  - Existing coverage: none. **GAP** (widget test needed).

- **`static Widget semanticIconButton({...})`** — ❌ Missing
  - Semantics-wrapped IconButton with 48×48 min constraints + tooltip.
  - Test cases:
    1. renders IconButton with given icon; tapping fires onPressed
    2. Semantics node has label + button:true; tooltip == label
    3. constraints enforce 48×48 minimum
  - Existing coverage: none. **GAP**.

- **`static String getBudgetStatusLabel(double percentage, String category)`** — ✅ Covered
  - ≥100 "Over budget", ≥85 "Approaching limit", else "Under budget".
  - Test cases: 100/110 over; 85/90 approaching; 0/50 under; 84.9 under (boundary). Existing coverage: group `getBudgetStatusLabel` (7).

- **`static IconData getBudgetStatusIcon(double percentage)`** — ✅ Covered
  - Test cases: ≥100 cancel; [85,100) warning; <85 check_circle. Existing coverage: group `getBudgetStatusIcon` (3).

- **`static bool meetsContrastRequirement(Color foreground, Color background)`** — ✅ Covered
  - Uses `computeLuminance()` (Flutter's), ≥4.5. Test: black/white both orders true; near-identical grays false. Existing coverage: group `meetsContrastRequirement` (3). (Note: different luminance path than ColorContrastHelper — not cross-checked against it.)

- **`static Color getAccessibleTextColor(Color background)`** — ✅ Covered
  - luminance>0.5 → black87 else white. Test: black→white; white→black87. Existing coverage: group `getAccessibleTextColor` (2).

- **`static Widget makeFocusable(Widget child, {required VoidCallback onTap, String? semanticLabel})`** — ❌ Missing
  - Focus + GestureDetector + Semantics(focusable, focused mirrors Focus state).
  - Test cases:
    1. tapping the child fires onTap
    2. Semantics carries semanticLabel and button:true
    3. focused flag flips when the Focus node gains focus (requestFocus → pump → focused:true)
  - Existing coverage: none. **GAP**.

- **`static Widget accessibleChip({...})`** — ❌ Missing
  - FilterChip + Semantics(label includes "selected"/"not selected", selected mirrors state).
  - Test cases:
    1. renders label text; optional leading icon shown when provided / absent when null
    2. tapping toggles via onSelected(bool)
    3. Semantics label reads "<label>, selected" vs "not selected" per isSelected
  - Existing coverage: none. **GAP**.

- **`static void announce(BuildContext context, String message)`** — ❌ Missing
  - Shows a 500ms floating SnackBar (used as a screen-reader announcement).
  - Test cases:
    1. shows SnackBar with the message
    2. duration is 500ms, behavior floating
    3. no-op safety if messenger absent (currently would throw — worth documenting it requires a ScaffoldMessenger ancestor)
  - Existing coverage: none. **GAP**.

- **`static Widget accessibleProgressIndicator({required double value, required String label, ...})`** — ❌ Missing
  - LinearProgressIndicator + Semantics(label "<label>: N% complete", value "N%").
  - Test cases:
    1. value 0.5 → Semantics value "50%", label contains "50%"
    2. value 0 and 1 → "0%"/"100%"; minHeight 8 on the indicator
    3. fractional value 0.333 → truncates to "33%" (`.toInt()`)
  - Existing coverage: none. **GAP**.

- **`static String getPaymentProgressLabel(double amountPaid, double totalAmount)`** — ✅ Covered
  - Guards total>0 to avoid div-by-zero.
  - Test cases: 50/100→50%; 0/100→0%; 100/100→100%; 0/0→0% (div-zero guard). Existing coverage: group `getPaymentProgressLabel` (4).

### `lib/utils/category_icons.dart`

Icon registry + codePoint round-trip (tree-shake-safe lookup). Existing tests: `test/utils/category_icons_test.dart` (~15 cases).

- **`static const Map defaultExpenseIcons` / `defaultIncomeIcons`** — ✅ Covered
  - Test: all expected category keys present. Existing coverage: groups `defaultExpenseIcons`/`defaultIncomeIcons`.

- **`static const List<IconData> availableIcons`** — ✅ Covered
  - Test: non-empty; contains every default expense + income icon (guards the reverse-lookup map's completeness). Existing coverage: group `availableIcons` (3).

- **`static String iconToString(IconData icon)`** — ✅ Covered
  - Test: returns `codePoint.toString()`. Existing coverage: group `iconToString`.

- **`static IconData iconFromString(String? iconStr)`** — ✅ Covered
  - null/empty/non-numeric/unknown-codePoint → `Icons.category_rounded`; valid → constant from lookup map.
  - Test cases: null/empty/invalid → fallback; round-trip restaurant icon. Existing coverage: group `iconFromString` (4). (Edge: a numeric codePoint NOT in `availableIcons` → fallback — implied by lookup but no dedicated test.)

- **`static IconData getDefaultIcon(String categoryName, String type)`** — ✅ Covered
  - income vs expense map; unknown → category_rounded. Test: Food/expense→restaurant; Salary/income→wallet; Unknown→fallback. Existing coverage: group `getDefaultIcon` (3).

- **`static IconData getIcon(String? iconStr, String categoryName, String type)`** — ✅ Covered
  - Non-empty iconStr → parse; else default. Test: null/empty → default-for-category; valid custom string → custom icon. Existing coverage: group `getIcon` (3).

### `lib/utils/clock.dart`

Injectable clock for deterministic time in tests. Existing tests: `test/utils/clock_test.dart` (covers all, with tearDown reset).

- **`class Clock` — `const Clock()` ctor, `DateTime now()`, `static Clock instance`** — ✅ Covered
  - Test: default `instance.now()` ≈ wall clock (within ±100ms window). Existing coverage: group `Clock`.

- **`FakeClock.fixed(DateTime)` + `now()`** — ✅ Covered
  - Test: returns same instant on repeated calls; swappable per-test, reset in tearDown. Existing coverage: group `FakeClock.fixed` (2).

- **`FakeClock.sequence(List<DateTime>)` + `now()`** — ✅ Covered
  - Yields each then sticks on last; asserts on empty sequence.
  - Test cases:
    1. yields [d1,d2,d3] in order
    2. sticks on last after exhaustion (models "lockout expired and stays expired")
    3. empty list → AssertionError
  - Existing coverage: group `FakeClock.sequence` (2). Solid.

### `lib/utils/async_mutex.dart`

FIFO async lock guarding DB writes. Existing tests: `test/utils/async_mutex_test.dart` (thorough, ~20 cases).

- **`Future<void> acquire()`** — ✅ Covered
  - Immediate if free; else enqueue completer and await.
  - Test cases:
    1. acquire on free mutex locks immediately
    2. second acquire on locked mutex queues (waitingCount increments 1→2→3)
    3. re-entrance: second acquire blocks until release (asserts still-blocked after a microtask drain)
  - Existing coverage: `async_mutex_test.dart` groups `acquire() and release()`, `waitingCount`, `reentrance check`.

- **`void release()`** — ✅ Covered
  - Throws if not locked; else hands lock to next waiter (stays locked) or unlocks.
  - Test cases:
    1. release unlocks when no waiters
    2. release on unlocked → StateError
    3. release with waiter keeps `isLocked` true (handoff) and decrements waitingCount
  - Existing coverage: groups `acquire() and release()` + `isLocked getter` (handoff test).

- **`Future<T> synchronized<T>(Future<T> Function() fn)`** — ✅ Covered
  - acquire → run → release in finally.
  - Test cases:
    1. acquires around fn, releases after, returns value
    2. serializes concurrent calls (order [1,2,3,4]); 5 calls strict FIFO interleave
    3. releases on throw (isLocked false after); propagates the exception
  - Existing coverage: groups `synchronized<T>()` + `FIFO ordering` (exception-release explicitly tested).

- **`bool get isLocked`** — ✅ Covered
  - Test: false initially; true after acquire; false after release; stays true through handoff. Existing coverage: group `isLocked getter` (4).

- **`int get waitingCount`** — ✅ Covered
  - Test: 0 initially; increments per queued acquire; decrements as waiters acquire. Existing coverage: group `waitingCount` (2).

### `lib/utils/dialog_helpers.dart`

Confirmation/warning AlertDialogs; static session flag `_skipFutureDateWarning`. Existing tests: `test/utils/dialog_helpers_test.dart` (widget tests with `SystemChannels.platform` haptic mock + captured-context harness).

- **`static Future<bool> showBudgetDeletionWarning(BuildContext, {required categoryName, currentSpending, budgetAmount, currency})`** — ✅ Covered
  - Test cases:
    1. dialog shows category name + budget + spent amounts (formatted)
    2. Delete Budget → true
    3. Cancel → false. (Note: relies on AppColors theme extension being present.)
  - Existing coverage: `dialog_helpers_test.dart` group `showBudgetDeletionWarning` (2). The `!context.mounted` early-false path after the await is not tested (hard to trigger).

- **`static Future<String?> showCurrencyChangeWarning(BuildContext, {required oldCurrency, newCurrency, transactionCount})`** — ✅ Covered
  - Test cases: Keep Amounts → "keep"; Clear All Data → "clear"; Cancel → null; shows currencies + count. Existing coverage: group `showCurrencyChangeWarning` (3).

- **`static Future<bool> showFutureDateConfirmation(BuildContext, DateTime selectedDate)`** — ✅ Covered
  - Honors session skip flag; "Don't ask again" checkbox sets it.
  - Test cases:
    1. Continue → true; Change Date → false
    2. checkbox + Continue → subsequent calls short-circuit true with no dialog shown
    3. resetFutureDateWarning re-enables the prompt
  - Existing coverage: group `showFutureDateConfirmation` (4) — including the static-flag re-entrancy across calls.

- **`static void resetFutureDateWarning()`** — ✅ Covered
  - Test: re-enables prompt after it was skipped. Existing coverage: above group.

- **`static Future<bool> showConfirmation(BuildContext, {required title, message, confirmText='Confirm', cancelText='Cancel', isDangerous=false})`** — ✅ Covered
  - Test cases:
    1. Confirm → true; shows title/message
    2. Cancel → false; barrier-dismiss → false (null-coalesced)
    3. custom labels rendered; isDangerous gives FilledButton red background
  - Existing coverage: group `showConfirmation` (5).

### `lib/utils/snackbar_helper.dart`

Themed SnackBars; all guard `context.mounted`. Existing tests: `test/utils/snackbar_helper_test.dart` (widget tests with known-value AppColors).

- **`static void showSuccess/showError/showWarning/showInfo(BuildContext, String message)`** — ✅ Covered
  - Test cases:
    1. each shows its message + correct icon (check_circle/error/warning/info)
    2. correct background (incomeGreen/expenseRed/warningOrange/infoBlue), floating behavior
    3. error duration 4s (> the 3s others) asserted; the `!context.mounted` guard early-return not tested (low risk)
  - Existing coverage: `snackbar_helper_test.dart` groups showSuccess/showError/showWarning/showInfo (6).

- **`static void showUndo(BuildContext, String message, VoidCallback onUndo)`** — ✅ Covered
  - Test cases: shows message + UNDO action; tapping UNDO fires callback once; duration 5s. Existing coverage: group `SnackBarHelper.showUndo` (2).

### `lib/utils/haptic_helper.dart`

Thin wrappers over `HapticFeedback.*`. **No test file exists.**

- **`static Future<void> lightImpact()`** — ❌ Missing
  - Calls `HapticFeedback.lightImpact()`.
  - Test cases:
    1. mock `SystemChannels.platform` (HapticFeedback uses it) and assert `invokeMethod('HapticFeedback.vibrate', 'HapticFeedbackType.lightImpact')` was recorded
    2. completes without throwing when handler returns null
    3. (n/a) no input variation
  - Existing coverage: none. **GAP** (low value — pure delegation; one parametric test over all methods would suffice).

- **`static Future<void> mediumImpact()`** — ❌ Missing
  - Asserts `HapticFeedbackType.mediumImpact` arg via platform-channel spy. Existing coverage: none.

- **`static Future<void> heavyImpact()`** — ❌ Missing
  - Asserts `heavyImpact` arg. Existing coverage: none.

- **`static Future<void> selectionClick()`** — ❌ Missing
  - Records `HapticFeedback.selectionClick` method call. Existing coverage: none.

- **`static Future<void> vibrate()`** — ❌ Missing
  - Records `HapticFeedback.vibrate` (no arg). Existing coverage: none.

- **`static Future<void> budgetExceeded()`** — ❌ Missing
  - Delegates to heavyImpact — assert it produces the heavyImpact channel call. Existing coverage: none.

- **`static Future<void> itemDeleted()`** — ❌ Missing
  - Delegates to mediumImpact. Existing coverage: none.

- **`static Future<void> success()`** — ❌ Missing
  - Delegates to lightImpact. Existing coverage: none.

- **`static Future<void> error()`** — ❌ Missing
  - Delegates to vibrate. Existing coverage: none.

### `lib/utils/permission_helper.dart`

Android storage-permission flow with SDK-version branching + MethodChannel. **No test file exists.** Static cache `_cachedAndroidSdk`.

- **`static Future<bool> requestStoragePermission(BuildContext context)`** — ❌ Missing
  - Non-Android → true; SDK≥33 → true (SAF); SDK 30–32 → true regardless; SDK≤29 → real request flow + denied dialog.
  - Test cases:
    1. with `Platform.isAndroid` false → returns true (needs platform override or run on non-Android host)
    2. SDK 33 path returns true without requesting; SDK 30 path returns true even when permanentlyDenied
    3. SDK 29 permanentlyDenied → shows settings dialog (mock `permission_handler` + `app_settings` channels); async-gap `context.mounted` checked before dialog
  - Existing coverage: none. **GAP** — heavy platform-channel + `Platform.isAndroid` dependency makes this the hardest to test; needs `permission_handler` mock + `MethodChannel('budget_tracker/device_info')` stub. High-value but high-effort.

- **`static Future<bool> hasStoragePermission()`** — ❌ Missing
  - Non-Android → true; SDK≥30 → true; else checks `Permission.storage.status`.
  - Test cases:
    1. non-Android → true
    2. SDK≥30 → true without checking permission
    3. SDK≤29 granted → true / denied → false (mock permission_handler)
  - Existing coverage: none. **GAP**.

- **`static void showPermissionDeniedSnackbar(BuildContext context)`** — ❌ Missing
  - Orange SnackBar with "Settings" action (opens app settings).
  - Test cases:
    1. shows SnackBar with the permission message + orange background
    2. has a "Settings" action; tapping it invokes `AppSettings.openAppSettings` (mock app_settings channel)
    3. `!context.mounted` guard → no-op
  - Existing coverage: none. **GAP** (widget-testable, unlike the request flow).

  (Private helpers `_getAndroidSdkVersion`, `_detectAndroidVersionFallback`, `_showPermissionDeniedDialog` are not public API; exercised only indirectly.)

### `lib/utils/progress_indicator_helper.dart`

Modal progress dialogs (CircularProgressIndicator / LinearProgressIndicator). **No test file exists.**

- **`static void show(BuildContext context, {String message = 'Processing...'})`** — ❌ Missing
  - Non-dismissible PopScope dialog with spinner + message.
  - Test cases:
    1. shows AlertDialog with CircularProgressIndicator and default "Processing..." text
    2. custom message rendered
    3. PopScope canPop:false — back button does not dismiss (simulate `Navigator.maybePop`)
  - Existing coverage: none. **GAP** (widget-testable).

- **`static Future<void> showWithProgress(BuildContext context, {required String title, required Future<void> Function(void Function(double, String)) operation})`** — ❌ Missing
  - Shows dialog, runs operation with an `updateProgress(progress, status)` callback that rebuilds via StateSetter, pops in finally.
  - Test cases:
    1. operation calling updateProgress(0.5, 'Half') updates LinearProgressIndicator.value to 0.5 and shows "50%" + status (pump between updates)
    2. progress clamped to 0..1 (passing 2.0 shows 100%); title rendered
    3. dialog dismissed in finally even when operation throws (assert dialog gone + exception propagates); async-gap `context.mounted` guard before pop
  - Existing coverage: none. **GAP** — the most logic-bearing method here (clamp + StateSetter + finally-pop), worth a widget test.

- **`static void hide(BuildContext context)`** — ❌ Missing
  - Pops if mounted.
  - Test cases:
    1. after `show`, `hide` removes the dialog
    2. `!context.mounted` → no-op (no exception)
    3. double-hide does not over-pop the navigator (idempotency-ish)
  - Existing coverage: none. **GAP**.

- **`static Future<T> showDuring<T>(BuildContext context, Future<T> operation, {String message = 'Processing...'})`** — ❌ Missing
  - show → await operation → hide in finally; returns operation's result.
  - Test cases:
    1. returns the awaited value; dialog shown during, gone after
    2. hides even when operation throws (and rethrows)
    3. `context.mounted` re-checked after the async gap before hide
  - Existing coverage: none. **GAP**.

#### Coverage summary
74 public functions/getters/constructors; 50 ✅, 4 🟡, 20 ❌. Highest-priority gaps: `DateHelper.addDays` (recurring-transaction primitive, zero tests), `ProgressIndicatorHelper.showWithProgress` (clamp + StateSetter + finally-pop logic, untested), all of `permission_helper.dart` (SDK-branching storage flow, untested — needs permission_handler/device_info channel mocks), the five Widget-returning `AccessibilityHelper` methods (`ensureMinTouchTarget`, `semanticIconButton`, `makeFocusable`, `accessibleChip`, `accessibleProgressIndicator`), `AccessibilityHelper.announce`, and `SnackBarHelper`/`ProgressIndicatorHelper` `context.mounted` guard branches. Lower-priority: `haptic_helper.dart` (pure delegation — one parametric channel-spy test covers all 9); 🟡 items are `CurrencyHelper.formatCompact` (fallback branch), `Validators.validateTagName` (missing test pinning that no char-blocking applies), `DateHelper.today`/`isPast`/`isFuture`/`isToday` (correct but time-dependent, not Clock-injectable by design).


## Utility Helpers - security, storage, notifications, export (lib/utils/)

### `lib/utils/backup_crypto.dart`

- **`static Future<String> encrypt(String json, String passphrase)`** — ✅ Covered
  - PBKDF2(HMAC-SHA256, 100k iters) derives a 256-bit key from passphrase+salt; AES-GCM encrypts; returns a v4 JSON envelope with base64 salt/iv/ciphertext/tag.
  - Test cases:
    1. Round-trip: encrypt then decrypt with same passphrase recovers exact plaintext — assert equality.
    2. Empty passphrase throws `ArgumentError` (boundary) — `expectLater(..., throwsArgumentError)`.
    3. Two encrypts of same input → different IV and ciphertext (fresh-nonce invariant) — decode both, assert `iv` differs.
    4. Envelope shape: version==4, encrypted==true, salt 16 bytes, iv 12 bytes, tag 16 bytes.
    5. Unicode/large plaintext round-trips (UTF-8 multibyte, emoji in descriptions) — money/locale concern.
  - Existing coverage: `test/utils/backup_crypto_test.dart` covers 1-4 fully (round-trips, empty-passphrase throw, v4 shape with exact byte lengths, fresh-IV). Missing: explicit large/multibyte-UTF-8 payload (5) — only the small ASCII sample is exercised.

- **`static Future<String?> decrypt(String envelopeJson, String passphrase)`** — ✅ Covered
  - Reverses `encrypt`; returns `null` (never throws) on wrong passphrase, malformed JSON, non-envelope input, bad base64, wrong field lengths, or GCM tag mismatch.
  - Test cases:
    1. Wrong passphrase → null, never the wrong plaintext.
    2. Empty passphrase → null (early return).
    3. Plaintext v3 (`encrypted:false`) → null.
    4. Malformed JSON → null (FormatException swallowed).
    5. Tampered ciphertext (flip 1 bit) → null (GCM tag rejects).
    6. Tampered tag / tampered iv / tampered salt → null (each field independently).
    7. Wrong salt length (3 bytes) → null; also wrong iv length, wrong tag length.
    8. Non-base64 in a field (`base64Decode` FormatException) → null.
    9. Top-level JSON is a List/number not a Map → null.
  - Existing coverage: `backup_crypto_test.dart` covers 1-5, 7 (salt length), and 3/4. Missing: tampered **tag** and **iv** specifically (only ciphertext + salt-length tested), non-base64 field (8), and non-Map JSON (9).

- **`static bool isEncryptedEnvelope(String text)`** — ✅ Covered
  - Cheap detector: true only when text parses to a Map with `encrypted==true`, int `version`, and string salt/iv/ciphertext/tag.
  - Test cases:
    1. Fresh envelope → true.
    2. Plaintext v3 with `encrypted:false` → false; v3 without `encrypted` field → false.
    3. Empty / `{{{` / `'null'` → false.
    4. Missing required fields (salt only) → false.
    5. `version` present but not an int (e.g. `"4"`) → false (boundary).
  - Existing coverage: `backup_crypto_test.dart` covers 1-4. Missing: non-int version (5).

#### `lib/utils/crash_log.dart`

- **`static Future<void> init({required String appVersion})`** — 🟡 Partial
  - Idempotent global error-handler wiring; sets `FlutterError.onError` + `PlatformDispatcher.instance.onError`, stores appVersion.
  - Test cases:
    1. First call sets `_initialized`, records appVersion (observable via a subsequent record showing `App: FinanceFlow <ver>`).
    2. Second call is a no-op (idempotency) — call twice with different versions, assert first version still used.
    3. `FlutterError.onError` handler routes a synthetic `FlutterErrorDetails` into the log.
    4. `PlatformDispatcher.onError` handler returns true and records with context `platform_dispatcher`.
  - Existing coverage: `test/utils/crash_log_test.dart` `setUp` calls `init` and case 1 is implied via `record`. Missing: idempotency (2), and the two installed handlers (3,4) are never invoked/asserted.

- **`static Future<void> record(Object error, {StackTrace? stack, String? context})`** — ✅ Covered
  - Serializes appends via a write-queue (`_writeQueue`) so concurrent errors don't interleave; formats + redacts each record.
  - Test cases:
    1. Writes a formatted entry containing the error string, context, and app header.
    2. Concurrent `record` calls don't interleave bytes (re-entrancy/serialization) — fire 10 unawaited records, await queue, assert each record block is intact.
    3. `record` persists the redacted form (PII stripped) not the raw — already a strong test.
    4. Never throws even when the directory write fails (override to a bad dir).
  - Existing coverage: `crash_log_test.dart` covers 1 and 3 (redaction integration). Missing: explicit concurrent-interleave assertion (2) and write-failure-swallow (4) — serialization exists in code but isn't directly stressed.

- **`static Future<String> readAll()`** — ✅ Covered
  - Concatenates rotated files oldest→newest; returns `''` when no dir; returns an error string (never throws) on read failure.
  - Test cases:
    1. Returns oldest-first chronological order across rotation files.
    2. Empty when nothing logged.
    3. Returns `'Error reading crash log: ...'` on a read exception (does not throw).
  - Existing coverage: `crash_log_test.dart` covers 1 and 2 (via clear). Missing: error-path string (3).

- **`static Future<void> clear()`** — ✅ Covered
  - Deletes every rotation file; silent on error.
  - Test cases:
    1. After clear, `readAll` is empty.
    2. Safe when no files exist (idempotent).
  - Existing coverage: `crash_log_test.dart` covers 1. Missing: clear-when-empty (2) is implicit only.

- **`static String redactPii(String input)`** — 🟡 Partial
  - Masks emails, Windows/Unix user paths (shape-preserving), credit-card digit runs, currency-tagged amounts. Pure, never throws.
  - Test cases:
    1. Windows path `C:/Users/jane/...` → `C:/Users/[user]/...`, username gone. (covered)
    2. Unix `/home/x` + `/Users/y` paths masked. (covered)
    3. Email masked. (covered)
    4. Currency-tagged amounts `$`,`€`,`£`,`¥`,`₹` → `[amount]`. (covered for first four; `₹` not asserted)
    5. CC-shaped 16-digit run → `[cc]`. (covered)
    6. Plain ids/timestamps left verbatim. (covered)
    7. Empty input unchanged. (covered)
    8. **GAP — symbol-less amounts**: `"balance 1234.56 overdrawn"` has no currency symbol → NOT redacted (regex requires a leading `$€£¥₹`). Document/assert this is a known leak; a future fix would need a bare-decimal heuristic.
    9. **GAP — free-text PII**: names/phone numbers in pasted descriptions (`"call John at 555-123-4567"`) are not masked — only the four classes are. Assert phone-shaped runs survive (current behavior) so the gap is pinned.
    10. **GAP — backslash Windows path** `C:\Users\jane\...` (literal backslashes, as in real Windows stack traces) — the integration test covers it but no direct `redactPii` unit test for the `\\` variant in isolation.
    11. Email-adjacent false positives (e.g. `a@b` with no TLD) correctly NOT masked (boundary of `{2,}` TLD rule).
  - Existing coverage: `crash_log_test.dart` PII group covers 1-7 and the `record()` integration covers `\\`-path + email + amount. Missing: `₹` rupee (4), symbol-less amount gap (8), free-text/phone gap (9), isolated backslash-path unit (10), email boundary (11).

- **`@visibleForTesting static const int maxLogBytes` / `maxLogFiles`** — ✅ Covered
  - Rotation thresholds (256 KB, 3 files).
  - Test cases:
    1. Rotation occurs once active file exceeds `maxLogBytes`; file count between 2 and `maxLogFiles`.
  - Existing coverage: `crash_log_test.dart` "rotates when active file exceeds maxLogBytes" covers it.

- **`@visibleForTesting static void resetForTesting()`** / **`static Directory? directoryOverride`** — ✅ Covered (test seams, exercised every `setUp`/`tearDown`).

#### `lib/utils/secure_prefs.dart`

- **`static Future<String?> readString(String key)`** — ✅ Covered
  - Reads secure store first; on miss, lazily migrates from `SharedPreferences` (copy to secure, scrub legacy), returns legacy value. Swallows secure-read errors → treats as miss.
  - Test cases:
    1. Reads a value already in the secure store.
    2. Migrates a legacy string on first read; secure store populated, legacy scrubbed; second read hits secure only.
    3. Returns null when both stores empty.
    4. Secure-read throws (Keystore error) → falls through to legacy migration path (resilience).
  - Existing coverage: `test/utils/secure_prefs_test.dart` covers 1-3. Missing: secure-`read`-throws branch (4) — only `write` throwing is tested.

- **`static Future<bool?> readBool(String key)`** — ✅ Covered
  - Coerces stored string to bool (`=='true'`), null when absent.
  - Test cases: legacy bool migrates and reads back true (covered); stored `'false'`→false; absent→null.
  - Existing coverage: `secure_prefs_test.dart` covers true-migration + round-trip; false and null implicit via `writeBool` round-trip.

- **`static Future<int?> readInt(String key)`** — ✅ Covered
  - `int.tryParse` of stored string; null on absent or unparseable.
  - Test cases: legacy int migrates (covered); round-trip 42 (covered); unparseable string → null (edge, not asserted).
  - Existing coverage: `secure_prefs_test.dart` covers migration + round-trip. Missing: unparseable-value→null edge.

- **`static Future<void> writeString(String key, String value)`** — ✅ Covered
  - Writes secure; on success scrubs legacy; on secure-write failure falls back to `SharedPreferences` (never lose data).
  - Test cases:
    1. Persists to secure store, reads back.
    2. Scrubs an existing legacy entry on the same key.
    3. Secure-write throws → value lands in `SharedPreferences` fallback (data-loss-prevention).
  - Existing coverage: `secure_prefs_test.dart` covers 1, 2; the flaky-write test covers the *migration* fallback. Missing: the `writeString` direct fallback path (3) — distinct from migration fallback.

- **`static Future<void> writeBool(String, bool)` / `writeInt(String, int)`** — ✅ Covered (round-trip tests present).

- **`static Future<void> remove(String key)`** — ✅ Covered
  - Deletes from both stores; swallows secure-delete error.
  - Test cases: removes from both (covered); secure-delete throws but legacy still removed (edge, not asserted).
  - Existing coverage: `secure_prefs_test.dart` "remove deletes from both stores". Missing: secure-delete-throws edge.

#### `lib/utils/pin_security_helper.dart`

> NOTE: hashing is currently **single-round SHA-256** (`_hashPin`/`_hashPinWithSalt`), slated for PBKDF2 in this session's plan. Tests below should pin the current contract AND flag the upgrade so the migrate-on-verify path is added when PBKDF2 lands.

- **`static Future<bool> isPinEnabled()`** — ✅ Covered (storage test reads false→true→false through set/disable).
- **`static Future<int> getPinLength()`** — ✅ Covered (returns 4 default + migrated 4/6).

- **`static Future<bool> setPin(String pin)`** — ✅ Covered
  - Validates 4-6 digits; generates salt; stores salted hash + salt + enabled + length in secure store.
  - Test cases:
    1. Valid PIN → true; hash+salt in secure store, NOT in legacy prefs; length persisted.
    2. Invalid (letters / too short / too long) → false, nothing written.
    3. Salt is random — two `setPin` of same PIN yield different stored hashes (rainbow-table resistance).
  - Existing coverage: `test/utils/pin_security_storage_test.dart` covers 1, 2. Missing: random-salt-per-setPin assertion (3).

- **`static Future<bool> isLockedOut()`** — ✅ Covered
  - True while `now < lockoutUntil`; self-heals (clears data) once expired.
  - Test cases: armed after 5 fails (covered); self-heals after window via FakeClock (covered); false when never locked (covered).
  - Existing coverage: `test/utils/pin_lockout_test.dart` covers all under FakeClock.

- **`static Future<int> getRemainingLockoutSeconds()`** — ✅ Covered
  - Countdown from 300; 0 when not locked or expired.
  - Test cases: 300 right after arming; drops with moving clock (2min→180, 4:30→30); 0 when none.
  - Existing coverage: `pin_lockout_test.dart` "countdown reflects the moving clock".

- **`static Future<int> getRemainingAttempts()`** — ✅ Covered
  - `5 - failedAttempts`.
  - Test cases: 5 fresh; decrements per fail; resets on success/expiry.
  - Existing coverage: `pin_lockout_test.dart` + `pin_security_storage_test.dart`.

- **`static Future<bool> verifyPin(String pin)`** — 🟡 Partial
  - Returns false if locked out; constant-time compares salted (or legacy un-salted) hash; clears counters on success, increments + arms lockout on failure.
  - Test cases:
    1. Correct PIN → true, counter resets.
    2. Wrong PIN → false, counter increments.
    3. Locked out → returns false WITHOUT checking the hash (even with the right PIN) — assert a correct PIN during lockout still returns false.
    4. Legacy salted-prefs PIN migrates + verifies.
    5. Legacy un-salted PIN (no salt key) verifies via `_hashPin` path.
    6. 5th wrong arms lockout; success on a non-locked streak resets without arming.
    7. Constant-time compare: length-mismatch short-circuits to false (defensive) — hard to observe timing, but assert a truncated stored hash returns false.
  - Existing coverage: `pin_security_storage_test.dart` covers 1,2,4,5; `pin_lockout_test.dart` covers 1,2,6. Missing: **correct-PIN-while-locked-out still false (3)** — the security-critical lockout-precedence case is never asserted; (7) length-mismatch branch untested.

- **`static Future<bool> changePin(String oldPin, String newPin)`** — ❌ Missing
  - Verifies old PIN then `setPin(new)`; false if old wrong.
  - Test cases:
    1. Correct old + valid new → true; new PIN verifies, old no longer does.
    2. Wrong old → false; stored hash unchanged.
    3. Correct old but invalid new (3 digits) → false (returns `setPin` result); old PIN must still verify (no partial overwrite).
    4. `changePin` while locked out → old verify returns false → false (interaction with lockout).
  - Existing coverage: none. GAP — no test calls `changePin` at all.

- **`static Future<void> disablePin()`** — ✅ Covered (storage round-trip asserts enabled flag false + hash/salt gone).

- **`static String? checkPinStrength(String pin)`** — ✅ Covered
  - Returns format error / identical-digit / sequential warning / null.
  - Test cases: exhaustively covered — invalid formats, all-identical, ascending/descending 4-6 digit, strong PINs, unicode-digit rejection, leading zero, precedence (identical before sequential).
  - Existing coverage: `test/utils/pin_security_helper_test.dart` is exhaustive (~50 cases).

- **`static Future<void> resetPinData()`** — ✅ Covered (storage test "resetPinData wipes both stores").

- **(private, behavior-pinned) `_constantTimeEquals`, `_hashPin`, `_hashPinWithSalt`, `_generateSalt`, `_isValidPin`** — 🟡 Partial
  - Test cases: SHA-256 determinism, 64-hex output, salt-changes-hash, salt+pin concat, empty-string known digest. Constant-time equality is NOT directly tested (private; only its observable effect via verifyPin).
  - Existing coverage: `pin_security_helper_test.dart` "SHA-256 hashing concepts" group re-derives the hash behavior externally. Missing: direct constant-time-compare property and `_generateSalt` 16-byte/base64 length (only inferred). When PBKDF2 lands, these need migrate-on-verify (old SHA-256 hash → re-hash with PBKDF2 on next successful verify) — currently no such path exists, so it's a future GAP to scaffold.

#### `lib/utils/secure_window.dart`

- **`static Future<void> setSecure(bool on)`** — ✅ Covered
  - Routes through `testHandler` if set; else no-op off-Android; else invokes `budget_tracker/secure_window` channel, swallowing `PlatformException` + `MissingPluginException`.
  - Test cases:
    1. `setSecure(true)`/`(false)` route the right bool through `testHandler`.
    2. Off-Android (host) without handler → silent no-op (no channel call) — implicitly true since tests inject a handler.
    3. Real channel `PlatformException` swallowed (best-effort) — only reachable on Android; documented, not unit-tested.
  - Existing coverage: `test/utils/secure_window_test.dart` covers 1; the "swallows handler exceptions" test asserts the raw seam DOES rethrow (by design, so CI sees handler bugs). Missing: the real-channel exception-swallow (3) is platform-gated and untestable on host (acceptable).

- **`static Future<void> syncFromPinState()`** — ✅ Covered
  - Reads PIN state (via `pinStateOverride` or `PinSecurityHelper`), calls `setSecure` accordingly.
  - Test cases: PIN enabled → setSecure(true); disabled → setSecure(false).
  - Existing coverage: `secure_window_test.dart` covers both via `pinStateOverride`.

- **`@visibleForTesting testHandler` / `pinStateOverride`** — ✅ Covered (tearDown-reset asserted).

#### `lib/utils/widget_payload.dart`

- **`class WidgetData` (const ctor + `copyWith`)** — ✅ Covered
  - Immutable widget payload shape; `copyWith` overrides selected fields.
  - Test cases: `copyWith(isPositive:false)` flips only that field (covered via redaction tests); identity of non-overridden fields.
  - Existing coverage: `test/utils/widget_payload_test.dart` exercises `copyWith` indirectly. Missing: a direct standalone `copyWith` test (low priority).

- **`static WidgetData redactIfLocked(WidgetData data, {required bool pinEnabled})`** — ✅ Covered
  - When locked, replaces month→`Locked` and expenses/income/balance→`•••`; preserves currency + isPositive; returns new instance.
  - Test cases:
    1. PIN disabled → input returned unchanged.
    2. PIN enabled → all three monetary fields become `redactedAmount`.
    3. month → `redactedLabel`.
    4. currency preserved (layout stability).
    5. isPositive preserved (accent color stability), both polarities.
    6. Returns a new instance, never mutates input.
  - Existing coverage: `widget_payload_test.dart` covers all 6.

#### `lib/utils/notification_helper.dart`

> NOTE: known bugs flagged M17/M18/M19 in this layer — see test cases below. NO test file exists for this class (`notification_helper_test.dart` absent). Everything here is ❌ Missing unless noted.

- **`factory NotificationHelper()` / `_internal()`** — 🟡 Partial (singleton)
  - Always returns the same instance.
  - Test cases: two `NotificationHelper()` calls are `identical`.
  - Existing coverage: none directly; trivial.

- **`static void setChannelNames({...})`** — ❌ Missing
  - Overrides the six static channel name/desc strings (localization); null args leave defaults.
  - Test cases:
    1. Setting names updates the values used in subsequent `AndroidNotificationDetails`.
    2. Null args preserve existing (partial override).
    3. **Static-state leak**: because these are static, one test's override bleeds into the next — assert/reset in tearDown (re-entrancy/global-state concern).
  - Existing coverage: none.

- **`Future<void> initialize()`** — ❌ Missing
  - Idempotent; `tz.initializeTimeZones()` + plugin init.
  - Test cases: first call inits timezones + plugin (mock `dexterous.com/flutter/local_notifications`); second call no-ops; safe to call from every scheduling method.
  - Existing coverage: none.

- **`Future<bool> areNotificationsEnabled()`** — ❌ Missing
  - Android-only; defaults true off-Android or null result.
  - Test cases: null platform impl → true; mocked false → false.
  - Existing coverage: none.

- **`Future<bool> canScheduleExactAlarms()`** — ❌ Missing
  - Test cases: non-Android → true; granted → true; denied → false; null → true.
  - Existing coverage: none.

- **`Future<void> requestExactAlarmPermission()` / `Future<bool> requestPermissions()`** — ❌ Missing
  - Test cases: iOS path requests alert/badge/sound; Android-13 path requests notif permission; returns true when impl null.
  - Existing coverage: none.

- **`Future<void> scheduleBillReminder(RecurringExpense, {String currencySymbol})`** — ❌ Missing (HIGH priority — money + timezone + IDs + idempotency)
  - Computes due/reminder date, clamps day to month length, books a `zonedSchedule` in `tz.local`; uses ID range 10000-19999; for day≥29 (end-of-month) books one-shot with SharedPreferences idempotency marker; else monthly-repeat.
  - Test cases:
    1. Inactive expense or null id → no-op.
    2. Regular bill (day 1-28): schedules with `matchDateTimeComponents: dayOfMonthAndTime`, id == `10000 + expenseId`, body has `currencySymbol + amount.toStringAsFixed(2)` (money formatting).
    3. Day-31 bill in a 30-day month: `day` clamped to `maxDaysInMonth` (boundary — Feb/short months).
    4. Reminder already passed this month → rolls to next month, including Dec→Jan year rollover (`nextMonth>12`). **M17/M18/M19 candidate** — verify the next-month day clamp + year increment are correct.
    5. End-of-month (day≥29) idempotency: if stored epoch == computed epoch → skip (no re-book); else cancel prior + schedule one-shot + persist epoch (TOCTOU/idempotency).
    6. Timezone: scheduled `TZDateTime` is in `tz.local`; reminder fixed at 09:00 local — assert UTC/local conversion under a non-UTC `tz.setLocalLocation`.
    7. Amount with >2 decimals or large value formats to exactly 2 dp (money precision; note this path uses `double`, not Decimal — flag rounding).
  - Existing coverage: none. (Use mocked `flutter_local_notifications` channel + `SharedPreferences.setMockInitialValues` + `FakeClock` via `Clock.instance` + `tz` test location.)

- **`Future<void> cancelBillReminder(int expenseId)`** — ❌ Missing
  - Cancels id `10000+expenseId` and clears the EOM idempotency marker (so a later schedule isn't short-circuited).
  - Test cases: cancels the right id; removes `eom_bill_scheduled_<id>` from prefs; swallows prefs error.
  - Existing coverage: none.

- **`Future<void> rescheduleEndOfMonthBillReminders(List<RecurringExpense>, {String currencySymbol})`** — ❌ Missing
  - Iterates active day≥29 recurrings, re-books via `scheduleBillReminder`; idempotent; per-item try/catch.
  - Test cases: empty list → no-op; skips inactive / null-id / day<29; one failing item doesn't abort the loop (resilience); double-call is idempotent (epoch marker).
  - Existing coverage: none.

- **`Future<void> showBudgetAlert(Budget, double spent, double percentage, {String currencySymbol})`** — ❌ Missing
  - Immediate notification; id `20000 + budget.id`; tiered title/body by percentage thresholds; returns early under 0.8.
  - Test cases:
    1. <0.8 → no notification shown (boundary at exactly 0.8 fires "warning").
    2. 0.8 ≤ p <0.9 → warning; 0.9 ≤ p <1.0 → alert; ≥1.0 → exceeded — assert title + body text + amount formatting at each boundary.
    3. Exactly 0.9 and exactly 1.0 boundaries (off-by-one money thresholds).
    4. id == `20000 + (budget.id ?? 0)` — collision-free vs bill range; null budget.id → uses 0.
    5. Negative "remaining" when spent>budget at the 0.9 tier (money sign).
  - Existing coverage: none.

- **`Future<void> scheduleMonthlyReports()`** — ❌ Missing
  - Books id 9999 for 1st of next month 09:00, repeating monthly; falls forward 2 months if computed time is past.
  - Test cases: schedules 1st-of-next-month 09:00 in tz.local; `matchDateTimeComponents: dayOfMonthAndTime`; exact-vs-inexact mode by permission; Dec→Jan rollover.
  - Existing coverage: none.

- **`Future<void> cancelMonthlyReports()`** — ❌ Missing — cancels id 9999. Test: asserts the cancel call.

- **`Future<void> showMonthlySummary(double totalSpent, double budget, {String currencySymbol})`** — ❌ Missing
  - id 9999; computes percentage (guards budget==0 → 0%); status ✅/⚠️ by spent≤budget.
  - Test cases: budget==0 → 0% (division-by-zero guard); spent≤budget → ✅; spent>budget → ⚠️; amount formatted to 2dp.
  - Existing coverage: none.

- **`Future<void> cancelAllNotifications()`** — ❌ Missing — `cancelAll()`. Test: asserts call.

#### `lib/utils/notification_payload_store.dart`

- **`static Future<void> storePendingPayload(String? payload)`** — ✅ Covered
  - Appends to a JSON-array queue in prefs; no-op on null/empty.
  - Test cases: null no-op; empty no-op; valid round-trips; later store appends (not overwrites).
  - Existing coverage: `test/utils/notification_payload_store_test.dart` covers all.

- **`static Future<List<String>> consumePendingPayloads()`** — 🟡 Partial
  - Atomically reads queue + any legacy single-slot, clears both, returns in arrival order; tolerates malformed queue.
  - Test cases:
    1. Empty when nothing stored.
    2. Preserves arrival order.
    3. Drains (second read empty) — idempotency.
    4. Migrates legacy single-slot, removes legacy key.
    5. Merges legacy before queued.
    6. Malformed queue JSON → empty (no crash).
    7. **TOCTOU**: concurrent `consume`+`store` interleave — the read-then-clear is not atomic across awaits; two simultaneous consumers could both read the same queue, or a `store` between read and `remove` could be lost. Assert/spike the race (fire `consume` and `store` without awaiting between, check no payload silently dropped). This is the load-bearing concern called out for this store.
  - Existing coverage: `notification_payload_store_test.dart` covers 1-6 thoroughly. Missing: the TOCTOU/concurrency race (7) — the whole point of the queue rewrite, never stressed.

- **`static Future<String?> consumePendingPayload()`** — ✅ Covered
  - Drains entire queue, returns oldest (so the second payload isn't lost).
  - Test cases: null when empty; returns oldest AND drains the rest.
  - Existing coverage: `notification_payload_store_test.dart` covers both.

- **`static Future<void> clearPendingPayloads()`** — ✅ Covered (removes queue + legacy; safe when empty; removes legacy slot).
- **`static Future<void> clearPendingPayload()`** — ✅ Covered (back-compat alias routes to plural).

#### `lib/utils/home_widget_helper.dart`

- **`static Future<void> initialize()`** — 🟡 Partial
  - Calls `dispose()` first (prevents double-subscription), then `setAppGroupId`; swallows errors.
  - Test cases: cancels a prior subscription before re-init (no double-dispatch — Phase 3.5 fix); swallows channel error.
  - Existing coverage: `test/integration/home_widget_helper_test.dart` exercises `updateWidget` but NOT `initialize`'s dispose-first guard. Missing: the double-subscription regression.

- **`static Future<void> updateWidget(AppState appState)`** — ✅ Covered
  - Reads current-month totals from DB (not in-memory), formats via `CurrencyHelper`, redacts when PIN enabled, saves 6 widget keys, updates widget; swallows errors.
  - Test cases:
    1. Reads totals from DB not in-memory state (Bug #4 regression).
    2. Negative balance → `-` prefix + `is_positive:false`.
    3. Zero totals when no data → `0.00`, positive.
    4. Saves current month name.
    5. Account-scoped (other account's rows excluded).
    6. **PIN-enabled redaction**: when `PinSecurityHelper.isPinEnabled()` is true, saved expenses/income/balance == `•••` and month == `Locked` (the Phase 6.4 lock-screen leak guard) — currently the test seeds an empty secure store (PIN off) only.
  - Existing coverage: `home_widget_helper_test.dart` covers 1-5. Missing: the PIN-on redaction path (6) — a leak here defeats the PIN gate, so this is a HIGH-value gap.

- **`static Future<void> clearWidget({String currency})`** — ❌ Missing
  - Writes zeroed widget data with the given currency symbol.
  - Test cases: saves `<currency>0.00` for all money fields, `is_positive:true`; default `$` when no arg; swallows error.
  - Existing coverage: none.

- **`static Future<void> registerInteractivityCallback(Function(Uri?) callback)`** — ❌ Missing
  - Cancels prior subscription, subscribes to `HomeWidget.widgetClicked` (tap-routing into the app).
  - Test cases: cancels existing before subscribing (no leak); delivers a click Uri to the callback; swallows registration error.
  - Existing coverage: none.

- **`static Future<void> dispose()`** — 🟡 Partial
  - Cancels + nulls the click subscription.
  - Test cases: safe when no subscription; cancels an active one.
  - Existing coverage: indirectly via `initialize`; no direct test.

#### `lib/utils/csv_exporter.dart`

> NOTE: the existing `csv_exporter_test.dart` tests **re-implemented private copies** of `_escapeCsv`/`_formatNumber` inside the test file — it does NOT call the real `CsvExporter` methods. The public `exportExpenses`/`exportIncome`/`exportAllTransactions` are therefore untested end-to-end (file IO via `getApplicationDocumentsDirectory`).

- **`enum CsvSeparator` (`value`, `fromLocale`)** — ✅ Covered
  - `fromLocale` maps European language codes → semicolon, else comma; case-insensitive; strips country code.
  - Test cases: exhaustive locale matrix (European→semicolon, others→comma, mixed-case, with/without country).
  - Existing coverage: `test/utils/csv_exporter_test.dart` is exhaustive for the enum.

- **`static Future<File> exportExpenses(List<Expense>, String currencySymbol, {CsvSeparator})`** — ❌ Missing
  - Builds header + escaped data rows + totals + by-category section; writes to app docs dir with timestamped filename.
  - Test cases:
    1. Produces a file whose contents contain the header line, one row per expense with `_escapeCsv`'d description/category and `_formatNumber`'d amounts, and the SUMMARY/BY-CATEGORY footers.
    2. **Formula-injection**: a description starting with `=`/`+`/`-`/`@`/tab/CR is prefixed with `'` (read the actual file output, not a re-implementation).
    3. Separator/quote/newline in a field → RFC-quoted with doubled quotes.
    4. Empty list → header + zero totals, no data rows (boundary).
    5. Semicolon separator path → European number format (`1.234,56`) in the file.
    6. Totals = sum of amounts/paid/remaining; category totals sorted descending (money aggregation; note `double` accumulation rounding).
  - Existing coverage: only the re-implemented `_escapeCsv`/`_formatNumber` logic is tested — the **real method and its file output are untested**. GAP.

- **`static Future<File> exportIncome(List<Income>, String, {CsvSeparator})`** — ❌ Missing
  - Same shape, income variant.
  - Test cases: header + rows + Total Income + by-category; escaping; empty list; semicolon locale.
  - Existing coverage: none for the real method.

- **`static Future<File> exportAllTransactions(List<Expense>, List<Income>, String, {CsvSeparator})`** — ❌ Missing
  - Merges expenses (amount negated) + incomes, sorts by date desc, writes combined rows + net-balance summary.
  - Test cases: expenses appear with negative amount; sorted date-descending; Net Balance = income − expenses; status column (Paid/Unpaid for expenses, `-` for income); escaping; empty inputs.
  - Existing coverage: none.

#### `lib/utils/pdf_exporter.dart`

> NOTE: no `pdf_exporter_test.dart` exists. All ❌ Missing. PDF correctness is testable by saving and asserting the file is non-empty + starts with `%PDF` magic, and by exercising the data-shaping (category totals, percentages, status thresholds) which is the load-bearing logic.

- **`static Future<File> exportExpensesToPdf({required List<Expense>, required String currencySymbol, required String currencyCode, String? title, DateTime? startDate, DateTime? endDate, String? category})`** — ❌ Missing
  - Builds an A4 multi-page PDF: header (+ optional period/category lines), summary (grand total, count), category breakdown table (percent of total), detailed transaction table.
  - Test cases:
    1. Returns a File that exists, is non-empty, and whose first bytes are `%PDF-` (generation correctness).
    2. Grand total == sum of expense amounts; category percentages sum to ~100% (money aggregation).
    3. `grandTotal==0` (empty list) → no divide-by-zero (percentage guarded to 0.0); summary shows 0 count.
    4. Optional period/category header lines appear only when provided.
    5. Categories sorted by amount descending.
    6. Amount formatting `toStringAsFixed(2)` (money precision; double-based — flag).
  - Existing coverage: none.

- **`static Future<File> exportIncomeToPdf({...})`** — ❌ Missing
  - Income variant (green theme, no payment/status column).
  - Test cases: valid `%PDF`; grand total; empty list guard; optional period line; sorted categories.
  - Existing coverage: none.

- **`static Future<File> exportMonthlySummaryToPdf({required ... expenses, incomes, budgets, currencySymbol, currencyCode, monthName, totalIncome, totalExpenses, balance})`** — ❌ Missing
  - Financial overview (income/expenses/net, colored by sign) + budget-performance table (Over/Warning/On Track by percent thresholds).
  - Test cases:
    1. Valid `%PDF`, non-empty.
    2. Net balance color/branch by `balance >= 0`.
    3. Budget status thresholds: `>100`→Over, `>90`→Warning, else On Track (boundary at exactly 90/100).
    4. `budget.amount==0` → no divide-by-zero (percentage guarded 0.0).
    5. Category spending aggregated from expenses; budget without matching spending → spent 0.
    6. Empty budgets → budget section omitted.
  - Existing coverage: none.

#### `lib/utils/backup_helper.dart`

- **`@visibleForTesting static Future<String> wrapBackupIfNeeded(String json, String? passphrase)`** — ✅ Covered
  - No-op when passphrase null/empty; else returns a `BackupCrypto` v4 envelope.
  - Test cases: null→unchanged; empty→unchanged; passphrase→v4 envelope; envelope hides inner keys (`database`/`settings`/`darkMode`/`schema_version`); two wraps differ (fresh salt/IV).
  - Existing coverage: `test/integration/backup_restore_v4_test.dart` covers all.

- **`@visibleForTesting static Future<String?> unwrapBackupIfNeeded(String contents, String? passphrase)`** — ✅ Covered
  - Plaintext passes through (legacy v2/v3, even if a passphrase is supplied); encrypted needs the right passphrase, else null (null/empty/wrong → null).
  - Test cases: plaintext unchanged; plaintext + unused passphrase unchanged; encrypted+null→null; encrypted+empty→null; encrypted+wrong→null; full wrap→unwrap round-trip recovers JSON byte-for-byte and re-parses to same map.
  - Existing coverage: `backup_restore_v4_test.dart` covers all incl. round-trip + distinct-envelopes.

- **`Future<void> exportBackup(BuildContext)`** — ❌ Missing
  - Gathers all data (accounts/expenses/incomes/categories/recurring/budgets/templates/monthly_balances/tags/transaction_tags) into a v3 JSON, writes temp file, shares via SharePlus; shows error SnackBar on failure.
  - Test cases:
    1. Produces a JSON with `version:3`, `schema_version`, and every section key (round-trip schema completeness).
    2. Pulls ALL rows from DB (`getAllExpensesForBackup`), not in-memory list.
    3. Failure path shows a SnackBar when `context.mounted` (async-gap mounted check).
  - Existing coverage: none (needs a widget-test harness with AppState provider + mocked SharePlus/path_provider channels).

- **`Future<void> importBackup(BuildContext)`** — ❌ Missing
  - Picks a JSON, validates `version`+`expenses` present, shows restore-confirmation dialog; error SnackBar on failure.
  - Test cases: missing `version` or `expenses` → throws "Invalid backup file format" → error SnackBar; valid → confirmation dialog; user cancels picker → no-op; mounted guard on async gap.
  - Existing coverage: none.

- **`Future<RestoreResult> restoreDatabase({required Future<void> Function() closeDatabase, void Function()? onStart, File? sourceFile, PassphraseRequest? onPassphraseRequest})`** — ❌ Missing (HIGH priority — atomic replace, rollback, v2/v3/v4 envelopes)
  - Routes `.etbackup` → comprehensive path; `.db` → SQLite-header validation + atomic temp-rename with pre-restore backup + WAL/SHM cleanup + rollback on failure.
  - Test cases:
    1. `.db` with valid SQLite magic → success, atomic rename, `.bak` cleaned up, WAL/SHM deleted.
    2. `.db` with bad magic header → `RestoreResult.invalidFile`, original DB untouched.
    3. Mid-restore failure → rollback from `.bak` (data-loss prevention; force a rename throw).
    4. No file / empty picker → `cancelled`; picked path null + bytes null → `fileNotFound`.
    5. `sourceFile` provided (Recent Backups path) skips the picker, fires `onStart` immediately.
    6. Source file doesn't exist → `fileNotFound`.
    7. In-memory bytes branch (`pickedFile.bytes`) writes in chunks then validates.
  - Existing coverage: none directly. `backup_restore_test.dart` tests `DatabaseHelper.restoreFromJsonBackup` (the JSON path), not this file-level method.

- **`Future<void> shareDatabase({void Function()? onProcessingStart, String? passphrase})`** — ❌ Missing
  - Builds comprehensive `.etbackup` in isolate, optionally encrypts, saves a local copy, shares it.
  - Test cases: DB-missing → throws; passphrase → shared bytes are a v4 envelope; local copy written to backups dir; rethrows on failure.
  - Existing coverage: none.

- **`Future<String?> saveBackupToUserSelectedLocation({void Function()? onProcessingStart, void Function()? onProcessingEnd, String? passphrase})`** — ❌ Missing
  - Reads DB, builds backup in isolate, optionally encrypts, saves local copy, opens SAF save dialog; returns saved path or null on cancel.
  - Test cases: DB-missing → throws "Database file not found"; passphrase → bytes encrypted before disk; picker cancel → null; processing callbacks fire in order (start before picker, end before picker).
  - Existing coverage: none.

- **`Future<List<File>> getBackupList()`** — ❌ Missing
  - Lists `.db`/`.etbackup` in app docs `/backups`, newest-first by mtime; `[]` when dir absent or on error.
  - Test cases: empty when no dir; filters to `.db`/`.etbackup` only; sorted by modified desc; swallows error → `[]`.
  - Existing coverage: none.

- **`Future<void> deleteBackup(File)`** — ❌ Missing
  - Deletes if exists; rethrows on error.
  - Test cases: existing file deleted; non-existent → no-op; delete throws → rethrows.
  - Existing coverage: none.

- **`Future<Map<String, dynamic>> getBackupInfo(File)`** — ❌ Missing
  - Returns `{date, size}` from file stat.
  - Test cases: returns modified time + size for an existing file.
  - Existing coverage: none.

- **`String formatFileSize(int bytes)`** — ❌ Missing
  - B / KB / MB formatting with 1-dp at KB/MB.
  - Test cases: <1024→`N B`; 1024≤<1MB→`x.x KB`; ≥1MB→`x.x MB`; exact boundaries (1024, 1048576).
  - Existing coverage: none (pure, trivial to add — quick win).

- **`Future<void> exportCsv(BuildContext)`** — ❌ Missing
  - Writes a simple expenses CSV (RFC-4180 quote-doubling via `_escapeCsvField`), shares it; error SnackBar on failure.
  - Test cases: fields with `"`/comma quoted+doubled; isPaid → Yes/No; failure → SnackBar (mounted guard).
  - Existing coverage: none.

- **(private, behavior-pinned) `_createBackupInIsolate` / `_decodeBackupInIsolate` / `_validateSqliteHeader` / `_isValidSqliteFile` / `_restoreComprehensiveBackup`** — ❌ Missing
  - Test cases (reachable via `restoreDatabase`/`shareDatabase` integration once a harness exists):
    1. `_isValidSqliteFile`: 16-byte magic match → true; truncated/garbage → false (boundary at exactly 16 bytes).
    2. Comprehensive restore decodes base64 DB in isolate; settings restored to prefs with defaults for missing keys.
    3. **Bug #9 schema gate**: `schema_version > DatabaseConstants.databaseVersion` → `incompatibleVersion` BEFORE any file write.
    4. **v4 envelope restore**: encrypted `.etbackup` triggers `onPassphraseRequest` retry loop — wrong passphrase loops with `isRetry:true`, null cancels, correct decrypts then proceeds.
    5. Encrypted file but `onPassphraseRequest==null` → `invalidFile`.
    6. Quick string validation rejects content missing `"version"`/`"database"` → `invalidFile` (note: runs AFTER decrypt so v4 isn't false-flagged).
    7. >10MB file uses streaming read; rollback from pre-restore backup on write failure.
  - Existing coverage: none for this file's path. (`backup_restore_v4_test.dart` covers the crypto wrap/unwrap seam only; `backup_restore_test.dart` covers `DatabaseHelper.restoreFromJsonBackup`, a different code path.)

#### Coverage summary
89 public functions/items; 33 ✅, 9 🟡, 47 ❌. Highest-priority gaps: (1) `notification_helper.dart` — entire class untested incl. timezone/ID-range/idempotency/money-threshold logic and the flagged M17/M18/M19 next-month-rollover bugs; (2) `pin_security_helper.verifyPin` correct-PIN-while-locked-out precedence + `changePin` (no test at all) — security-critical, plus the pending SHA-256→PBKDF2 migrate-on-verify path; (3) `home_widget_helper.updateWidget` PIN-on redaction path (lock-screen leak guard untested); (4) `notification_payload_store.consumePendingPayloads` TOCTOU/concurrency race (the reason the queue was built); (5) `csv_exporter` real `exportExpenses/Income/AllTransactions` (only re-implemented copies tested — formula-injection on real output unverified); (6) `pdf_exporter` all three exporters (no test file); (7) `backup_helper.restoreDatabase` atomic-replace/rollback + v2/v3/v4 envelope routing and the Bug #9 schema gate at the file level; (8) `crash_log.redactPii` symbol-less-amount and free-text PII leaks.


## Database (lib/database/, lib/constants/database.dart)

Persistence layer. `DatabaseHelper` is a process-singleton (`factory DatabaseHelper() => _instance`) wrapping a single sqflite `Database` (schema v19, `PRAGMA foreign_keys = ON`). All money columns are SQLite `REAL` (doubles in transit); the `Decimal` boundary lives in the model `fromMap`/`toMap` layer, so amount-precision concerns here are about double round-trip fidelity, not Decimal math. Dates are stored as 10-char `YYYY-MM-DD` strings; month keys as `YYYY-MM` (post-v19). Existing integration tests drive the real class through `sqflite_common_ffi` via `makeFreshDb()` in `test/integration/_test_helpers.dart`.

A structural caveat that colours every coverage call below: the only *direct* DatabaseHelper integration tests are `database_helper_test.dart` (Bug #2 month-range), `database_helper_atomic_add_test.dart` (carryover atomicity), `cascade_delete_test.dart` (soft/hard delete + emptyTrash), `migration_v18_to_v19_test.dart` (one migration path), `backup_restore_test.dart` (restoreFromJsonBackup), and `recurring_processing_test.dart` (which tests `AppState.processRecurringInstances`, NOT a DatabaseHelper method — it does not touch this layer at all). The vast majority of the ~72 CRUD methods are either untested or only exercised transitively through `app_state_crud_test.dart`/`wallet_screen_test.dart` via AppState, with no assertions on the SQL behaviour itself.

### `lib/constants/database.dart`

- **`class DatabaseConstants`** — ✅ Covered (indirectly, load-bearing-by-use)
  - String/int constants for table/column names + `databaseVersion = 19`. Private constructor prevents instantiation.
  - Test cases:
    1. `databaseVersion == 19` and matches the version `_initDatabase` opens with — assert `DatabaseConstants.databaseVersion == 19`.
    2. Every `tableX` constant names a table that exists after `_onCreate` — query `sqlite_master` for each.
    3. Constructor is private — compile-time only; no runtime test needed.
  - Existing coverage: `migration_v18_to_v19_test.dart` asserts `user_version == DatabaseConstants.databaseVersion`; `restoreFromJsonBackup` uses it in the schema-version gate, tested in `backup_restore_test.dart`. No dedicated test, but value is pinned transitively.

### `lib/database/database_helper.dart`

#### Singleton / lifecycle / init

- **`factory DatabaseHelper()`** — 🟡 Partial
  - Returns the shared `_instance`.
  - Test cases:
    1. `identical(DatabaseHelper(), DatabaseHelper())` is true.
    2. State persists across calls (same `_database`).
  - Existing coverage: used everywhere but never asserted to be a singleton. Missing: explicit identity assertion.

- **`Future<Database> get database`** — 🟡 Partial
  - Lazy-inits the DB; uses a `Completer` to serialise concurrent first-access (race guard).
  - Test cases:
    1. First access returns an open DB — assert non-null, queryable.
    2. **Concurrency**: fire N simultaneous `database` getters before init completes, assert all resolve to the *same* instance and `_initDatabase` ran once (the `_initCompleter` guard is the whole point of the method and is UNTESTED).
    3. Init failure path: force `_initDatabase` to throw, assert `_initCompleter` is reset to null so a retry can succeed.
  - Existing coverage: every integration test calls it. Missing: the concurrency race guard (cases 2–3) — never directly tested.

- **`static Future<void> resetForTesting()`** — ✅ Covered
  - Closes + nulls the cached DB and deletes the file; swallows all errors.
  - Test cases: 1) after reset, next `database` runs `_onCreate` fresh; 2) reset when no DB open is a no-op; 3) reset when file locked swallows error.
  - Existing coverage: every test `tearDown` calls it; `makeFreshDb` relies on it for a clean `_onCreate`.

- **`_initDatabase` / `_onConfigure` (private)** — 🟡 Partial
  - Opens at `databaseVersion` with FK pragma, honoring `databaseNameOverride`.
  - Test cases: 1) fresh open creates all 13 tables + indexes + 2 triggers; 2) `PRAGMA foreign_keys` returns 1 after open; 3) `databaseNameOverride` routes to the override file.
  - Existing coverage: `database_helper_atomic_add_test.dart` asserts `PRAGMA foreign_keys == 1`; `_test_helpers` exercises the override. Missing: explicit table/index/trigger inventory on a fresh DB.

- **`static String? databaseNameOverride`** — ✅ Covered (used by `_test_helpers`).

#### Schema creation & migration

- **`_onCreate(db, version)` (private)** — 🟡 Partial
  - Creates 13 tables, seeds default account + 8 expense + 5 income categories, creates all performance/unique indexes and the two `transaction_tags` cleanup triggers.
  - Test cases:
    1. Fresh DB has exactly the expected tables — query `sqlite_master WHERE type='table'`.
    2. Default "Main Account" exists with `isDefault=1`; 13 default categories seeded (8 expense + 5 income).
    3. `idx_transaction_tags_unique` UNIQUE index exists — inserting a duplicate (transaction_id, type, tag_id) is ignored/rejected.
    4. Both cleanup triggers exist and fire (see cascade tests).
    5. Account FK CASCADE present on every child table at create time (not just post-migration).
  - Existing coverage: `cascade_delete_test.dart` proves the triggers fire on a fresh DB; default seeding is leaned on by AppState tests. Missing: explicit default-category count, default-account flag, unique-index enforcement on a *fresh* (non-migrated) DB.

- **`_onUpgrade(db, oldVersion, newVersion)` (private)** — 🟡 Partial
  - Sequential `if (oldVersion < N)` blocks for v4→v19 (income/templates tables, deleted_income, recurring_income/tags, frequency cols, deleted_accounts, currencyCode, end/max/occurrence cols, indexes, color/icon, monthly_balances, overall_budget, tag unique index + dedup, v19 bundle).
  - Test cases:
    1. **v3→v19 full chain** (task-requested, MISSING): build a v3-shaped DB by hand, reopen via DatabaseHelper, assert it lands at v19 with all columns/tables present and no data loss. Currently only v18→v19 is tested.
    2. Each intermediate hop (e.g. v8→v19, v15→v19) preserves rows and adds the right columns — at minimum a v16→v19 (monthly_balances exists but lacks overall_budget) and a pre-v6 (no tags tables) path.
    3. v18 dedup block: seed duplicate `transaction_tags` rows in a <18 DB, assert the `DELETE ... MIN(id)` dedup runs before the unique index is created (no constraint failure).
    4. Idempotency: re-running upgrade logic (all `IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS`) does not throw.
  - Existing coverage: `migration_v18_to_v19_test.dart` covers ONLY the v18→v19 hop. The v3→v19 chain the task calls for, the dedup-before-unique-index path, and every intermediate hop are MISSING.

- **`_migrateToV19(db)` (private)** — 🟡 Partial
  - Phase 4 bundle: file backup (`.v18-backup`), FK-off table rebuilds for deleted_expenses/deleted_income/income/quick_templates, two triggers, `month` normalisation, FK re-enable in `finally`.
  - Test cases:
    1. Row counts preserved across all rebuilt tables (COVERED).
    2. `monthly_balances.month` normalised YYYY-MM-DD→YYYY-MM (COVERED).
    3. Trash tables gain account CASCADE FK (COVERED).
    4. **Rollback on failure**: inject a throw mid-transaction (e.g. corrupt a `createSql`), assert the whole migration rolls back and the live `.db` is intact — MISSING.
    5. `PRAGMA foreign_keys` is ON after migration even if the body threw (the `finally`) — MISSING.
    6. `.v18-backup` file is deleted on success, retained on failure — MISSING.
    7. v4-table rebuild is *skipped* when `_tableHasAccountCascade` already true (idempotency / probe correctness) — MISSING.
  - Existing coverage: `migration_v18_to_v19_test.dart` covers cases 1–3 and the account-cascade end-result. The atomicity/rollback contract, the FK-re-enable guarantee, the backup-file lifecycle, and the probe-skip branch are MISSING.

- **`static _rebuildTableWithAccountCascade(txn, ...)` (private)** — 🟡 Partial
  - SQLite 12-step rebuild: create tmp, copy via `PRAGMA table_info` column list, drop, rename, recreate indexes.
  - Test cases:
    1. Data copied verbatim including all columns when column order differs (the named-column INSERT is the safety feature) — partially covered via row-count.
    2. **SQL-injection/identifier safety**: `tableName` and `createSql` are string-interpolated into DDL (`INSERT INTO $tmpName ($colList) ...`, `DROP TABLE $tableName`). Inputs are hardcoded literals from `_migrateToV19`, NOT user data — assert/document that no caller passes external input here.
    3. Indexes recreated after rename — assert each `indexSql` index exists post-rebuild.
  - Existing coverage: `migration_v18_to_v19_test.dart` exercises it for deleted_expenses/income via row-count + FK assertions. Missing: column-mismatch fidelity, index-recreation assertion, injection-surface documentation.

- **`static _tableHasAccountCascade(db, tableName)` (private)** — 🟡 Partial
  - Reads `PRAGMA foreign_key_list` and checks for account_id→accounts ON DELETE CASCADE.
  - Test cases: 1) true for a table with the cascade; 2) false for one without (drives the Phase 4.3 skip); 3) `tableName` interpolated into PRAGMA — hardcoded input only.
  - Existing coverage: the migration test mirrors this logic inline (`hasAccountCascade` helper) but never calls the production method directly. Missing: direct unit coverage of the false branch.

- **`_addColumnIfNotExists(db, table, col, def)` (private)** — ❌ Missing
  - PRAGMA-checks then `ALTER TABLE ADD COLUMN` only if absent.
  - Test cases: 1) adds a missing column; 2) no-op when column already exists (no throw); 3) `table`/`col`/`def` interpolated into DDL — hardcoded inputs only, document injection surface.
  - Existing coverage: none directly (only exercised inside untested upgrade hops).

- **`_queryWithTimeout<T>(query, {timeout})` (private)** — ❌ Missing
  - Wraps a query with `.timeout`; returns null on `TimeoutException`, rethrows other errors.
  - Test cases: 1) fast query returns its value; 2) slow query past timeout returns null; 3) query throwing a non-timeout error rethrows.
  - Existing coverage: none. Used by `searchExpenses`/`searchIncome`/`searchTransactionsUnified` — its null-on-timeout path (which silently returns empty results) is untested.

#### Row-parse resilience (private helpers)

- **`static _parseExpenseRows(rows)` / `static _parseIncomeRows(rows)`** — ❌ Missing
  - Map rows through `Expense.tryFromMap`/`Income.tryFromMap`, dropping rows that fail validation (debug-log per skip).
  - Test cases: 1) all-valid rows pass through unchanged; 2) **corrupt row** (missing `category` or `account_id`) is dropped, valid neighbours retained; 3) empty input → empty list.
  - Existing coverage: none. The whole point — corrupt-row resilience so one bad row doesn't crash the list load — is UNTESTED. High priority given they back `readAllExpenses`, `getExpensesByMonth`, `getExpensesInRange`, `searchExpenses`, and income equivalents.

- **`static _isValidAmount(raw)`** — 🟡 Partial
  - Finite, non-NaN, `[0, 1e10)`.
  - Test cases: 1) valid mid-range; 2) boundaries: `0` valid, `-0.01` rejected, `1e10` rejected, `1e10-1` accepted; 3) `NaN`/`Infinity`/`1e308` rejected; 4) non-num (string/null) rejected.
  - Existing coverage: only the rejection path is implicitly hit by `restoreFromJsonBackup` happy-path tests (which never feed bad amounts). No boundary tests. The `>= 1e10` overflow-injection guard is UNTESTED.

- **`static _isValidBackupDate(raw)`** — ❌ Missing
  - Parseable, on/after 2000-01-01, ≤100 years past today.
  - Test cases: 1) valid recent date; 2) boundaries: `2000-01-01` accepted, `1999-12-31` rejected, today+100y accepted, +101y rejected; 3) unparseable/non-string rejected; 4) **timezone**: uses `DateTime.utc(2000,1,1)` and `DateTime.now().toUtc()` — verify a date near the UTC boundary classifies consistently regardless of local tz.
  - Existing coverage: none.

- **`static _isValidDescription(raw)`** — ❌ Missing
  - null OK (optional), string ≤1024 chars, else rejected.
  - Test cases: 1) null accepted; 2) 1024-char string accepted, 1025 rejected; 3) non-string rejected.
  - Existing coverage: none.

#### Income CRUD

- **`createIncome(income)`** — 🟡 Partial — inserts, returns id. Tests: 1) round-trips via readAllIncome; 2) FK violation on bad account_id throws; 3) amount double fidelity. Existing: transitively via AppState; no direct DB assertion.
- **`readAllIncome(accountId)`** — 🟡 Partial — account-scoped, date DESC, corrupt-row-safe via `_parseIncomeRows`. Tests: 1) returns only this account's rows in date-DESC order; 2) corrupt row dropped; 3) empty account → []. Existing: indirect; ordering + corrupt-drop untested directly.
- **`getIncomeByMonth(accountId, year, month)`** — ✅ Covered — month-window via DateHelper (Bug #2). Tests: 1st-of-month inclusion, multi-day, account scoping. Existing: `database_helper_test.dart` covers 1st-of-month + day-1/15/last.
- **`updateIncome(income)`** — ❌ Missing — Tests: 1) updates fields by id; 2) returns rows-affected (0 for missing id); 3) wrong id no-op. Existing: none direct.
- **`deleteIncome(id)`** — 🟡 Partial — scrubs `transaction_tags` then deletes row (two separate statements, NOT a transaction — note the trigger also fires). Tests: 1) deletes row + its tag links; 2) **non-atomic gap**: tag-delete and row-delete aren't wrapped in a txn (unlike `moveIncomeToDeleted`) — document/assert behaviour; 3) missing id → 0. Existing: trigger-based hard-delete cleanup covered in `cascade_delete_test.dart` but for raw `db.delete`, not this method.
- **`moveIncomeToDeleted(income)`** — 🟡 Partial — txn: insert trash + scrub tags + delete live; UTC `deletedAt`. Tests: 1) round-trip to trash; 2) tags scrubbed; 3) **rollback** if any step throws; 4) `deletedAt` is UTC. Existing: `moveIncomeToDeletedById` (the by-id variant) is covered in cascade test; this object variant is NOT directly tested.
- **`moveIncomeToDeletedById(id)`** — ✅ Covered — txn read+scrub+insert+delete, returns date or null. Tests: tag scrub before move, trash row created, corrupt/missing row → null. Existing: `cascade_delete_test.dart` covers the tag-scrub + move; missing-id-null and corrupt-row-null branches untested but logic is shared.

#### Quick Template CRUD

- **`createTemplate(t)`** — ❌ Missing — insert, returns id. Tests: round-trip, FK, sortOrder default.
- **`readAllTemplates(accountId)`** — ❌ Missing — account-scoped, `sortOrder ASC, name ASC`. Tests: 1) ordering; 2) account scope; 3) empty.
- **`updateTemplate(t)`** — ❌ Missing — Tests: update by id, missing-id no-op.
- **`deleteTemplate(id)`** — ❌ Missing — Tests: delete by id, missing-id → 0.
- Existing coverage: none for any template method (only transitively via wallet/AppState).

#### Account CRUD

- **`createAccount(a)`** — 🟡 Partial — insert. Tests: round-trip, currencyCode default 'USD'. Existing: indirect via AppState `addAccount`.
- **`readAllAccounts()`** — 🟡 Partial — `isDefault DESC, name ASC`, **corrupt-row-safe** (try/catch per row → skip). Tests: 1) ordering (default first); 2) corrupt account row skipped not crashed; 3) empty. Existing: indirect; corrupt-skip + ordering untested directly.
- **`updateAccount(a)`** — ❌ Missing — Tests: update by id, missing-id no-op.
- **`setDefaultAccountById(accountId)`** — ❌ Missing — txn: clear all `isDefault` then set one. Tests: 1) exactly one default after call; 2) previous default cleared; 3) **atomicity** — clear+set in one txn; 4) nonexistent id leaves zero defaults (edge). Existing: none.
- **`deleteAccount(id)`** — ❌ Missing (DB-level) — Large method: refuses default/missing account (throws), streams a JSON backup file in 500-row batches, batch-scrubs tags, then atomically deletes all child data in a txn. Tests: 1) refuses default account (throws 'Cannot delete default account'); 2) refuses missing id (throws 'Account not found'); 3) happy path removes account + cascades all child tables; 4) backup JSON file written with account/expenses/income/budgets/.../monthlyBalances; 5) **disk-full** during backup write → friendly 'Not enough disk space' exception + incomplete file cleaned/tracked; 6) **transaction atomicity** of the final multi-table delete; 7) batch-boundary correctness (>500 expenses); 8) `_trackOrphanedFile` invoked when cleanup delete fails. Existing: only the two throw-guards are exercised via AppState (`app_state_crud_test.dart` lines 240–256), and the full delete+restore round-trip test is SKIPPED (path_provider mock races under parallel isolates). The streaming backup, disk-full path, batch boundaries, and final-txn atomicity are all MISSING. High priority.
- **`_trackOrphanedFile(path)` (private)** — ❌ Missing — appends to `orphaned_files.log`. Tests: 1) appends a UTC-timestamped line; 2) swallows write errors. Existing: none.
- **`cleanOrphanedBackupFiles()`** — ❌ Missing — reads orphan log + deletes, then scans `deleted_accounts` dir for files not registered in DB. Tests: 1) deletes logged orphans + clears log; 2) deletes dir files absent from `deleted_accounts.data`; 3) returns count; 4) registered files NOT deleted; 5) swallows per-file errors. Existing: none.
- **`getDeletedAccounts()`** — ❌ Missing — purges >30-day backups (file + row, UTC cutoff) then returns remaining, `deletedAt DESC`. Tests: 1) returns trashed accounts; 2) **30-day boundary**: a 31-day-old row is purged (file deleted + row deleted), a 29-day-old retained; 3) UTC cutoff (not local); 4) failed file delete → `_trackOrphanedFile`. Existing: only invoked inside the skipped AppState round-trip.
- **`restoreDeletedAccount(deletedId)`** — ❌ Missing (DB-level) — reads backup JSON file, rebuilds account + all children in ONE txn with old→new id remapping (expenseIdMap/incomeIdMap/tagIdMap drive transaction_tags rewiring), skips default categories, deletes trash row + backup file. Tests: 1) full restore reconstructs every table; 2) **id remapping**: transaction_tags point at the new expense/income/tag ids; 3) missing deletedId throws 'Deleted account not found'; 4) missing backup file throws 'Backup file not found'; 5) **txn atomicity** — a mid-restore failure rolls back (no half-restored account); 6) default categories skipped (not duplicated against the new account's seeded defaults); 7) tag links with unresolved old ids dropped silently. Existing: AppState round-trip test is SKIPPED. Effectively zero real coverage. High priority.
- **`permanentlyDeleteAccount(deletedId)`** — ❌ Missing — deletes backup file then row. Tests: 1) row + file gone; 2) missing file tolerated; 3) missing id no-op. Existing: none.

#### Expense CRUD + carryover

- **`createExpense(e)`** — 🟡 Partial — insert. Tests: round-trip, FK on bad account, amountPaid/paymentMethod defaults. Existing: indirect.
- **`createExpenseWithCarryover(expense, balanceUpserts)`** — ✅ Covered — txn: insert + N monthly_balance upserts. Tests: both commit on success; **rollback** of expense when a balance upsert FK-fails. Existing: `database_helper_atomic_add_test.dart` covers commit + FK-rollback.
- **`createIncomeWithCarryover(income, balanceUpserts)`** — ✅ Covered — symmetric. Existing: `database_helper_atomic_add_test.dart` covers the FK-rollback contract.
- **`_upsertMonthlyBalanceTxn(exec, balance)` (private)** — 🟡 Partial — LIKE `YYYY-MM%` lookup then update-or-insert (handles pre-v19 YYYY-MM-DD leftovers). Tests: 1) insert when absent; 2) update when present; 3) **matches a leftover YYYY-MM-DD row** via the LIKE prefix; 4) month-key from `DateHelper.toMonthString`. Existing: commit path hit by carryover tests; the YYYY-MM-DD-leftover match (the whole reason for LIKE) is UNTESTED.
- **`readAllExpenses(accountId)`** — 🟡 Partial — account-scoped, date DESC, `_parseExpenseRows`. Tests: ordering, corrupt-drop, account scope, empty. Existing: indirect; ordering+corrupt-drop untested directly.
- **`getExpensesByMonth(accountId, year, month)`** — ✅ Covered — Bug #2 month window. Existing: `database_helper_test.dart` (1st-of-month, day-1/15/last).
- **`updateExpense(e)`** — ❌ Missing — Tests: update by id, missing-id no-op, rows-affected. Existing: none direct.
- **`deleteExpense(id)`** — 🟡 Partial — scrub tags (non-txn) then delete. Tests: deletes row+links; non-atomic note; missing id → 0. Existing: trigger covered in cascade test for raw delete, not this method.
- **`getExpenseById(id)`** — ❌ Missing — uses `Expense.fromMap` (NOT tryFromMap → will throw on corrupt row). Tests: 1) returns row; 2) missing id → null; 3) corrupt row throws (vs list methods that skip — divergent behaviour worth pinning). Existing: none.
- **`getIncomeById(id)`** — ❌ Missing — same shape. Tests: returns/null/corrupt-throws. Existing: none.
- **`moveToDeleted(expense)`** — 🟡 Partial — txn insert+scrub+delete, UTC deletedAt, copies amountPaid/paymentMethod. Tests: round-trip, tag scrub, rollback, UTC. Existing: by-id variant covered; this object variant NOT directly tested.
- **`moveToDeletedById(id)`** — ✅ Covered — txn read+scrub+insert+delete, corrupt→null, returns date. Existing: `cascade_delete_test.dart` covers scrub+move; also drives `emptyTrash` seeding. Corrupt-row-null branch untested but shares logic.
- **`getAllDeletedExpenses(accountId)`** — ❌ Missing — 30-day UTC window, account-scoped, deletedAt DESC. Tests: 1) returns recent trash; 2) **31-day-old row excluded, 29-day included** (boundary); 3) account scope; 4) UTC cutoff. Existing: none.
- **`getAllDeletedIncome(accountId)`** — ❌ Missing — same. Tests as above. Existing: none.
- **`restoreDeletedExpense(deletedId)`** — ❌ Missing — txn: insert into expenses (strips trash-only cols) + delete trash row. Tests: 1) restored to live with amount/category/date/amountPaid/paymentMethod; 2) trash row gone; 3) missing id no-op; 4) txn atomicity. Existing: none.
- **`restoreDeletedIncome(deletedId)`** — ❌ Missing — same shape (no amountPaid). Tests as above. Existing: none.
- **`permanentlyDeleteExpense(deletedId)`** — ❌ Missing — Tests: trash row removed, missing id no-op. Existing: none.
- **`permanentlyDeleteIncome(deletedId)`** — ❌ Missing — same. Existing: none.
- **`getLastDeleted(accountId)`** — ❌ Missing — newest trash row → `Expense` via `DecimalHelper.fromDoubleSafe` + `DateHelper.parseDate` fallbacks. Tests: 1) returns most-recent by deletedAt DESC; 2) empty → null; 3) **null amount / unparseable date** fall back to 0 / today (the fromDoubleSafe + parseDate guards); 4) account scope. Existing: none.
- **`restoreLastDeleted(accountId)`** — ❌ Missing — txn: re-insert newest trash + delete it. Tests: 1) newest restored; 2) empty no-op; 3) txn atomicity; 4) account scope. Existing: none.
- **`clearOldDeleted()`** — ❌ Missing — txn deletes both trash tables older than 30d (UTC). Tests: 1) >30d rows in both tables purged; 2) ≤30d retained; 3) **boundary** at exactly 30d; 4) **txn atomicity** (the Phase 4.6 reason — both or neither); 5) UTC cutoff. Existing: none.
- **`emptyTrash(accountId)`** — ✅ Covered — txn empties both trash tables for one account. Tests: clears target account's expense+income trash, leaves other account untouched. Existing: `cascade_delete_test.dart` covers account-scoped empty + cross-account isolation.

#### Budget CRUD + monthly balances

- **`createBudget(b)`** — ❌ Missing — Tests: round-trip, FK. Existing: none direct.
- **`readAllBudgets(accountId, {month, limit})`** — ❌ Missing — optional month window (Bug #2 date-string fix), default `limit: 100`. Tests: 1) all budgets when no month; 2) month-window filtering with correct YYYY-MM-DD bounds; 3) **default 100-row cap** applied; 4) custom limit honoured; 5) month DESC order. Existing: none. The Bug-#2 date-string fix here is UNTESTED (unlike the analogous expense/income month methods).
- **`getBudgetsForMonth(accountId, year, month)`** — ❌ Missing — `month LIKE 'YYYY-MM%'`. Tests: 1) matches both YYYY-MM and leftover YYYY-MM-DD rows; 2) wrong month excluded; 3) account scope. Existing: none.
- **`updateBudget(b)`** — ❌ Missing — Tests: update by id, missing-id no-op.
- **`deleteBudget(id)`** — ❌ Missing — Tests: delete by id, missing-id → 0.
- **`getMonthlyBalance(accountId, month)`** — ❌ Missing — `month LIKE 'YYYY-MM%'` (built via `toIso8601String().substring(0,7)` — note LOCAL DateTime, not UTC). Tests: 1) returns the row; 2) absent → null; 3) **local-vs-UTC month-key**: a `DateTime` near a month boundary in a non-UTC tz could resolve to the wrong month-string — pin behaviour; 4) matches YYYY-MM-DD leftover via LIKE. Existing: none.
- **`upsertMonthlyBalance(balance)`** — 🟡 Partial — get-then-update-or-insert (NOT a single txn — read+write race window). Tests: 1) insert when absent; 2) update when present; 3) **concurrency**: two upserts for the same (account,month) — non-atomic check-then-act could double-insert (no UNIQUE on month-prefix, only on exact month). Existing: only via AppState overall-budget round-trip (`app_state_crud_test.dart` line 944), no DB-level assertion.
- **`getMonthlyBalances(accountId, {limit})`** — ❌ Missing — account-scoped, month DESC, optional limit. Tests: 1) returns rows in month-DESC; 2) limit honoured; 3) account scope; 4) empty. Existing: none.
- **`deleteMonthlyBalance(id)`** — ❌ Missing — Tests: delete by id, missing-id → 0.
- **`calculateMonthBalance(accountId, year, month)`** — ✅ Covered — returns `({income, expenses})` via COALESCE SUM, Bug #2 window. Tests: 1st-of-month, multi-day, leap-Feb, out-of-window exclusion, account scope, empty→zeros. Existing: `database_helper_test.dart` covers all of these thoroughly.

#### Recurring expense / income CRUD + batch

- **`createRecurringExpense(e)`** — ❌ Missing — Tests: round-trip, FK, frequency/occurrence defaults.
- **`readAllRecurringExpenses(accountId)`** — ❌ Missing — account-scoped. Tests: scope, empty.
- **`readActiveRecurringExpenses(accountId)`** — ❌ Missing — `isActive = 1` filter. Tests: 1) excludes inactive; 2) account scope. Existing: none (the active-only optimisation is untested).
- **`updateRecurringExpense(e)`** — ❌ Missing — Tests: update by id, missing-id no-op.
- **`deleteRecurringExpense(id)`** — ❌ Missing — Tests: delete by id, missing-id → 0.
- **`createRecurringExpensesBatch({expenses, recurringToUpdate})`** — ❌ Missing — txn: insert all expenses + update recurring's lastCreated. Tests: 1) all expenses + recurring update commit; 2) **rollback** if any insert FK-fails (none persist); 3) empty list still updates recurring. Existing: none. Atomicity contract UNTESTED.
- **`createRecurringIncome(i)`** — ❌ Missing — Tests: round-trip, FK.
- **`readAllRecurringIncome(accountId)`** — ❌ Missing — Tests: scope, empty.
- **`readActiveRecurringIncome(accountId)`** — ❌ Missing — Tests: excludes inactive, scope.
- **`updateRecurringIncome(i)`** — ❌ Missing — Tests: update by id, missing-id no-op.
- **`deleteRecurringIncome(id)`** — ❌ Missing — Tests: delete by id, missing-id → 0.
- **`createRecurringIncomeBatch({incomes, recurringToUpdate})`** — ❌ Missing — txn atomicity as above. Existing: none.
- (NOTE: `recurring_processing_test.dart` tests `AppState.processRecurringInstances`, a scheduling pure-function — it does NOT exercise any of these DatabaseHelper methods.)

#### Category CRUD + bulk operations

- **`createCategory(c)`** — ❌ Missing — Tests: round-trip, FK, type default 'expense'.
- **`readAllCategories(accountId, {type})`** — ❌ Missing — optional type filter. Tests: 1) all when no type; 2) expense-only / income-only filter; 3) account scope. Existing: indirect via AppState only.
- **`updateCategory(c)`** — ❌ Missing — Tests: update by id, missing-id no-op.
- **`renameCategoryInAllTables(accountId, oldName, newName, type)`** — ❌ Missing — txn cascading rename across expenses/recurring/templates/budgets/deleted (expense branch) or income/recurring_income/templates/deleted_income (income branch). Tests: 1) expense rename hits all 5 tables, scoped to account+oldName; 2) income rename hits its 4 tables; 3) **atomicity** — all-or-nothing; 4) raw-string SQL uses parameterised whereArgs (injection-safe) — verify a malicious newName like `'; DROP TABLE` is treated as data; 5) unknown type is a no-op. Existing: none. High priority (raw `rawUpdate` interpolation surface + multi-table consistency).
- **`bulkReassignCategory(accountId, oldCat, newCat, type)`** — ❌ Missing — txn, same table set as rename. Tests: 1) expense branch reassigns all 5 tables; 2) income branch; 3) atomicity; 4) parameterisation; 5) unknown type no-op. Existing: none.
- **`bulkReassignCategoryAndDelete(accountId, categoryId, oldCat, newCat, type)`** — ❌ Missing — reassign + delete the category (only if `isDefault = 0`) in one txn. Tests: 1) reassigns then deletes non-default category atomically; 2) default category NOT deleted (the `isDefault = 0` guard); 3) atomicity; 4) parameterisation. Existing: none.
- **`bulkDeleteTransactionsAndCategory(accountId, categoryId, category, type)`** — ❌ Missing — moves matching txns to trash (with UTC deletedAt), scrubs their tags via `IN (placeholders)`, deletes live rows, deletes non-default category — all in one txn. Tests: 1) all matching expenses moved to trash + tags scrubbed + category deleted; 2) income branch; 3) **placeholder injection safety** of the `IN ($placeholders)` clause (count matches whereArgs); 4) default category preserved; 5) atomicity; 6) UTC deletedAt; 7) empty-match path skips the IN-clause delete (no malformed empty `IN ()`). Existing: none. High priority.
- **`bulkDeleteTransactionsByCategory(accountId, category, type)`** — ❌ Missing — like the above minus category deletion. Tests: 1) expense move-to-trash + tag scrub; 2) income branch; 3) IN-placeholder safety + empty-match guard; 4) atomicity; 5) UTC deletedAt. Existing: none.
- **`deleteCategory(id)`** — ❌ Missing — `WHERE id = ? AND isDefault = 0`. Tests: 1) deletes non-default; 2) **default category NOT deleted** (returns 0); 3) missing id → 0. Existing: none. The default-guard is a notable behaviour to pin.

#### Lazy-loading / counts / range queries

- **`countExpensesByCategory(accountId, category)`** — ❌ Missing — `SELECT COUNT(*)`. Tests: 1) correct count; 2) zero for unused category; 3) account scope. Existing: none.
- **`countIncomesByCategory(accountId, category)`** — ❌ Missing — same. Existing: none.
- **`getExpensesInRange(accountId, start, end)`** — ❌ Missing — date-string range (Bug #2 fix), `_parseExpenseRows`. Tests: 1) inclusive bounds (start and end dates both included); 2) **boundary**: row exactly on `start`/`end` included; 3) corrupt-row drop; 4) account scope; 5) date DESC order. Existing: none. The Bug-#2 boundary fix here is UNTESTED.
- **`getIncomeInRange(accountId, start, end)`** — ❌ Missing — same, but uses inline try/catch `Income.fromMap` (not `_parseIncomeRows`). Tests as above + corrupt-row skip. Existing: none.
- **`getExpenseCount(accountId)`** — ❌ Missing — Tests: count, account scope, zero. Existing: none.

#### Maintenance

- **`vacuum()`** — ❌ Missing — runs `VACUUM`. Tests: completes without error on a populated DB. Existing: none.
- **`analyze()`** — ❌ Missing — runs `ANALYZE`. Tests: completes without error. Existing: none.
- **`getDatabaseSize()`** — ❌ Missing — file length or 0. Tests: 1) >0 for existing DB; 2) 0 when file absent. Note: hardcodes `expense_tracker_v4.db` (ignores `databaseNameOverride`) — under FFI tests it will read the wrong/absent path; document this seam. Existing: none.
- **`needsMaintenance()`** — ❌ Missing — `freelist_count / page_count > 20%`. Tests: 1) false on a fresh DB; 2) true after bulk delete inflating freelist; 3) page_count 0 → false (div-guard). Existing: none.
- **`performMaintenance({force})`** — ❌ Missing — vacuum+analyze if force/needed, then cleanOrphanedBackupFiles (errors swallowed). Tests: 1) `force: true` always vacuums; 2) skips when not needed and not forced; 3) orphan-cleanup error swallowed. Existing: none.

#### Backup / restore plumbing

- **`getDatabasePath()`** — ❌ Missing — joins `getDatabasesPath()` + hardcoded `expense_tracker_v4.db` (ignores override). Tests: 1) returns a path ending in the db name; 2) document the override-ignored seam. Existing: none.
- **`closeDatabase()`** — ❌ Missing — awaits in-flight init, closes, nulls `_database`/`_initCompleter`. Tests: 1) after close, next `database` re-inits; 2) close during in-flight init waits then closes (no race); 3) close when nothing open is a no-op. Existing: none. The async-gap/race handling is the interesting part and is untested.

#### Tag CRUD + junction

- **`createTag(name, accountId, {color})`** — ❌ Missing — Tests: round-trip, FK, null color. Existing: indirect (cascade test seeds tags via raw insert, not this method).
- **`readAllTags(accountId)`** — ❌ Missing — account-scoped, name ASC. Tests: ordering, scope, empty.
- **`readAllTransactionTags(accountId)`** — ❌ Missing — JOIN against tags to scope by account (junction has no account_id). Tests: 1) returns only this account's links; 2) ordered by id ASC; 3) cross-account links excluded. Existing: none.
- **`updateTag(id, name, {color})`** — ❌ Missing — Tests: update by id, missing-id no-op, color null-out.
- **`deleteTag(id)`** — 🟡 Partial — delete tag; FK cascade removes its junction rows. Tests: 1) tag gone; 2) **junction rows cascade-deleted** (the `tags`→`transaction_tags` ON DELETE CASCADE); 3) missing id → 0. Existing: cascade test seeds tags and notes they're shared but does not test deleteTag's cascade directly.
- **`addTagToTransaction(txnId, type, tagId)`** — ❌ Missing — insert with `ConflictAlgorithm.ignore`. Tests: 1) creates link; 2) **duplicate ignored** (unique index, no throw); 3) link visible via getTagsForTransaction. Existing: none. The idempotency-via-ignore is untested.
- **`removeTagFromTransaction(txnId, type, tagId)`** — ❌ Missing — Tests: removes the specific link, leaves others. Existing: none.
- **`getTagsForTransaction(txnId, type)`** — ❌ Missing — JOIN tags↔transaction_tags. Tests: 1) returns tags for the txn; 2) type-scoped (expense vs income same id don't bleed); 3) none → []. Existing: none.
- **`getTransactionIdsForTag(tagId, type)`** — ❌ Missing — Tests: 1) returns matching txn ids; 2) type-scoped; 3) none → []. Existing: none.

#### Search

- **`searchExpenses(accountId, query, {limit, offset})`** — ❌ Missing — sanitised LIKE on description/category with `ESCAPE '\'`, `LIMIT/OFFSET` string-interpolated (but only from int params). Tests: 1) matches description and category; 2) empty/whitespace query → []; 3) **LIKE-wildcard injection**: a query of `%`/`_` is escaped to literal (via `_sanitizeSearchQuery`), not treated as wildcard; 4) limit/offset pagination; 5) timeout → [] (via `_queryWithTimeout`); 6) account scope; 7) corrupt-row drop. Existing: none. High priority (security-adjacent: LIKE escaping + interpolated LIMIT/OFFSET).
- **`searchIncome(accountId, query, {limit, offset})`** — ❌ Missing — same shape. Tests as above. Existing: none.
- **`_sanitizeSearchQuery(query)` (private)** — ❌ Missing — trims, escapes `%`→`\%` and `_`→`\_`, caps at 100 chars. Tests: 1) `%`/`_` escaped; 2) >100 chars truncated; 3) empty → ''; 4) leading/trailing whitespace trimmed. Existing: none. Core injection-defence — untested.
- **`_parseSearchTokens(query)` (private)** — ❌ Missing — tokeniser respecting quotes + backslash escapes. Tests: 1) `Coffee 50` → 2 tokens; 2) `"Coffee Shop" 20` → quoted phrase kept whole; 3) escaped quote `\"`; 4) trailing-space + empty-token filtering; 5) unterminated quote. Existing: none.
- **`searchTransactionsUnified(accountId, query, {limit, offset, category, startDate, endDate, sortOrder})`** — ❌ Missing — UNION ALL of expenses+income, per-token AND conditions (numeric tokens also match CAST(amount)), category/date filters, 5 sort orders, timeout-safe, returns `{expenses, income, hasMore}`. Tests: 1) merges both types chronologically; 2) **multi-token AND** semantics; 3) **numeric token** also matches amount via CAST; 4) each `sortOrder` (newest/oldest/highest/lowest/category) orders correctly; 5) category='All' bypasses filter; 6) startDate/endDate window; 7) **arg-count alignment** — the dynamic `args` list must match the `?` count for both halves of the UNION (a classic break-point); 8) empty tokens → empty result map; 9) `hasMore` true when `result.length >= limit`; 10) timeout → empty map; 11) LIKE-escape safety. Existing: none. High priority — the most complex query builder in the file, fully untested, with a fragile arg-ordering contract.

#### JSON backup restore

- **`restoreFromJsonBackup(backupData)`** — 🟡 Partial — returns `BackupRestoreStats`; one big txn; schema-version gate; account name-merge with id remap; per-section validation (`_isValidAmount/_isValidBackupDate/_isValidDescription`) incrementing `rowsSkipped`; tag + transaction_tags remap. Tests:
    1. Accounts/expenses/income/budgets restored with preserved account+date+month (COVERED).
    2. Schema-version newer than app → throws `BackupRestoreException`, no rows written (COVERED).
    3. Same-name account merges onto existing id (COVERED).
    4. **`rowsSkipped` counting** — feed a backup with a NaN/overflow amount, an out-of-range date, an oversize description, a missing category → each increments rowsSkipped and is NOT inserted (MISSING — no test feeds invalid rows; validation helpers are effectively dead-tested).
    5. **Tags + transaction_tags remap** — backup with tags + junction rows: tag_id and transaction_id remapped via the three id maps; links with unresolved ids dropped to rowsSkipped (MISSING — sample backup has no tags/junction).
    6. **Budget last-write-wins** on (account,category,month) conflict — duplicate month updates amount (MISSING).
    7. Recurring expense/income dedup on (account,description,frequency,dayOfMonth) (MISSING).
    8. Template dedup on (account,name,type); null amount allowed, bad amount skipped (MISSING).
    9. **Account fallback** — a row referencing an account_id not in the backup falls back to the first DB account (MISSING).
    10. **Txn atomicity** — a mid-restore failure rolls back every section (MISSING — only the pre-txn schema gate's no-write is tested).
    11. `stats.total` sums all section counters (MISSING).
  - Existing coverage: `backup_restore_test.dart` covers cases 1–3 and the happy-path counters for accounts/expenses/income/budgets. The entire Phase 4.9 validation/skip path, the tag+junction remap (cases 4–5), dedup branches, account fallback, and full-txn rollback are MISSING. (Note: that test's comment says "18 is the live databaseVersion" — stale; current is 19. Test still passes because 18 < 19 is accepted, but the comment is wrong.)

- **`class BackupRestoreException`** — ✅ Covered — `toString()` returns message; thrown by the schema gate (tested in `backup_restore_test.dart`).
- **`class BackupRestoreStats`** — 🟡 Partial — counters + `total` getter. Tests: `total` sums every field; counters increment per section. Existing: account/expense/income/budget counters asserted; `tagsAdded`/`transactionTagsAdded`/`rowsSkipped`/`total` UNTESTED.

#### Coverage summary

~84 public/notable members (≈72 public CRUD/query methods + key private helpers + 3 top-level classes). 12 ✅, 26 🟡, 46 ❌. Highest-priority gaps: (1) `searchTransactionsUnified` — the most complex, fully-untested query builder with a fragile dynamic-arg/`?`-count contract and LIKE-escape surface; (2) `_sanitizeSearchQuery` + `searchExpenses`/`searchIncome` — the LIKE-injection defence is entirely untested; (3) `restoreFromJsonBackup` Phase 4.9 validation/skip path, tag+junction remap, dedup branches, and full-txn rollback; (4) `deleteAccount` + `restoreDeletedAccount` — streaming backup, disk-full handling, id-remap on restore, and txn atomicity, with the only round-trip test SKIPPED; (5) `_parseExpenseRows`/`_parseIncomeRows` corrupt-row resilience that backs every list read; (6) the bulk category ops (`bulkDeleteTransactionsAndCategory`, `bulkReassignCategoryAndDelete`, `renameCategoryInAllTables`) — multi-table atomicity, the `isDefault=0` guard, the `IN ($placeholders)` empty-match guard, and rawUpdate parameterisation; (7) the v3→v19 full migration chain and `_migrateToV19` rollback/FK-re-enable/backup-file-lifecycle (only v18→v19 happy path tested); (8) the 30-day trash boundary + UTC-cutoff logic across `getAllDeleted*`, `clearOldDeleted`, `getDeletedAccounts`; (9) batch atomicity in `createRecurring{Expenses,Income}Batch`.


## AppState & Services (lib/providers/app_state.dart, lib/services/)

Coverage judged against: `test/logic/app_state_mutators_test.dart` (settings/filters, DB-free), `test/logic/app_state_logic_test.dart` (CurrencyHelper/DatabaseConstants only — touches NO AppState method), `test/integration/app_state_crud_test.dart` (CRUD), `test/integration/app_state_lifecycle_test.dart` (recurring/dispose/stream), `test/integration/app_state_load_data_coalesce_test.dart`, `test/integration/app_state_prune_test.dart`, `test/integration/app_state_close_database_race_test.dart`, `test/integration/app_state_use_template_test.dart`, `test/integration/recurring_processing_test.dart` (pure scheduler), `test/services/onboarding_service_test.dart`.

Convention notes that bite here: time-dependent reads use `DateHelper.today()` (NOT `Clock.instance.now()`) in `_loadExpensesInternal`/`_loadIncomesInternal`/`_autoRolloverBudgets`/`_processRecurring*`/`_calculateAndStoreCarryover`/`goToToday`/`getUpcomingBillsThisMonth`, but `ensureMonthLoaded`/`_pruneDistantMonths`/`useTemplate` use `Clock.instance.now()`. So a `FakeClock` alone will NOT move the in-memory expense window — the window tracks the real wall-clock month. Most integration tests anchor seed dates to `DateHelper.today()`/`subtractMonths` for exactly this reason. Money is `Decimal` end-to-end; getters convert to `double` via `_decimalToDouble`/`DecimalHelper.toDouble` at the boundary.

### `lib/providers/app_state.dart`

#### Construction / disposal / notify plumbing

- **`AppState()` (implicit ctor)** — 🟡 Partial
  - Constructs with `_isLocked = true`, `_selectedMonth = startOfMonth(now)`, empty lists, broadcast stream controllers.
  - Test cases:
    1. Fresh instance: `isLocked == true`, `isInitialized == false`, `isOnboardingComplete == false`, all list getters empty, `lastAutoCreatedCount == 0`, `loadDataInternalRunCount == 0`.
    2. `selectedMonth` equals start-of-current-month (assert day==1, hour/min==0).
    3. `currentAccountId` returns `1` when `_currentAccount` null (fallback).
  - Existing coverage: implicitly constructed in every test; no test asserts the initial-field contract directly.
- **`notificationHelper` (getter)** — ❌ Missing
  - Exposes the singleton `NotificationHelper`.
  - Test cases:
    1. Returns non-null, returns the same instance on repeated reads.
  - Existing coverage: none.
- **`dispose()`** — ✅ Covered
  - Sets `_isDisposed`, cancels lock timer, closes both stream controllers.
  - Test cases:
    1. After dispose, `onRecurringBatch`/`onAccountSwitch` complete (`.toList()` resolves empty).
    2. dispose after recurring run does not throw (late `_safeNotify`).
    3. Double-dispose is safe (idempotent guard).
  - Existing coverage: lifecycle_test "stream closes on AppState dispose" + "recurring processing followed by dispose does not throw"; mutators_test tearDown disposes every state. Case 3 (double-dispose) untested.
- **`_safeNotify` / `safeNotifyForTesting()`** — ✅ Covered
  - Notifies listeners unless disposed.
  - Existing coverage: lifecycle_test "safeNotify after dispose does not throw" (both pre- and post-dispose).
- **`runRecurringProcessingForTesting()`** — ✅ Covered
  - Test-only wrapper for `_processRecurringInBackground`.
  - Existing coverage: lifecycle_test drives it for Bug #7 + onRecurringBatch.

#### loadData & initialization

- **`loadData()` (coalescing)** — ✅ Covered
  - Returns shared in-flight Future; reruns after completion.
  - Test cases:
    1. 3 concurrent calls → `loadDataInternalRunCount == 1`.
    2. sequential calls after completion → count increments (2).
    3. (gap) exception inside `_loadDataInternal` clears `_loadingFuture` via `whenComplete` so a retry runs again.
  - Existing coverage: load_data_coalesce_test cases 1+2. Case 3 (error path clears the future) untested.
- **`isOnboardingComplete` / `isInitialized` (getters)** — 🟡 Partial
  - Reflect onboarding flag + `_isInitialized` set at end of `_loadDataInternal`.
  - Test cases:
    1. `isInitialized` false before `loadData`, true after.
    2. `isOnboardingComplete` reflects SharedPreferences seed (`onboarding_complete=true`).
  - Existing coverage: indirectly (bootstrap awaits loadData) but no explicit assertion.
- **`completeOnboarding()`** — 🟡 Partial
  - Persists onboarding flag, sets `_isOnboardingComplete`, notifies once.
  - Test cases:
    1. After call, `isOnboardingComplete == true` and `OnboardingService().isOnboardingComplete()` is true (persistence round-trip).
    2. notifyListeners fires exactly once.
  - Existing coverage: onboarding_service_test covers the service layer, but the AppState wrapper (state flag + single notify) is untested.
- **`lastAutoCreatedCount` (getter) / `clearAutoCreatedCount()`** — ✅ Covered
  - Existing coverage: lifecycle_test "clearAutoCreatedCount zeroes the counter"; mutators_test "clearAutoCreatedCount".
- **`isProcessingRecurring` (getter)** — ❌ Missing
  - True while `_processRecurringInBackground` runs.
  - Test cases:
    1. false at rest; (harder) true mid-run — assert it flips back to false after `runRecurringProcessingForTesting`.
    2. re-entrancy: calling `_processRecurringInBackground` while already processing returns immediately (guarded by flag) — no double counting.
  - Existing coverage: none (Bug #7 tests assert the *count* not the flag).
- **`_processRecurringInBackground` (via wrapper)** — 🟡 Partial
  - Resets `_lastAutoCreatedCount`, runs expenses→incomes→clearOldDeleted→performMaintenance→notifications, gated on `_backgroundProcessingEpoch` and `currentAccountId` not changing; emits onRecurringBatch only when count>0.
  - Test cases:
    1. counter resets each run (Bug #7). ✅
    2. emits onRecurringBatch per non-empty batch, suppresses empty. ✅
    3. epoch guard: if `_backgroundProcessingEpoch` bumps mid-run (a concurrent `loadData`), the post-run notify+stream-emit is skipped. ❌
    4. account-switch guard: if `currentAccountId` changes during the run, no notify/emit. ❌
    5. re-entrant call while `_processingRecurring` returns early. ❌
  - Existing coverage: lifecycle_test cases 1+2 only.

#### In-memory 2-month window

- **`ensureMonthLoaded(DateTime)`** — 🟡 Partial
  - Loads a month's expenses+incomes into the caches under `_writeMutex`, dedups by id, records access time, then prunes. Re-check under lock.
  - Test cases:
    1. Loading a not-yet-loaded month adds its rows to `allExpenses`/`incomes` without duplicating existing rows.
    2. Idempotent: calling twice for the same month does not duplicate (existing-id set guard).
    3. Already-loaded month: only updates `_monthAccessTimes`, no DB hit (verify via row count unchanged).
    4. Concurrency: two concurrent `ensureMonthLoaded` for the same month → rows loaded once (mutex + re-check).
  - Existing coverage: prune_test drives it 10× to force eviction (exercises load+prune), but no direct dedup/idempotency/concurrency assertion.
- **`_loadExpensesInternal` / `_loadIncomesInternal` (private, via loadData/refresh)** — 🟡 Partial
  - Loads prev-month-start..current-month-end keyed off `DateHelper.today()`; resets loaded-month sets to the 2-month window.
  - Test cases:
    1. After loadData, `allExpenses` holds only current+previous month rows; older rows excluded.
    2. Window is keyed off `today()` not `selectedMonth` — seed a row 3 months back, assert it is NOT in `allExpenses` after loadData.
    3. notifyListeners NOT fired by the internal loader itself (caller fires).
  - Existing coverage: prune_test seeds current-month sentinel + 10 historical and asserts sentinel survives; the "row outside window excluded on initial load" assertion is absent.
- **`_pruneDistantMonths` (private)** — ✅ Covered
  - LRU+distance eviction past `_maxMonthsInMemory` (6); never evicts the real current month (Phase 1.2 key-format fix).
  - Test cases:
    1. current month survives even with 10 months loaded. ✅
    2. (gap) a distant low-recency month IS evicted from `_loadedExpenseMonths` and its rows dropped from `_expenses`.
  - Existing coverage: prune_test case 1. Case 2 (positive eviction proof) untested but lower priority.

#### Expense mutators

- **`addExpense(Expense)`** — ✅ Covered
  - Validates amount>0/category/description; atomic insert + carryover upserts via `createExpenseWithCarryover`; refreshes window, checks budget alerts, notifies, updates widget. Returns new id.
  - Test cases:
    1. persists + appears in list + returns nonzero id + notifies. ✅
    2. amount<=0 → ArgumentError. ✅
    3. empty description → ArgumentError. ✅
    4. empty category → ArgumentError. ✅
    5. (gap) carryover upsert: adding an expense in month M writes/updates the M+1 `MonthlyBalance` in `_monthlyBalances` AND on disk (atomic — assert both reflect the delta).
    6. (gap) notifyListeners fires exactly once (current test only asserts `isNotEmpty`).
    7. (gap) decimal precision: amount `0.1+0.2`-style sums round to exact cents, not float drift.
  - Existing coverage: crud_test "addExpense" group (cases 1–4). Carryover side-effect + exact notify count untested.
- **`addExpenseRaw({...})`** — ❌ Missing
  - Builds an `Expense` from doubles and delegates to `addExpense`.
  - Test cases:
    1. round-trips amount/category/description/date/paymentMethod/amountPaid into a persisted row.
    2. amountPaid passthrough produces correct `isPaid`.
    3. invalid amount (0) bubbles the ArgumentError from `addExpense`.
  - Existing coverage: none.
- **`updateExpense(Expense)`** — 🟡 Partial
  - Updates row, reloads window, invalidates cache, recalculates carryover for the txn month, notifies, updates widget.
  - Test cases:
    1. edited description persists. ✅
    2. date edit moves row across months + amount untouched. ✅
    3. (gap) editing amount triggers carryover recompute for next month (assert `_monthlyBalances` delta).
    4. (gap) exactly-one notifyListeners.
  - Existing coverage: crud_test "updateExpense" cases 1+2.
- **`deleteExpense(int)`** — 🟡 Partial
  - Finds in cache (or by id from DB), moves to trash, reloads, recalculates carryover, notifies.
  - Test cases:
    1. row vanishes from active list, appears in trash. ✅
    2. (gap) deleting a row NOT in the in-memory window still works via `moveToDeletedById` (seed an out-of-window row, delete by id).
    3. (gap) unknown id → early return, no notify, no throw.
    4. (gap) carryover recomputed for the deleted row's month+1.
  - Existing coverage: crud_test "delete + trash flow (expense)" case 1 only.
- **`addPayment(Expense, double)`** — 🟡 Partial — **M1 sub-10c auto-round-to-paid bug lives here**
  - Adds payment; caps at expense amount; if remaining is `>0 && <0.10` auto-rounds to fully paid. **This silently overpays by up to 9.99c of "paid" credit — write a test PINNING the intended behavior and flag the decision.**
  - Test cases:
    1. payment == amount → `isPaid`, amountPaid==amount. ✅
    2. payment leaving <10c → auto-rounds to fully paid. ✅ (current test asserts the *buggy* behavior as if intended)
    3. **M1 pin**: payment leaving exactly `0.10` remaining must NOT round (boundary: `< tenCents` is strict) — assert `isPaid == false`, amountPaid unchanged. This pins the boundary so a "fix" that changes `<` to `<=` is caught.
    4. **M1 pin**: payment leaving `0.05` remaining → decide+document: today it marks paid with `amountPaid == amount` (i.e. records 5c the user never paid). Pin current behavior AND leave a `// ponytail:` note that the intended behavior may be "mark paid but keep amountPaid at the actual tendered sum". Pick one and assert it.
    5. overpayment: payment > remaining caps `amountPaid` at `amount` (no negative remaining).
    6. partial payment >10c remaining → `isPaid == false`, amountPaid == sum, remaining correct to the cent (Decimal, no float drift).
    7. multiple sequential partial payments accumulate exactly (0.33+0.33+0.34 on a 1.00 expense → paid).
    8. carryover recompute after payment (paid amount changes available cash).
    9. exactly-one notifyListeners.
  - Existing coverage: crud_test "addPayment" cases 1+2. **Boundary (0.10), the no-real-money-tendered concern (case 4), overpayment cap, multi-payment accumulation, and the carryover side-effect are all untested.** This is the highest-value gap.
- **`undoDelete()`** — ❌ Missing
  - Restores last-deleted expense for the account, reloads, recomputes carryover, notifies.
  - Test cases:
    1. after `deleteExpense`, `undoDelete` brings the row back into `expenses`.
    2. no prior deletion → restoreLastDeleted no-op, no throw.
    3. restores the MOST RECENT deletion when several were deleted (ordering).
  - Existing coverage: none (note: distinct from `restoreDeletedExpense(deletedId)` which IS covered).
- **`getExpensesForSelectedMonth()`** — 🟡 Partial
  - Filters `_expenses` to `_selectedMonth` by year+month.
  - Test cases:
    1. returns only selected-month rows.
    2. empty list when no rows that month.
  - Existing coverage: exercised transitively by `expenses` getter and totals; no direct test.
- **`expenses` (getter, cached+hashed)** — 🟡 Partial
  - Applies category/date/amount/paid filters + sort (date desc, id desc); caches keyed on a content hash + filter snapshot.
  - Test cases:
    1. sort order: same-date rows ordered by id desc.
    2. cache invalidation: editing an expense's amount (same count) refreshes the list (hash catches content change).
    3. filter application: category filter narrows; date-range inclusive of endpoints; min/max amount; paidStatus.
    4. cache hit: repeated reads with no change return the same list instance (or equal contents) without recompute.
  - Existing coverage: none direct (filters assert only notify in mutators_test; the actual filtered output is untested at AppState level).
- **`allExpenses` (getter)** — ✅ Covered (used as the unfiltered probe in prune_test/crud_test).

#### Income mutators

- **`addIncome(Income)`** — 🟡 Partial
  - Validation + atomic insert + carryover upserts + reload + notify + widget.
  - Test cases:
    1. persists + in list + nonzero id. ✅
    2. amount<=0 → ArgumentError. ✅
    3. (gap) empty category/description → ArgumentError (validated but untested).
    4. (gap) carryover upsert side-effect (both memory + disk).
    5. (gap) exactly-one notify.
  - Existing coverage: crud_test "addIncome" cases 1+2.
- **`addIncomeRaw({...})`** — ❌ Missing
  - Builds Income from doubles, delegates.
  - Test cases: round-trip persistence; invalid amount bubbles error.
  - Existing coverage: none.
- **`updateIncome(Income)`** — 🟡 Partial
  - Update + reload + carryover recompute + notify + widget.
  - Test cases:
    1. edited description persists. ✅
    2. (gap) amount edit recomputes carryover; (gap) exactly-one notify.
  - Existing coverage: crud_test "updateIncome" case 1.
- **`deleteIncome(int)`** — 🟡 Partial
  - Test cases:
    1. moves to trash, removed from active list. ✅
    2. (gap) delete out-of-window row by id; unknown id early-return; carryover recompute.
  - Existing coverage: crud_test "delete + trash flow (income)" case 1.

#### Trash methods

- **`getDeletedExpenses()` / `getDeletedIncome()`** — ✅ Covered (used as assertions across trash tests).
- **`restoreDeletedExpense(int)` / `restoreDeletedIncome(int)`** — ✅ Covered
  - Existing coverage: crud_test "trash lifecycle" restores both; asserts reappearance + vacating trash.
- **`permanentlyDeleteExpense(int)` / `permanentlyDeleteIncome(int)`** — ✅ Covered
  - Existing coverage: crud_test "trash lifecycle" both.
- **`emptyTrash()`** — ✅ Covered
  - Existing coverage: crud_test "emptyTrash wipes both deleted tables".

#### Budget methods

- **`setBudget(String, double)`** — 🟡 Partial
  - Validates amount>0 / category non-empty / category EXISTS; upserts for selected month; notifies.
  - Test cases:
    1. creates a budget for the selected month. ✅
    2. overwrites existing rather than duplicating. ✅
    3. (gap) amount<=0 → ArgumentError.
    4. (gap) empty category → ArgumentError.
    5. (gap) non-existent category → ArgumentError ("does not exist").
    6. (gap) exactly-one notify; decimal amount stored exactly.
  - Existing coverage: crud_test "setBudget" cases 1+2. Validation throws (3–5) untested.
- **`deleteBudget(int)`** — ❌ Missing
  - Saves `_lastDeletedBudget`, deletes, reloads, notifies.
  - Test cases:
    1. removes budget from `budgets`.
    2. stores last-deleted for undo.
    3. unknown id: still notifies, `_lastDeletedBudget` left as prior value (no throw).
  - Existing coverage: none.
- **`undoBudgetDeletion()`** — ❌ Missing
  - Recreates `_lastDeletedBudget` (without id); clears the slot; notifies. Early-returns if null.
  - Test cases:
    1. after `deleteBudget`, undo re-adds an equal budget (category/amount/month).
    2. no prior deletion → early return, no notify.
    3. undo twice → second is a no-op (slot cleared).
  - Existing coverage: none.
- **`getBudgetSpentBreakdown(String)`** — ❌ Missing
  - Returns `{actual, projected, total}`: actual = sum of this-month expenses in category; projected = remaining recurring occurrences this month × amount.
  - Test cases:
    1. no recurring → projected 0, total == actual.
    2. monthly recurring not yet materialized → projected == one occurrence amount.
    3. recurring already created this month → remaining occurrences reduced (alreadyCreatedCount subtracted), projected drops.
    4. weekly/biweekly occurrence counting within the month.
    5. recurring startDate after month / endDate before month → 0 occurrences.
    6. Decimal precision on the sums.
  - Existing coverage: none.
- **`getBudgetSpent(String)` / `getBudgetSpentActual(String)`** — ❌ Missing
  - `getBudgetSpent` = breakdown total; `getBudgetSpentActual` = actual only.
  - Test cases:
    1. actual matches summed expenses; total includes projected recurring.
    2. unknown category → 0.0.
  - Existing coverage: none.
- **`getBudgetProgress(Budget)`** — ❌ Missing
  - `spent/amount` clamped 0..1; 0 when amount==0 (Decimal.zero guard).
  - Test cases:
    1. half-spent → 0.5.
    2. over-budget → clamps to 1.0.
    3. zero-amount budget → 0.0 (no div-by-zero).
  - Existing coverage: none.
- **`_autoRolloverBudgets` (private, via loadData)** — ❌ Missing
  - If no budgets exist for the current month, clones previous month's budgets forward.
  - Test cases:
    1. prev-month budgets exist, current month empty → cloned on loadData.
    2. current-month budgets already exist → no rollover (no duplication).
    3. no prev budgets → no-op.
  - Existing coverage: none.
- **`_checkBudgetAlerts` (private, via addExpense)** — ❌ Missing
  - Fires a notification when category spend crosses the configurable warning threshold; gated on `_budgetAlertsEnabled`.
  - Test cases:
    1. alerts disabled → no notification call (mock NotificationHelper / channel).
    2. spend below threshold → no alert.
    3. spend crossing threshold → `showBudgetAlert` invoked once.
  - Existing coverage: none (would require a NotificationHelper seam/mock).
- **`setOverallMonthlyBudget(double)` / `removeOverallMonthlyBudget()`** — 🟡 Partial
  - Upsert/clear `overallBudget` on the selected month's MonthlyBalance, preserving carryover; notify.
  - Test cases:
    1. set then read `overallMonthlyBudget` round-trips. ✅
    2. remove → null. ✅
    3. (gap) amount<=0 → ArgumentError.
    4. (gap) set preserves existing carryover (don't clobber `carryoverFromPrevious`).
    5. (gap) remove when none set → no-op (no throw, no notify).
  - Existing coverage: crud_test "overall monthly budget" cases 1+2.

#### Budget/cash computed getters

- **`totalCategoryBudget` / `overallMonthlyBudget` / `hasOverallMonthlyBudget` / `totalMonthlyBudget`** — ❌ Missing
  - Test cases: empty → 0/null/false; with category budgets → exact Decimal sum; overall set → `totalMonthlyBudget` returns overall not category sum.
  - Existing coverage: `overallMonthlyBudget` touched transitively in crud_test; the sum/precedence logic untested.
- **`carryoverForSelectedMonth` / `carryoverForSelectedMonthDecimal` / `hasCarryover`** — ❌ Missing
  - Test cases: no balance → 0/Decimal.zero/false; balance present → exact value; `hasCarryover` uses Decimal comparison (a `0.00` carryover → false; tiny non-zero → true).
  - Existing coverage: none.
- **`totalAvailableCash` / `totalIncomeWithCarryover` / `projectedEndOfMonthBalance`** — ❌ Missing
  - Test cases: with seeded income+expenses+carryover, assert each formula to the cent; sign correctness when expenses exceed income+carryover.
  - Existing coverage: none.
- **`currentMonthBudgets` (getter)** — ❌ Missing — filters `_budgets` to selected month. Test: only selected-month budgets returned.
- **`overallMonthlyBudget`/etc. via `currentMonthBudgets`** — see above.

#### Carryover methods

- **`getCarryoverForMonth(DateTime)`** — ❌ Missing
  - Cache → DB → compute fallback chain.
  - Test cases:
    1. cached → returns cached value without DB hit.
    2. not cached but in DB → loads + caches + returns.
    3. neither → computes via `_calculateCarryoverForMonth` and returns (0.0 when no prior data).
  - Existing coverage: none.
- **`recalculateCarryovers()`** — ❌ Missing
  - Recomputes current + selected month, reloads balances, notifies; mutex-guarded.
  - Test cases:
    1. after editing a past-month transaction, carryover into later months updates.
    2. selected==current month → only one compute (no redundant).
    3. exactly-one notify.
  - Existing coverage: none.
- **`_computeCarryoverForMonth` / `_prepareCarryoverUpserts` (private)** — 🟡 Partial
  - Pure-ish carryover math: `prevMonthBalance(income-expenses) + prevCarryover`; returns null when unchanged (no write needed). `_prepareCarryoverUpserts` collects next-month + selected-month pending upserts.
  - Test cases:
    1. chain: M has carryover = (M-1 income − M-1 expenses) + (M-1's own carryover) — multi-month chain accumulates.
    2. returns null when computed value equals cached (idempotent — no redundant write).
    3. Decimal precision across the income−expense subtraction.
    4. `_prepareCarryoverUpserts` returns next-month upsert; adds selected-month upsert only when selected != next-month.
  - Existing coverage: exercised transitively by addExpense/addIncome (which assert the row but not the balance); the math itself is unverified. High value — money correctness.
- **`_calculateCarryoverForMonth` / `_calculateAndStoreCarryover` / `_recalculateCarryoverAfterTransaction` / `_ensureCarryoverLoaded` (private)** — ❌ Missing
  - Existing coverage: none direct; all run during loadData/mutators but no balance assertion exists.

#### Account methods

- **`addAccount(String)`** — ✅ Covered
  - Existing coverage: crud_test "accounts" — empty/whitespace reject + append + (implicitly) default-category seeding.
- **`updateAccount(Account)`** — ✅ Covered (crud_test "updateAccount persists rename").
- **`setDefaultAccount(int)`** — ✅ Covered
  - Existing coverage: crud_test "setDefaultAccount flips the default exclusively"; (gap) unknown id → early return is untested.
- **`deleteAccount(int)`** — 🟡 Partial
  - Refuses last account; on deleting current, switches to default/first, clears filters, reloads.
  - Test cases:
    1. refuses last account → ArgumentError. ✅
    2. removes a non-current account. ✅
    3. (gap) deleting the CURRENT account switches `_currentAccount` to remaining default/first + reloads its data + clears filters.
  - Existing coverage: crud_test cases 1+2. Current-account-deletion path untested.
- **`resetAccount(int)`** — ❌ Missing
  - Transactionally wipes all tables for the account (junction first), reloads if current, notifies.
  - Test cases:
    1. seeded expenses/income/budgets/recurring/templates/tags all removed for the account.
    2. default categories survive (`isDefault = 0` guard), custom categories removed.
    3. resetting the CURRENT account reloads + clears filters.
    4. resetting a non-current account leaves current data intact.
    5. atomicity: a mid-transaction failure rolls back (hard to force in FFI; lower priority).
  - Existing coverage: none.
- **`getDeletedAccounts()`** — 🟡 Partial (used as assertion in the skipped restore test).
- **`restoreDeletedAccount(int)`** — 🟡 Partial (test exists but `skip:` — path_provider race). Behavior unverified in CI.
- **`permanentlyDeleteAccount(int)`** — ❌ Missing
  - Test cases: removes the trashed account row; notify.
  - Existing coverage: none.
- **`switchAccount(Account)`** — ✅ Covered
  - Sets current+currency, clears filters, reloads, seeds categories if empty, emits onAccountSwitch.
  - Existing coverage: crud_test "switchAccount changes currentAccountId + emits onAccountSwitch". (gap) currency change + filter clear assertions absent.
- **`onAccountSwitch` (stream getter)** — ✅ Covered (asserted in switchAccount test + closes on dispose).
- **`refreshCurrentMonthData()`** — ❌ Missing
  - Reloads expenses+incomes, invalidates cache, notifies once.
  - Test cases: after an out-of-band DB write, refresh surfaces it; exactly-one notify.
  - Existing coverage: none.

#### Category methods

- **`addCategory(String, {type,color,icon})`** — 🟡 Partial
  - Trims, rejects empty, rejects case-insensitive duplicate within type; persists; notify.
  - Test cases:
    1. add + delete round-trip. ✅
    2. (gap) empty/whitespace name → ArgumentError.
    3. (gap) duplicate name (case-insensitive, same type) → ArgumentError.
    4. (gap) same name across different types allowed (expense "Other" vs income "Other").
  - Existing coverage: crud_test "categories" add+delete only.
- **`updateCategory(Category, {oldName})` (rename back-propagation + re-entrancy guard)** — 🟡 Partial
  - Guarded by `_categoryRenameInProgress`; renames across all tables when name changes, reloads dependent caches.
  - Test cases:
    1. rename back-propagates to existing expenses. ✅
    2. (gap) rename propagates to income/budgets/templates/recurring too.
    3. (gap) re-entrancy: a second `updateCategory` while one is in progress early-returns (the flag) — assert no double-rename / no crash.
    4. (gap) no-name-change update (color/icon only) skips the rename path.
  - Existing coverage: crud_test "updateCategory propagates rename to existing expenses" (expenses only).
- **`deleteCategory(int)`** — ✅ Covered (crud_test add+delete round-trip).
- **`bulkReassignCategory(old,new,type)`** — ❌ Missing
  - Reassigns category across expenses/income/budgets/templates/recurring; reloads; notify.
  - Test cases: expenses+income reassigned; budgets+recurring+templates reassigned; notify.
  - Existing coverage: none (distinct from `reassignCategoryAndDelete`).
- **`bulkDeleteTransactionsByCategory(category,type)`** — ❌ Missing
  - Test cases: all matching expenses (or income) removed; other categories untouched.
  - Existing coverage: none.
- **`reassignCategoryAndDelete(categoryId,old,new,type)`** — ✅ Covered (crud_test "reassignCategoryAndDelete").
- **`deleteTransactionsAndCategory(categoryId,category,type)`** — ✅ Covered (crud_test "deleteTransactionsAndCategory").
- **`getCategoryUsageInRecurring(String)`** — ❌ Missing
  - Returns `{recurringExpenses, recurringIncome}` counts for a category.
  - Test cases: counts both lists; 0 when unused.
  - Existing coverage: none.
- **`countTransactionsByCategory(String, type)`** — ❌ Missing
  - Test cases: counts expenses for type=='expense', income otherwise; 0 for unused category.
  - Existing coverage: none.

#### Quick templates

- **`addTemplate` / `updateTemplate` / `deleteTemplate`** — ✅ Covered (crud_test "quick template CRUD").
- **`useTemplate(QuickTemplate)`** — ✅ Covered
  - Creates a real transaction; expense templates start UNPAID (Phase 1.1 fix); category fallback when deleted; uses `Clock.instance.now()` for the date.
  - Test cases:
    1. expense template → adds expense of right amount/category. ✅ (crud_test)
    2. templated expense `amountPaid == 0`, `isPaid == false`. ✅ (use_template_test)
    3. missing category → falls back without auto-paying. ✅ (use_template_test)
    4. (gap) income template → adds income (only expense path is tested for type routing).
    5. (gap) no categories at all → ArgumentError ('No expense categories available').
  - Existing coverage: use_template_test + crud_test (expense paths thorough; income path + empty-categories throw untested).

#### Recurring methods

- **`addRecurringExpense` / `updateRecurringExpense` / `deleteRecurringExpense`** — 🟡 Partial
  - add ✅; update persists fields ✅ (but notification reschedule throws under flutter_test — swallowed); delete is `skip:`-ped (notification platform mock gap).
  - Test cases:
    1. add persists + cache. ✅
    2. update persists field edits. ✅ (notification call swallowed)
    3. (gap) update on active+remindersEnabled schedules a bill reminder; inactive cancels it — needs a NotificationHelper seam.
    4. delete cancels reminder + drops from cache. ❌ (skipped — needs flutter_local_notifications platform mock).
    5. (gap) notification IDs: scheduled reminder id derives from recurring id (verify via mock capture).
  - Existing coverage: crud_test "recurring expense CRUD" (delete skipped).
- **`addRecurringIncome` / `updateRecurringIncome` / `deleteRecurringIncome`** — 🟡 Partial (add ✅, update ✅, delete skipped — same notification gap).
- **`_processRecurringExpenses` / `_processRecurringIncomes` (private, via wrapper)** — 🟡 Partial
  - Query active rows, skip if `lastCreated == today`, generate via `processRecurringInstances`, batch insert + update `lastCreated`/`occurrenceCount`, per-item try/catch, accumulate count, reload; expenses also reschedule end-of-month reminders.
  - Test cases:
    1. monthly due today → one row created, count==1. ✅
    2. same-day re-run → skipped (count resets to 0). ✅
    3. (gap) per-item failure isolation: one malformed recurring throws but others still process.
    4. (gap) `occurrenceCount` increments by the number created.
    5. (gap) `lastCreated` advanced to today after a run.
    6. (gap) weekly/biweekly DB-level processing (only the pure scheduler is tested, not the DB batch path).
  - Existing coverage: lifecycle_test (count semantics) + recurring_processing_test (pure scheduler exhaustively). DB-side occurrenceCount/lastCreated/error-isolation untested.
- **`processRecurringInstances<T>` (static, @visibleForTesting)** — ✅ Covered
  - Existing coverage: recurring_processing_test — monthly (current/skip/backfill/day-31 clamp/leap-year), biweekly (step/startDate/<14d/Bug#1), weekly (step/startDate/backfill/Bug#1/safety-cap), unknown index → empty. Thorough.
- **`_processMonthlyRecurring` / `_processIntervalRecurring` (private static)** — ✅ Covered transitively via the dispatcher tests above.

#### Tag methods

- **`addTag(String,{color})` / `updateTag(int,name,{color})` / `deleteTag(int)`** — ❌ Missing
  - Test cases: add persists + appears in `tags`/`allTags`; update edits name/color; delete removes; notify each.
  - Existing coverage: none.
- **`addTagToTransaction` / `removeTagFromTransaction`** — ❌ Missing
  - Test cases: junction row added/removed; notify; idempotent re-add.
  - Existing coverage: none.
- **`getTagsForTransaction(int,type)`** — ❌ Missing
  - Test cases: returns mapped `Tag` list; empty when none.
  - Existing coverage: none.
- **`allTags` (getter)** — ❌ Missing — maps `_tags` maps to `Tag`. Test: count + mapping.

#### Search & analytics

- **`searchTransactionsUnified(query,{...})`** — ❌ Missing
  - Empty query → empty result with `hasMore:false`; otherwise delegates to DB with paging/filters.
  - Test cases: empty query short-circuit; matching query returns expenses+income; limit/offset paging; category/date filters; sortOrder.
  - Existing coverage: none.
- **`getMonthOverMonthComparison()` / `getIncomeMonthOverMonthComparison()`** — ❌ Missing
  - Current vs previous month totals + percent change (Decimal, scaleOnInfinitePrecision:4) + per-category breakdown.
  - Test cases: prev==0 → percentChange 0 (no div-by-zero); 100→150 → +50%; category breakdown includes categories present in either month; Decimal precision.
  - Existing coverage: none.
- **`getSpendingTrends({months})`** — ❌ Missing
  - Loads each of the last N months (via `ensureMonthLoaded` — relative to `_selectedMonth`, NOT today), returns `[{month,expenses,income,savings}]`.
  - Test cases: N months returned oldest→newest; per-month totals correct; savings = income−expenses; ensureMonthLoaded pulls months outside the default window.
  - Existing coverage: none.
- **`getCategorySpending()` / `getSpentForCategory(String)`** — ❌ Missing
  - Test cases: per-category sums map; `getSpentForCategory` delegates to budget-spent (includes projected recurring — note the subtlety).
  - Existing coverage: none.
- **`getUpcomingBillsThisMonth()`** — ❌ Missing
  - For active recurring expenses, computes due date this selected month (clamps day to last-of-month), includes only those not before today, sorts by date, returns maps with `daysUntilDue`.
  - Test cases: bill due later this month included; bill already past today excluded; day-31 clamps in a 30-day month; sort order; inactive recurring excluded; `daysUntilDue` correct.
  - Existing coverage: none.

#### Navigation

- **`goToPreviousMonth()` / `goToNextMonth()` / `goToMonth(DateTime)` / `goToToday()`** — ❌ Missing
  - Each ensures the target month is loaded, sets `_selectedMonth`, ensures carryover loaded, notifies once.
  - Test cases:
    1. prev/next shift `selectedMonth` by ∓1 month; `selectedMonthName` updates.
    2. `goToMonth` snaps to start-of-month.
    3. `goToToday` returns to current month (uses `DateHelper.today()`).
    4. navigating loads the new month's rows into the window (ensureMonthLoaded) and its carryover.
    5. exactly-one notify per call.
    6. year boundary: December→January increments year.
  - Existing coverage: none.
- **`selectedMonth` / `selectedMonthName` (getters)** — ❌ Missing
  - Test cases: name formats as "Month YYYY"; month index mapping (Jan==month 1).
  - Existing coverage: none.

#### Settings & filters

- **`toggleDarkMode` / `setThemeMode` / `toggleBillReminders` / `toggleBudgetAlerts` / `toggleMonthlySummary` / `toggleShowTransactionColors` / `setTransactionColorIntensity` / `setReminderTime`** — ✅ Covered
  - Existing coverage: mutators_test — each asserts state + SettingsHelper persistence + exactly-one notify; intensity clamps tested both ends; reminderTime hour+minute persisted.
- **`changeCurrency(String)`** — ❌ Missing
  - Sets `_currencyCode`, persists onto the current account row, notifies; mutex-guarded.
  - Test cases:
    1. updates `currencyCode` + `currency` symbol; account row persisted (`updateAccount`).
    2. null current account → no DB write, still notifies (or not — pin behavior).
    3. exactly-one notify.
  - Existing coverage: none.
- **`setFilterCategory` / `setDateRange` / `setAmountRange` / `setPaidStatusFilter` / `clearFilters`** — 🟡 Partial
  - Set private filter fields, invalidate cache, notify once (synchronous).
  - Test cases:
    1. each fires exactly-one notify. ✅
    2. setDateRange null/null clears. ✅; clearFilters resets category + ranges. ✅
    3. (gap) the FILTER ACTUALLY APPLIES to `expenses` output — category narrows, date-range inclusive of endpoints, amount min/max bounds, paidStatus filters. The mutators_test explicitly defers this ("integration coverage") but NO integration test asserts the filtered list. This is a real gap.
  - Existing coverage: mutators_test (notify + clear semantics only). Filtered-output behavior untested anywhere.
- **`formatAmount` / `formatWithCurrency` / `formatCompact` (getters/methods)** — 🟡 Partial
  - Thin delegates to CurrencyHelper using `_currencyCode`.
  - Test cases: delegate with the state's currency code; respects decimalDigits.
  - Existing coverage: CurrencyHelper itself is exhaustively tested in app_state_logic_test, but the AppState delegation (uses `_currencyCode`) is untested.
- **List/simple getters: `incomes`, `budgets`, `accounts`, `categories`, `quickTemplates`, `recurringExpenses`, `recurringIncomes`, `tags`, `monthlyBalances`, `expenseCategories`, `incomeCategories`, `categoryNames`, `currentAccount`, `currentAccountId`, `isDarkMode`, `themeMode`, `currencyCode`, `currency`, `*Enabled`, `reminderTime`, `showTransactionColors`, `transactionColorIntensity`, `filterCategory`, `dateRange`, `allExpenseCategoryNames`, `allIncomeCategoryNames`** — 🟡 Partial
  - Mostly exercised transitively as assertion targets; `expenseCategories`/`incomeCategories` filter by type; `categoryNames` derives from expense categories; `allExpense/IncomeCategoryNames` union categories + transaction categories, sorted+deduped.
  - Test cases worth adding: `allExpenseCategoryNames` dedups + sorts a category that exists only on a transaction; `expenseCategories` vs `incomeCategories` partition.
  - Existing coverage: used as assertion targets throughout crud_test; the union/sort getters untested.

#### Calculations & aliases

- **`totalExpensesThisMonth` / `totalIncomeThisMonth` / `balanceThisMonth` / `totalPaid` / `totalRemaining` / `availableIncomeBalance`** — ❌ Missing
  - Decimal sums over selected month, converted to double.
  - Test cases: seeded month → each equals the exact summed value; balance = income−expenses; totalRemaining = Σ(amount−amountPaid); precision (no float drift on e.g. 0.1×3).
  - Existing coverage: none direct.
- **`getExpensesForMonth(DateTime)` / `getIncomeForMonth(DateTime)` / `getAvailableIncomeForMonth(DateTime)`** — ❌ Missing
  - Per-arbitrary-month sums (used by widget).
  - Test cases: sums for a specific month; 0 for an empty month; available = income − paid.
  - Existing coverage: none.
- **`totalIncome` / `totalSpent` / `netSavings` (aliases)** — ❌ Missing — alias the *ThisMonth getters. Test: equal to their targets.
- **`getAllExpensesForBackup()` / `getAllIncomesForBackup()`** — ❌ Missing
  - Read ALL rows (not windowed) from DB for the account.
  - Test cases: returns rows outside the in-memory window (seed an old row, assert it's included).
  - Existing coverage: none.
- **`closeDatabase()`** — ✅ Covered
  - Spins on `_processingRecurring` then serializes the close through `_writeMutex`.
  - Existing coverage: close_database_race_test — behavioral (5 concurrent writes + close, no DatabaseClosed errors) + structural (source still contains the mutex guard).
- **`reloadAfterRestore()`** — ❌ Missing
  - `closeDatabase()` then `loadData()`.
  - Test cases: after a simulated restore (swap DB file), reload surfaces the new data; no double-notify storm.
  - Existing coverage: none.

#### PIN lock

- **`isLocked` (getter)** — 🟡 Partial — true at construction. Test: starts true; flips on unlock/lock.
- **`isPinEnabled()`** — ❌ Missing
  - Delegates to `PinSecurityHelper.isPinEnabled()`.
  - Test cases: false when no PIN set; true after a PIN is configured (mock secure storage channel).
  - Existing coverage: none at AppState level (PinSecurityHelper has its own tests).
- **`initializeLockState()`** — ❌ Missing
  - Sets `_isLocked` from PIN-enabled; fires `SecureWindow.setSecure` (unawaited).
  - Test cases:
    1. PIN enabled → `isLocked == true`; PIN disabled → `isLocked == false`.
    2. `SecureWindow.setSecure` called with the pin-enabled value (mock `budget_tracker/secure_window` channel + capture).
    3. idempotent on repeated cold-start calls.
  - Existing coverage: none.
- **`unlock()`** — ❌ Missing
  - Clears lock, starts the 3-min timer, notifies.
  - Test cases:
    1. `isLocked` → false; notify fires.
    2. starts a timer (FakeAsync: advancing 3 min with PIN enabled re-locks).
  - Existing coverage: none.
- **`lock()`** — ❌ Missing
  - Cancels timer, sets locked, notifies.
  - Test cases: `isLocked` → true; notify fires; timer cancelled (advancing time doesn't double-fire).
  - Existing coverage: none.
- **`resetLockTimer()`** — ❌ Missing
  - Restarts the timer only when unlocked.
  - Test cases:
    1. when unlocked: restarts timer (FakeAsync — partial advance then reset → no lock at original deadline).
    2. when locked: no-op.
  - Existing coverage: none.
- **`_startLockTimer` / `_cancelLockTimer` (private, async-gap mounted checks)** — ❌ Missing
  - Timer callback re-checks `_isDisposed` before AND after the `await PinSecurityHelper.isPinEnabled()` async gap.
  - Test cases:
    1. timer fires after 3 min with PIN enabled → `lock()` called → `isLocked == true` (FakeAsync).
    2. dispose during the timer's async gap → no `lock()` / no notify-after-dispose throw.
    3. PIN disabled when timer fires → stays unlocked.
  - Existing coverage: none. The async-gap disposed-checks are exactly the kind of re-entrancy concern the harness calls out — high value, needs FakeAsync + secure-storage channel mock.

### `lib/services/onboarding_service.dart`

- **`isOnboardingComplete()`** — ✅ Covered (false fresh, true after complete, persists across instances, false after reset).
- **`completeOnboarding()`** — ✅ Covered (sets flag, idempotent).
- **`isFirstLaunch()`** — ✅ Covered (true first call, self-extinguishing, resettable).
- **`hasSeenAddTransactionTooltip()`** — ❌ Missing
  - Defaults false; true after `markAddTransactionTooltipSeen`.
  - Test cases:
    1. false on fresh install.
    2. true after `markAddTransactionTooltipSeen`.
    3. false again after `resetOnboarding`.
  - Existing coverage: none (the test file predates this Phase 5.5 pair).
- **`markAddTransactionTooltipSeen()`** — ❌ Missing
  - Test cases: persists true; idempotent (call twice still true).
  - Existing coverage: none.
- **`resetOnboarding()`** — ✅ Covered (asserted via the reset cases in the complete/firstLaunch groups; also resets the tooltip key, which is untested — see above).

#### Coverage summary
~135 public members (≈96 AppState public methods/getters/streams + the simple list/computed getters + 6 OnboardingService methods). Approx 23 ✅, 28 🟡, 84 ❌. Highest-priority gaps: (1) **`addPayment` M1 sub-10c auto-round-to-paid bug** — pin the 0.10 boundary and the "records money never tendered" concern, decide intended behavior; (2) **carryover math** (`_computeCarryoverForMonth`, `getCarryoverForMonth`, `recalculateCarryovers`, the cash getters) — money correctness, currently only transitively touched; (3) **filter application on the `expenses` getter** — every `set*Filter` test asserts only notify, never the filtered output (explicitly deferred but never picked up); (4) **PIN lock timer** (`unlock`/`lock`/`resetLockTimer`/`_startLockTimer` async-gap disposed-checks) — needs FakeAsync + secure-storage mock; (5) **month navigation** (`goToNextMonth`/`goToPreviousMonth`/`goToToday`/`goToMonth`) + `getSpendingTrends`/`getUpcomingBillsThisMonth`/MoM-comparison analytics; (6) **tag CRUD + junction** and **`addExpenseRaw`/`addIncomeRaw`** entirely untested; (7) the per-expense **carryover side-effect of add/update/delete/addPayment** — asserted at the row level but never at the `MonthlyBalance` level; (8) recurring **notification scheduling/cancel + IDs** (blocked on a flutter_local_notifications platform seam — two delete tests are `skip:`-ped).


## Screens (lib/screens/)

Layer-wide notes that apply to every entry below:

- **No golden tests exist anywhere in the repo.** `Glob test/goldens/**` and `test/**/*golden*` both return nothing; `matchesGoldenFile` appears in zero files. **Stage D.3 (golden tests) is 100% unimplemented** — every "golden-able" note below is a gap, not a partial.
- **The recurring-processor pump hazard** governs every seeded test: `AppState.loadData()` fires a fire-and-forget `_processRecurringInBackground()` that never settles, so `pumpAndSettle()` hangs. The established workaround (used by home/budget/wallet/analytics/recurring/history/settings tests) is: seed inside `tester.runAsync(() async { await state.loadData(); …; await Future.delayed(200ms); })`, then a bounded `pumpAndDrain` of `pump()` + `pump(350ms)` + `pump(700ms)`. Re-use this for any new seeded test.
- **Surface sizing**: list/sliver-heavy screens use `setSurfaceSize(Size(800,1600))` (or taller, e.g. settings `420×3200`, analytics `800×2400`) so off-screen slivers stay in the tree (Flutter lazily skips off-screen children on the default 800×600).
- **Relative-time flakiness (golden blocker)**: `_GlassHomeExpenseTile`, `HistoryScreen._buildExpenseItem`, and the dated tile builders all call `DateHelper.getRelativeTime(...)` ("2 hours ago", "Yesterday"). Any golden over these screens MUST run under `withClock(Clock.fixed(...))` (or seed all dates relative to a `FakeClock` instant) or the golden bytes drift hourly. `lib/utils/clock.dart` (`Clock.instance` / `FakeClock`) is the abstraction, but **no screen test currently wraps a pump in `withClock`** — golden setup will have to introduce this.
- **Accessibility audit (M8–M12)**: icon-only buttons route through `AccessibilityHelper.semanticIconButton` (home search, budget month nav) or explicit `Semantics(label:…, button:true)` wrappers. No screen test asserts the 48dp minimum tap-target (M9), `textScaler`/large-font reflow (M11/M12), or that every icon button carries a non-empty semantic label (M8/M10). These are uniformly **missing** across the layer.

---

### `lib/screens/history/history_grouping.dart`

- **`DateTime itemDate(dynamic item)`** — ✅ Covered
  - Returns `.date` for `Expense`/`Income`, throws `ArgumentError` otherwise.
  - Test cases:
    1. Expense → returns its `date`.
    2. Income → returns its `date`.
    3. Unsupported type (e.g. `int`) → throws `ArgumentError`.
  - Existing coverage: `history_grouping_test.dart` exercises this indirectly through `groupByDay`; the `ArgumentError` path on an unsupported type is **not** directly asserted (minor gap).

- **`String itemCategory(dynamic item)`** — 🟡 Partial
  - Returns `.category` for `Expense`/`Income`, throws otherwise.
  - Test cases:
    1. Expense → returns `category`.
    2. Income → returns `category`.
    3. Unsupported type → throws `ArgumentError`.
  - Existing coverage: `groupByCategory` tests exercise the happy paths; the throw-on-unsupported-type case is untested.

- **`Map<String,List<dynamic>> groupByDay(List<dynamic> items)`** — ✅ Covered
  - Buckets items by `yyyy-MM-dd`, discarding time-of-day, preserving insertion order.
  - Test cases:
    1. Two items either side of midnight land in separate buckets.
    2. Same-day morning + evening land in one bucket.
    3. Empty input → empty map.
    4. (missing) insertion order within a bucket preserved across 3+ same-day items.
  - Existing coverage: `history_grouping_test.dart` group `groupByDay` covers 1–3; order-preservation (4) is asserted only implicitly.

- **`Map<String,List<dynamic>> groupByCategory(List<dynamic> items)`** — ✅ Covered
  - Buckets by raw case-sensitive category string.
  - Test cases:
    1. Same-category across dates grouped; distinct categories separated.
    2. Empty input → empty map.
    3. (boundary) case-sensitivity — 'Food' vs 'food' produce distinct keys.
  - Existing coverage: `groupByCategory` group covers 1–2; case-sensitivity (3) not pinned.

- **`enum GroupSortOrder { newestFirst, oldestFirst, alphabetical }`** — ✅ Covered (exercised via `sortGroupKeys`).

- **`List<String> sortGroupKeys(Iterable<String> keys, GroupSortOrder order)`** — ✅ Covered
  - Returns a new sorted list; never mutates input.
  - Test cases:
    1. `newestFirst` → descending `yyyy-MM-dd`.
    2. `oldestFirst` → ascending.
    3. `alphabetical` → A→Z.
    4. Does not mutate the input iterable.
  - Existing coverage: `sortGroupKeys` group covers all four explicitly.

- **`String formatDateHeader(DateTime date)`** — 🟡 Partial
  - Returns `TODAY`/`YESTERDAY`/uppercased `EEEE, MMM d`. **Reads `DateHelper.today()` (wall clock)** — flaky around midnight.
  - Test cases:
    1. Today (any time component) → `TODAY`.
    2. Yesterday → `YESTERDAY`.
    3. Older date → uppercased weekday + month/day.
    4. (missing) run under `withClock(Clock.fixed(...))` to remove the midnight-rollover race in CI.
  - Existing coverage: `formatDateHeader` group covers 1–3 using live `DateHelper.today()`; no clock injection (4 is the durability gap).

- **`String formatDateHeaderWithMonth(DateTime date, {DateTime? now})`** — ✅ Covered
  - Same TODAY/YESTERDAY rule; appends year only for prior-year dates. `now` param is injectable (good).
  - Test cases:
    1. Today/Yesterday rules match `formatDateHeader`.
    2. Same-year date → no year shown.
    3. Prior-year date → year shown.
    4. (boundary) Dec-31 prior year vs Jan-1 current year with a fixed `now`.
  - Existing coverage: `formatDateHeaderWithMonth` group covers 1–3 with an injected `now`; the exact year-boundary (4) is close but not the literal Dec31/Jan1 pair.

---

### `lib/screens/history/history_list.dart`

- **`typedef ExpenseTileBuilder / IncomeTileBuilder / DatedExpenseTileBuilder / DatedIncomeTileBuilder`** — ✅ Covered (compile-time contracts, exercised through `HistoryList`).

- **`HistoryList(...)` (StatelessWidget, named ctor with 14 required fields)** — 🟡 Partial
  - Dispatches grouped (`_buildGrouped`) vs flat (`_buildFlat`) rendering based on `sortOrder`; hosts the `RefreshIndicator` + `ListView.builder`, the loading-more spinner, and the limit-reached tile.
  - Test cases:
    1. `sortOrder='newest'` → grouped-by-day with `formatDateHeader` headers (no month).
    2. `sortOrder='oldest'` → grouped, oldest-first key order.
    3. `sortOrder='category'` → grouped-by-category, alphabetical uppercased headers.
    4. `sortOrder='highest'/'lowest'` → flat list via `_buildFlat` (dated tile builders called with `showMonth`).
    5. `showMonth=true` + `isLoadingMore=true` → trailing `CircularProgressIndicator` appended.
    6. `showLimitMessage` true (`showMonth && !hasMoreData && totalLoaded>=maxTotalResults`) → "Result limit reached" tile renders the `maxTotalResults` count.
    7. `showMonth=false` → scroll controller NOT attached (only attached in all-time mode).
    8. Mixed Expense+Income items → `StaggeredListItem` wraps each, expense vs income builder dispatched correctly.
    9. (golden, D.3) grouped list snapshot under `withClock` fixed instant.
  - Existing coverage: only **indirectly** via `history_screen_test.dart` (which drives the whole `HistoryScreen`). `HistoryList` itself has **no dedicated test** — the grouped-vs-flat dispatch, limit tile, and loading-more spinner (cases 4–7) are untested in isolation. This is a worthwhile extract-and-unit-test gap because the builders are pure given the inputs.

- **`HistoryEmptyState(...)` (StatelessWidget)** — ❌ Missing
  - Renders the no-transactions placeholder; `hasFilters` swaps the copy and hides the Add-Expense/Add-Income buttons.
  - Test cases:
    1. `hasFilters=false` → "Get started…" copy + both Add buttons present; tapping fires `onAddExpense`/`onAddIncome`.
    2. `hasFilters=true` → "Try adjusting…" copy, NO Add buttons.
    3. Tap Add Expense / Add Income invokes the respective callback exactly once.
    4. (a11y) both `OutlinedButton.icon` targets ≥48dp.
  - Existing coverage: none. `HistoryScreen` builds its own inline empty state (`_buildEmptyState`) and does **not** appear to use `HistoryEmptyState`, so this public widget is entirely dead-of-test (verify it's still wired anywhere — possible dead code candidate).

---

### `lib/screens/history/history_filter_bar.dart`

- **`HistoryFilterBar(...)` (StatelessWidget)** — ❌ Missing
  - Pure-render filter strip: search `TextField` (+ clear button when `searchTerm` non-empty), all-time chip (with spinner when `isLoadingAllTime`), date-range chip (deletable when a range is set), sort chip, plus injected `categoryChips` / optional `paymentFilterChips`. All state lives in the parent.
  - Test cases:
    1. Renders search field with the "Search transactions…" hint and the search semantic label.
    2. `searchTerm` non-empty → clear (X) IconButton appears with "Clear search" semantics; tapping fires `onSearchCleared`.
    3. `searchTerm` empty → no clear button.
    4. Typing fires `onSearchChanged` on every keystroke (no debounce here — parent owns it).
    5. `searchAllTime=true` → all-time chip selected, semantic label "All time search enabled"; `isLoadingAllTime=true` → inline `CircularProgressIndicator` in the chip.
    6. `dateRange != null` → chip shows `formatDateRange(...)`, delete icon present, `onDateRangeCleared` fires on delete; null → "Date range" label, `onDateRangeRequested` on tap.
    7. `sortOrder != 'newest'` → sort chip shows selected + `sortLabelFor`/`sortIconFor` output.
    8. `paymentFilterChips` null vs supplied → trailing chip row appears only when supplied.
    9. (a11y) every chip carries a `button:true` Semantics label (M8/M10).
  - Existing coverage: none directly. `HistoryFilterBar` is rendered as part of `HistoryScreen` but `history_screen_test.dart` never asserts on the search box, clear button, or chips. This is a clean unit-test target (stateless, callback-driven).

---

### `lib/screens/history/history_screen.dart`

`HistoryScreen` is a 1,845-line stateful screen. Most pure logic (`_matchesSearch`, `_sortItems`, `_matchesPaymentStatus`, `_isInDateRange`, `_formatDateRange`) is **private** and only reachable through the widget; the grouping helpers were extracted to `history_grouping.dart` (well-tested). Public surface:

- **`HistoryScreen({super.key})`** — 🟡 Partial
  - Tabbed (All/Expenses/Income) transaction browser with search-debounce, all-time pagination, date-range, sort, category + payment-status filters, swipe-to-delete, and edit/pay affordances.
  - Test cases:
    1. Header "History" + 3-tab bar (All/Expenses/Income) render — ✅ covered.
    2. Empty state on fresh state — ✅ covered (loose `findsAtLeastNWidgets` on "No ").
    3. Seeded expenses surface their descriptions on All tab — ✅ covered.
    4. Tapping Income tab shows income, hides expenses; tab-switch resets `_filterCategory`/`_paymentStatusFilter`/`_searchTerm` — ✅ partly covered (filter/search reset on tab change NOT asserted).
    5. `state.expenses` (selected-month) vs `state.allExpenses` (cross-month) — ✅ covered.
    6. (missing) Search debounce: typing flips `_searchAllTime` on and triggers `_loadAllTimeData`; 300ms `_debounce` timer must be drained without leaking.
    7. (missing) Sort bottom-sheet (`_showSortOptions`) → choosing "Highest Amount" re-renders flat list with inline date labels.
    8. (missing) Payment-status chips only render on the Expenses tab (index==1); selecting "Unpaid" filters via `_matchesPaymentStatus` (Decimal-based, money-precision concern).
    9. (missing) Swipe-to-delete an expense (`Dismissible` endToStart) → `confirmDismiss` dialog → `appState.deleteExpense` → undo snackbar; all-time list locally removes the row first.
    10. (missing) Date-range > 730 days → "Date Range Too Large" dialog, range rejected.
    11. (missing) `_loadAllTimeData` race/cancellation: rapid tab switches enqueue `_cancelledRequestIds`; stale responses are dropped (re-entrancy concern — the file has extensive request-ID dedup logic that is entirely untested).
    12. (missing) Pagination: scrolling near `maxScrollExtent-200` calls `_loadMoreData`; `_maxTotalResults` (1000) cap flips `_hasMoreData=false` and renders the limit tile.
    13. (a11y) expense/income tiles expose the long Semantics label ("Expense: …, Tap to add payment, long press to edit, swipe left to delete").
    14. (golden, D.3) the All tab seeded list — requires `withClock` (relative-time strings in tiles).
  - Existing coverage: `history_screen_test.dart` covers 1–5 (5 widget tests). The entire concurrency/cancellation machinery (11), pagination (12), debounce (6), sort sheet (7), payment filter (8), swipe-delete (9), and date-range guard (10) are **untested** — these are the highest-value gaps in the layer because the cancellation/dedup code is genuinely error-prone.

- **`extension StringExtension on String`** (line 1839) — ❌ Missing
  - String helper (likely capitalize). Test cases: 1. typical word capitalized; 2. empty string no-throw; 3. already-capitalized idempotent. Existing coverage: none.

---

### `lib/screens/home_screen.dart`

- **`HomeScreen({super.key})`** — 🟡 Partial
  - Dashboard: glass header (settings avatar + brand + history search), month navigator (chevrons / picker / swipe / long-press today), financial summary card, optional upcoming-bills banner, optional quick-add bar, recent-transactions glass sheet or empty state.
  - Test cases:
    1. "FinanceFlow" brand label renders — ✅ covered.
    2. No FAB on Home — ✅ covered.
    3. Empty-state messaging + receipt icon when no expenses — ✅ covered.
    4. Seeded expenses render in Recent Transactions list — ✅ covered.
    5. Summary card Income/Expenses/Total derive from seeded `AppState` selectors — ✅ covered (asserts via `state.totalIncome` etc., not the AnimatedCounter text — deliberate to dodge animation frames).
    6. Header shows `selectedMonthName` — ✅ covered.
    7. "SEE ALL" TextButton wired — ✅ covered (presence only; navigation push NOT asserted).
    8. (missing) Horizontal swipe past `_swipeVelocityThreshold` (500) calls `goToPreviousMonth`/`goToNextMonth` + `HapticHelper.selectionClick`; below threshold does nothing.
    9. (missing) Month chevrons tap → prev/next; month label long-press → `goToToday`.
    10. (missing) `_showMonthPicker` bottom sheet: year arrows, current-month dot indicator (FIX #13), tapping a month → `goToMonth` + pop.
    11. (missing) Upcoming-bills banner renders only when `getUpcomingBillsThisMonth().isNotEmpty`; "Due today/tomorrow/Overdue/in N days" text branches; "+N more" when >3.
    12. (missing) Quick-add bar renders only when `quickTemplates` non-empty; tapping a chip calls `useTemplate` and shows the "added!" snackbar; income vs expense chip styling.
    13. (missing) Expense tile tap → `AddPaymentDialog`; long-press → `AddTransactionScreen` edit (navigation).
    14. (a11y) settings avatar "Open settings", search "Open transaction history", summary card live-region label, per-tile money label.
    15. (golden, D.3) seeded dashboard — REQUIRES `withClock` (tile relative-time) + the `AnimatedCounter`/`ScaleTransition` must be pumped to completion or frozen.
  - Existing coverage: `home_screen_test.dart` (9 tests) covers 1–7. Month navigation (8–10), bills banner branches (11), quick-add (12), and tile interactions (13) are gaps.

- **`_FinancialSummaryCard`, `_GlassHomeExpenseTile`, `_UpcomingBillsBanner`, `_QuickAddBar`** — private; covered only transitively through `HomeScreen`. The `_UpcomingBillsBanner` due-date text branches (today/tomorrow/overdue/+N) and `_QuickAddBar` snackbar are the most logic-dense and are untested.

---

### `lib/screens/add_transaction_screen.dart`

- **`enum TransactionType { expense, income }`** — ✅ Covered (drives the whole form; toggle tested).

- **`AddTransactionScreen({initialType, expense, income})`** — 🟡 Partial
  - Unified add/edit form with 3 `assert`s guarding the edit-mode invariants (at most one of expense/income; initialType must match the edited type).
  - Test cases:
    1. Renders GlassTopAppBar + segmented control + "Add Expense" save button — ✅ covered.
    2. Type toggle preserves amount + description controllers (R15) — ✅ covered.
    3. Income→Expense round-trip resets amount-paid to "0" (one-way clear) — ✅ covered.
    4. First-launch tooltip appears, dismisses on "Got it", persists dismissal in SharedPreferences — ✅ covered.
    5. Edit-mode hides segmented control, shows "Update Expense", suppresses tooltip, renders archived-category placeholder for a deleted category — ✅ covered.
    6. After `loadData()`, CategoryBentoGrid renders seeded expense categories — ✅ covered.
    7. Toggle to Income renders income categories — ✅ covered.
    8. `addExpense` end-to-end via the seeded bootstrap — ✅ covered (drives `state.addExpense` directly, NOT the Save button — deliberate dodge of the Navigator.pop dispose race).
    9. (missing) the **assert** guards: constructing with both `expense` + `income`, or `expense` with `initialType:income`, throws in debug.
    10. (missing) Amount validator boundaries: empty, non-numeric, `<=0`, `>999999999.99` → each error string (money-precision/boundary concern).
    11. (missing) Amount-paid validator: negative, `>total` → errors; income mode → validator returns null (skipped).
    12. (missing) `_save` happy path through the Save button: future-date confirmation dialog (`Validators.isFutureDate`), budget-warning dialog (`_checkBudgetWarning` exceed vs approaching-90% branches), category-not-selected snackbar, different-month "saved to <Month>" snackbar with switch action, vs same-month "added" snackbar. This is the richest untested logic — `_checkBudgetWarning`'s arithmetic (subtracts the edited expense's own amount before comparing) is a real correctness concern.
    13. (missing) `_save` re-entrancy: `_isSaving` guards double-submit; `setState` after pop guarded by `mounted` checks (async-gap mounted concern — the screen is dense with `if (!mounted) return`).
    14. (missing) Unsaved-changes `PopScope`: dirty form → "Discard changes?" dialog; clean form pops freely. `_isFormDirty` per-field diff (expense includes amount-paid + payment method; income excludes them).
    15. (missing) `_pickDate` clamps initialDate within min/max and re-confirms future dates; `_markFullyPaid` for an unpaid expense edits `amountPaid=amount`.
    16. (missing) `_showCreateCategoryDialog` / `_showCreateTagDialog` validators (empty, >50 chars, duplicate category).
    17. (missing) `_syncTags` diff add/remove against existing.
    18. (a11y) save button, delete IconButton tooltip, date InkWell.
    19. (golden, D.3) the form in expense vs income vs edit mode (no relative-time here, so `withClock` not strictly needed — but `DateFormat.yMMMMEEEEd()` on `_selectedDate` will float if the default date is "today"; seed a fixed `_selectedMonth` or wrap to stabilize).
  - Existing coverage: `add_transaction_screen_test.dart` (8 tests) covers 1–8 well. The entire `_save` decision tree (12), validators (10–11), budget-warning math (12), and PopScope dirty-guard (14) are gaps — by the author's own note, the Save-button path is dodged because Navigator.pop races dispose.

---

### `lib/screens/add_payment_dialog.dart`

- **`AddPaymentDialog({required Expense expense})`** — ❌ Missing
  - Records a partial/full payment against an expense; optional "Pay from Income" toggle (gated on available income); live-validates the amount against `remainingAmount` and available balance; disables the CTA with a reason label ("Insufficient Balance" / "Amount Too High").
  - Test cases:
    1. Renders header (description + category), PAID/TOTAL/Remaining figures, progress bar + "% paid".
    2. Fully-paid expense (`remaining==0`) → shows the "Fully Paid" panel, NO payment input, NO Add-Payment button.
    3. Amount validator: empty → "Enter amount"; `<=0` → "Enter valid amount"; `>remaining+0.001` → "Cannot exceed remaining" (the `0.001` float tolerance is a money-precision concern worth pinning).
    4. "Pay All" button fills the field with `remaining.toStringAsFixed(2)`.
    5. CTA disabled until `isPaymentValid` (>0, <=remaining, sufficient balance); label reflects the disabled reason.
    6. "Pay from Income" toggle only enabled when `availableIncome>0`; when on and amount>available → on submit shows the insufficient-balance snackbar and aborts.
    7. Happy path: valid amount → `appState.addPayment(expense, amount)` → pop; income-funded path shows "recorded from income" snackbar.
    8. Error path: `addPayment` throws → "Error recording payment" snackbar; `_isSaving` reset in finally.
    9. Re-entrancy: `_isSaving` disables CTA during the await.
    10. `CurrencyHelper.parseDecimal` handles comma vs dot decimal separators (locale concern).
  - Existing coverage: none. This dialog carries real money-arithmetic and async-error handling and is one of the highest-priority gaps. Note `addPayment` is testable at the AppState level, but the dialog's validation/disable-reason logic and income-balance guard are screen-only.

---

### `lib/screens/advanced_filter_dialog.dart`

- **`AdvancedFilterDialog({super.key})`** — ❌ Missing
  - Bottom-sheet with category dropdown, date-range picker, min/max amount fields, and paid-status ChoiceChips; Apply pushes filters into `AppState`, Clear All resets them. Reads `appState.filterCategory`/`dateRange` in `initState`.
  - Test cases:
    1. Pre-fills category + date range from `AppState` on open.
    2. Category dropdown lists "All" + `categoryNames`.
    3. Date-range InkWell → `showDateRangePicker`; selecting a range shows the formatted label + "Clear date range" button.
    4. Paid-status chips are mutually exclusive (All=null, Paid=true, Unpaid=false); re-tapping a selected chip clears to null.
    5. Apply with `_minAmount > _maxAmount` → "Min amount cannot be greater than max amount" snackbar, dialog stays open (cross-field validation — a real correctness case).
    6. Apply happy path → calls `setFilterCategory`/`setDateRange`/`setAmountRange`/`setPaidStatusFilter` then pops.
    7. Clear All → `appState.clearFilters()` + pop.
    8. Min/max parse via `parseDecimal` (comma/dot locale).
  - Existing coverage: none. The min>max guard (5) and the four AppState setter calls (6) are the load-bearing untested logic.

---

### `lib/screens/budget_screen.dart`

- **`BudgetScreen({super.key})`** — ✅ Covered
  - Glass app bar with month nav, monthly-summary card, per-category budget list (GlassProgressBar zones), add-budget FAB.
  - Test cases:
    1. GlassTopAppBar "Budgets" + chevron month nav — ✅.
    2. Empty state in GlassPanel ("No budgets for …") — ✅.
    3. Add-budget FAB present + tooltip — ✅.
    4. Under-budget 25% → green check_circle + "25%" raw semantics — ✅.
    5. At-100% → error icon + "100%" — ✅.
    6. Over-budget 130% → error icon + raw "130%" while bar clamps visually — ✅ (money/clamp boundary well-covered).
    7. Multiple budgets → one GlassPanel + GlassProgressBar per category, correct per-card icon zones — ✅.
    8. (missing) Month nav chevrons actually call `goToPreviousMonth`/`goToNextMonth` and re-render the month label; long-press → `goToToday`.
    9. (golden, D.3) seeded budget list — no relative-time, but the projected-balance row depends on "today"; safe to golden with a fixed seed month.
  - Existing coverage: `budget_screen_test.dart` (7 tests) covers the three color zones + composition thoroughly. Only the month-nav interaction (8) and golden (9) remain. **This is the best-covered hero screen.**

- **`static void BudgetScreen.showAddBudget(BuildContext)`** — ❌ Missing
  - Opens the add-budget bottom sheet (`_AddBudgetDialog`). Test cases: 1. sheet opens on FAB tap; 2. category + amount validation; 3. `setBudget` called on save. Existing coverage: none (FAB presence tested, but tapping it / the dialog flow is not).

---

### `lib/screens/wallet_screen.dart`

- **`WalletScreen({super.key})`** — ✅ Covered
  - Account list with active badge + default subtitle, add-account FAB, deleted-accounts trash section (`_DeletedAccountsSection` loads `getDeletedAccounts()` in initState — DB-close race noted; tearDown intentionally skips `resetForTesting`).
  - Test cases:
    1. GlassTopAppBar "Wallet" with no BackButton — ✅.
    2. Add-account FAB present — ✅.
    3. Multiple accounts render; exactly one "Active" badge; default subtitle visible — ✅.
    4. Each account row wrapped in GlassPanel — ✅.
    5. Soft-deleted account absent from the active ListView — ✅.
    6. (missing) `_AddAccountDialog` flow: name validation, `addAccount` called, new row appears.
    7. (missing) Switching the active account (tap a non-active row) → `setCurrentAccount`, badge moves.
    8. (missing) `_DeletedAccountsSection`: a soft-deleted account surfaces in the trash section and can be restored.
    9. (golden, D.3) multi-account list.
  - Existing coverage: `wallet_screen_test.dart` (5 tests) covers composition + multi-account + soft-delete invariant. Add/switch/restore flows (6–8) are gaps.

---

### `lib/screens/analytics_screen.dart`

- **`AnalyticsScreen({super.key})`** — 🟡 Partial — **RESURRECTED, verify stability**
  - Five hero panels: `_MonthOverMonthInsights`, `_SpendingTrendsChart` (StatefulWidget with an 800ms AnimationController + `_loadTrends` future), `_SpendingChart`, `_BudgetProgress`, `_CategoryBreakdown`.
  - **Ticker-leak status**: the test file's docstring confirms this was deferred to D.2 because chart `AnimationController` tickers leak under `pumpAndSettle`. The resurrection's `pumpAndDrain` fakes elapsed time via `tester.runAsync(() => Future.delayed(1500ms))` (real wall clock to let `_loadTrends().forward(from:0)` settle) then `pump(800ms)` — **never** `pumpAndSettle`. This is the stability mechanism. Confirm the 2 tests still pass without "A Timer is still pending" / "AnimationController was not disposed" errors on the current branch (run `flutter test test/screens/analytics_screen_test.dart`). If the chart animation duration changed, the 1500ms drain must be re-tuned.
  - Test cases:
    1. GlassTopAppBar "Analytics" without BackButton — ✅.
    2. Seeded spending surfaces "TOP CATEGORIES" + category labels (`_CategoryBreakdown` returns `SizedBox.shrink()` until spending exists) — ✅.
    3. Hero GlassPanel cards render once seeded (lower-bound `findsAtLeastNWidgets(1)`) — ✅ (loose; exact 5-panel count not pinned because viewport height fluctuates).
    4. (missing) `_SpendingTrendsChart` month-over-month line: `_loadTrends` populates and the chart animates; an empty-data state.
    5. (missing) `_BudgetProgress` panel reflects seeded budgets.
    6. (missing) `_MonthOverMonthInsights` up/down delta vs previous month (sign + percentage).
    7. (missing) Empty analytics (no expenses) → which panels collapse to `SizedBox.shrink` vs show an empty message.
    8. (golden, D.3) — **hard**: chart tickers must be frozen at a fixed frame AND `withClock` fixed (trends are month-relative). Treat as a known-hard golden.
  - Existing coverage: `analytics_screen_test.dart` (3 tests, resurrected). The chart-specific behaviour (4–6) and empty state (7) are gaps. The resurrection is structurally sound but should be smoke-run to confirm no ticker leak regressed.

---

### `lib/screens/settings_screen.dart`

- **`SettingsScreen({super.key})`** — 🟡 Partial
  - Eight Luminous sections (Accounts/Appearance/Security/Preferences/Insights/Data & Backup/Notifications/Advanced); async PIN-state load in initState; PIN section (`_PinSecuritySection`) reflects enabled/disabled; transaction-color intensity tile; footer.
  - Test cases:
    1. GlassTopAppBar "Settings & Security" — ✅.
    2. All eight section headings render exactly once — ✅.
    3. PIN disabled → "Lock app with PIN", switch off, no "Change PIN" — ✅ (uses a full secure-storage backing-map mock).
    4. PIN enabled (seeded secure keys) → "Enabled (4 digits)", "Change PIN", auto-lock subtitle, switch on — ✅.
    5. "FinanceFlow / Made by Leo Atienza" footer — ✅.
    6. Current Account tile shows seeded default account name — ✅.
    7. Currency tile shows "US Dollar ($)" / `currencyCode=='USD'` — ✅.
    8. Recurring Expenses entry-point label present — ✅.
    9. (missing) Theme picker dialog → `setThemeMode`; currency picker → `setCurrency`; account picker → `setCurrentAccount` (the dialogs the docstring explicitly defers).
    10. (missing) PIN switch toggle → navigates to `PinSetupScreen` / disables PIN (security flow).
    11. (missing) `_ColorIntensityTile` slider drives `setTransactionColorIntensity`; "Transaction Colors" switch toggles `setShowTransactionColors`.
    12. (missing) Navigation pushes for each Advanced/Data tile (Crash Log, Backup, Export, Trash, Categories, Notifications).
    13. (a11y) each `GlassListTile` icon + switch labeled.
  - Existing coverage: `settings_screen_test.dart` (8 tests) covers composition + PIN states + seeded header tiles. The interactive flows (9–12) are gaps; the dialog helpers are noted as tested elsewhere (not in this file).

- **`_ColorIntensityTile`, `_PinSecuritySection`** — private; only the PIN section's display state is tested (via parent). The slider and the PIN navigation are untested.

---

### `lib/screens/notification_settings_screen.dart`

- **`NotificationSettingsScreen({super.key})`** — 🟡 Partial — **RESURRECTED, verify stability**
  - ALERTS toggles (Bill Reminders / Budget Alerts / Monthly Summary), REMINDER TIME picker, TEST section, EXAMPLES.
  - **Late-final platform status**: the docstring confirms this was deferred because `FlutterLocalNotificationsPlatform.instance` is a `late final` static that throws `LateInitializationError` the first time the screen queries permissions in initState. The resurrection sets `FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform()` (using `MockPlatformInterfaceMixin` to bypass token verification) **once at the top of `main()`** before any pump, and stubs every method the screen touches (`cancelAll`, `pendingNotificationRequests`, `getActiveNotifications`, `show`, `periodicallyShow*`). Confirm: (a) the static assignment is process-global so it doesn't fight other suites — the docstring claims re-registration is tolerated; (b) the 3 tests pass on the current branch (`flutter test test/screens/notification_settings_screen_test.dart`). If a new screen code path calls an un-stubbed platform method, add the override to `_FakeNotificationsPlatform`.
  - Test cases:
    1. GlassTopAppBar "Notifications" with BackButton — ✅.
    2. ALERTS / REMINDER TIME / TEST / EXAMPLES headings — ✅.
    3. Bill / Budget / Monthly toggle labels — ✅.
    4. (missing) Toggling a switch persists the preference (SharedPreferences) and schedules/cancels via the notification service.
    5. (missing) Reminder-time picker updates the displayed time and reschedules.
    6. (missing) "Send test notification" button calls `show`.
    7. (missing) `_ExampleNotification` preview rows render.
  - Existing coverage: `notification_settings_screen_test.dart` (3 tests, resurrected). Toggle persistence + scheduling (4–6) are gaps. Resurrection is structurally sound; smoke-run to confirm no late-init regression.

- **`_ExampleNotification`** — private preview widget; untested.

---

### `lib/screens/recurring_items_screen.dart`

- **`RecurringItemsScreen({super.key, this.initialType = 'expense'})`** — ✅ Covered
  - Merged expense/income recurring manager; GlassSegmentedControl swaps `RecurringExpensesView`/`RecurringIncomeView`; FAB opens the matching add dialog.
  - Test cases:
    1. GlassTopAppBar "Recurring Items" + GlassSegmentedControl + FAB — ✅.
    2. `initialType:'expense'` → expense empty state; `'income'` → income empty state — ✅ (both).
    3. Tapping Income segment swaps the visible empty state — ✅.
    4. Seeded recurring expenses show on Expenses tab — ✅.
    5. Seeded recurring income shows on Income tab — ✅.
    6. Segment toggle preserves seeded data across both views (round-trip) — ✅.
    7. (missing) FAB on Expenses tab → `showAddRecurringExpenseDialog`; on Income tab → `showAddRecurringIncomeDialog`.
    8. (golden, D.3) seeded list.
  - Existing coverage: `recurring_items_screen_test.dart` (7 tests) covers composition + both seeded views + toggle persistence thoroughly. Only the FAB→dialog dispatch (7) is a gap.

---

### `lib/screens/recurring/recurring_expenses_view.dart`

- **`void showAddRecurringExpenseDialog(BuildContext context)`** — ❌ Missing
  - Top-level function opening the add-recurring-expense bottom sheet. Test cases: 1. sheet opens; 2. validation (amount/category/day-of-month 1–31); 3. `addRecurringExpense` called. Existing coverage: none.

- **`RecurringExpensesView({super.key})`** — 🟡 Partial
  - List of recurring expenses (embedded inside `RecurringItemsScreen`), empty state, per-item edit/delete + day-of-month label.
  - Test cases:
    1. Empty state "No recurring expenses" — ✅ (via `RecurringItemsScreen` tests).
    2. Seeded items render description + amount — ✅ (via parent: Netflix/Rent).
    3. (missing) Per-item delete → `deleteRecurringExpense` + confirmation; edit opens `_AddRecurringDialog` prefilled.
    4. (missing) Day-of-month / next-run formatting (date concern).
    5. (a11y) per-item action buttons labeled.
  - Existing coverage: parent screen tests cover render only; the view's own delete/edit affordances are untested.

---

### `lib/screens/recurring/recurring_income_view.dart`

- **`void showAddRecurringIncomeDialog(BuildContext context)`** — ❌ Missing
  - Add-recurring-income bottom sheet. Test cases: 1. opens; 2. validation; 3. `addRecurringIncome` called. Existing coverage: none.

- **`RecurringIncomeView({super.key})`** — 🟡 Partial
  - Mirror of the expenses view for income.
  - Test cases: 1. empty state "No recurring income" — ✅ (via parent); 2. seeded item renders — ✅ (Paycheck/Freelance); 3. (missing) delete/edit affordances; 4. (missing) day-of-month formatting. Existing coverage: render-only via parent tests.

---

### `lib/screens/category_manager_screen.dart`

- **`CategoryManagerScreen({super.key})`** — 🟡 Partial
  - GlassTopAppBar "Categories", expense/income category list, add-category FAB, per-tile edit/delete, icon picker, type chips.
  - Test cases:
    1. GlassTopAppBar "Categories" + BackButton — ✅.
    2. Empty state "No categories" in GlassPanel — ✅.
    3. Add-Category FAB present — ✅.
    4. (missing) Seeded categories render as `_CategoryTileRow`s split by expense/income (default vs custom tile state — the docstring punts this to AppState integration tests).
    5. (missing) `_AddCategoryDialog`: name validator (empty / >50 / duplicate per type), `_IconPicker` selection, `_TypeChip` expense/income toggle, `addCategory` on save.
    6. (missing) `_DeleteCategoryDialog`: deleting a category with existing transactions warns / reassigns; `deleteCategory` called.
    7. (a11y) FAB + per-tile delete labeled.
  - Existing coverage: `category_manager_screen_test.dart` (3 tests) — composition smoke only (the docstring is explicit that per-tile state is deferred). The add/delete dialogs (5–6) carry the validation logic and are the gaps.

---

### `lib/screens/export_data_screen.dart`

- **`ExportDataScreen({super.key})`** — 🟡 Partial
  - Data-type selector (All/Expenses/Income), 5 date-range pills (GlassPillChip), CSV + PDF export buttons.
  - Test cases:
    1. GlassTopAppBar "Export Data" + BackButton — ✅.
    2. Info banner in GlassPanel — ✅.
    3. Three export-type options render — ✅.
    4. Five date-range GlassPillChips (All Time/This Month/Last Month/This Year/Custom Range) — ✅.
    5. Export to CSV + PDF buttons render — ✅.
    6. (missing) Selecting a data type + range then Export CSV → calls the CSV export util with the right filter; "Custom Range" opens a date-range picker.
    7. (missing) Export PDF path; success/error snackbars; empty-data guard.
    8. (missing) Share-sheet invocation (`share_plus`).
  - Existing coverage: `export_data_screen_test.dart` (5 tests) — composition smoke. The actual export invocation + custom-range picker (6–7) are gaps.

- **`_SectionHeader`** — private; trivial.

---

### `lib/screens/backup_restore_screen.dart`

- **`BackupRestoreScreen({super.key})`** — 🟡 Partial
  - Save / Share / Choose-Backup-File CTAs; `_loadBackups()` reads app-support dir in initState; encrypted-envelope passphrase dialogs (per MEMORY: two-field confirm on save, single-field retry on restore).
  - Test cases:
    1. GlassTopAppBar "Backup & Restore" + BackButton — ✅.
    2. Save Backup / Share Backup / Choose Backup File CTAs render — ✅.
    3. (missing) Save → two-field passphrase dialog with min-6-char validation → `BackupHelper.saveBackupToUserSelectedLocation` with the passphrase contract.
    4. (missing) Restore an encrypted envelope → single-field retry-loop dialog; wrong passphrase re-prompts; legacy v2/v3 plaintext restores without prompting (`BackupCrypto.isEncryptedEnvelope` gate).
    5. (missing) `_loadBackups` lists existing backups (`_BackupTile` rows) with size/date; empty → empty copy.
    6. (missing) Restore success → app reloads data; error snackbars.
    7. (a11y) CTAs labeled.
  - Existing coverage: `backup_restore_screen_test.dart` (2 tests) — composition smoke only. The passphrase dialogs + encryption branches (3–4) are security-relevant gaps (the crypto itself is tested at the helper level per MEMORY, but the screen's dialog UX is not).

- **`_SectionCard`, `_BackupTile`** — private; the `_BackupTile` (size/date formatting) is untested.

---

### `lib/screens/quick_templates_screen.dart`

- **`QuickTemplatesScreen({super.key})`** — 🟡 Partial
  - Template grid/list, add-template FAB, empty state, per-card use/edit/delete.
  - Test cases:
    1. GlassTopAppBar "Quick Templates" + BackButton — ✅.
    2. Add-Template FAB present + labeled — ✅.
    3. Empty state "No templates yet" in GlassPanel — ✅.
    4. (missing) Seeded templates render as `_TemplateCard`s (name/amount/type).
    5. (missing) `_AddTemplateDialog`: name/amount/type/category validation → `addQuickTemplate`.
    6. (missing) Tapping a card's "use" → `useTemplate` + snackbar; edit/delete affordances.
    7. (a11y) FAB + per-card actions.
  - Existing coverage: `quick_templates_screen_test.dart` (3 tests) — composition smoke. Seeded cards + add/use/delete (4–6) are gaps.

- **`_EmptyTemplates`, `_TemplateCard`** — private; the card's use/edit/delete logic is untested.

---

### `lib/screens/trash_screen.dart`

- **`TrashScreen({super.key})`** — 🟡 Partial
  - Tabbed (expenses/income) soft-deleted-item viewer; restore / permanent-delete / empty-trash dialog; empty-trash IconButton only when items exist.
  - Test cases:
    1. GlassTopAppBar "Trash" + BackButton — ✅.
    2. Empty-trash IconButton absent when no items — ✅.
    3. (missing) Seeded soft-deleted expenses/income render per tab; tab swap filters.
    4. (missing) Restore an item → `restoreExpense`/`restoreIncome` → row leaves trash, snackbar.
    5. (missing) Permanent delete → confirm dialog → `permanentlyDelete*` (irreversible — money/data concern).
    6. (missing) Empty-trash IconButton present when items exist → `_EmptyTrashConfirmDialog` (typed/held confirmation) → clears all.
    7. (a11y) restore/delete buttons labeled.
  - Existing coverage: `trash_screen_test.dart` (2 tests) — composition + empty-state IconButton absence only (the docstring defers per-item state to "D.6 hero tests" which don't exist yet). Restore/permanent-delete/empty-all (3–6) are the data-integrity gaps.

- **`_EmptyTrashConfirmDialog`** — private; the destructive-confirmation gate is untested.

---

### `lib/screens/crash_log_screen.dart` — NO TEST FILE

- **`CrashLogScreen({super.key})`** — ❌ Missing
  - Reads `CrashLog.readAll()` in initState (FutureBuilder), shows selectable text, share via `SharePlus`, clear via confirm dialog. Empty → `_EmptyCrashLog`.
  - Test cases:
    1. GlassTopAppBar renders + back button; FutureBuilder shows the log text once `readAll` resolves.
    2. Empty log → `_EmptyCrashLog` placeholder (no share/clear active).
    3. Share with non-empty content → `SharePlus.instance.share(ShareParams(...))` invoked; empty content → share is a no-op (guard `content.trim().isEmpty`).
    4. Clear → "Clear crash log?" dialog → confirm → `CrashLog.clear()` (or equivalent) + `_refresh()` re-reads; cancel → no-op.
    5. PII-redaction is at the `CrashLog` util level (per MEMORY 6.6 regex set) — verify the screen displays already-redacted text (don't re-test redaction here).
    6. (a11y) share + clear icon buttons labeled.
  - Existing coverage: none. The share-empty guard and the clear-confirm-then-refresh flow are the logic worth pinning. The screen mocks needed: `share_plus` channel + path_provider (for `CrashLog` file IO).

- **`_EmptyCrashLog`** — private; trivial placeholder.

---

### `lib/screens/pin_unlock_screen.dart` — NO TEST FILE

- **`PinUnlockScreen({super.key})`** — ❌ Missing
  - PIN entry with rate-limiting: `_remainingAttempts`, `_lockoutSeconds` countdown (`Timer.periodic`), error messaging; delegates to `PinSecurityHelper`.
  - Test cases:
    1. Renders PIN dots + keypad; entering the correct PIN (mock `PinSecurityHelper.verifyPin`→true) → unlocks (pops / navigates).
    2. Wrong PIN → decrements attempts, clears entry, haptic feedback, error message.
    3. Lockout: hitting the attempt limit starts `_startLockoutCountdown` — "Too many attempts. Try again in N seconds." text ticks down each second.
    4. (timer concern) `_lockoutTimer` is cancelled in dispose — no pending-timer leak (must drive with bounded `pump(Duration(seconds:1))` increments, not `pumpAndSettle`).
    5. (async-gap) `mounted` guard inside the periodic callback (the code cancels the timer if `!mounted`).
    6. (security) verify PIN comparison goes through the constant-time helper, not a raw string compare (assert at helper level; screen just wires it).
    7. (a11y) keypad digits labeled.
  - Existing coverage: none. The lockout countdown timer (3–4) is the tricky, test-worthy logic and a leak risk. `test/utils/pin_lockout_test.dart` covers the *helper*; the *screen's* timer/UI is untested.

---

### `lib/screens/pin_setup_screen.dart` — NO TEST FILE

- **`PinSetupScreen({super.key, this.isChangingPin = false, this.oldPin})`** — ❌ Missing
  - Two-phase entry (enter → confirm); `isChangingPin` re-titles to "Change PIN" and requires `oldPin`; toggles `SecureWindow`/FLAG_SECURE.
  - Test cases:
    1. Set-up mode: title "Set Up PIN"; entering `_firstPin` flips to confirm mode; matching confirm → `PinSecurityHelper.setPin` + success/pop.
    2. Mismatched confirm → error, resets to first-entry.
    3. Change mode (`isChangingPin:true`, `oldPin` supplied): title "Change PIN"; flow validates against `oldPin`.
    4. PIN length toggle (4 vs 6 digits) adjusts `_pinLength` and the dot count.
    5. (security) calls `setSecure(true)` while on this screen (FLAG_SECURE) and restores on exit — mock `MethodChannel('budget_tracker/secure_window')`.
    6. (a11y) keypad + length toggle labeled.
  - Existing coverage: none. The enter→confirm→mismatch state machine (1–2) is the core untested logic.

---

### `lib/screens/onboarding_screen.dart` — NO TEST FILE

- **`OnboardingScreen({super.key})`** — ❌ Missing
  - PageView slides in GlassPanels; "Get Started" → `_completeOnboarding` (marks `OnboardingService` + `pushReplacementNamed('/home')`); optional `_loadSampleData`.
  - Test cases:
    1. Renders the first slide; swiping advances `_currentPage` + page indicators.
    2. Final slide CTA → `_completeOnboarding` → `OnboardingService().completeOnboarding()` called + navigates to `/home` (mock a `/home` route).
    3. `_loadSampleData` seeds demo data into AppState then completes.
    4. (async-gap) `mounted` guard before `pushReplacementNamed`.
    5. `_pageController` disposed (no leak).
    6. (a11y) Skip / Next / Get Started buttons labeled.
  - Existing coverage: none. The completion + navigation (2) and sample-data seeding (3) are the gaps. Requires a `MaterialApp` with a `/home` named route in the harness.

---

#### Coverage summary

~38 public functions/widgets across the layer (10 pure functions/enums in `history_grouping.dart` + ~28 public screen/dialog/view classes & top-level dialog functions). Tally: **9 ✅** (`groupByDay`, `groupByCategory`, `sortGroupKeys`, `GroupSortOrder`, `formatDateHeaderWithMonth`, `BudgetScreen`, `WalletScreen`, `RecurringItemsScreen`, `itemDate`), **15 🟡** (`itemCategory`, `formatDateHeader`, `HistoryList`, `HistoryScreen`, `HomeScreen`, `AddTransactionScreen`, `AnalyticsScreen`, `SettingsScreen`, `NotificationSettingsScreen`, `RecurringExpensesView`, `RecurringIncomeView`, `CategoryManagerScreen`, `ExportDataScreen`, `BackupRestoreScreen`, `QuickTemplatesScreen`, `TrashScreen` — note several are render-only smoke), **14 ❌** (`HistoryEmptyState`, `HistoryFilterBar`, `StringExtension`, `AddPaymentDialog`, `AdvancedFilterDialog`, `BudgetScreen.showAddBudget`, `showAddRecurringExpenseDialog`, `showAddRecurringIncomeDialog`, `CrashLogScreen`, `PinUnlockScreen`, `PinSetupScreen`, `OnboardingScreen`, plus the two un-asserted `ArgumentError` throws).

Highest-priority gaps:
1. **`HistoryScreen` concurrency/cancellation + pagination + debounce** — the request-ID dedup, `_maxTotalResults` cap, and 300ms debounce are genuinely error-prone and entirely untested (re-entrancy/race correctness).
2. **`AddPaymentDialog`** — money arithmetic (`remaining + 0.001` tolerance, income-balance guard) and async error handling, no test at all.
3. **`AddTransactionScreen._save` decision tree + `_checkBudgetWarning`** — the budget exceed/approaching math (subtracts the edited expense's own amount) and the multi-branch save snackbars are untested; the Save-button path is deliberately dodged.
4. **`HistoryFilterBar` + `HistoryEmptyState`** — pure, callback-driven, trivially unit-testable, currently zero direct coverage (and `HistoryEmptyState` may be dead code — confirm wiring).
5. **PIN screens (`PinUnlockScreen` lockout timer, `PinSetupScreen` enter/confirm state machine) + `OnboardingScreen` completion-nav** — no test files exist; the lockout `Timer.periodic` is also a leak risk.
6. **Stage D.3 golden tests** — none exist; home/history/analytics goldens MUST be wrapped in `withClock(Clock.fixed(...))` to defuse `DateHelper.getRelativeTime` flakiness, and analytics goldens additionally need frozen chart tickers.
7. **Accessibility (M8–M12)** — no screen asserts 48dp tap targets, `textScaler` reflow, or exhaustive icon-button semantic labels anywhere in the layer.
8. **Verify the two resurrected suites are stable** — `analytics_screen_test.dart` (chart ticker leak, drained via real-clock `runAsync` + bounded pump) and `notification_settings_screen_test.dart` (`FlutterLocalNotificationsPlatform.instance` late-final populated via `_FakeNotificationsPlatform` at `main()` top). Both are structurally sound; smoke-run each to confirm no pending-timer / late-init regression on the current branch.


## Reusable Widgets (lib/widgets/, premium_animations)

### `lib/widgets/accessible_button.dart`

- **`AccessibleButton({required String label, required VoidCallback onPressed, IconData? icon, bool isPrimary=false, bool isDestructive=false})`** — ✅ Covered
  - Stateless button: `FilledButton.icon` when `isPrimary`, else `OutlinedButton.icon`; red theming when `isDestructive`; wrapped in `Semantics(label, button:true, enabled:true)`; 48dp min touch target.
  - Test cases:
    1. Renders label text — pump, `expect(find.text('Save'), findsOneWidget)`.
    2. `isPrimary=false` → OutlinedButton (no FilledButton); `isPrimary=true` → FilledButton (predicate finder, since `.icon` returns private subclass).
    3. `isDestructive + isPrimary` → backgroundColor resolves to `Colors.red`; `isDestructive` outlined → foregroundColor/side red.
    4. `onPressed` fires once on tap.
    5. `icon` renders when provided; absent icon → `SizedBox.shrink` (no Icon) — MISSING explicit "no icon" assertion (currently only "icon renders").
    6. Meets 48dp min height via `tester.getSize`.
    7. Semantics exposes label + button:true.
    8. Boundary: very long label ellipsis/overflow behavior — MISSING (label is unconstrained `Text`, no maxLines; could overflow — note).
  - Existing coverage: `test/widgets/accessible_button_test.dart` covers label, primary/outlined variant switch, destructive red (both variants), onPressed, icon-present, 48dp, Semantics. Adequate.

- **`AccessibleIconButton({required IconData icon, required String label, required VoidCallback onPressed, Color? color, double size=24.0})`** — ✅ Covered
  - Icon button with `tooltip=label`, `Semantics(label, button:true)`, 48dp min constraints.
  - Test cases:
    1. Renders the icon.
    2. `onPressed` fires once on tap.
    3. `tooltip == label`.
    4. Meets 48dp min width AND height.
    5. Edge: custom `color` applied to IconButton — MISSING (minor).
    6. Edge: custom `size` reflected on inner Icon — MISSING (minor).
  - Existing coverage: `test/widgets/accessible_button_test.dart` covers icon render, onPressed, tooltip, 48dp. color/size props untested but low risk.

#### File summary: 2 public classes, both ✅.

### `lib/widgets/category_tile.dart`

- **`CategoryColors` (private ctor `._()`) — static maps `expenseColors`, `incomeColors`**  — ✅ Covered
  - Const color lookup maps keyed by category name.
  - Test cases:
    1. Map contains expected entries (implicitly via getDefaultColor tests).
    2. "Other" key present in both maps with different colors.
  - Existing coverage: exercised indirectly through `getDefaultColor` tests.

- **`CategoryColors.getDefaultColor(String categoryName, String categoryType) → Color`** — ✅ Covered
  - Routes to income vs expense map; falls back to green (income) / red (expense) for unknown names.
  - Test cases:
    1. Known expense name → mapped color (Food/Transport/Health).
    2. Known income name → mapped color (Salary/Investment).
    3. Unknown expense → `0xFFEF4444`; unknown income → `0xFF10B981`.
    4. "Other" routes differently per type (proves type arg matters).
    5. Edge: empty `categoryName` → falls to default — MISSING (minor, same code path as unknown).
  - Existing coverage: `test/widgets/category_tile_test.dart` group `CategoryColors.getDefaultColor` covers 1-4. Adequate.

- **`CategoryTile({required String categoryName, required String categoryType, String? color, String? icon, double size=44, double borderRadius=12, double iconScale=0.5})`** — 🟡 Partial
  - Stateless visual tile: gradient bg + border + shadow from base color (parsed hex OR default), icon from `CategoryIcons`; dark mode brightens icon via HSL lightness clamp.
  - Test cases:
    1. Renders at given `size` (width/height) — covered.
    2. Renders exactly one Icon — covered.
    3. Builds under light AND dark without throwing — covered.
    4. `color=null` and `color=''` both fall back to default — covered.
    5. `iconScale` → `Icon.size == size*iconScale` — covered.
    6. Valid hex `color` (e.g. '#3B82F6') drives base color (gradient/border use parsed color, not default) — MISSING (no assertion that a provided color actually changes the rendered gradient vs default).
    7. Domain/boundary: malformed hex `color` ('zzz') → `parseColor` returns transparent → tile still renders (no throw) — MISSING.
    8. Dark-mode HSL lightness clamp at extremes (near-white base → lightness clamps to 1.0, no overflow) — MISSING (called out in test as "golden-test territory").
  - Existing coverage: `test/widgets/category_tile_test.dart` group `CategoryTile` covers size, icon count, both themes, null/empty color fallback, iconScale. Missing: explicit custom-color path + malformed-hex resilience.

- **`CategoryTileSmall({required categoryName, required categoryType, String? color, String? icon})`** — ✅ Covered
  - Delegates to `CategoryTile(size:36, borderRadius:10)`.
  - Test cases:
    1. Renders at 36x36.
    2. Edge: passes color/icon through — MISSING (minor; pure delegation).
  - Existing coverage: `category_tile_test.dart` asserts 36x36.

- **`CategoryTileLarge({required categoryName, required categoryType, String? color, String? icon})`** — ✅ Covered
  - Delegates to `CategoryTile(size:56, borderRadius:14)`.
  - Test cases:
    1. Renders at 56x56.
  - Existing coverage: `category_tile_test.dart` asserts 56x56.

#### File summary: 5 public items; 4 ✅, 1 🟡 (CategoryTile custom-color + malformed-hex paths).

### `lib/widgets/color_picker.dart`

- **`ColorPicker({String? selectedColor, required Function(String?) onColorSelected})`** — 🟡 Partial
  - Bottom-sheet body: grab handle, title, 16-swatch `Wrap` (incl. a null "no color" option). Tapping a swatch calls `onColorSelected(color)` THEN `Navigator.pop(context)`. Selected swatch gets a primary 3px border + check icon; null gets block icon.
  - Test cases:
    1. Renders title 'Choose Color' + all 16 swatches — MISSING.
    2. Tapping a swatch fires `onColorSelected` with that hex AND pops the sheet — MISSING (the pop-after-callback is the load-bearing behavior; needs a `Navigator` + route so `pop` has something to pop, else it throws).
    3. Tapping the null swatch fires `onColorSelected(null)` — MISSING.
    4. `selectedColor` matching a swatch → that swatch shows check icon + 3px primary border; others 1px — MISSING (selected/unselected state visual).
    5. Null option always shows `Icons.block` regardless of selection — MISSING.
    6. Boundary: `selectedColor` not in palette → no swatch shows selected state, still renders — MISSING.
    7. Dark vs light: surface/onSurface colors switch — MISSING.
    8. Re-entrancy: double-tap a swatch — second tap fires on an already-popped sheet (callback + pop on unmounted) — MISSING (note: `Navigator.pop` after first tap removes the sheet; guard concern).
  - Existing coverage: `test/widgets/color_picker_test.dart` covers ONLY the static `parseColor`. The widget `build`, onTap/onColorSelected callbacks, Navigator.pop, and selected/unselected rendering are entirely UNTESTED.

- **`ColorPicker.parseColor(String? hex) → Color`** (static) — ✅ Covered
  - Parses `#RRGGBB` → opaque Color; null/empty/invalid → `Colors.transparent`. Forces 0xFF alpha.
  - Test cases:
    1. null → transparent; '' → transparent.
    2. Valid hex (#4CAF50, #EF4444, #3B82F6, #000000, #FFFFFF) → exact Color.
    3. Lowercase hex parses.
    4. 'invalid' / '#ZZZZZZ' / '#' → transparent (catch branch).
    5. No-`#` string ('4CAF50') → substring(1) quirk parses to a NON-transparent (documented-wrong) color.
    6. Always full opacity (alpha==255).
    7. All palette entries parse non-transparent; null palette entry → transparent.
  - Existing coverage: `color_picker_test.dart` group `parseColor()` — exhaustive on the static method. Adequate.

#### File summary: 2 public items; 1 ✅ (parseColor), 1 🟡 (the ColorPicker widget build/callbacks/Navigator.pop are a real gap).

### `lib/widgets/loading_skeleton.dart`

- **`LoadingSkeleton({double? width, double height=16, double borderRadius=8})`** — ✅ Covered
  - Stateful shimmer: 1500ms `repeat()` controller drives a moving linear gradient; grey base/highlight differs dark vs light.
  - Test cases:
    1. Renders at configured height; accepts width when given — covered.
    2. Animation loop runs several frames + disposes cleanly when removed from tree (no pending-timer leak) — covered.
    3. Dark vs light builds without throwing — covered.
    4. Boundary: `width=null` (intrinsic/unbounded) inside Expanded/Row — implicitly covered by other widgets; explicit unbounded-no-width render — partially covered.
  - Existing coverage: `test/widgets/loading_skeleton_test.dart` covers height, width, repeat+dispose, dark/light. Adequate (repeat-controller dispose is the key risk and it's tested).

- **`TransactionListSkeleton({int itemCount=5})`** — ✅ Covered
  - Non-scrolling shrinkWrap ListView of Card placeholders (4 skeletons each).
  - Test cases:
    1. Default → 5 Cards; `itemCount:3` → 3 Cards — covered.
    2. Dark mode renders — covered.
    3. Boundary: `itemCount:0` → no cards, no throw — MISSING (minor).
  - Existing coverage: `loading_skeleton_test.dart` group `TransactionListSkeleton` covers default count, custom count, dark mode.

- **`BudgetCardSkeleton()`** — ✅ Covered
  - Single Card with title + progress + 2 label skeletons.
  - Test cases:
    1. Renders a single Card.
    2. Contains ≥4 LoadingSkeleton placeholders.
  - Existing coverage: `loading_skeleton_test.dart` group `BudgetCardSkeleton`. Adequate.

#### File summary: 3 public classes, all ✅.

### `lib/widgets/luminous/glass_panel.dart`

- **`GlassPanel({required Widget child, EdgeInsetsGeometry padding=glassPadding, double borderRadius=radiusCard, List<BoxShadow>? boxShadow})`** — 🟡 Partial
  - Frosted panel: `ClipRRect` → `BackdropFilter(blur sigma)` → `DecoratedBox` (fill + 1px border + default soft shadow). Fill/border swap dark vs light.
  - Test cases:
    1. Renders child without throwing (light + dark) — INDIRECTLY covered (used inside GlassListSection smoke test) but no direct GlassPanel test.
    2. Custom `padding` / `borderRadius` applied — MISSING.
    3. Custom `boxShadow` overrides default — MISSING.
    4. Dark mode → fill `black 0.45` + border `white 0.22`; light → token fill/border — MISSING (no direct assertion).
    5. **Audit M7 — RepaintBoundary**: GlassPanel does NOT add its own `RepaintBoundary`; callers must wrap it. Verified by source-grep lint, NOT widget test. Test that home_screen wraps the transactions GlassPanel in a RepaintBoundary — covered by `test/lint/glass_blur_perf_test.dart` (regex over home_screen.dart). Note the panel itself is not self-isolating — if a future caller forgets the boundary the blur repaints every frame; consider asserting GlassPanel is wrapped at each call site.
  - Existing coverage: `test/lint/glass_blur_perf_test.dart` pins the home_screen RepaintBoundary + blurSigma=15. No direct widget test for GlassPanel rendering/props/dark-light.

- **`GlassHeaderStrip({required Widget child})`** — 🟡 Partial
  - Blurred top strip with a 1px bottom hairline; base color + border swap dark/light. Used by `GlassTopAppBar` when `showDivider`.
  - Test cases:
    1. Renders child + bottom border, no throw — INDIRECTLY covered via GlassTopAppBar smoke test (showDivider default true).
    2. Dark vs light base/border — MISSING.
  - Existing coverage: only transitively through `GlassTopAppBar` smoke test. No direct test.

#### File summary: 2 public classes; 0 ✅, 2 🟡 (only indirect/lint coverage; no direct render/prop/dark-light widget tests).

### `lib/widgets/luminous/glass_surface.dart`

- **(export shim — re-exports `glass_panel.dart`)** — ✅ Covered (n/a)
  - No public symbols of its own; legacy import path. Nothing to test directly.
  - Existing coverage: n/a — covered by GlassPanel coverage.

#### File summary: 0 public functions (export-only).

### `lib/widgets/luminous/glass_progress_bar.dart`

- **`GlassProgressBar({required double progress, Color? color, double height=8, String? semanticLabel})`** — 🟡 Partial
  - Rounded animated fill (420ms easeOutCubic). Visual width clamps to `[0,1]` but Semantics announces the RAW `(progress*100).round()%`.
  - Test cases:
    1. progress=1.25 → Semantics.value `'125%'` while visual fill clamps to full — covered (the key clamp-vs-raw-semantics assertion).
    2. progress=0 → empty fill, Semantics `'0%'` — MISSING.
    3. progress between (e.g. 0.5) → Semantics `'50%'`, fill ~half — MISSING.
    4. Negative progress (-0.2) → clamp visual to 0, Semantics `'-20%'` — MISSING (boundary; clamp(0,1) handles visual, raw still announced).
    5. `semanticLabel` flows into the Semantics label — MISSING (only value asserted).
    6. Custom `color` drives gradient fill — MISSING.
    7. Dark vs light track color swap — MISSING.
    8. Animation settles without pending timer (AnimatedContainer) — MISSING explicit, but pumpAndSettle elsewhere.
  - Existing coverage: `test/widgets/luminous/luminous_components_smoke_test.dart` group `GlassProgressBar` covers the 1.25 clamp-vs-raw-semantics case only. Missing: 0/mid/negative, label, color, dark/light.

#### File summary: 1 public class; 🟡 (raw-semantics clamp tested; label/0/mid/negative/color/dark-light missing).

### `lib/widgets/luminous/floating_glass_nav_bar.dart`

- **`FloatingGlassNavDestination({required IconData icon, required IconData selectedIcon, required String label})`** — ❌ Missing
  - Immutable data holder for a nav destination.
  - Test cases:
    1. Construct + field round-trip — MISSING (trivial, low priority).
  - Existing coverage: none.

- **`FloatingGlassNavBar({required int currentIndex, required ValueChanged<int> onTap, required List<FloatingGlassNavDestination> destinations})`** — ❌ Missing
  - Pill nav: blurred, generates Expanded InkWell columns; selected index → `selectedIcon` + active color, center index (i==2) icon is 26px else 24px; `HapticFeedback.selectionClick()` + `onTap(i)` on press; labels uppercased.
  - Test cases:
    1. Renders one column per destination (labels uppercased) without throwing — MISSING.
    2. Tapping index i fires `onTap(i)` exactly once — MISSING.
    3. Selected index shows `selectedIcon`; non-selected show `icon` — MISSING (selected/unselected state).
    4. Center destination (index 2) icon size 26 vs 24 for others — MISSING (boundary).
    5. Dark vs light fill/stroke swap — MISSING.
    6. **Audit M8 — selected-tab announcement**: GAP IN SOURCE. The nav bar does NOT wrap items in `Semantics(selected: true)` — unlike GlassPillChip/GlassSegmentedControl/CategoryBentoGrid which all set `selected:`. A screen reader cannot announce which tab is current. Test should assert each item has `Semantics(selected: i==currentIndex)` once the source is fixed; currently there is nothing to assert and no test exists. HIGH priority (accessibility + named audit item).
    7. **Audit M7 — RepaintBoundary**: nav bar must sit behind a RepaintBoundary in main.dart — covered by `test/lint/glass_blur_perf_test.dart` (source-grep), not a widget test on this file.
  - Existing coverage: none direct. M7 boundary asserted via lint test on main.dart. M8 announcement is both an untested gap AND an unimplemented source feature.

#### File summary: 2 public classes, both ❌ (no direct tests; M8 selected-tab Semantics is a real source + test gap).

### `lib/widgets/luminous/glass_top_app_bar.dart`

- **`GlassTopAppBar({Widget? leading, required String title, String? subtitle, List<Widget> actions=const[], bool showDivider=true})`** (implements `PreferredSizeWidget`) — 🟡 Partial
  - 64px header strip: optional leading, title (headlineMedium) + optional subtitle, trailing actions; wrapped in `GlassHeaderStrip` when `showDivider`.
  - Test cases:
    1. Renders title + subtitle + actions; leading present — covered (full-slots smoke test).
    2. `preferredSize.height == 64` — MISSING (it implements PreferredSizeWidget; used as appBar elsewhere).
    3. `showDivider=false` → no GlassHeaderStrip (bare strip) — MISSING (branch).
    4. No leading / no subtitle / empty actions → collapses cleanly — MISSING (the "all optional" contract).
    5. Title overflow → ellipsis (maxLines 1) — MISSING (boundary).
    6. Dark vs light (delegated to GlassHeaderStrip) — MISSING.
  - Existing coverage: `luminous_components_smoke_test.dart` group `GlassTopAppBar` covers the all-slots-present render only. Missing: preferredSize, showDivider:false branch, empty-slot collapse, overflow.

#### File summary: 1 public class; 🟡 (happy path tested; branches/preferredSize/optional-slot collapse missing).

### `lib/widgets/luminous/glass_list_section.dart`

- **`GlassListSection({required String title, required List<Widget> children, EdgeInsetsGeometry padding=...})`** — 🟡 Partial
  - All-caps section header + GlassPanel(padding:zero) containing children separated by hairline Dividers (none after last).
  - Test cases:
    1. Renders uppercased header + child tiles — covered ('PREFERENCES' + 2 tiles).
    2. N children → N-1 Dividers (no trailing divider) — MISSING (the divider-between-not-after logic is the load-bearing branch).
    3. Single child → zero Dividers — MISSING (boundary).
    4. Empty children → renders header + empty panel, no throw — MISSING (boundary).
    5. Custom `padding` applied — MISSING (minor).
  - Existing coverage: `luminous_components_smoke_test.dart` covers header + two tiles render. Missing: divider-count logic, single/empty children.

#### File summary: 1 public class; 🟡 (header+tiles tested; divider-count / empty / single-child untested).

### `lib/widgets/luminous/glass_list_tile.dart`

- **`GlassListTile({IconData? icon, Color? iconColor, required String label, String? sublabel, String? value, Widget? trailing, bool chevron=false, VoidCallback? onTap})`** — 🟡 Partial
  - Flexible row: optional icon-in-container, label + optional sublabel, optional value text, trailing widget OR chevron (trailing wins). `onTap` wraps in InkWell + `HapticFeedback.selectionClick()`; min height = touchTargetMin+4.
  - Test cases:
    1. Renders label; with icon + value + chevron variants — PARTIALLY covered (the section smoke test renders a Switch-trailing tile and a value+chevron tile).
    2. `trailing` set AND `chevron:true` → trailing wins, chevron suppressed — MISSING (mutual-exclusion branch).
    3. `onTap` fires once + haptic on tap; tile wrapped in InkWell only when onTap != null — MISSING (no-onTap → returns bare content, no Material/InkWell).
    4. `sublabel` renders second line; absent → single line — MISSING.
    5. `icon==null` → no leading container (label shifts left) — MISSING.
    6. `iconColor` overrides default primary tint — MISSING.
    7. Min touch-target height ≥ touchTargetMin+4 — MISSING (accessibility boundary).
    8. Dark vs light tileColor swap — MISSING.
    9. Long label/sublabel ellipsis (maxLines 1/2) — MISSING.
  - Existing coverage: `luminous_components_smoke_test.dart` (group GlassListSection+GlassListTile) renders label/value/chevron/trailing-switch via the section. No isolated GlassListTile test of onTap/haptic, trailing-vs-chevron, min-height, dark/light.

#### File summary: 1 public class; 🟡 (rendered in a section; onTap/haptic, trailing-vs-chevron exclusivity, min-touch-target, dark/light untested).

### `lib/widgets/luminous/glass_pill_chip.dart`

- **`GlassPillChip({required String label, IconData? icon, bool selected=false, VoidCallback? onTap, Color? activeColor})`** — 🟡 Partial
  - Animated filter chip wrapped in `Semantics(button: onTap!=null, selected: selected, label: label)`. Selected → tinted fill/border/fg; `onTap` adds haptic.
  - Test cases:
    1. Renders label + icon; selected=true builds — covered (label + icon present).
    2. **Semantics: `selected:true` exposed; `selected:false` exposed** — MISSING (the announcement is the headline accessibility behavior — should assert `tester.getSemantics(...).hasFlag(SemanticsFlag.isSelected)`).
    3. `button` flag true when onTap given, false when onTap null — MISSING.
    4. `onTap` fires once + haptic on tap; null onTap → InkWell onTap null (not tappable) — MISSING.
    5. `activeColor` overrides default primary tint when selected — MISSING.
    6. Selected vs unselected fill/border/fg colors (incl. dark/light) — MISSING.
    7. `icon==null` → no leading icon — MISSING.
  - Existing coverage: `luminous_components_smoke_test.dart` group `GlassPillChip` renders selected chip with icon (text + icon found). The Semantics selected/button flags, onTap, activeColor, dark/light untested despite the comment "selected state announces correctly" (it never asserts the announcement).

#### File summary: 1 public class; 🟡 (renders; the actual selected/button Semantics announcement + onTap + activeColor are untested — the existing test name overclaims).

### `lib/widgets/luminous/glass_segmented_control.dart`

- **`GlassSegmentedControl<T>({required List<T> values, required List<String> labels, required T selected, required ValueChanged<T> onChanged})`** — 🟡 Partial
  - Generic pill segmented switch (assert values.length==labels.length, >=2). Tapping a NON-selected segment fires haptic + `onChanged`; re-tapping selected is a no-op. Outer `Semantics(container:true)`; each `_Segment` has `Semantics(button:true, selected:)`.
  - Test cases:
    1. Tapping unselected segment calls `onChanged` once with that value — covered (tap 'Second' → selected 'b').
    2. Re-tapping the already-selected segment does NOT fire `onChanged` (no-op guard) — MISSING (load-bearing branch `if (values[i]==selected) return;`).
    3. Selected segment Semantics `selected:true`, others false — MISSING (accessibility).
    4. Assertion: `values.length != labels.length` throws — MISSING (debug assert).
    5. Assertion: `<2 values` throws — MISSING (debug assert).
    6. Generic type T other than String (e.g. enum) routes correctly — MISSING.
    7. Active fill / colors swap dark vs light — MISSING.
    8. Animated indicator settles (220ms) without pending timer — MISSING explicit.
  - Existing coverage: `luminous_components_smoke_test.dart` group `GlassSegmentedControl` covers single happy-path tap. Missing: no-op-on-reselect, asserts, Semantics selected, generic-enum, dark/light.

#### File summary: 1 public class; 🟡 (happy tap tested; reselect no-op, asserts, selected-Semantics, dark/light missing).

### `lib/widgets/luminous/glass_bar_chart.dart`

- **`BarDatum({required String label, required double value, Color? color})`** — ✅ Covered (data class)
  - Immutable bar datum.
  - Test cases:
    1. Construct + fields — exercised via chart tests.
  - Existing coverage: used in `luminous_components_smoke_test.dart` chart tests.

- **`GlassBarChart({required List<BarDatum> data, Color? barColor, String Function(double)? valueFormatter, Color? axisColor, double height=220})`** — 🟡 Partial
  - CustomPaint vertical bars; default formatter `toStringAsFixed(1)`; painter early-returns on empty data; `maxV` floored at 1.0; single-bar centered.
  - Test cases:
    1. Empty data → no throw (painter early return) — covered.
    2. Non-empty data → no throw — covered.
    3. Custom `valueFormatter` used for value labels — MISSING.
    4. Single datum → centered bar (`barCount==1` branch) — MISSING (boundary).
    5. All-zero values → `maxV` floored at 1.0, no divide-by-zero / no NaN height — MISSING (domain boundary).
    6. Negative value → bar height direction/clamp behavior — MISSING (domain; `value/maxV` could go negative).
    7. `shouldRepaint` returns true on value/label/color/length change, false otherwise — MISSING (painter contract, unit-testable directly).
    8. Custom barColor / axisColor / height applied — MISSING.
  - Existing coverage: `luminous_components_smoke_test.dart` group `GlassBarChart` covers empty + non-empty no-throw only. Missing: formatter, single/zero/negative, shouldRepaint.

#### File summary: 2 public items; 1 ✅ (BarDatum), 1 🟡 (GlassBarChart — only no-throw smoke; formatter/boundaries/shouldRepaint untested).

### `lib/widgets/luminous/glass_donut_chart.dart`

- **`DonutSlice({required String label, required double value, required Color color})`** — ✅ Covered (data class)
  - Immutable slice.
  - Existing coverage: used in donut chart test.

- **`GlassDonutChart({required List<DonutSlice> slices, double size=220, double thickness=28, Widget? center, double sliceGap=0.04})`** — 🟡 Partial
  - CustomPaint donut: track circle + arc per slice (sweep ∝ value/total); painter early-returns when total<=0; optional centered child.
  - Test cases:
    1. Renders slices + center widget ('TOTAL' found) — covered.
    2. Empty slices / total<=0 → track only, no throw, center still shows — MISSING (boundary; `if (total<=0) return`).
    3. Single slice (value>0) → near-full ring — MISSING.
    4. `center==null` → no center child, no throw — MISSING.
    5. Custom size/thickness/sliceGap applied (radius math, no negative radius when thickness>size) — MISSING (domain boundary).
    6. `shouldRepaint` true on value/color/length change, false otherwise — MISSING (painter contract).
  - Existing coverage: `luminous_components_smoke_test.dart` group `GlassDonutChart` covers slices+center render. Missing: empty/total<=0, single slice, null center, sizing boundaries, shouldRepaint.

- **`DonutLegend({required List<DonutSlice> slices, required String Function(DonutSlice) valueFormatter})`** — ❌ Missing
  - Column legend: color swatch + label + formatted value per slice.
  - Test cases:
    1. Renders one row per slice with label + formatted value — MISSING.
    2. Empty slices → empty column, no throw — MISSING.
    3. `valueFormatter` invoked per slice — MISSING.
    4. Long label ellipsis — MISSING.
  - Existing coverage: none.

#### File summary: 3 public items; 1 ✅ (DonutSlice), 1 🟡 (GlassDonutChart), 1 ❌ (DonutLegend untested).

### `lib/widgets/luminous/category_bento_grid.dart`

- **`CategoryBentoItem({required Object id, required String label, required IconData icon, required Color color})`** — ✅ Covered (data class)
  - Immutable grid cell model (id is the selection key).
  - Existing coverage: used in bento grid test.

- **`CategoryBentoGrid({required List<CategoryBentoItem> items, required Object? selectedId, required ValueChanged<Object> onSelected, int columns=4})`** — 🟡 Partial
  - 4-col non-scrolling GridView of `_BentoCell`; each cell `Semantics(button:true, selected: id==selectedId)`, haptic + `onSelected(id)` on tap, selected → tinted fill/border 1.4px.
  - Test cases:
    1. Tapping a cell fires `onSelected(item.id)` — covered (tap 'Travel' → id 2).
    2. Selected cell Semantics `selected:true`, others false — MISSING (accessibility).
    3. Renders one cell per item with label + icon — MISSING (explicit count).
    4. `selectedId==null` → no cell selected, still renders — MISSING (boundary).
    5. `selectedId` not in items → none selected — MISSING.
    6. Custom `columns` honored — MISSING.
    7. Empty items → empty grid, no throw — MISSING.
    8. Dark vs light tileFill/border swap — MISSING.
  - Existing coverage: `luminous_components_smoke_test.dart` group `CategoryBentoGrid` covers onSelected fire only. Missing: selected-Semantics, count, null/absent selectedId, columns, empty, dark/light.

#### File summary: 2 public items; 1 ✅ (CategoryBentoItem), 1 🟡 (grid — onSelected tested; selected-Semantics/null-id/columns/empty/dark-light missing).

### `lib/widgets/luminous/organic_blob_background.dart`

- **`OrganicBlobBackground()`** — ❌ Missing
  - Const decorative background: ColoredBox + two radial-gradient blobs (mint/blue), different positions/colors dark vs light; blobs wrapped in `IgnorePointer`.
  - Test cases:
    1. Renders without throwing in light AND dark (different branch each) — MISSING.
    2. Blobs are IgnorePointer (do not absorb taps — overlay content stays interactive) — MISSING (load-bearing: it's a full-screen background under tappable content).
    3. Uses `MediaQuery.sizeOf` for blob sizing — survives tiny/large surface without overflow throw — MISSING (boundary).
    4. Dark branch uses surface base color; light branch uses LuminousTokens.background — MISSING.
  - Existing coverage: none. (Appears in screen tests transitively but never asserted; IgnorePointer behavior — the one thing that could break taps — is untested.)

#### File summary: 1 public class; ❌ (no direct test; IgnorePointer pass-through is the key untested concern).

### `lib/utils/premium_animations.dart`

- **`PremiumAnimations` (static duration/curve constants)** — ❌ Missing
  - Const tokens (microDuration…longDuration, enter/exit/spring/smooth curves).
  - Test cases:
    1. Constants hold expected values (trivial; low priority) — MISSING.
  - Existing coverage: none.

- **`AnimatedCounter({required double value, String prefix='', String suffix='', TextStyle? style, Duration duration=500ms, int decimalPlaces=2, bool compact=false})`** — ❌ Missing
  - Tweens displayed number on value change (didUpdateWidget restarts from old→new); formats with decimalPlaces; `compact` → K/M suffixes ≥1e3/1e6.
  - Test cases:
    1. Initial render shows `prefix + value(decimalPlaces) + suffix` — MISSING.
    2. `value` change animates: mid-animation text is between old and new; settled text == new — MISSING (the core behavior; pump partway then pumpAndSettle).
    3. `compact`: 1500→'1.5K', 2_000_000→'2.0M', 999→raw — MISSING (boundary at 1000/1_000_000).
    4. `decimalPlaces=0` → integer text — MISSING.
    5. Negative value with compact (abs() thresholds) → '-1.5K' style — MISSING (domain).
    6. **Money precision concern**: takes a `double` not Decimal — note in handoff that callers must format Decimal→double upstream; rounding via `toStringAsFixed` not Decimal-accurate — MISSING.
    7. Controller disposes cleanly when removed mid-animation (no pending-timer leak) — MISSING.
  - Existing coverage: none (only used inside screen tests, never asserted as a unit).

- **`StaggeredListItem({required int index, required Widget child, Duration delay=50ms, Duration duration=300ms, Offset beginOffset=(0,0.1), Duration maxTotalDelay=500ms})`** — ❌ Missing
  - Fade+slide-in; per-index delay capped at `maxTotalDelay` (items past cap animate immediately via postFrame; capped items use `Future.delayed` with `mounted` guard).
  - Test cases:
    1. Child renders; after duration it's fully opaque/in-position — MISSING.
    2. `index*delay <= maxTotalDelay` → delayed start; large index past cap → immediate (Duration.zero branch) — MISSING (the cap branch is the documented FIX).
    3. **Async-gap mounted check**: unmount during the `Future.delayed`/postFrame window → no setState/forward after dispose (no throw) — MISSING (re-entrancy/lifecycle concern; the `if (mounted)` guard is load-bearing).
    4. Controller disposes cleanly — MISSING.
  - Existing coverage: none direct.

- **`ScaleTapAnimation({required Widget child, VoidCallback? onTap, VoidCallback? onLongPress, double scaleDown=0.97, bool enableHaptic=true})`** — ❌ Missing
  - Scale-down on tap-down, restore on up/cancel; `onTap`/`onLongPress` fire with optional light/medium haptic.
  - Test cases:
    1. `onTap` fires once on tap; `onLongPress` on long-press — MISSING.
    2. `enableHaptic=false` → no HapticFeedback call (mock SystemChannels.platform, assert no `HapticFeedback.*`) — MISSING.
    3. Tap-down then cancel reverses scale (no callback) — MISSING (gesture branch).
    4. Null onTap/onLongPress → no throw on interaction — MISSING.
    5. Controller disposes cleanly — MISSING.
  - Existing coverage: none.

- **`PremiumPageRoute<T>({required Widget page, SlideDirection direction=right})`** + **`SlideDirection` enum** — ❌ Missing
  - PageRouteBuilder with slide+fade transition; begin offset per direction.
  - Test cases:
    1. Pushing the route navigates to `page` after pumpAndSettle — MISSING.
    2. Each `SlideDirection` (right/left/up/down) maps to expected begin offset via `_getBeginOffset` (private — test via push + transition presence) — MISSING.
    3. transitionDuration 300ms / reverse 250ms honored — MISSING.
  - Existing coverage: none.

- **`AnimatedPressCard({required Widget child, VoidCallback? onTap, VoidCallback? onLongPress, double elevation=0, double pressedElevation=4, BorderRadius? borderRadius, Color? color, Border? border})`** — ❌ Missing (NOTE: not in the task's named list but is public in this file)
  - Scale+shadow on press; haptic on tap/longpress; dark/light shadow alpha differs.
  - Test cases:
    1. `onTap` fires once + haptic; `onLongPress` fires — MISSING.
    2. tap-down/up/cancel animates scale+elevation — MISSING.
    3. Custom color/border/borderRadius applied — MISSING.
    4. Dark vs light shadow alpha branch — MISSING.
    5. Controller disposes cleanly — MISSING.
  - Existing coverage: none.

- **`FadeInOnLoad({required Widget child, Duration duration=300ms, Duration delay=Duration.zero, Curve curve=easeOut})`** — ❌ Missing
  - Fades child in on first build; delay via `Future.delayed` with `mounted` guard.
  - Test cases:
    1. With `delay=zero` → starts immediately, fully opaque after duration — MISSING.
    2. With `delay>0` → opacity stays 0 until delay elapses, then animates — MISSING (boundary).
    3. **Async-gap**: unmount during the delayed window → no forward-after-dispose throw (the `if (mounted)` guard) — MISSING.
    4. Controller disposes cleanly mid-animation — MISSING.
  - Existing coverage: none direct (screens use it; the task note warns to pumpAndSettle/bounded-pump to avoid pending timers — that risk is exactly here).

- **`ShimmerLoading({required Widget child, bool isLoading=true, Color? baseColor, Color? highlightColor})`** — ❌ Missing
  - When `isLoading` wraps child in animated ShaderMask gradient; else returns child as-is. Repeat() controller.
  - Test cases:
    1. `isLoading=false` → returns child directly (no ShaderMask, no running controller) — MISSING (the short-circuit branch).
    2. `isLoading=true` → ShaderMask present, animates over frames — MISSING.
    3. Custom base/highlight colors used; default differs dark vs light — MISSING.
    4. Repeat controller disposes cleanly when removed — MISSING (pending-timer leak risk).
  - Existing coverage: none.

- **`BounceAnimation({required Widget child, bool animate=true, Duration duration=600ms})`** — ❌ Missing
  - elasticOut scale 0.8→1.0; forwards on init if `animate`; `didUpdateWidget` re-forwards when animate flips false→true.
  - Test cases:
    1. `animate=true` → scales in, settles at 1.0 — MISSING.
    2. `animate=false` → no animation, child static — MISSING.
    3. `didUpdateWidget`: flip animate false→true re-triggers from 0 — MISSING (the update branch).
    4. Controller disposes cleanly — MISSING.
    5. Task note: under elasticOut, use bounded pump/pumpAndSettle so no pending timer leaks — MISSING.
  - Existing coverage: none direct.

- **`AnimatedProgressBar({required double value, Color? color, Color? backgroundColor, double height=4, BorderRadius? borderRadius, Duration duration=300ms})`** — ❌ Missing
  - Stateless AnimatedContainer fill = `maxWidth * value.clamp(0,1)`.
  - Test cases:
    1. value=0.5 → half-width fill after settle — MISSING.
    2. value>1 clamps to full; value<0 clamps to 0 — MISSING (boundary — note: unlike GlassProgressBar this has NO semantics, so no raw-vs-clamp announcement; clamp is purely visual).
    3. Custom color/backgroundColor/height applied — MISSING.
    4. Dark/light default colors (surfaceContainerHighest / primary) — MISSING.
  - Existing coverage: none.

- **`PulsingDot({Color? color, double size=8})`** — ❌ Missing
  - Repeat(reverse:true) opacity pulse on a circular dot.
  - Test cases:
    1. Renders a circle of `size`; default color = primary — MISSING.
    2. Custom color/size applied — MISSING.
    3. Repeat controller disposes cleanly (pending-timer leak risk) — MISSING.
  - Existing coverage: none.

- **`AnimatedThemeWrapper({required Widget child, Duration duration=300ms})`** — ❌ Missing (public, not in task list)
  - Wraps child in AnimatedTheme with current theme.
  - Test cases:
    1. Renders child; theme change animates — MISSING.
  - Existing coverage: none.

- **`NavigatorExtensions.pushPremium<T>(Widget page, {SlideDirection direction=right})`** + **`ContextNavigatorExtensions.pushPremium<T>(...)`** — ❌ Missing
  - Extension sugar pushing a `PremiumPageRoute`.
  - Test cases:
    1. `context.pushPremium(page)` navigates to page (pumpAndSettle) — MISSING.
    2. `Navigator.of(context).pushPremium(page, direction: up)` uses up offset — MISSING.
    3. Returns the route result Future<T?> on pop — MISSING.
  - Existing coverage: none direct.

#### File summary (premium_animations): 14 public items (1 const class, 9 widgets, 1 enum, 1 route, 2 extensions) — all ❌. Highest-priority: AnimatedCounter value-change animation + compact/decimal formatting (and the double-not-Decimal money note); the `mounted`-guard async-gap cases in StaggeredListItem/FadeInOnLoad; repeat-controller dispose for ShimmerLoading/PulsingDot.

#### Coverage summary
44 public functions/items across the layer; 13 ✅, 13 🟡, 18 ❌.
- ✅ (13): AccessibleButton, AccessibleIconButton, CategoryColors(class+getDefaultColor), CategoryTileSmall, CategoryTileLarge, ColorPicker.parseColor, LoadingSkeleton, TransactionListSkeleton, BudgetCardSkeleton, glass_surface(export), BarDatum, DonutSlice, CategoryBentoItem.
- 🟡 (13): CategoryTile, ColorPicker(widget), GlassPanel, GlassHeaderStrip, GlassProgressBar, GlassTopAppBar, GlassListSection, GlassListTile, GlassPillChip, GlassSegmentedControl, GlassBarChart, GlassDonutChart, CategoryBentoGrid.
- ❌ (18): FloatingGlassNavDestination, FloatingGlassNavBar, DonutLegend, OrganicBlobBackground, PremiumAnimations, AnimatedCounter, StaggeredListItem, ScaleTapAnimation, PremiumPageRoute(+SlideDirection), AnimatedPressCard, FadeInOnLoad, ShimmerLoading, BounceAnimation, AnimatedProgressBar, PulsingDot, AnimatedThemeWrapper, NavigatorExtensions.pushPremium, ContextNavigatorExtensions.pushPremium.

**Highest-priority gaps:**
1. **FloatingGlassNavBar M8 — selected-tab announcement**: nav items have NO `Semantics(selected:)`; a screen reader cannot tell the active tab. This is a source defect AND a test gap (accessibility, named audit item). Fix source, then assert per-item `selected: i==currentIndex`.
2. **ColorPicker widget** — onColorSelected callback + the `Navigator.pop`-after-callback flow + selected/null-swatch rendering are entirely untested (only `parseColor` is). Bottom-sheet pop is a real interaction risk.
3. **premium_animations entire file (14 items, 0 tests)** — esp. AnimatedCounter value-change/compact formatting, the `mounted`-guard async-gap paths in StaggeredListItem/FadeInOnLoad (the exact pending-timer trap the harness note warns about), and repeat-controller dispose for ShimmerLoading/PulsingDot/LoadingSkeleton-style widgets.
4. **GlassPillChip / GlassSegmentedControl / CategoryBentoGrid selected-Semantics** — the announcement is implemented in source but never asserted (the smoke test name "selected state announces correctly" does not actually check the flag); plus GlassSegmentedControl's reselect no-op and length/min-2 asserts.
5. **GlassPanel direct test + M7** — no direct render/prop/dark-light test; RepaintBoundary isolation only enforced by source-grep lint on home_screen/main, not at the widget or per-call-site level.
6. **OrganicBlobBackground IgnorePointer** — full-screen background under tappable content; that taps pass through is untested.
7. **Chart painters** — GlassBarChart/GlassDonutChart `shouldRepaint` contracts and degenerate-data boundaries (all-zero/total<=0/single/negative) are directly unit-testable and untested.
