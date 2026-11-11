package com.elderguard.ai.detection

import com.elderguard.ai.config.FallDetectionConfig
import com.elderguard.ai.config.HeartRateAnomalyConfig
import com.elderguard.ai.config.HeartRateAnomalyConfig.BPM_THRESHOLD
import com.elderguard.ai.config.HeartRateAnomalyConfig.STILLNESS_TOLERANCE_G
import com.elderguard.ai.config.HeartRateAnomalyConfig.SUSTAINED_DURATION_MS
import com.elderguard.ai.telemetry.Accelerometer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private const val HIGH = BPM_THRESHOLD + 20
private val STILL = Accelerometer(0.0, 0.0, 1.0)
private val MOVING = Accelerometer(0.4, 0.5, 1.4)

/** Mirrors tests/heartRateAnomalyDetector.test.js. */
class HeartRateAnomalyDetectorTest {
    private val detector = HeartRateAnomalyDetector()
    private var time = 0L
    private val events = mutableListOf<AnomalyEvent>()

    private val warnings get() = events.count { it == AnomalyEvent.Warning }
    private val resolutions get() = events.count { it == AnomalyEvent.Resolved }

    private fun sample(heartRate: Int, accelerometer: Accelerometer = STILL, elapsedMs: Long = 1000) {
        time += elapsedMs
        detector.process(heartRate, accelerometer, time)?.let { events += it }
    }

    private fun reachWarning() {
        sample(HIGH)
        sample(HIGH, STILL, SUSTAINED_DURATION_MS)
    }

    // --- Configuration ---

    @Test
    fun hasTheAgreedValuesSharingTheStillnessToleranceOfTheFallDetector() {
        assertEquals(120, HeartRateAnomalyConfig.BPM_THRESHOLD)
        assertEquals(8000L, HeartRateAnomalyConfig.SUSTAINED_DURATION_MS)
        assertEquals(FallDetectionConfig.IMMOBILITY_TOLERANCE_G, HeartRateAnomalyConfig.STILLNESS_TOLERANCE_G, 0.0)
        assertEquals(160, HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD)
        assertTrue(HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD > HeartRateAnomalyConfig.BPM_THRESHOLD)
    }

    // --- Reaching the warning ---

    @Test
    fun startsNormal() {
        assertEquals(AnomalyState.Normal, detector.state)
    }

    @Test
    fun sustainedHighBpmAtRestWarnsCountingFromTheFirstHighSample() {
        sample(HIGH)
        assertEquals(AnomalyState.Elevated, detector.state)

        sample(HIGH, STILL, SUSTAINED_DURATION_MS - 1)
        assertEquals(AnomalyState.Elevated, detector.state)
        assertEquals(0, warnings)

        sample(HIGH, STILL, 1)
        assertEquals(AnomalyState.Warning, detector.state)
        assertEquals(1, warnings)
    }

    @Test
    fun warnsOnlyOnceWhileTheConditionLasts() {
        reachWarning()
        repeat(20) { sample(HIGH) }
        assertEquals(1, warnings)
    }

    @Test
    fun needsTheHeartRateAboveTheThresholdNotAtIt() {
        repeat(20) { sample(BPM_THRESHOLD) }
        assertEquals(AnomalyState.Normal, detector.state)

        sample(BPM_THRESHOLD + 1)
        assertEquals(AnomalyState.Elevated, detector.state)
    }

    // --- What does not warn ---

    @Test
    fun ignoresNormalHeartRates() {
        repeat(30) { sample(70) }
        assertEquals(0, warnings)
    }

    @Test
    fun aBriefSpikeDoesNotWarnAndTheCountStartsOverAfterIt() {
        sample(HIGH)
        sample(HIGH, STILL, SUSTAINED_DURATION_MS - 1000)
        sample(70)
        assertEquals(AnomalyState.Normal, detector.state)

        sample(HIGH)
        sample(HIGH, STILL, SUSTAINED_DURATION_MS - 1)
        assertEquals(0, warnings)
    }

    @Test
    fun movementPreventsTheWarningHoweverLongItLasts() {
        repeat(30) { sample(HIGH, MOVING) }
        assertEquals(AnomalyState.Normal, detector.state)
        assertEquals(0, warnings)
    }

    @Test
    fun movementInterruptingTheCountStartsItOver() {
        sample(HIGH)
        sample(HIGH, STILL, SUSTAINED_DURATION_MS - 1000)
        sample(HIGH, MOVING)
        sample(HIGH)
        sample(HIGH, STILL, SUSTAINED_DURATION_MS - 1)
        assertEquals(0, warnings)
    }

    @Test
    fun treatsTheEdgeOfTheToleranceAsRestingAndPastItAsMoving() {
        sample(HIGH, Accelerometer(0.0, 0.0, 1 + STILLNESS_TOLERANCE_G))
        assertEquals(AnomalyState.Elevated, detector.state)
        sample(HIGH, Accelerometer(0.0, 0.0, 1 + STILLNESS_TOLERANCE_G + 0.01))
        assertEquals(AnomalyState.Normal, detector.state)
    }

    @Test
    fun countsAnyOrientationAsRestingSinceOnlyTheMagnitudeMatters() {
        sample(HIGH, Accelerometer(0.6, 0.8, 0.0))
        assertEquals(AnomalyState.Elevated, detector.state)
    }

    // --- Going back to normal ---

    @Test
    fun resolvesWhenTheHeartRateDrops() {
        reachWarning()
        sample(70)
        assertEquals(AnomalyState.Normal, detector.state)
        assertEquals(1, resolutions)
    }

    @Test
    fun resolvesWhenMovementResumes() {
        reachWarning()
        sample(HIGH, MOVING)
        assertEquals(AnomalyState.Normal, detector.state)
        assertEquals(1, resolutions)
    }

    @Test
    fun doesNotReportResolvedIfNoWarningHadBeenGiven() {
        sample(HIGH)
        sample(70)
        assertEquals(0, resolutions)
    }

    @Test
    fun canWarnAgainAfterTheFullTime() {
        reachWarning()
        sample(70)
        reachWarning()
        assertEquals(2, warnings)
    }

    // --- Reset ---

    @Test
    fun resetGoesBackToNormalWithoutReportingAnything() {
        reachWarning()
        detector.reset()
        assertEquals(AnomalyState.Normal, detector.state)
        assertEquals(0, resolutions)
    }

    @Test
    fun resetForgetsTheTimeAlreadyCounted() {
        sample(HIGH)
        sample(HIGH, STILL, SUSTAINED_DURATION_MS - 1000)
        detector.reset()
        sample(HIGH)
        assertEquals(AnomalyState.Elevated, detector.state)
        assertEquals(0, warnings)
    }

    // --- Other thresholds ---

    @Test
    fun takesItsThresholdsFromItsParameters() {
        val critical = HeartRateAnomalyDetector(bpmThreshold = 160, sustainedDurationMs = 2000)

        assertEquals(null, critical.process(150, STILL, 0))
        assertEquals(null, critical.process(150, STILL, 5000))

        assertEquals(null, critical.process(170, STILL, 6000))
        assertEquals(AnomalyEvent.Warning, critical.process(170, STILL, 8000))
    }
}
