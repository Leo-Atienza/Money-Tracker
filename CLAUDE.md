# Expense Tracker

- Build command: `flutter build apk` (or `flutter run`)
- Run command: `flutter run`
- Main file: `lib/main.dart`
- Style:
  - Material 3 Design
  - Dark/Light mode support
  - Clean, minimalist UI
  - State management: Provider (`AppState`)
  - Persistence: SQflite (`DatabaseHelper`)
  - No remote backend (local only)

## Shipping the APK

**Vercel Git integration is DISCONNECTED for `expense-tracker-landing`.** Pushing to `main` does not trigger a Vercel deploy — you must run `vercel --prod --yes` manually to deploy.

Full pipeline (run from the Money-Tracker directory):

```bash
flutter build apk --release && \
cp build/app/outputs/flutter-apk/app-release.apk /c/Users/leooa/Documents/personal-projects/expense-tracker-landing/public/downloads/money-tracker.apk && \
git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing add public/downloads/money-tracker.apk && \
git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing commit -m "chore: update APK to $(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}')" && \
git -C /c/Users/leooa/Documents/personal-projects/expense-tracker-landing push && \
(cd /c/Users/leooa/Documents/personal-projects/expense-tracker-landing && vercel --prod --yes)
```

Takes ~60s (build + deploy). Live URL: https://leo-money-tracker.vercel.app/downloads/money-tracker.apk

Verify after: `curl -sL https://leo-money-tracker.vercel.app/downloads/money-tracker.apk | sha1sum` should match `sha1sum build/app/outputs/flutter-apk/app-release.apk`.

## Common Tasks

- **Add Screen**: Create in `lib/screens/`, extend `StatelessWidget` or `StatefulWidget`, use `Scaffold`.
- **Add Model**: Create in `lib/models/`, add `toMap` and `fromMap` methods.
- **Database**: Update `DatabaseHelper` in `lib/database/database_helper.dart` for schema changes.
- **State**: Add methods to `AppState` in `lib/providers/app_state.dart`, use `notifyListeners()`.

## Project Structure

- `lib/models/`: Data models (Expense, Category, etc.)
- `lib/screens/`: UI Screens
- `lib/providers/`: State management
- `lib/database/`: Database handling
- `lib/utils/`: Helpers (Currency, CSV, Notifications)
