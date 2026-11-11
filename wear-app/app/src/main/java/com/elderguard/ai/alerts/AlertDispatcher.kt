package com.elderguard.ai.alerts

import com.elderguard.ai.config.HeartRateAnomalyConfig
import com.elderguard.ai.detection.AnomalyEvent
import com.elderguard.ai.detection.HeartRateAnomalyDetector
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.TelemetryState
import com.elderguard.ai.telemetry.TelemetryStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Port of src/core/alertDispatcher.js. A mock: it never touches the network. Sending an alert
 * means building its payload and recording it in [alerts], which is where a real integration
 * with a messaging service would go.
 *
 * Two things send one:
 * - Every SOS, from a fall or from the button. Its listener runs inside [SosController.trigger],
 *   so the payload records the state of that very moment.
 * - A heart rate above [HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD] at rest for the sustained
 *   time, once per episode. A health alert, not a fall: nobody is asked anything, and the device
 *   mode stays as it is. The warning level (120 BPM) only shows the banner; it sends nothing.
 */
class AlertDispatcher(
    private val store: TelemetryStore,
    sos: SosController,
    scope: CoroutineScope,
    private val now: () -> Long,
    private val criticalDetector: HeartRateAnomalyDetector =
        HeartRateAnomalyDetector(bpmThreshold = HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD),
) {
    private val _alerts = MutableStateFlow<List<AlertPayload>>(emptyList())

    /** Every alert sent, oldest first. Read-only and made of immutable payloads. */
    val alerts: StateFlow<List<AlertPayload>> = _alerts.asStateFlow()

    private val _criticalActive = MutableStateFlow(false)

    /** True while a critical heart rate episode, already reported to the family, lasts. */
    val criticalActive: StateFlow<Boolean> = _criticalActive.asStateFlow()

    private val _sosAlert = MutableStateFlow<AlertPayload?>(null)

    /**
     * The alert sent for the SOS in progress, which the SOS screen confirms; null when no SOS is
     * in progress. A health alert sent during an SOS is not what that screen reports, so it never
     * appears here.
     */
    val sosAlert: StateFlow<AlertPayload?> = _sosAlert.asStateFlow()

    init {
        sos.onTriggered { trigger -> _sosAlert.value = dispatch(trigger.reason.alertType, store.state.value) }
        scope.launch {
            store.state.collect { state ->
                // The next SOS must not show this one's details.
                if (state.deviceStatus.mode != DeviceMode.Sos) _sosAlert.value = null
                when (criticalDetector.process(state.heartRate.bpm, state.accelerometer, now())) {
                    AnomalyEvent.Warning -> {
                        _criticalActive.value = true
                        dispatch(AlertType.HighHeartRate, state)
                    }
                    AnomalyEvent.Resolved -> _criticalActive.value = false
                    null -> Unit
                }
            }
        }
    }

    /** Forgets every alert sent and the critical time counted so far. */
    fun reset() {
        _alerts.value = emptyList()
        _sosAlert.value = null
        criticalDetector.reset()
        _criticalActive.value = false
    }

    private fun dispatch(type: AlertType, state: TelemetryState): AlertPayload {
        val alert = buildAlertPayload(state, type, now())
        _alerts.update { it + alert }
        return alert
    }
}
