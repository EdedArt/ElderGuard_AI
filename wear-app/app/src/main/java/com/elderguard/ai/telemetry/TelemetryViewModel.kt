package com.elderguard.ai.telemetry

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.StateFlow

/**
 * Owns the telemetry store and the simulation engine for the screen.
 *
 * A ViewModel survives Android re-creating the activity (for example when the system language changes),
 * so the simulation keeps its state instead of starting over. The engine runs in viewModelScope,
 * which is cancelled when the ViewModel is cleared, so the ticker stops on its own.
 */
class TelemetryViewModel : ViewModel() {
    private val store = TelemetryStore()
    val engine = SimulationEngine(store, viewModelScope)
    val state: StateFlow<TelemetryState> = store.state

    init {
        engine.start()
    }

    /** Called when the SOS hold completes: the watch switches to the SOS screen. */
    fun triggerSos() {
        store.setMode(DeviceMode.Sos)
    }

    /** Called from the SOS screen's cancel button: the watch goes back to monitoring. */
    fun cancelSos() {
        store.setMode(DeviceMode.Monitoring)
    }
}
