package com.elderguard.ai.detection

import com.elderguard.ai.config.FallDetectionConfig
import com.elderguard.ai.config.FallDetectionConfig.IMMOBILITY_DURATION_MS
import com.elderguard.ai.config.FallDetectionConfig.IMMOBILITY_START_WINDOW_MS
import com.elderguard.ai.config.FallDetectionConfig.IMMOBILITY_TOLERANCE_G
import com.elderguard.ai.config.FallDetectionConfig.IMPACT_THRESHOLD_G
import com.elderguard.ai.telemetry.Accelerometer
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.TelemetryStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

private val SPIKE = Accelerometer(0.0, 0.0, IMPACT_THRESHOLD_G + 1)
private val STILL = Accelerometer(0.0, 0.0, 1.0)
private val MOVING = Accelerometer(0.0, 0.0, 1 + IMMOBILITY_TOLERANCE_G + 0.3)

/** Mirrors tests/fallDetector.test.js. */
class FallDetectorTest {
    private val detector = FallDetector()
    private var confirmed = 0

    private fun feed(timestamp: Long, accelerometer: Accelerometer) {
        if (detector.process(accelerometer, timestamp)) confirmed++
    }

    // A reading once per second over [from, to], like the telemetry engine.
    private fun feedEverySecond(from: Long, to: Long, accelerometer: Accelerometer) {
        for (timestamp in from..to step 1000) feed(timestamp, accelerometer)
    }

    private fun z(value: Double) = Accelerometer(0.0, 0.0, value)

    // --- Real fall ---

    @Test
    fun aRealFallWalksThroughEveryStateAndConfirmsOnce() {
        assertEquals(FallState.Idle, detector.state)

        feed(0, SPIKE)
        assertEquals(FallState.Impact, detector.state)

        feed(1000, STILL)
        assertEquals(FallState.Immobility, detector.state)
        assertEquals(0, confirmed)

        feed(1000 + IMMOBILITY_DURATION_MS - 1, STILL)
        assertEquals(FallState.Immobility, detector.state)
        assertEquals(0, confirmed)

        feed(1000 + IMMOBILITY_DURATION_MS, STILL)
        assertEquals(FallState.Confirmed, detector.state)
        assertEquals(1, confirmed)
    }

    @Test
    fun confirmsWithStillnessInAnyOrientationOfTheWatch() {
        feed(0, SPIKE)
        feedEverySecond(1000, 1000 + IMMOBILITY_DURATION_MS, Accelerometer(1.0, 0.0, 0.0))
        assertEquals(1, confirmed)
    }

    @Test
    fun acceptsSmallNoiseWithinTheTolerance() {
        feed(0, SPIKE)
        feed(1000, z(1 + IMMOBILITY_TOLERANCE_G - 0.01))
        feed(2000, z(1 - IMMOBILITY_TOLERANCE_G + 0.01))
        feed(1000 + IMMOBILITY_DURATION_MS, STILL)
        assertEquals(1, confirmed)
    }

    @Test
    fun acceptsASpikeExactlyAtTheThreshold() {
        feed(0, z(IMPACT_THRESHOLD_G))
        assertEquals(FallState.Impact, detector.state)
    }

    @Test
    fun staysConfirmedAndDoesNotConfirmAgainUntilReset() {
        feed(0, SPIKE)
        feedEverySecond(1000, 1000 + IMMOBILITY_DURATION_MS, STILL)

        feed(10_000, SPIKE)
        feedEverySecond(11_000, 11_000 + IMMOBILITY_DURATION_MS, STILL)

        assertEquals(FallState.Confirmed, detector.state)
        assertEquals(1, confirmed)
    }

    // --- False alarms ---

    @Test
    fun aSpikeFollowedByMovementDoesNotConfirm() {
        feed(0, SPIKE)
        feedEverySecond(1000, 1000 + IMMOBILITY_START_WINDOW_MS + IMMOBILITY_DURATION_MS, MOVING)

        assertEquals(FallState.Idle, detector.state)
        assertEquals(0, confirmed)
    }

