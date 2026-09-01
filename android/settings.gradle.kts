pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // The FlutterFire / google-services plugin declaration was removed: Firebase
    // was dropped from this app, nothing applies the plugin, there is no
    // google-services.json, and no firebase_* package is in pubspec.yaml. It was
    // costing a plugin resolution on every Gradle configuration for nothing.
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
