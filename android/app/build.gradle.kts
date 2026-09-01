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
// *.jks / *.keystore) and is NOT committed — see `docs/RELEASE_SIGNING.md`.
//
// When the file is absent the build falls back to the debug key. That is the
// project's CURRENT DELIBERATE STATE, not a bug to be alarmed by: this app ships
// as a direct APK download rather than through Play, and a debug-signed build
// installs and updates fine there.
//
// Note the debug key is randomly generated per machine — the alias and password
// are well known ("androiddebugkey" / "android") but the key pair is not shared,
// so a stranger's debug key cannot sign an update over this app. The real
// exposure is losing ~/.android/debug.keystore, which is the only key that can
// ever update an existing install. Back it up.
//
// `scripts/verify-release-apk.sh` is the ship gate. It warns (exit 0) when this
// fallback is in play, and fails only when key.properties exists yet the APK is
// still debug-signed — i.e. the config silently did not take effect. Gradle's
// own logger.warn below cannot be relied on: `flutter build apk` suppresses
// Gradle output on success, so it never reaches the terminal.
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
                    "  NOTE: signing the RELEASE build with the DEBUG key.\n" +
                    "  android/key.properties was not found.\n" +
                    "  For a direct APK download this is fine and is the current\n" +
                    "  deliberate state. But ~/.android/debug.keystore is then the\n" +
                    "  ONLY key that can ever update an existing install — if it is\n" +
                    "  lost, users must uninstall (which destroys their data).\n" +
                    "  BACK IT UP. See docs/RELEASE_SIGNING.md.\n" +
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
