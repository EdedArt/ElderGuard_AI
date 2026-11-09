package com.elderguard.ai.telemetry

import com.elderguard.ai.config.TelemetryConfig
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** Everything the watch knows at one moment. The single source of data for the UI. */
data class TelemetryState(
    val heartRate: HeartRate,
    val accelerometer: Accelerometer,
    val gps: Gps,
    val battery: Battery,
    val deviceStatus: DeviceStatus,
) {
    companion object {
        /** The state before the first tick, matching createInitialState in the web store. */
        fun initial(): TelemetryState = TelemetryState(
            heartRate = HeartRate(
                bpm = (TelemetryConfig.HeartRate.RESTING_MIN + TelemetryConfig.HeartRate.RESTING_MAX) / 2,
            ),
            accelerometer = Accelerometer(
                x = TelemetryConfig.Accelerometer.REST_X,
                y = TelemetryConfig.Accelerometer.REST_Y,
                z = TelemetryConfig.Accelerometer.REST_Z,
            ),
            gps = Gps(
                lat = TelemetryConfig.Gps.BASE_LAT,
                lng = TelemetryConfig.Gps.BASE_LNG,
                accuracy = TelemetryConfig.Gps.ACCURACY_MIN,
                signal = true,
            ),
            battery = Battery(level = TelemetryConfig.Battery.START_LEVEL, charging = false),
            deviceStatus = DeviceStatus(mode = DeviceMode.Monitoring, lastUpdate = null),
        )
    }
}

// StateFlow, for Java developers: think of it as an observable field that always holds a value,
// like a thread-safe AtomicReference you can also subscribe to (similar to LiveData or a
// BehaviorSubject in RxJava). Reading `state.value` gives the current value; collecting the flow
// (as Compose does with collectAsState) delivers the current value and then every new one.
// It replaces the web store's subscribe/notify code:
// - Subscribers only see real changes: setting a value equal to the current one (data class
//   equals) emits nothing, like the web store skipping updates where nothing changed.
// - A slow subscriber skips intermediate values and gets the latest one, which suits a UI.
// MutableStateFlow is the writable version; it stays private so only this class can change state.
class TelemetryStore {
    private val _state = MutableStateFlow(TelemetryState.initial())

    /** Read-only view of the state, for the UI and the detectors. */
    val state: StateFlow<TelemetryState> = _state.asStateFlow()

    /**
     * Replaces the state with the result of [transform], applied to the current state.
     * The transform returns a merged copy, for example `update { it.copy(heartRate = HeartRate(90)) }`,
     * so every field it does not mention is kept. The change is atomic even across threads.
     */
    fun update(transform: (TelemetryState) -> TelemetryState) {
        _state.update(transform)
    }

    /** Restores the initial state. */
    fun reset() {
        _state.value = TelemetryState.initial()
    }
}
