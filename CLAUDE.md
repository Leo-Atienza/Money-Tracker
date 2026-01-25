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