    @Test
    fun anyMovementDuringImmobilityReturnsToIdle() {
        feed(0, SPIKE)
        feed(1000, STILL)
        feed(1000 + IMMOBILITY_DURATION_MS - 1, MOVING)
        assertEquals(FallState.Idle, detector.state)

        feed(1000 + IMMOBILITY_DURATION_MS, STILL)
        feed(1000 + IMMOBILITY_DURATION_MS * 2, STILL)
        assertEquals(0, confirmed)
    }

    @Test
    fun stillnessWithoutASpikeDoesNotConfirm() {
        feedEverySecond(0, IMMOBILITY_DURATION_MS * 3, STILL)

        assertEquals(FallState.Idle, detector.state)
        assertEquals(0, confirmed)
    }

    @Test
    fun aSlowSitDownBelowTheThresholdDoesNotConfirm() {
        val sitDown = listOf(1.0, 1.2, 1.6, 2.1, IMPACT_THRESHOLD_G - 0.01, 1.8, 1.3, 1.0)
        sitDown.forEachIndexed { index, value -> feed(index * 500L, z(value)) }
        assertEquals(FallState.Idle, detector.state)

        feedEverySecond(5000, 5000 + IMMOBILITY_DURATION_MS * 2, STILL)
        assertEquals(0, confirmed)
    }

    @Test
    fun stillnessThatStartsTooLateDoesNotConfirm() {
        feed(0, SPIKE)
        feed(1000, MOVING)
        feed(IMMOBILITY_START_WINDOW_MS + 1, STILL)
        assertEquals(FallState.Idle, detector.state)

        feedEverySecond(IMMOBILITY_START_WINDOW_MS + 1001, IMMOBILITY_DURATION_MS * 3, STILL)
        assertEquals(0, confirmed)
    }

    @Test
    fun acceptsStillnessThatStartsAtTheVeryEndOfTheWindow() {
        feed(0, SPIKE)
        feed(IMMOBILITY_START_WINDOW_MS, STILL)
        assertEquals(FallState.Immobility, detector.state)
    }

    // --- Repeated impacts ---

    @Test
    fun restartsTheWindowFromTheLatestImpact() {
        feed(0, SPIKE)
        feed(2000, SPIKE)
        feed(2000 + IMMOBILITY_START_WINDOW_MS, STILL)
        assertEquals(FallState.Immobility, detector.state)
    }

    @Test
    fun aSecondImpactDuringImmobilityRestartsTheSequenceInsteadOfIdling() {
        feed(0, SPIKE)
        feed(1000, STILL)
        feed(2000, SPIKE)
        assertEquals(FallState.Impact, detector.state)

        feed(3000, STILL)
        feed(3000 + IMMOBILITY_DURATION_MS - 1, STILL)
        assertEquals(0, confirmed)
        feed(3000 + IMMOBILITY_DURATION_MS, STILL)
        assertEquals(1, confirmed)
    }

    @Test
    fun canDetectAFallAfterAnEarlierFalseAlarm() {
        feed(0, SPIKE)
        feed(1000, STILL)
        feed(2000, MOVING)

        feed(3000, SPIKE)
        feedEverySecond(4000, 4000 + IMMOBILITY_DURATION_MS, STILL)
        assertEquals(1, confirmed)
    }

    // --- Reset ---

    @Test
    fun resetReturnsToIdleFromEveryState() {
        val reach = mapOf<FallState, () -> Unit>(
            FallState.Impact to { feed(0, SPIKE) },
            FallState.Immobility to {
                feed(0, SPIKE)
                feed(1000, STILL)
            },
            FallState.Confirmed to {
                feed(0, SPIKE)
                feedEverySecond(1000, 1000 + IMMOBILITY_DURATION_MS, STILL)
            },
        )
        for ((state, reachState) in reach) {
            reachState()
            assertEquals(state, detector.state)
            detector.reset()
            assertEquals("Reset from $state", FallState.Idle, detector.state)
        }
    }

    @Test
    fun resetForgetsAFallInProgress() {
        feed(0, SPIKE)
        feed(1000, STILL)
        detector.reset()

        feedEverySecond(2000, 2000 + IMMOBILITY_DURATION_MS, STILL)
        assertEquals(0, confirmed)
    }

