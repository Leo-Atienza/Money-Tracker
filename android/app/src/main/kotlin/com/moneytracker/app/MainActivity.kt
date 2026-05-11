package com.moneytracker.app

import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceInfoChannel = "budget_tracker/device_info"
    private val secureWindowChannel = "budget_tracker/secure_window"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceInfoChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidSdkVersion" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Phase 6.5: FLAG_SECURE toggle.
        //
        // When the Flutter side reports a PIN is enabled, we add
        // FLAG_SECURE to the host window so screenshots, screen recording,
        // and the launcher's Recents thumbnail are all blocked. The flag
        // can be cleared again if the user disables their PIN. Window
        // changes must run on the UI thread.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            secureWindowChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    runOnUiThread {
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
