# Session Handoff — v5.0.0 Release Branch

**Branch**: `release/v5.0.0` — pushed to `origin` (session 3) and merged into `main` at the same SHA.
**Master plan**: `docs/MASTER_PLAN.md`
**Per-task checklist**: `docs/CHECKLIST.md`
**Next-steps plan**: `docs/NEXT_STEPS.md`
**Last commit at handoff**: `789c59c docs(handoff): close-out for session 3 — brand, 6.3/6.4 crypto, 7.3/5/7/9/10`
**Sync state at handoff**: `main` == `origin/main` == `release/v5.0.0` == `origin/release/v5.0.0` == `789c59c`.
**Paused**: 2026-05-11 (Session 3 — Brand alignment + Phase 6.3/6.4 + Phase 7.3/5/7/9/10 + push + main merge)

> To resume: `git checkout release/v5.0.0` (already there) and read this file top-to-bottom plus `docs/CHECKLIST.md` and `docs/NEXT_STEPS.md`. The master plan has the full "why" for each phase; this file has "where we are" + "what's left."

---

## TL;DR — what's done, what's next

| Phase | Status | Tests | What's in it |
|---|---|---|---|
| 0 — Pre-flight | ✅ Done | 1,643 baseline | Master plan + checklist + analyze baseline + APP_INFO design brief |
| 1 — Stop the Bleeding | ✅ Done (10/10) | 1,661 (+18) | useTemplate, pruneDistantMonths, Navigator.pushNamed, HomeWidget race, loadData coalesce, addExpense atomic tx, blur perf, fadeController, Android backup hardening, notification redaction |
| 2 — Architectural Foundations | ✅ Done (7/7) | 1,673 (+12) | AppColors → theme/, LuminousTokens consolidated, Luminous widget skeleton, history narrow selects, package_info_plus, NotificationHelper singleton, Hanken Grotesk bundled |
| 3 — Race & Lifecycle | 🟡 7/7 (3.8 deferred) | 1,683 (+10) | Notification payload queue, recurring snackbar stream, FocusManager hook, accountSwitch stream, HomeWidgetHelper dispose, mounted guards |
| 4 — Schema v19 + Data Integrity | ✅ 12/12 | 1,685 (+1) | v19 migration bundle, tx wrapping, soft-delete tag cleanup, backup validation, strict model validation |
| 5 — Luminous Design Integration | 🟡 starter + 5.10 | n/a | `a231db4` 5-tab nav skeleton + Home redesign (session 1). **5.10 brand alignment landed this session.** 5.1–5.9 still ahead. |
| 6 — Security Hardening | 🟡 5/6 (this session +2) | 1,741 (+21) | 6.2 PIN→secure-storage, 6.5 FLAG_SECURE, 6.6 PII redactor done previously. **This session: 6.3 backup AES-GCM crypto layer + 6.4 widget PIN redaction.** 6.1 SQLCipher remaining. |
| 7 — Test Coverage Rebuild | 🟡 5/10 (this session) | 1,764 (+23) | **This session: 7.3 OnboardingService real tests, 7.5 cascade-delete coverage, 7.7 PIN lockout under FakeClock, 7.9 Clock injection, 7.10 CI test-count gate.** 7.1/2/6/8 deferred. |
| 8 — Polish & Ship | 🟡 2/5 | 1,720 prior | 8.1 preflight + lint, 8.3 APK build verified (59.2 MB unchanged this session). 8.2 perf / 8.4 version bump / 8.5 ship pipeline still ahead. |

**Total test growth this session**: +44 (1,720 → 1,764).
**Total commits this session**: 4 new (23413e6, 6c56fe2, b66cdf6, plus the cryptography deps).

---

## Session-3 commits (5 new since session 2 close at `4f1d62f`)

```
789c59c docs(handoff): close-out for session 3 — brand, 6.3/6.4 crypto, 7.3/5/7/9/10
b66cdf6 feat(phase-7): cover OnboardingService, cascade deletes, PIN lockout + ratchet CI gate
6c56fe2 feat(phase-7.9): Clock injection across time-dependent code
5fcff2d feat(phase-6.3,6.4): widget redaction + backup AES-GCM crypto module
23413e6 feat(phase-5.10,cleanup): brand alignment FinanceFlow + retire orphan MainActivity
```

