# Session Handoff — v5.0.0 Release Branch

**Branch**: `release/v5.0.0` — in sync with `origin/release/v5.0.0` and `origin/main` (both at session-4 close SHA).
**Master plan**: `docs/MASTER_PLAN.md`
**Per-task checklist**: `docs/CHECKLIST.md`
**Next-steps plan**: `docs/NEXT_STEPS.md`
**Last committed work at handoff**: session 4 — Phase 6.3 UX wiring complete; release build verified.
**Paused**: 2026-05-11 (Session 4 — Phase 6.3 UX wiring + integration tests + APK rebuild)

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
| 5 — Luminous Design Integration | 🟡 starter + 5.10 | n/a | `a231db4` 5-tab nav skeleton + Home redesign (session 1) + 5.10 brand alignment (session 3). 5.1–5.9 hero screens still ahead. |
| 6 — Security Hardening | 🟡 5/6 (6.3 UX wired this session) | 1,775 (+11) | 6.2 PIN→secure-storage, 6.4 widget redaction, 6.5 FLAG_SECURE, 6.6 PII redactor done previously. **This session: 6.3 backup AES-GCM UX wiring landed — passphrase prompts + retry-on-wrong + plaintext-fallback.** 6.1 SQLCipher remaining. |
| 7 — Test Coverage Rebuild | 🟡 5/10 | 1,775 | 7.3 OnboardingService, 7.5 cascade-delete, 7.7 PIN lockout, 7.9 Clock injection, 7.10 CI gate. 7.1/2/6/8 still ahead. |
| 8 — Polish & Ship | 🟡 2/5 | 1,775 | 8.1 preflight + lint, 8.3 APK build verified (59.4 MB, +0.2 MB vs session 3). 8.2 perf / 8.4 version bump / 8.5 ship pipeline still ahead. |

**Total test growth this session**: +11 (1,764 → 1,775).
**APK size**: 59.4 MB (was 59.2 MB at session 3 close; +0.2 MB from `_promptForBackupPassphrase` + `_requestRestorePassphrase` UI code in `backup_restore_screen.dart` plus the helper wiring).

---

## Session-4 commits (2 new since session 3 close at `6f4e608`)

```
(this docs commit)  docs(handoff): close-out for session 4 — Phase 6.3 UX wiring + tests
7a262d3             feat(phase-6.3): wire backup encryption UX — passphrase prompts + retry restore
6f4e608             docs(plan): rewrite NEXT_STEPS for session 4 — precise remaining work
789c59c             docs(handoff): close-out for session 3 — brand, 6.3/6.4 crypto, 7.3/5/7/9/10
b66cdf6             feat(phase-7): cover OnboardingService, cascade deletes, PIN lockout + ratchet CI gate
6c56fe2             feat(phase-7.9): Clock injection across time-dependent code
5fcff2d             feat(phase-6.3,6.4): widget redaction + backup AES-GCM crypto module
```

Branch history (30 commits since the pre-v5 `main` diverged): `git log --oneline release/v5.0.0`. After session 4 fast-forward-merged into `main`, those 30 commits are also on `origin/main`.

---

## What landed in session 4 (this session)

### Stage C — Phase 6 security
- **C.2 (6.3) Backup AES-GCM UX wiring** ✅ — the crypto layer landed session 3; this session wired it into the production save / share / restore flows. Three layers landed:
  1. **`lib/utils/backup_helper.dart`** — new public `@visibleForTesting` static methods `BackupHelper.wrapBackupIfNeeded(json, passphrase)` and `BackupHelper.unwrapBackupIfNeeded(contents, passphrase)`. New `PassphraseRequest` typedef for the restore retry loop. Three production methods now thread the contract through: `saveBackupToUserSelectedLocation({passphrase})`, `shareDatabase({passphrase})`, `restoreDatabase({onPassphraseRequest})`. The wrap step runs on the main isolate after the `compute()` returns so `package:cryptography` doesn't have to cross the isolate boundary.
  2. **`lib/screens/backup_restore_screen.dart`** — new `_promptForBackupPassphrase()` (two-field confirmation dialog, min-6-char validation, show/hide toggle, "we cannot recover this file" copy) and `_requestRestorePassphrase({required bool isRetry})` (single-field passphrase dialog with retry banner). `_exportBackup` and `_shareBackup` both gate on the prompt before doing any DB work; `_performRestore` passes `_requestRestorePassphrase` as the callback to `BackupHelper.restoreDatabase`. The helper loops on wrong passphrase until correct or user cancels (the user can give up at any retry).
  3. **`test/integration/backup_restore_v4_test.dart`** — 11 new tests covering: wrap-passes-through-on-null/empty-passphrase, wrap-produces-v4-envelope, wrap-hides-all-inner-keys (`"database"`, `"settings"`, `"darkMode"`, `"schema_version"`), unwrap-plaintext-passthrough (legacy v2/v3 restore transparently), unwrap-null-on-encrypted-with-null/empty/wrong-passphrase, full round-trip preserves JSON byte-for-byte, two consecutive wraps produce distinct envelopes (proves the fresh-salt-and-IV contract survives the integration layer).
