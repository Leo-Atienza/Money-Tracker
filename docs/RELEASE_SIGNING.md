# Release signing & APK size

## Current state: debug-signed, and that is OK for now

Every FinanceFlow release up to and including **v5.1.2+11** is signed with the
Android **debug** keystore, because `android/app/build.gradle.kts` carried
Flutter's stock `signingConfig = signingConfigs.getByName("debug")` and its
`TODO` was never done. Those APKs are published at
`https://leo-money-tracker.vercel.app/downloads/money-tracker.apk`.

**This is not urgent to change.** An earlier version of this document claimed
the debug key made the app forgeable by anyone. That was wrong, and the
correction matters because it changes the priority:

> `~/.android/debug.keystore` is **randomly generated per machine** on first
> debug build. Every developer's copy shares the alias `androiddebugkey` and the
> password `android`, but **not the key pair**. Someone else's debug key
> therefore cannot sign an update that installs over this app — Android rejects
> the signature mismatch exactly as it would for any other stranger's key.

So of the three reasons originally given here:

| Claim | Verdict |
|---|---|
| Anyone can forge an in-place update with their own debug key | **False.** Keys are per-machine random. |
| Google Play rejects debug-signed uploads | True, but **moot** — this app is not distributed through Play. |
| The key is not durable | **True, and the one that actually matters.** |

### The risk that is real: losing the key

`C:\Users\leooa\.android\debug.keystore` is a **2.6 KB single point of failure.**
It is the only key that can ever ship an update to an existing install. If it is
lost — new laptop, SDK reinstall, disk failure, or clearing `~/.android` while
troubleshooting Android tooling, which people do routinely — then every user
running a previous build is stuck. Android refuses the update, and because
`android:allowBackup="false"` and the database is encrypted, their only way
forward is to uninstall, which destroys their data.

For reference, the key currently signing production:

```
Owner:      C=US, O=Android, CN=Android Debug
SHA-1:      2F:EB:6A:C3:76:DB:41:4E:5C:D7:C0:AA:A4:8D:38:5D:A5:89:1D:6C
Valid until Dec 13 2055
```

That fingerprint is public information — it is readable from any published APK
with `apksigner verify --print-certs` — so it is safe to record here, and it
lets you confirm a recovered backup is the right file.

### What to do about it

**Now, and it takes a minute: back up `debug.keystore`.** Copy
`C:\Users\leooa\.android\debug.keystore` into your password manager or an
encrypted offline copy. That solves update continuity completely, costs nothing,
and disrupts no users. Do not commit it — its password is public, so the file
itself is the secret.

**Later, generate a real keystore when either becomes true:**

- you decide to publish on Google Play, which requires it; or
- the app has enough users that stranding them would genuinely hurt.

The migration below is priced per user: nearly free while the install base is
small, painful once it is not. So if you expect real growth, doing it early is
the cheaper option — but it is a judgement call, not a security emergency.

## Generating a real keystore (when you want one)

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

This is a one-time cost, unavoidable, and it scales with the number of people
already running a debug-signed build — which is the whole argument for deciding
early rather than drifting into it. It is not, however, a reason to switch
today: as long as `debug.keystore` is backed up, staying on it costs nothing.

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
