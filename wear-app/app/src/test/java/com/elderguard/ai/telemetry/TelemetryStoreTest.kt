package com.elderguard.ai.telemetry

import com.elderguard.ai.config.TelemetryConfig
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class TelemetryStoreTest {
    @Test
    fun startsWithTheDocumentedState() {
        val expected = TelemetryState(
            heartRate = HeartRate(70),
            accelerometer = Accelerometer(0.0, 0.0, 1.0),
            gps = Gps(
                lat = TelemetryConfig.Gps.BASE_LAT,
                lng = TelemetryConfig.Gps.BASE_LNG,
                accuracy = TelemetryConfig.Gps.ACCURACY_MIN,
                signal = true,
            ),
            battery = Battery(level = TelemetryConfig.Battery.START_LEVEL, charging = false),
            deviceStatus = DeviceStatus(mode = DeviceMode.Monitoring, lastUpdate = null),
        )

        assertEquals(expected, TelemetryStore().state.value)
    }

    @Test
    fun updateMergesNestedValuesAndKeepsTheRest() {
        val store = TelemetryStore()
        val before = store.state.value

        store.update { it.copy(gps = it.gps.copy(signal = false)) }

        val after = store.state.value
        assertEquals(before.gps.copy(signal = false), after.gps)
        assertEquals(before.copy(gps = after.gps), after)
    }

    @Test
    fun updateChangesSeveralSensorsAtOnce() {
        val store = TelemetryStore()

        store.update {
            it.copy(heartRate = HeartRate(90), battery = it.battery.copy(level = 50.0))
        }

        val state = store.state.value
        assertEquals(HeartRate(90), state.heartRate)
        assertEquals(Battery(level = 50.0, charging = false), state.battery)
    }

    @Test
    fun updatesBuildOnEachOther() {
        val store = TelemetryStore()

        store.update { it.copy(heartRate = HeartRate(90)) }
        store.update { it.copy(heartRate = HeartRate(it.heartRate.bpm + 1)) }

        assertEquals(HeartRate(91), store.state.value.heartRate)
    }

    @Test
    fun resetRestoresTheInitialState() {
        val store = TelemetryStore()
        store.update {
            it.copy(
                heartRate = HeartRate(150),
                gps = it.gps.copy(signal = false),
                deviceStatus = DeviceStatus(DeviceMode.Sos, lastUpdate = 12345L),
            )
        }

        store.reset()

        assertEquals(TelemetryState.initial(), store.state.value)
        assertNull(store.state.value.deviceStatus.lastUpdate)
    }

    @Test
    fun subscribersSeeOnlyRealChanges() = runTest {
        val store = TelemetryStore()
        val seen = mutableListOf<Int>()
        // Unconfined: the collector runs as soon as a value is emitted, so none is skipped.
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            store.state.collect { seen += it.heartRate.bpm }
        }

        store.update { it.copy(heartRate = HeartRate(90)) }
        store.update { it.copy(heartRate = HeartRate(90)) } // Same value: no emission
        store.reset()
        store.reset() // Already initial: no emission

        assertEquals(listOf(70, 90, 70), seen)
    }
}
