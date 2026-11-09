package com.elderguard.ai.telemetry

import com.elderguard.ai.config.TelemetryConfig
import com.elderguard.ai.telemetry.generators.nextAccelerometer
import com.elderguard.ai.telemetry.generators.nextBattery
import com.elderguard.ai.telemetry.generators.nextGps
import com.elderguard.ai.telemetry.generators.nextHeartRate
import java.util.concurrent.ConcurrentHashMap
import kotlin.random.Random
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Port of src/core/simulationEngine.js. Every tick runs the generators and writes all readings to
 * the store in a single update. While a sensor has an override, its generator is skipped and the
 * override value is used instead.
 *
 * The ticker runs as a coroutine in [scope], so it stops on its own when the scope is cancelled
 * (for example when the ViewModel that owns it is cleared). [random] and [now] are injectable so
 * tests are deterministic.
 */
class SimulationEngine(
    private val store: TelemetryStore,
    private val scope: CoroutineScope,
    private val random: Random = Random,
    private val now: () -> Long = System::currentTimeMillis,
) {
    // Written from the UI thread and read by the ticker, so it must be thread-safe.
    private val overrides = ConcurrentHashMap<Sensor<*>, Any>()
    private var ticker: Job? = null

    val isRunning: Boolean
        get() = ticker?.isActive == true

    /** Starts ticking every [TelemetryConfig.TICK_INTERVAL_MS]. Starting twice has no effect. */
    fun start() {
        if (isRunning) return
        // launch starts a coroutine: a lightweight task that can pause in delay() without
        // blocking a thread, like a scheduled executor task but cancellable as a whole.
        ticker = scope.launch {
            while (isActive) {
                delay(TelemetryConfig.TICK_INTERVAL_MS)
                tick()
            }
        }
    }

    fun stop() {
        ticker?.cancel()
        ticker = null
    }

    /** Uses [value] for [sensor] on every tick. Applied right away, so it does not wait for a tick. */
    fun <T : Any> setOverride(sensor: Sensor<T>, value: T) {
        overrides[sensor] = value
        store.update { sensor.write(it, value) }
    }

    /**
     * Overrides [sensor] with a change to its current value, the equivalent of a partial override
     * in the web version: `setPartialOverride(Sensor.GPS) { it.copy(signal = false) }`.
     * (A different name from setOverride: with the same name, a lambda would match both.)
     */
    fun <T : Any> setPartialOverride(sensor: Sensor<T>, transform: (T) -> T) {
        setOverride(sensor, transform(sensor.read(store.state.value)))
    }

    /** The sensor is generated again from the next tick, starting from its current value. */
    fun clearOverride(sensor: Sensor<*>) {
        overrides.remove(sensor)
    }

    fun clearAllOverrides() {
        overrides.clear()
    }

    private fun tick() {
        val timestamp = now()
        store.update { state ->
            state
                .next(Sensor.HEART_RATE) { nextHeartRate(it, random) }
                .next(Sensor.ACCELEROMETER) { nextAccelerometer(random) }
                .next(Sensor.GPS) { nextGps(it, random) }
                .next(Sensor.BATTERY) { nextBattery(it) }
                .let { it.copy(deviceStatus = it.deviceStatus.copy(lastUpdate = timestamp)) }
        }
    }

    // The override value if there is one, otherwise the generated one. An extension function:
    // called as `state.next(...)`, as if it were a method of TelemetryState.
    private fun <T : Any> TelemetryState.next(sensor: Sensor<T>, generate: (T) -> T): TelemetryState {
        // Safe: setOverride only stores a T under a Sensor<T>.
        @Suppress("UNCHECKED_CAST")
        val value = overrides[sensor] as T? ?: generate(sensor.read(this))
        return sensor.write(this, value)
    }
}