    @Test
    fun resetAllowsANewDetectionAfterAConfirmedFall() {
        feed(0, SPIKE)
        feedEverySecond(1000, 1000 + IMMOBILITY_DURATION_MS, STILL)
        detector.reset()

        feed(20_000, SPIKE)
        feedEverySecond(21_000, 21_000 + IMMOBILITY_DURATION_MS, STILL)
        assertEquals(2, confirmed)
    }

    // --- Configuration ---

    @Test
    fun hasTheDocumentedDefaultValues() {
        assertEquals(2.5, FallDetectionConfig.IMPACT_THRESHOLD_G, 0.0)
        assertEquals(0.15, FallDetectionConfig.IMMOBILITY_TOLERANCE_G, 0.0)
        assertEquals(5000L, FallDetectionConfig.IMMOBILITY_DURATION_MS)
        assertEquals(3000L, FallDetectionConfig.IMMOBILITY_START_WINDOW_MS)
        assertEquals(10, FallDetectionConfig.COUNTDOWN_SECONDS)
        assertEquals(3, FallDetectionConfig.URGENT_SECONDS)
    }

    @Test
    fun takesEveryThresholdFromItsParameters() {
        val custom = FallDetector(
            impactThresholdG = 5.0,
            immobilityToleranceG = 0.5,
            immobilityDurationMs = 100,
            immobilityStartWindowMs = 50,
        )

        custom.process(z(4.0), 0)
        assertEquals(FallState.Idle, custom.state)

        custom.process(z(5.0), 0)
        assertEquals(FallState.Impact, custom.state)

        custom.process(z(1.4), 50)
        assertEquals(FallState.Immobility, custom.state)

        assertEquals(true, custom.process(z(0.6), 150))
    }
}

/** The coroutine that feeds the detector from the store, like fallMonitor.js's subscription. */
@OptIn(ExperimentalCoroutinesApi::class)
class FallDetectorFeedTest {
    private val store = TelemetryStore()
    private val detector = FallDetector()
    private var time = 0L
    private var confirmed = 0

    // Unconfined: the collector handles each state as soon as it is set, so none is skipped.
    // backgroundScope's job is kept, so the collector is cancelled when the test ends.
    private fun TestScope.startFeed() {
        val scope = CoroutineScope(backgroundScope.coroutineContext + UnconfinedTestDispatcher(testScheduler))
        detector.feedFrom(store, scope, now = { time }) { confirmed++ }
    }

    private fun reading(accelerometer: Accelerometer, atMs: Long) {
        time = atMs
        // A new lastUpdate on every reading, as each engine tick writes one.
        store.update { it.copy(accelerometer = accelerometer, deviceStatus = it.deviceStatus.copy(lastUpdate = atMs)) }
    }

    private fun fallFrom(startMs: Long) {
        reading(SPIKE, startMs)
        for (offset in 1000L..1000L + IMMOBILITY_DURATION_MS step 1000) reading(STILL, startMs + offset)
    }

    @Test
    fun confirmsAFallFedThroughTheStore() = runTest {
        startFeed()
        fallFrom(1000)
        assertEquals(1, confirmed)
    }

    @Test
    fun countsAReadingThatRepeatsTheSameAccelerometerValue() = runTest {
        startFeed()
        reading(SPIKE, 0)
        // Identical readings: only lastUpdate changes, which still makes each a new sample.
        reading(STILL, 1000)
        reading(STILL, 1000 + IMMOBILITY_DURATION_MS)
        assertEquals(1, confirmed)
    }

    @Test
    fun ignoresReadingsAndForgetsTheSequenceWhileNotMonitoring() = runTest {
        startFeed()
        reading(SPIKE, 0)
        reading(STILL, 1000)
        assertEquals(FallState.Immobility, detector.state)

        store.setMode(DeviceMode.Sos)
        assertEquals(FallState.Idle, detector.state)
        fallFrom(2000)
        assertEquals(0, confirmed)

        store.setMode(DeviceMode.Monitoring)
        fallFrom(20_000)
        assertEquals(1, confirmed)
    }
}
