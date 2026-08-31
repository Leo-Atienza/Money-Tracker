# Release signing & APK size

## Why this exists

Every FinanceFlow release up to and including **v5.1.2+11** was signed with the
Android **debug** keystore, because `android/app/build.gradle.kts` carried
Flutter's stock `signingConfig = signingConfigs.getByName("debug")` line and its
`TODO: Add your own signing config` was never done. Those APKs were published
publicly at `https://leo-money-tracker.vercel.app/downloads/money-tracker.apk`.

That matters for three reasons, worst first:

1. **The debug signing key is public.** Every Android SDK install ships the same
   `~/.android/debug.keystore` with alias `androiddebugkey` and password
   `android`. Anyone who downloads the published APK can build a modified
   FinanceFlow, sign it with *their* debug key, and Android will accept it as a
   legitimate **in-place update** over the real one — no uninstall prompt, no
   signature warning. For an app holding SQLCipher-encrypted financial records,
   that is a real path to a malicious "update".
2. **The key is not durable.** `debug.keystore` is machine-local and is
   regenerated whenever it is missing (new laptop, SDK reinstall, cleared
   `~/.android`). If it changes, the signature no longer matches and existing
   users **can never update in place again** — they must uninstall first. With
   `android:allowBackup="false"` and an encrypted database, uninstall means
   irreversible total data loss for that user.
3. **Google Play rejects debug-signed uploads outright.**

The build is now wired to use a real keystore when one is present. It is not
possible for the repo to carry the keystore itself, so the steps below are
yours to run once.

## One-time setup

### 1. Generate the keystore

Run in **PowerShell** (not the Claude Code prompt). Pick a strong password when
prompted and store it in your password manager — see the warning below about
losing it.

```powershell
keytool -genkeypair -v -keystore "C:\Users\leooa\keystores\financeflow-release.p12" -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 10000 -alias financeflow
```

Notes:

- **PKCS12, not JKS.** `keytool` warns that JKS is a proprietary legacy format
  and recommends PKCS12; it is the industry standard and what modern Android
  tooling expects.
- `-validity 10000` (~27 years). An Android signing key cannot be rotated for an
  already-published app without breaking updates, so it must outlive the app.
