# Dependency status (2026-09-04)

Everything that can be upgraded on the current toolchain has been. The seven
packages below are deliberately pinned below their latest release. Each entry
says what blocks it, so nobody has to re-derive it — and so nobody "helpfully"
bumps `flutter_secure_storage` to v11 and destroys user databases.

Toolchain at the time of writing: **Flutter 3.47.2 / Dart 3.13.2**, AGP 8.13.2,
Gradle 8.14.3, Kotlin 2.2.20.

## Upgraded on 2026-09-04 (the Flutter SDK bump, v5.3.1+14)

Flutter 3.38.5 → **3.47.2** (Dart 3.10.4 → 3.13.2), done on its own branch with
the full suite as the gate, as the previous pass recommended. That cleared the
whole `win32 6.x` knot at once:

| Package | From | To | Note |
|---|---|---|---|
| `file_picker` | 10.3.10 | **12.2.0** | Federated rewrite. `FilePicker.platform.*` is gone: `pickFile()` is static and returns `PlatformFile?`, `saveFile()` returns `Uri?`, and a SAF pick is a `content://` URI with **no file path** — restore now reads it with `PlatformFile.readAsBytes()`. The dead JSON `importBackup` path (no callers) was deleted instead of migrated. |
| `share_plus` | 12.0.2 | **13.3.0** | |
| `package_info_plus` | 8.3.1 | **10.2.1** | Needs AGP ≥ 8.12.1 / Kotlin 2.2 — see toolchain below. |
| `pdf` | 3.12.0 | **3.13.0** | Needed Dart ≥ 3.12. |
| `sqflite` (+ `sqflite_common` 2.5.11, `sqflite_common_ffi` 2.4.2+1) | 2.4.2+1 | **2.4.3** | Needed Dart ≥ 3.12. |
| `win32` | 5.15.0 | **6.4.0** | Transitive; Windows-desktop only. |

**Android toolchain.** Flutter 3.47's Gradle plugin refuses Gradle < 8.14, so the
wrapper moved 8.11.1 → **8.14.3**, AGP 8.9.1 → **8.13.2** and Kotlin 2.1.0 →
**2.2.20**. Those are the smallest versions inside the Flutter tool's documented
compatibility ranges (`flutter_tools/lib/src/android/gradle_utils.dart`). The SDK's
own `flutter create` template now defaults to Gradle 9.3.1 / AGP 9.1.0 / Kotlin
2.4.0 — AGP 9 switches to the new Gradle DSL and was deliberately **not** taken in
the same pass; it is the next toolchain step when there is a reason for it.

**Flutter 3.47 debug assertions that fired in the suite.** A `ListTile` under a
`DecoratedBox` with a fill (and no `Material` between them) now asserts, because
the fill hides the ripple. `GlassPanel` and `AnimatedPressCard` gained a
transparent `Material` inside their clip, and the recurring-income row moved its
fill/border onto the tile (`tileColor` + `shape`). A new lint
(`unawaited_return_in_try_block`) also caught `db_open.dart` returning the
integrity row-count future before its `finally` closed the connection.

## Upgraded on 2026-08-30

| Package | From | To | Note |
|---|---|---|---|
| `flutter_local_notifications` | 19.5.0 | **22.3.0** | v20 moved `initialize`/`show`/`zonedSchedule`/`cancel` from positional to named parameters; migrated in `lib/utils/notification_helper.dart` and the fake platform in `test/screens/notification_settings_screen_test.dart`. |
| `flutter_local_notifications_platform_interface` | 9.1.0 | **12.2.0** | Matches the above. |
| `timezone` | 0.10.1 | **0.11.1** | Coupled — FLN 19 pins `timezone ^0.10.0`, so these two only move together. |
| `flutter_secure_storage` | 9.2.2 | **10.3.1** | See the v11 warning below. |
| `home_widget` | 0.7.0 | **0.9.3** | |
| `pdf` | 3.11.1 | **3.12.0** | 3.13.0 needs Dart ≥3.12. |
| `fl_chart` | 1.1.1 | **1.2.0** | |
| `decimal`, `intl`, `path_provider`, `shared_preferences`, `cupertino_icons`, `sqflite_sqlcipher`, `share_plus` | — | latest in-constraint | Routine. |
| `permission_handler` | 11.3.1 | **removed** | Only `lib/utils/permission_helper.dart` imported it, and nothing imported that. The app needs no runtime storage permission at all: writes go to app-private storage and restore reads through SAF. |

Removing `permission_handler` also dropped the **discontinued**
`flutter_secure_storage_macos` from the tree.

## Blocked, with reasons

### `flutter_secure_storage` — pinned at 10.x, do NOT go to 11

**This is the one that can destroy user data.** `SecurePrefs` holds
`db_encryption_key`, the SQLCipher key for the entire database, plus the PIN
hash and salt. None of it is a recoverable secret — lose the key and the user's
data is permanently undecryptable.

- **v10** replaced the deprecated Jetpack Security backend with its own ciphers
  (RSA-OAEP-SHA256 + AES-GCM) and migrates v9 data automatically on first
  access, because `migrateOnAlgorithmChange` defaults to true.
- **v11** *deletes* the legacy algorithms. A device that never ran a v10 build
  has nothing to migrate from.

So v11 is only safe **after a v10 build has shipped and been run** on a device.
Since this app is distributed as a direct APK download with no forced-update
channel, there is no way to guarantee a given user passed through v10. Treat v11
as gated on a v10 release having been in the wild long enough.

### The `win32 6.x` cluster — cleared on 2026-09-04

`file_picker` 12, `share_plus` 13 and `package_info_plus` 10 were one
inseparable knot gated on Flutter ≥ 3.41.6; the 3.47.2 bump above resolved
all three (see the 2026-09-04 table). Kept here only so the history of *why*
they were pinned survives: the knot was `win32`, a Windows-desktop-only
transitive that pub still solves for because the `windows/` directory exists.

### `app_settings` — pinned at 7.x

v8 dropped CocoaPods support entirely: the plugin is Swift Package Manager only.
With an `ios/` directory in the repo, `flutter pub get` hard-fails with:

> Plugin app_settings is only Swift Package Manager compatible.

The fix is `flutter config --enable-swift-package-manager`, but that is a
**machine-wide Flutter setting** affecting every Flutter project on the box, so
it is not something to flip as a side effect of one dependency bump. Enable it
deliberately (and re-run the suite) if you want v9.

The app is Android-only in practice, so this is a bookkeeping constraint rather
than a functional one.

## Remaining gates

- **`flutter_secure_storage` 11** — the data-loss gate above. Still pinned at
  10.x; nothing about the SDK bump changes that reasoning.
- **`app_settings` 8** — needs the machine-wide Swift Package Manager switch.
  Still pinned at 7.x.
- **AGP 9 / Gradle 9 / Kotlin 2.4** — the current `flutter create` template.
  Flutter 3.47 already warns at build time that support for Gradle 8.14.3,
  AGP 8.13.2 and Kotlin 2.2.20 "will soon be dropped" and asks for Gradle
  >= 9.1.0, AGP >= 9.0.1, Kotlin >= 2.3.20. The Flutter migrator also wrote
  `android.newDsl=false` and `android.builtInKotlin=false` into
  `android/gradle.properties` to keep the 8.x behaviour. Take the 9.x set
  deliberately on its own branch, with the suite and a device walk as the
  gate, before the next Flutter minor.
