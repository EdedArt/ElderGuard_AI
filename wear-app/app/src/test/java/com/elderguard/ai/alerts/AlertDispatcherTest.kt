package com.elderguard.ai.alerts

import com.elderguard.ai.config.ContactsConfig
import com.elderguard.ai.config.FallDetectionConfig.COUNTDOWN_SECONDS
import com.elderguard.ai.config.FallDetectionConfig.IMMOBILITY_DURATION_MS
import com.elderguard.ai.config.HeartRateAnomalyConfig
import com.elderguard.ai.config.HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD
import com.elderguard.ai.config.HeartRateAnomalyConfig.SUSTAINED_DURATION_MS
import com.elderguard.ai.config.TelemetryConfig.TICK_INTERVAL_MS
import com.elderguard.ai.device.WatchDevice
import com.elderguard.ai.telemetry.Accelerometer
import com.elderguard.ai.telemetry.Battery
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.Gps
import com.elderguard.ai.telemetry.HealthAlert
import com.elderguard.ai.telemetry.HeartRate
import com.elderguard.ai.telemetry.Sensor
import com.elderguard.ai.telemetry.TelemetryState
import com.elderguard.ai.telemetry.batteryPercent
import kotlin.random.Random
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private const val SECOND = 1000L
private const val CRITICAL = 170
private const val TIME_TO_CONFIRM = SUSTAINED_DURATION_MS + TICK_INTERVAL_MS
private val STILL = Accelerometer(0.0, 0.0, 1.0)
private val MOVING = Accelerometer(0.4, 0.5, 1.4)
private val SPIKE = Accelerometer(2.5, 1.8, 3.2)

/** The state and time of the moment an alert went out, as the web test's dispatched spy records. */
private data class AtDispatch(val timestamp: Long, val state: TelemetryState)

/** Mirrors tests/alertDispatcher.test.js on a whole running device, in runTest's virtual time. */
@OptIn(ExperimentalCoroutinesApi::class)
class AlertDispatcherTest {
    private lateinit var device: WatchDevice
    private val atDispatch = mutableListOf<AtDispatch>()

    private val alerts get() = device.alerts.alerts.value
    private val mode get() = device.store.state.value.deviceStatus.mode

