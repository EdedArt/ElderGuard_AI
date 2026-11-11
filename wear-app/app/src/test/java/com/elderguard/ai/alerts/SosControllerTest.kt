package com.elderguard.ai.alerts

import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.TelemetryStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors tests/sosController.test.js. */
class SosControllerTest {
    private val store = TelemetryStore()
    private var time = 1000L
    private val sos = SosController(store, now = { time })
    private val triggers = mutableListOf<SosTrigger>()

    init {
        sos.onTriggered { triggers += it }
    }

    private val mode get() = store.state.value.deviceStatus.mode

    @Test
    fun triggerSwitchesToSosAndReportsTheReasonTimeAndPosition() {
        sos.trigger(SosReason.Fall)

        assertEquals(DeviceMode.Sos, mode)
        assertTrue(sos.isActive)
        val expected = SosTrigger(SosReason.Fall, 1000L, store.state.value.gps)
        assertEquals(listOf(expected), triggers)
        assertEquals(expected, sos.active.value)
    }

    @Test
    fun aManualTriggerKeepsItsOwnReason() {
        sos.trigger(SosReason.Manual)
        assertEquals(SosReason.Manual, sos.active.value?.reason)
    }

    @Test
    fun aSecondTriggerDuringAnSosIsIgnored() {
        sos.trigger(SosReason.Manual)
        time = 2000L
        sos.trigger(SosReason.Fall)

        assertEquals(1, triggers.size)
        assertEquals(SosReason.Manual, sos.active.value?.reason)
    }

    @Test
    fun cancelGoesBackToMonitoringAndAllowsANewSos() {
        sos.trigger(SosReason.Manual)
        sos.cancel()

        assertEquals(DeviceMode.Monitoring, mode)
        assertFalse(sos.isActive)
        assertNull(sos.active.value)

        sos.trigger(SosReason.Fall)
        assertEquals(2, triggers.size)
    }

    @Test
    fun cancelDoesNothingOutsideAnSos() {
        store.setMode(DeviceMode.FallCountdown)
        sos.cancel()
        assertEquals(DeviceMode.FallCountdown, mode)
    }

    @Test
    fun aRemovedListenerIsNotCalled() {
        var calls = 0
        val remove = sos.onTriggered { calls++ }
        remove()

        sos.trigger(SosReason.Manual)
        assertEquals(0, calls)
        assertEquals(1, triggers.size)
    }
}
