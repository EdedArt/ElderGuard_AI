package com.elderguard.ai.alerts

import com.elderguard.ai.config.FallDetectionConfig.COUNTDOWN_SECONDS
import com.elderguard.ai.config.FallDetectionConfig.IMMOBILITY_DURATION_MS
import com.elderguard.ai.config.HeartRateAnomalyConfig.SUSTAINED_DURATION_MS
import com.elderguard.ai.config.TelemetryConfig.TICK_INTERVAL_MS
import com.elderguard.ai.detection.AnomalyState
import com.elderguard.ai.device.WatchDevice
import com.elderguard.ai.telemetry.Accelerometer
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.HealthAlert
import com.elderguard.ai.telemetry.HeartRate
import com.elderguard.ai.telemetry.Sensor
import kotlin.random.Random
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private val STILL = Accelerometer(0.0, 0.0, 1.0)
private val MOVING = Accelerometer(0.4, 0.5, 1.4)
private val SPIKE = Accelerometer(2.5, 1.8, 3.2)
private const val HIGH = 140
private const val SECOND = 1000L

/**
 * The monitor on a whole running device, as in tests/heartRateMonitor.test.js and
 * tests/alerts.integration.test.js. The engine ticks on runTest's virtual time.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class HeartRateMonitorTest {
    private fun TestScope.startDevice(): WatchDevice =
        WatchDevice(backgroundScope, now = { testScheduler.currentTime }, random = Random(3)).also {
            it.start()
            runCurrent()
        }

    private fun TestScope.advance(millis: Long) {
        advanceTimeBy(millis)
        runCurrent()
    }

    private val WatchDevice.healthAlert get() = store.state.value.deviceStatus.healthAlert
    private val WatchDevice.mode get() = store.state.value.deviceStatus.mode

    private fun TestScope.holdRate(device: WatchDevice, bpm: Int, accelerometer: Accelerometer = STILL) {
        device.engine.setOverride(Sensor.ACCELEROMETER, accelerometer)
        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(bpm))
        runCurrent()
    }

    private fun TestScope.fall(device: WatchDevice) {
        device.engine.setOverride(Sensor.ACCELEROMETER, SPIKE)
        advance(TICK_INTERVAL_MS)
        device.engine.setOverride(Sensor.ACCELEROMETER, STILL)
        advance(IMMOBILITY_DURATION_MS + TICK_INTERVAL_MS)
    }

    @Test
    fun sustainedHighBpmAtRestSetsTheHealthAlert() = runTest {
        val device = startDevice()
        holdRate(device, HIGH)

        advance(SUSTAINED_DURATION_MS - SECOND)
        assertNull(device.healthAlert)

        advance(SECOND * 2)
        assertEquals(HealthAlert.HighHeartRate, device.healthAlert)
        assertEquals(AnomalyState.Warning, device.heartRate.detectorState)
        // A warning, not an alert: the watch keeps monitoring.
        assertEquals(DeviceMode.Monitoring, device.mode)
    }

    @Test
    fun aBriefSpikeDoesNotSetIt() = runTest {
        val device = startDevice()
        holdRate(device, HIGH)
        advance(SUSTAINED_DURATION_MS - SECOND * 2)
        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(70))
        advance(SECOND * 30)

        assertNull(device.healthAlert)
    }

    @Test
    fun movementPreventsIt() = runTest {
        val device = startDevice()
        holdRate(device, HIGH, MOVING)
        advance(SUSTAINED_DURATION_MS * 3)

        assertNull(device.healthAlert)
    }

    @Test
    fun clearsItWhenTheBpmDrops() = runTest {
        val device = startDevice()
        holdRate(device, HIGH)
        advance(SUSTAINED_DURATION_MS + SECOND)

        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(70))
        runCurrent()
        assertNull(device.healthAlert)
        assertEquals(AnomalyState.Normal, device.heartRate.detectorState)
    }

    @Test
    fun clearsItWhenMovementResumes() = runTest {
        val device = startDevice()
        holdRate(device, HIGH)
        advance(SUSTAINED_DURATION_MS + SECOND)

        device.engine.setOverride(Sensor.ACCELEROMETER, MOVING)
        runCurrent()
        assertNull(device.healthAlert)
    }

    @Test
    fun resetClearsItAndTheTimeCounted() = runTest {
        val device = startDevice()
        holdRate(device, HIGH)
        advance(SUSTAINED_DURATION_MS + SECOND)

        device.heartRate.reset()
        assertNull(device.healthAlert)
        advance(SUSTAINED_DURATION_MS - SECOND)
        assertNull(device.healthAlert)
    }

    @Test
    fun coexistsIndependentlyWithAFallCountdown() = runTest {
        val device = startDevice()
        fall(device)
        assertEquals(DeviceMode.FallCountdown, device.mode)

        // A high rate during the countdown warns, and the countdown carries on.
        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(HIGH))
        // Past the sustained time, still within the countdown.
        advance(SUSTAINED_DURATION_MS + SECOND / 2)
        assertEquals(HealthAlert.HighHeartRate, device.healthAlert)
        assertEquals(DeviceMode.FallCountdown, device.mode)
        assertTrue(device.countdown.isRunning)

        // Cancelling the fall leaves the warning in place.
        device.fall.cancel()
        runCurrent()
        assertEquals(DeviceMode.Monitoring, device.mode)
        assertEquals(HealthAlert.HighHeartRate, device.healthAlert)

        // Resolving the warning does not touch a new fall countdown either.
        fall(device)
        assertEquals(DeviceMode.FallCountdown, device.mode)
        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(70))
        runCurrent()
        assertNull(device.healthAlert)
        assertEquals(DeviceMode.FallCountdown, device.mode)
        advance(COUNTDOWN_SECONDS * SECOND)
        assertEquals(DeviceMode.Sos, device.mode)
    }
}