Full branch history (28 commits since main diverged): `git log --oneline release/v5.0.0` or browse on GitHub. After session 3 fast-forward-merged into `main`, those 28 commits are now also on `origin/main`.

---

## What landed in session 3 (this session)

### Stage A — De-risk (partial)
- **A.1 push branch to origin** ✅ — done at session 3 close after the user authorised it explicitly. Also fast-forward-merged into `main` and pushed `main` (one extra step beyond what A.1 calls for, paid forward to avoid drift). See `docs/NEXT_STEPS.md` §2.A.1.
- **A.2–A.6 device smokes** — still pending; require real hardware for PIN migration / FLAG_SECURE / crash redaction / widget redaction. Resume here when device is back.

### Stage B — Phase 5 Luminous (partial)
- **B.10 Brand alignment** ✅ — AndroidManifest label + every "Money Tracker" string in lib/ → "FinanceFlow". Test expectation in `crash_log_test.dart` updated. Verified by `grep -rn "Money Tracker" lib/` = 0.
- B.1–B.9 visual screen redesigns — **DEFERRED**. Each spec entry explicitly requires device visual verification per screen.

### Stage C — Phase 6 security
- **C.1 (6.4) Home widget redaction** ✅ — new `lib/utils/widget_payload.dart` + wiring through `home_widget_helper.dart` + 6 unit tests. Currency code + accent stay verbatim so widget layout doesn't shift on PIN toggle.
- **C.2 (6.3) Backup AES-GCM (crypto layer)** ✅ — new `lib/utils/backup_crypto.dart` with `package:cryptography ^2.7.0`. v4 envelope shape, PBKDF2-HMAC-SHA256 @ 100k, GCM tag rejection. 15 tests. **UX wiring (passphrase prompt in backup_restore_screen) deferred — needs device.**
- C.3 (6.1) SQLCipher — **DEFERRED**. Highest data-loss risk; needs device + the safe migration dance from `NEXT_STEPS.md` C.3.

### Stage D — Phase 7 tests
- **D.3 (7.3) Onboarding tests** ✅ — `test/services/onboarding_service_test.dart`, 8 tests.
- **D.5 (7.5) Cascade-delete tests** ✅ — `test/integration/cascade_delete_test.dart`, 5 tests.
- **D.7 (7.7) PIN lockout under FakeClock** ✅ — `test/utils/pin_lockout_test.dart`, 5 tests. Sub-second simulation of the 5-minute window.
- **D.9 (7.9) Clock injection** ✅ — new `lib/utils/clock.dart` + 20 call sites migrated across the 5 files in spec (validators, notification_helper, home_widget_helper, pin_security_helper, app_state). UI/export paths intentionally left on `DateTime.now()` per spec.
- **D.10 (7.10) CI test-count gate** ✅ — `scripts/preflight.sh` + `.ps1` now parse the test trailer and fail when count drops below 1750.
- D.1, D.2, D.6, D.8 — **DEFERRED** per per-item rationale in `docs/CHECKLIST.md` Phase 7.

### Stage E — Ship
**Not started.** All ship items (E.1 perf pass on device, E.2 version bump, E.3 vercel deploy, E.4 GitHub release, E.5 merge to main) need either device or explicit user confirmation for shared-system changes. Version stays at `4.4.0+6` until Stage B Phase 5 redesigns land — bumping to 5.0.0+1 without the Luminous redesign would misrepresent the release per Phase 8.4's commentary.

---

## State of the working tree at handoff (Session 3 close)

