package com.elderguard.ai.detection

import com.elderguard.ai.config.FallDetectionConfig
import com.elderguard.ai.telemetry.Accelerometer
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.TelemetryStore
import com.elderguard.ai.telemetry.isAtRest
import com.elderguard.ai.telemetry.magnitude
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/** Where the detector is in a fall: the 'idle' / 'impact' / 'immobility' / 'confirmed' of the web app. */
enum class FallState { Idle, Impact, Immobility, Confirmed }

/**
 * Port of src/core/fallDetector.js. A fall is an impact followed by stillness. Either one alone
 * happens in daily life: clapping or bumping the wrist makes a spike, and resting makes stillness.
 * Time comes from the samples, so the detector needs no clock and every scenario can be replayed
 * in a test.
 *
 * The thresholds default to [FallDetectionConfig]; tests can pass others.
 */
class FallDetector(
    private val impactThresholdG: Double = FallDetectionConfig.IMPACT_THRESHOLD_G,
    private val immobilityToleranceG: Double = FallDetectionConfig.IMMOBILITY_TOLERANCE_G,
    private val immobilityDurationMs: Long = FallDetectionConfig.IMMOBILITY_DURATION_MS,
    private val immobilityStartWindowMs: Long = FallDetectionConfig.IMMOBILITY_START_WINDOW_MS,
) {
    var state: FallState = FallState.Idle
        private set

    private var impactAt = 0L
    private var stillSince = 0L

    /**
     * Takes one reading, taken at [timestamp] in milliseconds. Returns true when this reading
     * confirms a fall, which happens once: the detector then stays [FallState.Confirmed] and
     * ignores every reading until [reset].
     */
    fun process(accelerometer: Accelerometer, timestamp: Long): Boolean {
        if (state == FallState.Confirmed) return false

        // Checked first in every state: a new blow restarts the sequence from that moment, so a
        // person who stumbles and then falls for real is still detected.
        if (accelerometer.magnitude >= impactThresholdG) {
            state = FallState.Impact
            impactAt = timestamp
            return false
        }

        val still = accelerometer.isAtRest(immobilityToleranceG)
        when (state) {
            FallState.Impact -> processAfterImpact(still, timestamp)
            FallState.Immobility -> processImmobility(still, timestamp)
            FallState.Idle, FallState.Confirmed -> Unit
        }
        return state == FallState.Confirmed
    }

    /** Forgets any sequence in progress, including a confirmed fall. */
    fun reset() {
        state = FallState.Idle
    }

    private fun processAfterImpact(still: Boolean, timestamp: Long) {
        if (timestamp - impactAt > immobilityStartWindowMs) {
            state = FallState.Idle
        } else if (still) {
            state = FallState.Immobility
            stillSince = timestamp
        }
    }

    private fun processImmobility(still: Boolean, timestamp: Long) {
        if (!still) {
            state = FallState.Idle
        } else if (timestamp - stillSince >= immobilityDurationMs) {
            state = FallState.Confirmed
        }
    }
}

/**
 * Feeds this detector from the telemetry store, in a coroutine launched in [scope] that collects
 * the store's state. Calls [onConfirmed] when a fall is confirmed. [now] gives each reading its
 * time; the store's own lastUpdate would miss readings set between two ticks.
 *
 * Like the store subscription of src/core/fallMonitor.js:
 * - Every new state counts as a reading, not only those where the accelerometer changed: a body
 *   lying perfectly still gives the same reading tick after tick, and the detector needs those
 *   readings to see the time go by. The tick's lastUpdate makes each of them a new state.
 * - Readings count only while the watch is monitoring. In any other mode the detector is reset,
 *   otherwise a fall in progress would resume, with a gap in its timing, after the alert ends.
 * - The first reading after coming back to monitoring is skipped: it still dates from the alert.
 *
 * StateFlow keeps only the latest state, so a reading replaced before the collector gets to run
 * may never be seen. A simulated impact must therefore stay in place for at least one tick.
 */
fun FallDetector.feedFrom(
    store: TelemetryStore,
    scope: CoroutineScope,
    now: () -> Long,
    onConfirmed: () -> Unit,
): Job = scope.launch {
    var previousMode = store.state.value.deviceStatus.mode
    store.state.collect { state ->
        val mode = state.deviceStatus.mode
        val wasMonitoring = previousMode == DeviceMode.Monitoring
        previousMode = mode
        if (mode != DeviceMode.Monitoring) {
            reset()
        } else if (wasMonitoring && process(state.accelerometer, now())) {
            onConfirmed()
        }
    }
}
