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

**Signing — gate every publish on `scripts/verify-release-apk.sh`.** Releases are
currently **debug-signed on purpose**: this app ships as a direct APK download,
not through Play, where that installs and updates fine. The debug key is
randomly generated per machine, so it is not a forgery risk — the real exposure
is that `~/.android/debug.keystore` is the only key that can ever update an
existing install, so **back it up**. The script warns about that (exit 0) and
fails only when `android/key.properties` exists yet the APK is still
debug-signed, or when x86 libraries are present. Do not rely on the Gradle
warning — `flutter build apk` suppresses Gradle output on success. See
[docs/RELEASE_SIGNING.md](docs/RELEASE_SIGNING.md), which covers backing up the
key and the one-way update break whenever a real keystore is adopted.

**Build flags:** the published APK is built `--target-platform
android-arm64,android-arm`. That drops the x86_64 slice (~29 MB, emulator-only)
and costs no phone compatibility. Build all ABIs only when installing a release
build on the x86_64 emulator.

**Vercel Git integration is DISCONNECTED for `expense-tracker-landing`.** Pushing to `main` does not trigger a Vercel deploy — you must run `vercel --prod --yes` manually to deploy.

Full pipeline (run from the Money-Tracker directory):

```bash
flutter build apk --release --target-platform android-arm64,android-arm && \
./scripts/verify-release-apk.sh && \
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
