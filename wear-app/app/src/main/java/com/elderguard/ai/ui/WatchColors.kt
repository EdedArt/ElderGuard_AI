package com.elderguard.ai.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.SemanticsPropertyKey
import androidx.compose.ui.semantics.SemanticsPropertyReceiver
import com.elderguard.ai.telemetry.BatteryState
import com.elderguard.ai.telemetry.GpsState

/**
 * The web app's dark-theme tokens (src/styles/tokens.css), reused on the watch's black background.
 * Every text/background pair reaches the WCAG AAA ratio of 7:1 (checked in WatchColorsTest).
 */
object WatchColors {
    val Background = Color(0xFF000000)
    val Text = Color(0xFFFFFFFF)

    // Danger: SOS button and SOS screen fill, with white text and a white outline.
    val Danger = Color(0xFFB00000)
    val OnDanger = Color(0xFFFFFFFF)
    val DangerBorder = Color(0xFFFFFFFF)

    // Danger-colored text on the black background. The fill red is too dark for text on black.
    val DangerText = Color(0xFFFF8A80)
    val Warning = Color(0xFFFFC233)

    // Text on a warning (amber) fill, such as the fall countdown and the heart rate banner.
    val OnWarning = Color(0xFF000000)
    val Success = Color(0xFF4ADE80)

    // Selected and interactive elements, such as the chosen language.
    val Accent = Color(0xFF7CC4FF)
    val OnAccent = Color(0xFF000000)
}

/** Same semantics as the web app: green when fine, amber when low, red when critical. */
fun BatteryState.color(): Color = when (this) {
    BatteryState.Normal -> WatchColors.Success
    BatteryState.Low -> WatchColors.Warning
    BatteryState.Critical -> WatchColors.DangerText
}

/** Green with signal, amber without it. */
fun GpsState.color(): Color = when (this) {
    GpsState.Ok -> WatchColors.Success
    GpsState.Lost -> WatchColors.Warning
}

/** The color an indicator shows, exposed to UI tests, which cannot read pixels without a device. */
val StatusColorKey = SemanticsPropertyKey<Color>("StatusColor")
var SemanticsPropertyReceiver.statusColor by StatusColorKey
