package com.elderguard.ai.telemetry

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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

    init {
        device.start()
    }

    /** Called when the SOS hold completes: the watch switches to the SOS screen. */
    fun triggerSos() {
        device.store.setMode(DeviceMode.Sos)
    }

    /** Called from the SOS screen's cancel button: the watch goes back to monitoring. */
    fun cancelSos() {
        device.store.setMode(DeviceMode.Monitoring)
    }

    /** Called from the fall countdown's "I'm OK" button. */
    fun cancelFall() {
        device.fall.cancel()
    }
}
