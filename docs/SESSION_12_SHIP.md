# Session 12 — v5.0.0 SHIPPED (2026-06-27)

**FinanceFlow v5.0.0+7 is live.** Continuation of `docs/SESSION_11_HANDOFF.md` §4.

## What shipped
- **Released commit:** `e11400d` on `release/v5.0.0`, fast-forward-merged to `main`. Tag `v5.0.0` → `e11400d`. All pushed to origin.
- **APK:** `5.0.0+7` (versionCode **7** > shipped 6 — OTA-safe), 64.2 MB, SHA-1 `ff6a84370f2f1d3bf7627a08af1bb59ed1617d68`.
- **Landing:** pushed + `vercel --prod --yes` deployed. Live URL serves matching SHA-1 (verified). https://leo-money-tracker.vercel.app/downloads/money-tracker.apk
- **GitHub release:** https://github.com/Leo-Atienza/Money-Tracker/releases/tag/v5.0.0 (APK attached).
- **Tests:** 2062 pass / 3 skipped, analyze clean, preflight green (gate ratcheted 1750 → **2050**).

## Work landed this session (8 commits on top of S11's `50d319a`)
| Commit | What |
|---|---|
| `aee7ad3` | **Model hardening (surface defects):** `tryFromMap` now catches `TypeError` too (was `ArgumentError`-only → a wrong-typed column dropped the whole list); added `tryFromMap` to RecurringExpense/RecurringIncome (had none) + routed the 4 bulk recurring reads through it. +12 tests. |
| `25a4162` | **M5 CSV → `compute()` isolate** + 4 output-locking builder tests. |
| `5c38faa` | **M5 PDF → `compute()` isolate** (relocate-only, byte-identical) + 4 `%PDF` tests. (Delegated to a subagent, diff-reviewed.) |
| `6375da7` | **LOW tail:** L30 (purge off the `getDeletedAccounts` read path → `performMaintenance`), L34 (`*_pre_restore_*` startup sweep; dropped the dead `Future.delayed(7d)`), L33 (SQL identifier allow-list), L27 (analytics mounted guard), M16 quick-template chips, deleted ~330 lines of dead code (L56 5 widgets, L57 2 helpers), + a `resetForTesting()` race fix (await in-flight init). |
| `e01394e` | **+129 tests** across models/utils/widgets via a 12-agent self-verifying workflow; ratchet gate → 2050. |
| `cba0596` | Version bump `4.4.0+6` → `5.0.0+7` + CHANGELOG v5.0.0. |
| merge `e11400d` | **Incorporated PR #11 security fix** (untrack `google-services.json`) that `main` had but `release` was missing — caught during the ship ff-merge; release would otherwise have re-tracked the leaked-keys file. |

## Device-verified on the RELEASE/AOT build (emulator-5554, all passed)
- Onboarding renders over the blob; Load Sample Data → Home.
- **M16 hero grouping:** `$2,845.00` / `$3,000.00` (incl. a11y labels).
- M13 month chevrons, M10 nav + active color, Settings glass redesign.
- **M5 CSV export via `compute()` isolate** → `transactions_*.csv` + share sheet.
- **M5 PDF export via `compute()` isolate** → `monthly_summary_*.pdf` + share sheet.
- L30/L34 DB maintenance ran during loadData without crashing; zero FATAL in logcat.
- (H2/H1 PIN unchanged this session — device-verified in S11.)

## Deferred (with rationale — NOT bugs, documented choices)
1. **Phase 6.1 SQLCipher** — highest data-loss-risk item; bolting a plaintext→encrypted migration onto a ship is the anti-pattern S11 avoided. App already ships PBKDF2 PIN + encrypted backups + FLAG_SECURE. Clean follow-up.
2. **D.3 goldens** — no golden infra exists (greenfield); golden tests are environment-fragile; every hero screen already has a widget test + device verification. Low value / high fragility right before ship.
3. **8.2 formal DevTools 60fps pass** — impractical to measure rigorously on emulator; the perf fixes (M5–M9) are code-verified and the release build was device-smoked with no jank.
4. **Test gaps in the two giants** — `database_helper.dart` (~110) and `app_state.dart` (~82) need the integration DB harness, which is race-prone (fixed one race this session). Adding ~190 integration tests risks flakiness against the now-green 2062-test suite. The deterministic model/util/widget gaps (133 tests) were closed; the screen-interaction tail + giants are the documented remaining test work.
5. **Per-agent honest deferrals** (10) — paths gated by `Platform.isAndroid`/`DateTime.now()` need a lib test-seam; unreachable catch-blocks; private painters; exact dark-mode RGB (golden territory). All captured in the workflow output.

## Notes / corrections to prior handoffs
- Handoff said bump to `5.0.0+1`; that would **regress** the Android versionCode below the shipped `+6` and break OTA upgrades → used `5.0.0+7` (audit L62).
- `google-services.json` is **vestigial** — the gms plugin is `apply false` and there are no Firebase deps, so the file is unused by the build (now untracked + gitignored, regenerate via `flutterfire configure` if Firebase is ever re-added).
