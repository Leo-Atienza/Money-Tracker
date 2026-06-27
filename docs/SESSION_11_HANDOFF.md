# Money Tracker (FinanceFlow) — Session 11 Handoff (2026-06-27)

> Continuation of `docs/NEXT_SESSION_HANDOFF.md`. That doc is still the master plan
> (env setup, full Remaining-Work groups, exhaustive per-function test plan). This
> doc records **what Session 11 landed**, the **current state**, and the **precise
> remaining work** to reach a shipped `v5.0.0+1`.

## 1. Current state

- **Branch:** `release/v5.0.0`. **NOT pushed** (Session 10 + Session 11 commits are local-only).
- **Version:** still `4.4.0+6` (bump to `5.0.0+1` only at ship — Group 10).
- **Tests:** **1913 pass / 3 skipped**, `flutter analyze` clean, `bash scripts/preflight.sh` green (gate ≥ 1750 — RATCHET this up; see §4).
- **Emulator:** `emulator-5554` (API 36) booted; debug APK installs + runs. App id `com.moneytracker.app`.

### Session 11 commits (on top of Session 10's `d4f4c8b`)
| SHA | What |
|---|---|
| H2 | `fix(security)`: PIN hash → PBKDF2-SHA256 100k (self-describing `pbkdf2_sha256$iters$key`), migrate-on-verify for BOTH legacy salted + un-salted SHA-256. **Note: handoff plan missed the salted-legacy case — that branch was added (would have locked out every existing v4.x user otherwise).** |
| M17–M21 | `fix(notifications)`: tap routing wired (callbacks were never set), reminder time honored, toggles schedule/cancel immediately, budget-alert + loadData failures contained. `notificationTapBackground` moved to `notification_payload_store.dart`. |
| M8–M14 | `fix(a11y+perf)`: nav-bar/chevron/category/PIN-backspace semantics, textScaler clamp 1.3x, history swipe-delete a11y action, GlassPanel RepaintBoundary, **history list flattened + StaggeredListItem capped at 12** (M7+M8). |
| M1/M16/M15 | `fix(money)`: addPayment records exact amount (no sub-10¢ round-up), locale grouping on Home/History/Analytics, Wallet add-account moved to header (FAB was occluded). |
| M6 | `perf(analytics)`: single-pass `getCategorySpendTotals()`. |
| L52/L32/L36 | `fix(db)`: **migration brick-fix** (`defer_foreign_keys` inside the txn — the old `foreign_keys=OFF` was a no-op), raw-`.db` restore schema-version trust check (`readSqliteUserVersion`). |
| M16-hero | `fix(money)`: `AnimatedCounter` now groups thousands — the **Total Balance hero showed `$2845.00`** (device-caught); also fixed a latent double-negative on negative balances. |

## 2. Device verification done this session (emulator-5554) — ALL PASSED
- **Blob bg:** app renders over the global `OrganicBlobBackground` (light) — onboarding, Home, Settings, Wallet, PIN screen. No black background.
- **H2 (PRIMARY):** set a fresh PIN `1397` via Settings → force-stop → reopen → app re-locked → entered `1397` → unlocked to Home. **Proves PBKDF2 set→verify round-trips through the real Android Keystore.** (Emulator currently has PIN `1397` set — `adb uninstall com.moneytracker.app` to reset.)
- **H1:** confirmed — the app re-locks on reopen when a PIN is set.
- **M16 hero:** confirmed the bug on-device (`$2845.00`) then confirmed the fix — Home shows `$2,845.00` / `$3,000.00`; a11y label `Total balance $2,845.00` matches the visible text.
- **M13:** home month chevrons report as `button` nodes labeled "Previous month"/"Next month".
- **M10/L46:** nav destinations are `button` nodes labeled "Home/History/Analytics/Wallet"; selected tab (WALLET) renders in the green active color.
- **M15:** Wallet add-account "+" sits in the header trailing slot, fully visible/tappable (no occluded FAB).
- **L42:** PIN keypad "Delete" reports `button` role + "Delete" label.
- **1d7cf3c:** "Load Sample Data" works end-to-end → Home with seeded data.

