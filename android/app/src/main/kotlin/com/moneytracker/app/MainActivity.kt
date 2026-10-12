package com.moneytracker.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.WindowManager
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceInfoChannel = "budget_tracker/device_info"
    private val secureWindowChannel = "budget_tracker/secure_window"
    private val widgetLaunchChannelName = "budget_tracker/widget_launch"

    private var widgetLaunchChannel: MethodChannel? = null

    /**
     * A home-screen widget quick-add tap that Flutter has not taken yet.
     *
     * Held here because the plugin's own route is lossy: when Android has
     * killed the backgrounded process, a widget tap re-creates this activity
     * with its ORIGINAL intent and delivers the tap through onNewIntent —
     * before the Flutter side is listening — so it was silently dropped and
     * the app opened on Home instead of the Add form. Flutter takes it (once)
     * via [widgetLaunchChannelName] at startup, on resume, and on a nudge.
     */
    private var pendingWidgetLaunch: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Only a fresh launch. A restored activity carries whatever intent
        // first created it, which may be a widget tap from long ago.
        if (savedInstanceState == null) rememberWidgetLaunch(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (rememberWidgetLaunch(intent)) {
            widgetLaunchChannel?.invokeMethod("launched", null)
        }
    }

    private fun rememberWidgetLaunch(intent: Intent?): Boolean {
        if (intent?.action != HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION) return false
        pendingWidgetLaunch = intent.data?.toString() ?: return false
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        widgetLaunchChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            widgetLaunchChannelName,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeLaunch" -> {
                        result.success(pendingWidgetLaunch)
                        pendingWidgetLaunch = null
                    }
                    else -> result.notImplemented()
                }
            }
        }

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
                // The PIN lockout runs on this monotonic clock (ms since
                // boot): changing the system time does not move it.
                "elapsedRealtime" -> {
                    result.success(SystemClock.elapsedRealtime())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