| Surface | State |
|---|---|
| Branch | `release/v5.0.0` — pushed to `origin`; `main` fast-forward-merged to the same SHA on both local and `origin/main` |
| HEAD | `789c59c docs(handoff): close-out for session 3 — brand, 6.3/6.4 crypto, 7.3/5/7/9/10` |
| Commits since the pre-v5 `main` (`233134f`) diverged | 28 |
| `flutter analyze` | No issues found |
| `flutter test` | 1,764 pass |
| `flutter build apk --release` | succeeded, 59.2 MB (unchanged from session 2) |
| `bash scripts/preflight.sh` | green (gate ≥ 1750) |
| DB schema version | 19 (unchanged) |
| `pubspec.yaml` version | `4.4.0+6` (unchanged — version bump waits on Stage B Phase 5) |
| New deps | `cryptography ^2.7.0` (for Phase 6.3 envelope) |

---

## What's left to reach `v5.0.0+1`

See `docs/NEXT_STEPS.md` for the full per-task spec. Headline gaps:

### Needs device verification (5–8 days)
- **A.3** Smoke-test Phase 6.2 PIN migration on real Keystore.
- **A.4** Smoke-test FLAG_SECURE in Recents.
- **A.5** Smoke-test PII redactor on a forced crash.
- **B.1–B.9** Nine Luminous hero-screen redesigns (each requires per-screen visual verification + scroll perf on Pixel 4a class device).
- **C.2 UX wiring** Passphrase dialogs in `backup_restore_screen.dart` (the crypto module is ready; needs device dialog flow).
- **C.3** SQLCipher migration (highest-risk: rekey dance + row-count verification + plaintext backup).
- **E.1** DevTools perf pass.
- **E.6** End-to-end smoke after the ship pipeline runs.

### Mechanical, doable without device (1–2 days)
- **D.1 + D.2** Rename `app_state_logic_test.dart` and write per-mutator AppState coverage (~30 mutators).
- **D.6** Hero-screen widget tests (depends on Stage B landing first).
- **D.8** Goldens (depends on Stage B; platform-sensitive).
- **B.11** `grep -rn "Spacing\." lib/` → 0 hits + delete `lib/constants/spacing.dart`. 756 call sites currently. Pragmatic alternatives discussed in `NEXT_STEPS.md` §3.

### User-confirmation required (ship gates — none outstanding from session 3)
- **A.1** Push `release/v5.0.0` to origin ✅ done (session 3).
- **A.7 / interim sync** Fast-forward-merge `release/v5.0.0` → `main` and push `main` ✅ done (session 3).
- **E.3** `vercel --prod --yes` from the landing repo — **pending Stage B Phase 5 completion + version bump**.
- **E.4** `gh release create v5.0.0+1` — **pending E.2 version bump**.
- **E.5** Final merge — at session 3 close `main` already matches `release/v5.0.0`; re-run after Stage E.2.

---

## Pointers for the next session

1. **Re-read** `docs/NEXT_STEPS.md` and this handoff first.
2. **Run `bash scripts/preflight.sh`** as a sanity check — should be green at gate ≥ 1750.
3. **Plug in a device** if you want to make headway on Stage A device smokes, Phase 5 hero screens, 6.1 SQLCipher, or 6.3 backup-passphrase UX.
4. **Wire the C.2 UX** when device is available — the crypto module is unit-tested and ready in `lib/utils/backup_crypto.dart`; the missing piece is the passphrase dialog in `backup_restore_screen.dart` + the version-4 branch in restore. See `docs/NEXT_STEPS.md` §4.C.2 for the exact wiring.
5. **Stage B hero screens** in spec order (B.1 Settings → B.9 secondaries). Each commit per `NEXT_STEPS.md` template.
6. **At session end**, fast-forward-merge `release/v5.0.0` into `main` and push — keep them in sync so a continuity-loss event still has the work on origin.

---

## Risk register (delta this session)

- **R12 (backup passphrase forgotten)** still applies — the crypto layer ships but UX wording hasn't shipped. Make sure the UX wiring in C.2 keeps the explicit "we can't recover this file if you forget it" copy.
- **R8 (PIN migration locks user out)** unchanged — still needs A.3 device test.

No new risks introduced this session.

---

**End of handoff. Last touched 2026-05-11 (Session 3).**
