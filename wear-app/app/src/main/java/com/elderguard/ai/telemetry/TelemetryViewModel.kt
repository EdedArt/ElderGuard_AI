package com.elderguard.ai.telemetry

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.elderguard.ai.alerts.AlertPayload
import com.elderguard.ai.alerts.SosReason
import com.elderguard.ai.device.WatchDevice
import kotlinx.coroutines.flow.StateFlow

/**
 * Owns the watch device (telemetry, simulation and alerts) for the screen.
 *
 * A ViewModel survives Android re-creating the activity (for example when the system language changes),
 * so the simulation keeps its state instead of starting over. The device runs in viewModelScope,
 * which is cancelled when the ViewModel is cleared, so every coroutine stops on its own.
 */
class TelemetryViewModel : ViewModel() {
    private val device = WatchDevice(viewModelScope)
    val engine = device.engine
    val state: StateFlow<TelemetryState> = device.store.state

    /** Seconds left before a detected fall calls for help, or null when no countdown is running. */
    val fallCountdown: StateFlow<Int?> = device.countdown.remaining

    /** True while a critical heart rate, already reported to the family, lasts. */
    val criticalHeartRate: StateFlow<Boolean> = device.alerts.criticalActive

    /** The alert sent for the SOS in progress, confirmed on the SOS screen, or null. */
    val sosAlert: StateFlow<AlertPayload?> = device.alerts.sosAlert

    init {
        device.start()
    }

    /** Called when the SOS hold completes: the watch switches to the SOS screen, for a manual reason. */
    fun triggerSos() {
        device.sos.trigger(SosReason.Manual)
    }

    /** Called from the SOS screen's cancel button: the watch goes back to monitoring. */
    fun cancelSos() {
        device.sos.cancel()
    }

    /** Called from the fall countdown's "I'm OK" button. */
    fun cancelFall() {
        device.fall.cancel()
    }
}
