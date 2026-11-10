package com.elderguard.ai.telemetry

import org.junit.Assert.assertEquals
import org.junit.Test

// Same cases as tests/watchStatus.test.js in the web app.
class WatchStatusTest {
    @Test
    fun roundsTheBatteryPercentHalfUp() {
        assertEquals(100, batteryPercent(99.5))
        assertEquals(99, batteryPercent(99.49))
        assertEquals(0, batteryPercent(0.0))
    }

    @Test
    fun batteryIsNormalAboveTwenty() {
        assertEquals(BatteryState.Normal, batteryState(100.0))
        assertEquals(BatteryState.Normal, batteryState(21.0))
        assertEquals(BatteryState.Normal, batteryState(20.01))
    }

    @Test
    fun batteryIsLowFromTwentyDownToJustAboveTen() {
        assertEquals(BatteryState.Low, batteryState(20.0))
        assertEquals(BatteryState.Low, batteryState(11.0))
        assertEquals(BatteryState.Low, batteryState(10.01))
    }

    @Test
    fun batteryIsCriticalAtTenAndBelow() {
        assertEquals(BatteryState.Critical, batteryState(10.0))
        assertEquals(BatteryState.Critical, batteryState(1.0))
        assertEquals(BatteryState.Critical, batteryState(0.0))
    }

    @Test
    fun displayedStateUsesTheRoundedPercent() {
        // 20.4 % is shown as "20 %", so it must look low, not normal.
        assertEquals(BatteryState.Low, Battery(level = 20.4, charging = false).displayState)
        assertEquals(BatteryState.Normal, Battery(level = 20.6, charging = false).displayState)
    }

    @Test
    fun gpsIsOkWithSignalAndLostWithoutIt() {
        val gps = TelemetryState.initial().gps
        assertEquals(GpsState.Ok, gpsState(gps))
        assertEquals(GpsState.Lost, gpsState(gps.copy(signal = false)))
    }
}