> **Gotcha confirmed:** the Session-10 install carried over a **legacy salted-SHA-256 PIN**. Entering the documented `1234` did NOT unlock — ambiguous (unknown real PIN vs. bug), so I did the definitive NEW-PIN test instead (above). The legacy→PBKDF2 upgrade is covered by 4 unit tests against real SHA-256 hashes through the same `flutter_secure_storage` channel the device uses. **Still recommended:** a real-device legacy-upgrade smoke with a KNOWN old PIN (set PIN on a v4.4.0 APK, sideload new build, confirm unlock) for full belt-and-braces.

## 3. Process learnings (don't re-hit)
- **`bash scripts/preflight.sh > log; echo $?` masks the real exit code** — the `echo` always returns 0, so the background-task "exit code 0" notification is meaningless. **Always grep the log for `preflight green` / `Some tests failed`.** (One red commit slipped in this way and was amended.)
- **Never edit `lib/`/`test/` while a background preflight/build runs** — the test runner picks up files mid-edit → transient "Failed to load" compile errors that look like real failures.
- **Device verification catches what unit tests miss** — the M16 hero `$2845.00` gap (a different widget, `AnimatedCounter`, not in the audit's M16 file list) was only visible on-device.

## 4. Remaining work to ship v5.0.0+1 (ordered)

1. **Ratchet `TEST_COUNT_MIN`** in `scripts/preflight.sh` + `.ps1` from 1750 → ~1900.
2. **M5 (perf, deferred):** move PDF/CSV generation to `compute()` isolates. `pdf_exporter.dart:355/633/877`, `csv_exporter.dart:131/244/338`. Pattern in `backup_helper.dart:482/622`. Pass materialized `List<Expense>`/`List<Income>` + scalars. Device perf verify in 8.2.
3. **LOW tail (opportunistic):** L30 (extract destructive purge out of `getDeletedAccounts` read path → `performMaintenance`), L34 (`.pre_restore` sweep from `cleanOrphanedBackupFiles` — the `Future.delayed(7d)` never fires; files at `${dbPath}_pre_restore_*`), L22–L24 (Decimal money), L25–L27 (lifecycle), L28/L29/L31/L33/L54/L55 (DB), L56/L57 (dead code), L58–L61. Full detail in `docs/AUDIT_FINDINGS_2026-06.md`. Also: home quick-template chip amounts (`home_screen.dart:1058/1101`) still use raw `toStringAsFixed(0)` — route through `formatWithCurrency` for M16 completeness.
4. **Per-function test gaps** (`docs/NEXT_SESSION_HANDOFF.md` § Comprehensive Per-Function Test Plan): close every ❌/🟡. Surface-defects to fix while adding tests: unguarded `fromMap` TypeErrors, `tryFromMap` leaking non-ArgumentError. Use ultracode workflows for exhaustive generation + adversarial verification.
5. **Phase 6.1 SQLCipher** (Group 7 in NEXT_SESSION_HANDOFF — high data-loss risk, device-only). Dep swap, `DbEncryption.getOrCreateKey`, plaintext→encrypted migration + row-count verify + `.pre-sqlcipher-backup`. 3 integration tests + device smoke.
6. **D.3 goldens** for 8 hero screens (Windows-locked, 2% tolerance).
7. **8.2 device perf pass** (DevTools, 60fps; validates M6/M7/M8/M9 + M5).
8. **8.4 version bump** `4.4.0+6` → `5.0.0+1` + CHANGELOG v5.0.0 (Added/Changed/Fixed/Security — incl. H2 PBKDF2, M-fixes, SQLCipher).
9. **8.5 ship pipeline** (build → copy to landing repo → `git push` → `vercel --prod --yes` → SHA-1 parity → `gh release` → ff-merge `main`). Vercel git integration is DISCONNECTED — `vercel --prod --yes` is required.

## 5. Definition of Done (unchanged from NEXT_SESSION_HANDOFF §6)
Every audit finding fixed/deferred-with-rationale; all ❌/🟡 tests closed; SQLCipher landed + device-verified; goldens pass; perf pass meets 60fps; version `5.0.0+1` + CHANGELOG; APK ≤ 70 MB; 5-min device smoke; tag on origin + `main`; landing serves matching SHA-1.