- Store it **outside the repo**. `C:\Users\leooa\keystores\` is a reasonable
  home. Anything inside the repo risks being committed.

### 2. Write `android/key.properties`

Create `android/key.properties` (already gitignored, along with `*.jks` and
`*.keystore`):

```properties
storePassword=<the store password you just chose>
keyPassword=<the key password you just chose>
keyAlias=financeflow
storeFile=C:/Users/leooa/keystores/financeflow-release.p12
```

Use forward slashes in `storeFile` — Gradle treats a backslash as an escape.

### 3. Gate every publish on the verify script

```powershell
cd C:\Users\leooa\Documents\personal-projects\Money-Tracker; bash scripts/verify-release-apk.sh
```

This is the real safety net, and it is already wired into the ship pipeline in
`CLAUDE.md`. It reads the built APK with `apksigner` and exits non-zero if the
artifact is debug-signed or still contains x86 libraries.

It exists because the Gradle warning cannot be relied on: `flutter build apk`
suppresses Gradle's output on a successful build (the whole log is ~4 lines), so
`logger.warn` never reaches the terminal. Checking the artifact is the only
approach that survives that.

### 4. Verify the signing config engaged

```powershell
cd C:\Users\leooa\Documents\personal-projects\Money-Tracker\android; .\gradlew :app:signingReport --console=plain
```

Look for the `release` variant. It must read `Config: release` and show your
keystore path. If it reads `Config: debug`, `key.properties` was not found or
`storeFile` does not resolve, and the build prints a loud warning saying the
APK must not be distributed.

## Back up the keystore

**If you lose this keystore, you can never ship an update to anyone who
installed a build signed with it.** Not "it's inconvenient" — there is no
recovery path, no override, no appeal. Back up both the keystore file and its
passwords to at least two places (password manager + an encrypted offline copy).

## The one-way door on the first properly-signed release

The first release signed with the new key **cannot update existing installs**.
Android refuses an update whose signature differs from the installed app, so
anyone running v5.1.2 or earlier (all of which are debug-signed) will get an
install failure until they uninstall.

Because `allowBackup` is `false` and the database is encrypted, **uninstalling
destroys their data**. So the release that switches keys must:

1. Ship a release note telling users to open **Settings → Backup & Restore**,
   create a backup, and share it off-device *before* updating.
2. State plainly that they must uninstall the old version, install the new one,
   and restore from that backup.

This is a one-time cost, unavoidable, and it only gets more expensive the longer
the debug-signed builds stay in circulation.

## APK size

The v5.1.2 release APK is **78.2 MB**. Nearly all of it is native libraries
compiled three times, once per ABI:

| ABI | native libs | needed for |
|---|---|---|
| `x86_64` | ~29.1 MB | emulators only — no physical Android phone |
| `arm64-v8a` | ~27.1 MB | every 64-bit Android device (~2015 onward) |
| `armeabi-v7a` | ~23.4 MB | older 32-bit devices |

(`libflutter.so` + `libapp.so` + `libsqlcipher.so` + `libsqlite3.so` per ABI.
Both SQLite variants genuinely ship: `lib/database/db_open.dart` really does
fall back to a plaintext `sqflite` open when no encryption key is available, so
neither native library is removable.)

**Dropping `x86_64` from the distributed build takes the release APK from
78.2 MB to 52.8 MB — a measured 25.4 MB (32%) cut, with no code change and no
loss of phone compatibility.**

It takes two mechanisms, not one. `--target-platform` alone is *not* enough:

1. `--target-platform android-arm64,android-arm` controls only **Flutter's own**
   artifacts (`libflutter.so`, `libapp.so`).
2. `android/app/build.gradle.kts` then has to filter the **plugin** natives,
   which AGP otherwise packages for every ABI regardless of that flag. Even with
   `ndk.abiFilters` set, libraries arriving prebuilt inside an AAR survive — so
   the `packaging.jniLibs.excludes` block is what finally removes the x86_64
   copies of `libsqlcipher.so`, `libdartjni.so` and
   `libdatastore_shared_counter.so`.

Measured, in order:

| build | APK | x86 entries |
|---|---|---|
| v5.1.2 baseline | 78.2 MB | all |
| `--target-platform` only | 63.3 MB | 7.4 MB of plugin natives left |
| `+ ndk.abiFilters` | 58.4 MB | 5.9 MB left |
| `+ packaging.jniLibs.excludes` | **52.8 MB** | **none** |

The gradle filtering is **release-only** and keyed on the task name, so debug
and profile builds still package `x86_64` and the x86_64 emulator keeps working
(verified: `flutter build apk --debug` contains all three ABIs). To build a
*release* APK that installs on the emulator:

```powershell
flutter build apk --release
```

...plus `-Pinclude-x86` passed through to Gradle if you need the filter off
explicitly.

`--split-per-abi` would go further (~30 MB for an arm64-only APK) but produces
three separate files, and the landing page serves a single download — so the
two-ABI universal APK is the right trade unless the download page grows a
per-device picker.

### Why R8 / minification is deliberately off

`isMinifyEnabled` is explicitly `false` in `build.gradle.kts`, and that is a
decision rather than an oversight:

- It would only shrink the ~2.3 MB Java dex. Flutter's own code is AOT-compiled
  into the native `libapp.so`, which R8 never touches — so the ceiling is ~1 MB
  against a 49 MB APK.
- Obfuscated stack traces would make the in-app crash-log screen
  (`lib/screens/crash_log_screen.dart`) unreadable to both you and the user.
- `flutter_local_notifications` documents that resource shrinking silently drops
  notification icons and RemoteViews layouts — which would also put the
  home-screen widget at risk — unless a hand-maintained `keep.xml` lists them.

The ABI change above delivers 30× the size saving for none of that risk.