- **Verification:** `flutter analyze` clean. `flutter test` 1,775 pass (+11). `bash scripts/preflight.sh` green (test-count gate ≥ 1,750, forbidden-pattern sweep green). `flutter build apk --release` succeeds at 59.4 MB.

### Stage A — De-risk
- **A.6 (widget redaction smoke)** — still requires device, unchanged.
- **A.2–A.5** — still require device, unchanged.

### Stage D — Phase 7 tests
- No D items landed this session (D.2 / D.6 / D.8 still deferred per per-item rationale in `docs/CHECKLIST.md`).

### Stage E — Ship
- **Not started.** Version stays at `4.4.0+6` until Stage B Phase 5 redesigns land.

---

## State of the working tree at handoff (Session 4 close)

| Surface | State |
|---|---|
| Branch | `release/v5.0.0` — pushed to `origin`; `main` fast-forward-merged to the same SHA on both local and `origin/main` |
| HEAD | session-4 commit (see git log) |
| Commits since the pre-v5 `main` (`233134f`) diverged | 29 |
| `flutter analyze` | No issues found |
| `flutter test` | 1,775 pass |
| `flutter build apk --release` | succeeded, 59.4 MB |
| `bash scripts/preflight.sh` | green (gate ≥ 1750) |
| DB schema version | 19 (unchanged) |
| `pubspec.yaml` version | `4.4.0+6` (unchanged — version bump waits on Stage B Phase 5) |
| New deps this session | none |

---

## What's left to reach `v5.0.0+1`

See `docs/NEXT_STEPS.md` for the full per-task spec. Headline gaps:

### Needs device verification (5–8 days)
- **A.3** Smoke-test Phase 6.2 PIN migration on real Keystore.
- **A.4** Smoke-test FLAG_SECURE in Recents.
- **A.5** Smoke-test PII redactor on a forced crash.
- **A.6** Smoke-test Phase 6.4 widget redaction.
- **B.1–B.9** Nine Luminous hero-screen redesigns (each requires per-screen visual verification + scroll perf on Pixel 4a class device).
- **C.2 device smokes** (new): encrypted save round-trip, wrong-passphrase retry, plaintext-legacy fallback, share-with-encryption.
- **C.3** SQLCipher migration (highest-risk: rekey dance + row-count verification + plaintext backup).
- **E.1** DevTools perf pass.
- **E.6** End-to-end smoke after the ship pipeline runs.

### Mechanical, doable without device (1–2 days)
- **D.1 + D.2** Rename `app_state_logic_test.dart` and write per-mutator AppState coverage (~30 mutators).
- **D.6** Hero-screen widget tests (depends on Stage B landing first).
- **D.8** Goldens (depends on Stage B; platform-sensitive).
- **B.11** `grep -rn "Spacing\." lib/` → 0 hits + delete `lib/constants/spacing.dart`. 756 call sites currently. Pragmatic alternatives discussed in `NEXT_STEPS.md` §3.

### User-confirmation required (ship gates)
- **E.3** `vercel --prod --yes` from the landing repo — **pending Stage B Phase 5 completion + version bump**.
- **E.4** `gh release create v5.0.0+1` — **pending E.2 version bump**.

---

## Pointers for the next session

1. **Re-read** `docs/NEXT_STEPS.md` and this handoff first.
2. **Run `bash scripts/preflight.sh`** as a sanity check — should be green at gate ≥ 1750.
3. **Plug in a device** if you want to make headway on Stage A device smokes (including the C.2 dialog flow now that the wiring is real), Phase 5 hero screens, or 6.1 SQLCipher.
4. **Stage B hero screens** in spec order (B.1 Settings → B.9 secondaries). The C.2 passphrase prompts are already wired into `backup_restore_screen.dart` — when B.9h redesigns that screen, just re-skin the `AlertDialog` shells; don't rip out `_promptForBackupPassphrase` / `_requestRestorePassphrase`.
5. **At session end**, fast-forward-merge `release/v5.0.0` into `main` and push — keep them in sync so a continuity-loss event still has the work on origin.

---

## Risk register (delta this session)

- **R12 (backup passphrase forgotten)** — the mitigation finally has a UI surface. The dialog copy reads "Choose a passphrase. We cannot recover this file if you forget it." with a warning icon. Validation requires a confirm-passphrase match and a 6-char minimum (the "12345" lockout case).
- **R8 (PIN migration locks user out)** unchanged — still needs A.3 device test.
- **R13 (`PinSecurityHelper.isPinEnabled()` aborts publish pipelines in tests)** — unchanged from session 3; relevant test fix already in place at `home_widget_helper_test.dart`. The new `backup_restore_v4_test.dart` operates at the helper layer and never touches `PinSecurityHelper`, so this risk does not re-emerge in this session's tests.

No new risks introduced this session.

---

**End of handoff. Last touched 2026-05-11 (Session 4).**
