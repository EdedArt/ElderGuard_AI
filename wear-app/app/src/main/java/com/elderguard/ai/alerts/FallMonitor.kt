package com.elderguard.ai.alerts

import com.elderguard.ai.config.FallDetectionConfig
import com.elderguard.ai.detection.FallDetector
import com.elderguard.ai.detection.feedFrom
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.TelemetryStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

/**
 * Port of src/core/fallMonitor.js: connects the detector to the telemetry stream and runs the
 * alert that follows a detection.
 *
 * A confirmed fall switches the watch to [DeviceMode.FallCountdown] and starts [countdown]. If
 * nobody cancels it in [FallDetectionConfig.COUNTDOWN_SECONDS], [onCountdownComplete] calls for
 * help. Leaving the countdown mode by any other way stops the countdown.
 */
class FallMonitor(
    private val store: TelemetryStore,
    private val countdown: Countdown,
    scope: CoroutineScope,
    now: () -> Long,
    private val onCountdownComplete: () -> Unit,
    private val detector: FallDetector = FallDetector(),
) {
    init {
        detector.feedFrom(store, scope, now) {
            store.setMode(DeviceMode.FallCountdown)
            countdown.start(FallDetectionConfig.COUNTDOWN_SECONDS, onCountdownComplete)
        }
        scope.launch {
            store.state.map { it.deviceStatus.mode }.distinctUntilChanged().collect { mode ->
                if (mode != DeviceMode.FallCountdown) countdown.cancel()
            }
        }
    }

    /** "I'm OK": stops the countdown and goes back to monitoring. Only acts during a countdown. */
    fun cancel() {
        if (store.state.value.deviceStatus.mode != DeviceMode.FallCountdown) return
        countdown.cancel()
        detector.reset()
        store.setMode(DeviceMode.Monitoring)
    }
}
