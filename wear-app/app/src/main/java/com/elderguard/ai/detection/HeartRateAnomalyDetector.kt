package com.elderguard.ai.detection

import com.elderguard.ai.config.HeartRateAnomalyConfig
import com.elderguard.ai.telemetry.Accelerometer
import com.elderguard.ai.telemetry.isAtRest

/** The 'normal' / 'elevated' / 'warning' states of the web app's detector. */
enum class AnomalyState { Normal, Elevated, Warning }

/** What a reading changed: the web app's 'warning' and 'resolved' events. */
enum class AnomalyEvent { Warning, Resolved }

/**
 * Port of src/core/heartRateAnomalyDetector.js. A fast heart is expected while moving and harmless
 * for a moment, so only one that stays fast at rest counts. Time comes from the samples, so every
 * case can be replayed in a test.
 *
 * The thresholds default to the warning level of [HeartRateAnomalyConfig]; the alert dispatcher
 * runs a second detector with the critical threshold.
 */
class HeartRateAnomalyDetector(
    private val bpmThreshold: Int = HeartRateAnomalyConfig.BPM_THRESHOLD,
    private val sustainedDurationMs: Long = HeartRateAnomalyConfig.SUSTAINED_DURATION_MS,
    private val stillnessToleranceG: Double = HeartRateAnomalyConfig.STILLNESS_TOLERANCE_G,
) {
    var state: AnomalyState = AnomalyState.Normal
        private set

    private var elevatedSince = 0L

    /**
     * Takes one reading, taken at [timestamp] in milliseconds. Returns [AnomalyEvent.Warning] when
     * this reading completes the sustained time, [AnomalyEvent.Resolved] when it ends a warning,
     * and null otherwise. The state is already updated when it returns.
     */
    fun process(heartRateBpm: Int, accelerometer: Accelerometer, timestamp: Long): AnomalyEvent? {
        val elevated = heartRateBpm > bpmThreshold
        if (!elevated || !accelerometer.isAtRest(stillnessToleranceG)) {
            val wasWarning = state == AnomalyState.Warning
            state = AnomalyState.Normal
            return if (wasWarning) AnomalyEvent.Resolved else null
        }

        if (state == AnomalyState.Normal) {
            state = AnomalyState.Elevated
            elevatedSince = timestamp
        }
        if (state == AnomalyState.Elevated && timestamp - elevatedSince >= sustainedDurationMs) {
            state = AnomalyState.Warning
            return AnomalyEvent.Warning
        }
        return null
    }

    /** Starts over without reporting anything: whoever resets knows the warning is gone. */
    fun reset() {
        state = AnomalyState.Normal
    }
}
