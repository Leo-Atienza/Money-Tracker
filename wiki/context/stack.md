---
title: "Stack & Architecture"
type: context
related: []
created: 2026-04-10
updated: 2026-04-10
---

# Money Tracker — Stack & Architecture

Flutter-based Android expense tracking app. Local-only (no remote backend).

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter |
| Design | Material 3, Dark/Light mode |
| State | Provider (`AppState`) |
| Persistence | SQflite (`DatabaseHelper`) — local only |
| Backend | None |

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Entry point |
| `lib/models/` | Data models (Expense, Category, etc.) |
| `lib/screens/` | UI screens |
| `lib/providers/app_state.dart` | State management |
| `lib/database/database_helper.dart` | SQflite schema + queries |
| `lib/utils/` | Currency, CSV, Notifications helpers |

## Common Patterns

- Add screen: create in `lib/screens/`, extend StatelessWidget/StatefulWidget, use Scaffold
- Add model: create in `lib/models/`, add `toMap`/`fromMap` methods
- State changes: add methods to `AppState`, call `notifyListeners()`
- Schema changes: update `DatabaseHelper`

## Related

- Landing page: `expense-tracker-landing` project (marketing site driving APK downloads)
- GitHub: https://github.com/Leo-Atienza/Money-Tracker
