package com.elderguard.ai.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import com.elderguard.ai.telemetry.BatteryState
import com.elderguard.ai.telemetry.GpsState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private const val AAA_RATIO = 7.0

/** WCAG contrast ratio. Color.luminance() is the WCAG relative luminance. */
private fun contrast(a: Color, b: Color): Double {
    val lighter = maxOf(a.luminance(), b.luminance())
    val darker = minOf(a.luminance(), b.luminance())
    return (lighter + 0.05) / (darker + 0.05)
}

private fun assertAaa(name: String, foreground: Color, background: Color) {
    val ratio = contrast(foreground, background)
    assertTrue("$name contrast is $ratio, below $AAA_RATIO", ratio >= AAA_RATIO)
}

class WatchColorsTest {
    @Test
    fun statusColorsReachAaaOnTheBlackBackground() {
        for (state in BatteryState.entries) assertAaa("Battery $state", state.color(), WatchColors.Background)
        for (state in GpsState.entries) assertAaa("GPS $state", state.color(), WatchColors.Background)
    }

    @Test
    fun textColorsReachAaa() {
        assertAaa("Text", WatchColors.Text, WatchColors.Background)
        assertAaa("Danger text", WatchColors.DangerText, WatchColors.Background)
        assertAaa("Text on danger", WatchColors.OnDanger, WatchColors.Danger)
        assertAaa("Text on accent", WatchColors.OnAccent, WatchColors.Accent)
        assertAaa("Accent", WatchColors.Accent, WatchColors.Background)
    }

    @Test
    fun theDangerFillIsOutlinedOnBlack() {
        // The dark red fill alone is hard to tell apart from black, so it gets a white outline.
        assertAaa("Danger outline", WatchColors.DangerBorder, WatchColors.Background)
    }

    @Test
    fun mapsStatesLikeTheWebApp() {
        assertEquals(WatchColors.Success, BatteryState.Normal.color())
        assertEquals(WatchColors.Warning, BatteryState.Low.color())
        assertEquals(WatchColors.DangerText, BatteryState.Critical.color())
        assertEquals(WatchColors.Success, GpsState.Ok.color())
        assertEquals(WatchColors.Warning, GpsState.Lost.color())
    }
}
