import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// True only when this Gradle invocation is building a RELEASE variant and the
// caller has not opted back into x86. Debug/profile builds keep every ABI so
// the x86_64 emulator still works.
//
// The fallback is deliberately permissive: if the task graph does not name a
// release task we assume "not a release build" and package everything. A build
// that is slightly too big is a non-event; silently stripping the emulator's
// ABI out of a debug build would waste an afternoon.
val restrictAbisToArm: Boolean = run {
    val taskNames = gradle.startParameter.taskNames
    val isReleaseInvocation = taskNames.any { it.contains("Release", ignoreCase = true) }
    isReleaseInvocation && !project.hasProperty("include-x86")
}

// Release signing material. `android/key.properties` is gitignored (along with
// *.jks / *.keystore) and is NOT committed — see `docs/RELEASE_SIGNING.md` for
// how to generate the keystore and write this file.
//
// When the file is absent the build still works, but falls back to the debug
// key and prints a warning. That fallback exists so `flutter run --release` and
// a fresh clone keep working; it must never be used for a build that is handed
// to a user, because the debug key's password is public ("androiddebugkey" /
// "android"), which lets anyone forge an in-place update.
//
// Do NOT rely on that warning to catch a debug-signed release: `flutter build
// apk` suppresses Gradle's output on success, so it never reaches the terminal.
// `scripts/verify-release-apk.sh` inspects the built artifact instead, and is
// the gate the ship pipeline actually runs.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseSigning = keystorePropertiesFile.exists() &&
        keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.moneytracker.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable core library desugaring for flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.moneytracker.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // The `ndk.abiFilters` in the release buildType below drops most of the
    // unwanted ABIs, but it does not reach native libraries that arrive
    // prebuilt inside an AAR — that left x86_64 copies of libsqlcipher.so,
    // libdartjni.so and libdatastore_shared_counter.so (5.9 MB) in the release
    // APK. Excluding the jniLibs path is what actually removes those, so both
    // mechanisms are needed.
    packaging {
        jniLibs {
            if (restrictAbisToArm) {
                excludes += setOf("lib/x86/**", "lib/x86_64/**")
            }
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // `--target-platform android-arm64,android-arm` only governs
            // Flutter's OWN artifacts (libflutter.so / libapp.so). AGP still
            // packages every ABI of the *plugin* native libraries, which left
            // 7.4 MB of x86_64 libsqlcipher.so + libsqlite3.so in the release
            // APK even with that flag. Filtering here is what actually drops
            // them.
            //
            // Build with `-Pinclude-x86` when you need a release APK that can
            // be installed on the x86_64 emulator for device verification.
            ndk {
                if (restrictAbisToArm) {
                    abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a"))
                }
            }

            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "\n" +
                    "**********************************************************************\n" +
                    "  WARNING: signing the RELEASE build with the DEBUG key.\n" +
                    "  android/key.properties was not found.\n" +
                    "  This APK must NOT be distributed: the debug key is public, so\n" +
                    "  anyone can sign a forged update that Android accepts in place.\n" +
                    "  See docs/RELEASE_SIGNING.md to set up a real keystore.\n" +
                    "**********************************************************************\n"
                )
                signingConfigs.getByName("debug")
            }

            // R8 is deliberately left OFF. It would only shrink the ~2.3 MB Java
            // dex (Flutter's own code lives in the native libapp.so, which R8
            // never touches), so the win is ~1 MB against two real costs:
            // obfuscated stack traces in the user-facing crash-log screen, and
            // flutter_local_notifications' documented warning that resource
            // shrinking silently drops notification icons and RemoteViews
            // layouts like the home-screen widget's. The APK size win that
            // actually matters comes from dropping the x86_64 ABI — see
            // docs/RELEASE_SIGNING.md.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