    private fun TestScope.startDevice() {
        device = WatchDevice(backgroundScope, now = { testScheduler.currentTime }, random = Random(5))
        // Unconfined: runs as soon as an alert is recorded, so the state it reads is that moment's.
        backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) {
            device.alerts.alerts.collect { list ->
                if (list.size > atDispatch.size) atDispatch += AtDispatch(testScheduler.currentTime, device.store.state.value)
            }
        }
        device.start()
        runCurrent()
    }

    private fun TestScope.advance(millis: Long) {
        advanceTimeBy(millis)
        runCurrent()
    }

    private fun TestScope.holdRate(bpm: Int, accelerometer: Accelerometer = STILL) {
        device.engine.setOverride(Sensor.ACCELEROMETER, accelerometer)
        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(bpm))
        runCurrent()
    }

    private fun TestScope.fall() {
        device.engine.setOverride(Sensor.ACCELEROMETER, SPIKE)
        advance(TICK_INTERVAL_MS)
        device.engine.setOverride(Sensor.ACCELEROMETER, STILL)
        advance(IMMOBILITY_DURATION_MS + TICK_INTERVAL_MS)
    }

    private fun assertAlertShape(alert: AlertPayload, type: AlertType, moment: AtDispatch) {
        val expected = AlertPayload(
            type = type,
            timestamp = moment.timestamp,
            gps = moment.state.gps,
            heartRate = moment.state.heartRate.bpm,
            batteryLevel = batteryPercent(moment.state.battery.level),
            contacts = ContactsConfig.CONTACTS,
        )
        assertEquals(expected, alert)
    }

    @Test
    fun theCriticalThresholdIsAboveTheWarningOneWithTheSameRestLogic() {
        assertEquals(160, CRITICAL_BPM_THRESHOLD)
        assertTrue(CRITICAL_BPM_THRESHOLD > HeartRateAnomalyConfig.BPM_THRESHOLD)
    }

    // --- Alerts that go out ---

    @Test
    fun aFallSosProducesACorrectlyShapedAlert() = runTest {
        startDevice()
        fall()
        assertEquals(DeviceMode.FallCountdown, mode)
        assertEquals(emptyList<AlertPayload>(), alerts)

        advance(COUNTDOWN_SECONDS * SECOND)
        assertEquals(DeviceMode.Sos, mode)
        assertEquals(1, alerts.size)
        assertAlertShape(alerts[0], AlertType.Fall, atDispatch[0])
        assertEquals("fall", alerts[0].type.id)
    }

    @Test
    fun aManualSosProducesACorrectlyShapedAlert() = runTest {
        startDevice()
        advance(SECOND * 3)
        device.sos.trigger(SosReason.Manual)

        assertEquals(1, alerts.size)
        assertAlertShape(alerts[0], AlertType.ManualSos, atDispatch[0])
        assertEquals("manual-sos", alerts[0].type.id)
    }

    @Test
    fun aSustainedCriticalHeartRateProducesACorrectlyShapedAlertWithNoSos() = runTest {
        startDevice()
        holdRate(CRITICAL)
        advance(SUSTAINED_DURATION_MS - 1)
        assertEquals(emptyList<AlertPayload>(), alerts)

        advance(TICK_INTERVAL_MS)
        assertEquals(1, alerts.size)
        assertAlertShape(alerts[0], AlertType.HighHeartRate, atDispatch[0])
        assertEquals(CRITICAL, alerts[0].heartRate)
        assertTrue(device.alerts.criticalActive.value)
        assertEquals(DeviceMode.Monitoring, mode)
    }

    @Test
    fun recordsTheBatteryAndLocationOfThatMomentNotLaterOnes() = runTest {
        startDevice()
        device.engine.setOverride(Sensor.BATTERY, Battery(level = 42.0, charging = false))
        device.engine.setOverride(Sensor.GPS, Gps(lat = 1.0, lng = 2.0, accuracy = 5.0, signal = false))
        device.sos.trigger(SosReason.Manual)
        device.engine.setOverride(Sensor.BATTERY, Battery(level = 5.0, charging = false))
        device.engine.setOverride(Sensor.GPS, Gps(lat = 3.0, lng = 4.0, accuracy = 5.0, signal = true))
        advance(SECOND * 3)

        assertEquals(42, alerts[0].batteryLevel)
        assertEquals(Gps(lat = 1.0, lng = 2.0, accuracy = 5.0, signal = false), alerts[0].gps)
    }

    @Test
    fun keepsEveryAlertOldestFirst() = runTest {
        startDevice()
        device.sos.trigger(SosReason.Manual)
        device.sos.cancel()
        advance(TICK_INTERVAL_MS)
        device.sos.trigger(SosReason.Manual)

        assertEquals(2, alerts.size)
        assertTrue(alerts[1].timestamp > alerts[0].timestamp)
    }

    // --- What does not send an alert ---

    @Test
    fun aResolvedAnomalyBelowTheCriticalThresholdSendsNothing() = runTest {
        startDevice()
        holdRate(140)
        advance(SUSTAINED_DURATION_MS + TICK_INTERVAL_MS)
        assertEquals(HealthAlert.HighHeartRate, device.store.state.value.deviceStatus.healthAlert)

        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(70))
        runCurrent()
        assertEquals(null, device.store.state.value.deviceStatus.healthAlert)

        advance(TICK_INTERVAL_MS * 30)
        assertEquals(emptyList<AlertPayload>(), alerts)
    }

    @Test
    fun aHeartRateExactlyAtTheCriticalThresholdSendsNothing() = runTest {
        startDevice()
        holdRate(CRITICAL_BPM_THRESHOLD)
        advance(TIME_TO_CONFIRM * 3)
        assertEquals(emptyList<AlertPayload>(), alerts)
    }

    @Test
    fun aBriefCriticalSpikeSendsNothing() = runTest {
        startDevice()
        holdRate(CRITICAL)
        advance(SUSTAINED_DURATION_MS - TICK_INTERVAL_MS * 2)
        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(70))
        advance(TICK_INTERVAL_MS * 30)
        assertEquals(emptyList<AlertPayload>(), alerts)
    }

    @Test
    fun aCriticalHeartRateWhileMovingSendsNothing() = runTest {
        startDevice()
        holdRate(CRITICAL, MOVING)
        advance(TIME_TO_CONFIRM * 3)
        assertEquals(emptyList<AlertPayload>(), alerts)
    }

    @Test
    fun aFallCancelledInTimeSendsNothing() = runTest {
        startDevice()
        fall()
        device.fall.cancel()
        advance(COUNTDOWN_SECONDS * SECOND * 2)
        assertEquals(emptyList<AlertPayload>(), alerts)
    }

    // --- One alert per episode ---

    @Test
    fun doesNotRepeatWhileTheCriticalRateLasts() = runTest {
        startDevice()
        holdRate(CRITICAL)
        advance(TIME_TO_CONFIRM + TICK_INTERVAL_MS * 30)
        assertEquals(1, alerts.size)
    }

    @Test
    fun sendsAnotherForANewEpisodeAndReportsTheEndOfTheFirst() = runTest {
        startDevice()
        holdRate(CRITICAL)
        advance(TIME_TO_CONFIRM)
        assertTrue(device.alerts.criticalActive.value)

        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(70))
        runCurrent()
        assertFalse(device.alerts.criticalActive.value)

        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(CRITICAL))
        advance(TIME_TO_CONFIRM)
        assertEquals(2, alerts.size)
    }

    // --- Next to the fall flow ---

    @Test
    fun aCriticalAlertGoesOutDuringACountdownWhichCarriesOn() = runTest {
        startDevice()
        fall()
        assertEquals(DeviceMode.FallCountdown, mode)

        device.engine.setOverride(Sensor.HEART_RATE, HeartRate(CRITICAL))
        advance(SUSTAINED_DURATION_MS)

        assertEquals(listOf(AlertType.HighHeartRate), alerts.map { it.type })
        assertEquals(DeviceMode.FallCountdown, mode)
        assertTrue(device.countdown.isRunning)

        advance(COUNTDOWN_SECONDS * SECOND)
        assertEquals(listOf(AlertType.HighHeartRate, AlertType.Fall), alerts.map { it.type })
    }

    // --- Reset ---

    @Test
    fun resetClearsTheHistoryAndStopsTheCriticalCount() = runTest {
        startDevice()
        device.sos.trigger(SosReason.Manual)
        device.sos.cancel()
        holdRate(CRITICAL)
        advance(TICK_INTERVAL_MS * 3)

        device.alerts.reset()
        assertEquals(emptyList<AlertPayload>(), alerts)

        advance(SUSTAINED_DURATION_MS - TICK_INTERVAL_MS * 2)
        assertEquals(emptyList<AlertPayload>(), alerts)
    }
}
