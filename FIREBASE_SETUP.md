# Firebase setup

This project uses Firebase for cloud sync (Auth + Firestore). Per-platform config files (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) are **not committed** — they're listed in `.gitignore`.

## Bootstrap

Easiest path — the FlutterFire CLI generates every per-platform file in one shot:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

Pick the platforms you build for (Android / iOS / macOS / web) when prompted. The CLI writes:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

All four files are git-ignored.

## Manual fallback

If you can't run the CLI, grab the platform configs directly from the [Firebase Console](https://console.firebase.google.com/) → **Project Settings → Your apps → Download config file**, and drop them at the paths above. `android/app/google-services.json.example` shows the expected JSON shape.

## ⚠ Key restrictions are required

Firebase client API keys are project identifiers, not secrets — they ship to every installed client. But unrestricted keys can be abused (sign-up flood on Identity Toolkit, billable Firebase calls), so each key must be locked down in [Google Cloud Console → APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials):

| Platform | Restriction |
|---|---|
| Android | Package name `com.moneytracker.app` + release/debug SHA-1 fingerprints |
| iOS | Bundle identifier |
| Web | HTTP referrer (your production domain) |

Plus: Firestore Security Rules must deny anonymous reads/writes by default. Verify at Firebase Console → Firestore → Rules.

## If a key leaks

A leaked-then-restricted client key is low-impact (attackers can hit your project but Security Rules and key restrictions cap the damage). Still rotate when convenient: Firebase Console → Project Settings → regenerate config, then re-run `flutterfire configure`.

GitHub secret scanning + push protection are enabled on this repo to catch future accidents at `git push` time.
