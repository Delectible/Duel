package com.dingo.duel

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

// Kept in the repo so its package stays com.dingo.duel (the applicationId
// registered on Google Play). Native channels go here when the app needs them.
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferFastestRefreshRate()
    }

    // Many phones keep an app at 60 Hz unless it asks for more: ask for the
    // display's fastest mode at its current resolution (90 / 120 Hz), so
    // animations run at the screen's full rate.
    private fun preferFastestRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else null)
            ?: @Suppress("DEPRECATION") windowManager.defaultDisplay
            ?: return
        val current = display.mode
        val fastest = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return
        if (fastest.modeId == current.modeId && fastest.refreshRate <= current.refreshRate) return
        window.attributes = window.attributes.also { it.preferredDisplayModeId = fastest.modeId }
    }
}
