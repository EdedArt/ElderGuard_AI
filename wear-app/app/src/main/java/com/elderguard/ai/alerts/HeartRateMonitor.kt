package com.elderguard.ai.alerts

import com.elderguard.ai.detection.AnomalyEvent
import com.elderguard.ai.detection.AnomalyState
import com.elderguard.ai.detection.HeartRateAnomalyDetector
import com.elderguard.ai.telemetry.HealthAlert
import com.elderguard.ai.telemetry.TelemetryStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Port of src/core/heartRateMonitor.js: feeds the anomaly detector from the telemetry store, in a
 * coroutine launched in [scope], and records the warning in deviceStatus.healthAlert.
 *
 * It only reports: it never touches the device mode, so it runs alongside the fall flow, whatever
 * state that is in. Every new state counts as a reading, in every mode.
 */
class HeartRateMonitor(
    private val store: TelemetryStore,
    scope: CoroutineScope,
    now: () -> Long,
    private val detector: HeartRateAnomalyDetector = HeartRateAnomalyDetector(),
) {
    val detectorState: AnomalyState
        get() = detector.state

    init {
        scope.launch {
            store.state.collect { state ->
                when (detector.process(state.heartRate.bpm, state.accelerometer, now())) {
                    AnomalyEvent.Warning -> setHealthAlert(HealthAlert.HighHeartRate)
                    AnomalyEvent.Resolved -> setHealthAlert(null)
                    null -> Unit
                }
            }
        }
    }

    /** Forgets the warning and the time counted so far. */
    fun reset() {
        detector.reset()
        setHealthAlert(null)
    }

    private fun setHealthAlert(healthAlert: HealthAlert?) {
        store.update { it.copy(deviceStatus = it.deviceStatus.copy(healthAlert = healthAlert)) }
    }
}
