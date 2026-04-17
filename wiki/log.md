---
title: Activity Log
type: log
---

# Activity Log

| Date | Action | Page | Notes |
|------|--------|------|-------|
| 2026-04-10 | init | - | Project wiki initialized |
| 2026-04-10 | ingest | context/stack.md | Compiled stack from CLAUDE.md |
| 2026-04-14 | session | - | Bug fix + safety net pass (PR #8) merged: 10 bugs fixed, crash log + Settings entry wired, sqflite_common_ffi integration test scaffold with 47 new regression tests, biometric stub + stale docs removed, version 4.0.0+4 -> 4.1.0+5. 1546 tests passing, release APK builds (58.8 MB). |
| 2026-04-15 | session | - | Version reconcile (PR #9 merged as 29b0bfa): discovered the 4.1.0+5 bump from PR #8 was numerically behind the public v4.3.0 GitHub release (L100 Quality Upgrade, shipping on landing page). Bumped pubspec/main.dart/CHANGELOG/crash_log.dart docstrings to 4.4.0+6 — clean step up from v4.3.0, minor bump because crash log is a new user-visible feature. 1546/1546 tests still passing, APK rebuilt on merged main (58.8 MB). Graphify rebuilt via graphify.watch._rebuild_code (81 nodes, 92 edges, 19 communities) but noted that Dart is not in graphify's CODE_EXTS allowlist so only Windows runner native code is indexed — falls back to Grep/Glob for Dart navigation. Handed off to user: 7-flow device smoke test blocks v4.4.0 tag + GitHub release + landing-page APK swap. |
| 2026-04-17 | session | - | Coverage pass ahead of v4.4.0 release. Added 97 new unit/widget tests across 7 suites: `settings_helper` (30), `dialog_helpers` (14), `category_tile`+`CategoryColors` (13), `accessible_button`+`AccessibleIconButton` (11), `loading_skeleton`+`TransactionListSkeleton`+`BudgetCardSkeleton` (11), `notification_payload_store` (11), `snackbar_helper` (7). Non-obvious patterns learned: (1) `find.byType(FilledButton)` misses `FilledButton.icon()` because the `.icon` factory returns a private `_FilledButtonWithIcon` subclass — use `find.byWidgetPredicate((w) => w is FilledButton)` instead; (2) `ThemeData(brightness:)` does not reliably propagate to `Theme.of(context).brightness` inside widget tests — use `ThemeData.dark()` / `ThemeData.light()` factories instead; (3) any helper that `await`s `HapticHelper.lightImpact()` before `showDialog` will hang in unit tests because the `flutter/platform` channel has no handler and `pumpAndSettle` won't resolve the Future — install a null mock via `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null)` in `setUp`. Final: 1643/1643 tests passing, `flutter analyze` clean. Device smoke test still blocks v4.4.0 release. |
