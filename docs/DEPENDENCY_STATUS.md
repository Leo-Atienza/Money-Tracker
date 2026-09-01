# Dependency status (2026-08-30)

Everything that can be upgraded on the current toolchain has been. The seven
packages below are deliberately pinned below their latest release. Each entry
says what blocks it, so nobody has to re-derive it — and so nobody "helpfully"
bumps `flutter_secure_storage` to v11 and destroys user databases.

Toolchain at the time of writing: **Flutter 3.38.5 / Dart 3.10.4**, AGP 8.9.1,
Gradle 8.11.1, Kotlin 2.1.0.

## Upgraded in this pass

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

### Gated on the Flutter SDK (the `win32 6.x` cluster)

`file_picker` 12, `share_plus` 13, and `package_info_plus` 10 form one
inseparable knot:

- `file_picker` ≥12 → `windows_file_picker` → `win32 ^6.3.0`
- `share_plus` ≥13.1 → `win32 ^6.0.1`
- `share_plus` <13.1 → `win32 ^5.5.3` — conflicts with `file_picker` 12
- `package_info_plus` <10 → `win32 <6` — conflicts with `share_plus` 13
- `package_info_plus` 10 → **requires Flutter 3.41.6 / Dart 3.11.0**

We are on Flutter 3.38.5 / Dart 3.10.4, so the whole cluster is stuck until
Flutter itself is upgraded. Upgrading Flutter is its own project — it can shift
widget layout under a 2474-test suite — and was deliberately not bundled into
this pass.

Note `win32` is only a *Windows desktop* concern; it is irrelevant to the
shipped Android app. It still blocks resolution because pub solves across all
platform targets present in the repo. A `dependency_overrides` hack could force
it, at the cost of silently breaking the Windows build — not worth it.

`package_info_plus` 9 is separately blocked: it needs AGP ≥8.12.1, Gradle ≥8.13,
and Kotlin 2.2.0; we are on 8.9.1 / 8.11.1 / 2.1.0.

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

### `pdf` 3.13.0 / `sqflite` 2.4.3

Both need Dart ≥3.12. Same Flutter-SDK gate as above.

## The single unblock

Upgrading Flutter to **≥3.41.6** clears `file_picker`, `share_plus`,
`package_info_plus`, `pdf`, and `sqflite` in one move. That is the highest-value
next step for dependency health — and it should be done on its own branch with
the full suite as the gate, not folded into unrelated work.
