package com.dingo.duel

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Kept in the repo so its package stays com.dingo.duel (the applicationId
// registered on Google Play). Native channels go here when the app needs them.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferFastestRefreshRate()
    }

    // Asked again whenever the app comes back: some phones drop the request
    // while it's in the background.
    override fun onResume() {
        super.onResume()
        preferFastestRefreshRate()
    }

    // The debug menu's "Screen" line (Settings, long-press About).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duel/display").setMethodCallHandler { call, result ->
            if (call.method != "info") return@setMethodCallHandler result.notImplemented()
            val d = currentDisplay()
            val power = getSystemService(Context.POWER_SERVICE) as? PowerManager
            result.success(
                mapOf(
                    "current" to d?.refreshRate?.toDouble(),
                    "modes" to (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) d?.supportedModes?.map { it.refreshRate.toDouble() } else null),
                    "asked" to fastestMode(d)?.refreshRate?.toDouble(),
                    "powerSaver" to (power?.isPowerSaveMode ?: false),
                    "sdk" to Build.VERSION.SDK_INT,
                ),
            )
        }
    }

    private fun currentDisplay(): Display? =
        (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else null)
            ?: @Suppress("DEPRECATION") windowManager.defaultDisplay

    // The display's fastest mode at its current resolution (90 / 120 Hz).
    private fun fastestMode(d: Display?): Display.Mode? {
        if (d == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        val current = d.mode
        return d.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate }
    }

    // Many phones keep an app at 60 Hz unless it asks for more: ask for the
    // display's fastest mode, so animations run at the screen's full rate.
    // Android 15+ may also lower an app's rate to save power unless the app
    // opts out (Pixels do this with Smooth Display on): opt out.
    private fun preferFastestRefreshRate() {
        val fastest = fastestMode(currentDisplay()) ?: return
        window.attributes = window.attributes.also {
            it.preferredDisplayModeId = fastest.modeId
            it.preferredRefreshRate = fastest.refreshRate
        }
        if (Build.VERSION.SDK_INT >= 35) {
            try {
                window.javaClass
                    .getMethod("setFrameRatePowerSavingsBalanced", Boolean::class.javaPrimitiveType)
                    .invoke(window, false)
            } catch (e: Exception) {
                // Not on this phone: the mode request above still applies.
            }
        }
    }
}
