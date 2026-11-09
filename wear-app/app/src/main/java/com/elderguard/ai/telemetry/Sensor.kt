package com.elderguard.ai.telemetry

/**
 * A sensor the simulation engine can override, together with the type of its value.
 *
 * Replaces the string names of the web version ('heartRate', 'gps', ...): the compiler checks
 * both the sensor and the value, so `setOverride(Sensor.HEART_RATE, HeartRate(150))` compiles and
 * `setOverride(Sensor.HEART_RATE, 150)` or an unknown sensor does not.
 * The constructor is private, so the four constants below are the only sensors.
 */
class Sensor<T : Any> private constructor(
    private val name: String,
    internal val read: (TelemetryState) -> T,
    internal val write: (TelemetryState, T) -> TelemetryState,
) {
    override fun toString(): String = name

    // A companion object holds the class's static members.
    companion object {
        val HEART_RATE = Sensor("heartRate", { it.heartRate }, { state, value -> state.copy(heartRate = value) })
        val ACCELEROMETER =
            Sensor("accelerometer", { it.accelerometer }, { state, value -> state.copy(accelerometer = value) })
        val GPS = Sensor("gps", { it.gps }, { state, value -> state.copy(gps = value) })
        val BATTERY = Sensor("battery", { it.battery }, { state, value -> state.copy(battery = value) })
    }
}
