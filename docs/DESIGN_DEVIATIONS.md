# Design Deviations — FinanceFlow Luminous

This file tracks intentional departures from the Stitch design spec
(`stitch_money_tracker_redesign/`), with rationale. Every deviation
must be:

- Approved by the design owner (or noted as a perf compromise).
- Documented here so future audits don't flag it as a regression.
- Reversible — listed with the original spec value so we can revisit.

---

## DD-001 — Glass blur sigma: 25 → 15

**Spec:** `bg-white/45 backdrop-blur-[25px]` (DESIGN.md → `glassBlurSigma = 25`)
**Implementation:** `LuminousTokens.glassBlurSigma = 15`
**Files:** [lib/theme/luminous_app_theme.dart](../lib/theme/luminous_app_theme.dart)

**Reason.** `BackdropFilter(ImageFilter.blur(25, 25))` measured at ~14 ms
per frame on a Pixel 4a class device (single tile) — well over the
16.7 ms 60-fps budget once 3-4 surfaces are visible (home screen has
~4 glass panels). At sigma 15 the per-tile cost roughly halves while
the visual difference is imperceptible at typical phone viewing
distance.

**Tradeoff.** Slightly less "frosted" look in side-by-side comparison
with the Figma export, especially on high-contrast backgrounds. Real
hardware testing on Pixel 4a + iPhone 14 confirmed no user-visible
regression.

**Revert path.** Set `glassBlurSigma = 25` and re-measure frame budget
on the slowest target device. If GPU is bypassed (Vulkan/Impeller is
ahead of where we measured), the spec value may be reachable.

---

## DD-002 — Spacing.* deprecation strategy

**Spec:** `docs/MASTER_PLAN.md` Phase 2.2 — "leave `lib/constants/spacing.dart`
for backward compat with a `@Deprecated('Use LuminousTokens.*')` annotation on
each constant."
**Implementation:** Class-level migration note instead of per-constant
`@Deprecated` annotations.
**Files:** [lib/constants/spacing.dart](../lib/constants/spacing.dart)

**Reason.** 757 `Spacing.*` call sites across 25 files. Per-constant
`@Deprecated` would emit ~757 `deprecated_member_use_from_same_package`
analyzer warnings on every `flutter analyze`, drowning out real signal and
breaking the Phase 0 "No issues found" baseline. Phase 5 will inline the
constants screen-by-screen onto `LuminousTokens` and then delete this file.

**Tradeoff.** Developers don't get an IDE strikethrough when typing `Spacing.x`.
The file's docstring and the `LuminousTokens.*` aliasing make the migration
intent obvious; Phase 5 task list enumerates every screen.

**Revert path.** When Phase 5 reduces `Spacing.*` usage to a manageable count
(< 50), re-add the per-constant `@Deprecated` to flush the long tail.

---

## (template — copy when adding a deviation)

## DD-NNN — Short description

**Spec:** what the design calls for
**Implementation:** what we shipped
**Files:** affected files

**Reason.** Why we diverged (perf / a11y / platform limitation).
**Tradeoff.** What we lost.
**Revert path.** What it would take to come back to spec.
