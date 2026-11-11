package com.elderguard.ai.alerts

import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.Gps
import com.elderguard.ai.telemetry.TelemetryStore
import java.util.concurrent.CopyOnWriteArrayList
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** Why help was called: the 'fall' / 'manual' reasons of the web app. */
enum class SosReason { Fall, Manual }

/** One call for help: the payload of the web app's sos:triggered event. */
data class SosTrigger(val reason: SosReason, val timestamp: Long, val gps: Gps)

/**
 * Port of src/core/sosController.js. Switches the watch to [DeviceMode.Sos] and back, and tells
 * its listeners why each SOS started.
 *
 * Listeners are called synchronously, inside [trigger], like the web app's event emitter: whoever
 * reacts (the alert dispatcher) sees the state of that very moment.
 */
class SosController(private val store: TelemetryStore, private val now: () -> Long) {
    private val listeners = CopyOnWriteArrayList<(SosTrigger) -> Unit>()
    private val _active = MutableStateFlow<SosTrigger?>(null)

    /** The SOS in progress, with its reason, or null when none is. */
    val active: StateFlow<SosTrigger?> = _active.asStateFlow()

    val isActive: Boolean
        get() = store.state.value.deviceStatus.mode == DeviceMode.Sos

    /** Calls for help, unless an SOS is already in progress. */
    fun trigger(reason: SosReason) {
        if (isActive) return
        store.setMode(DeviceMode.Sos)
        val trigger = SosTrigger(reason, now(), store.state.value.gps)
        _active.value = trigger
        listeners.forEach { it(trigger) }
    }

    /** Ends the SOS in progress and goes back to monitoring. */
    fun cancel() {
        if (!isActive) return
        store.setMode(DeviceMode.Monitoring)
        _active.value = null
    }

    /** Calls [listener] on every new SOS. Returns a function that removes it. */
    fun onTriggered(listener: (SosTrigger) -> Unit): () -> Unit {
        listeners += listener
        return { listeners -= listener }
    }
}
