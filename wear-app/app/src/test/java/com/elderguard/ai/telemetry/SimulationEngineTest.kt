package com.elderguard.ai.telemetry

import com.elderguard.ai.config.TelemetryConfig
import kotlin.random.Random
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private const val TICK = TelemetryConfig.TICK_INTERVAL_MS

/** Always the top of the range, so generated values visibly differ from the initial state. */
private object TopOfRangeRandom : Random() {
    override fun nextBits(bitCount: Int): Int = error("Not used by the generators")

    override fun nextDouble(): Double = 0.99
}

// Virtual time: advanceTimeBy moves the test clock without waiting, like vi.advanceTimersByTime.
// runCurrent then runs what is due at exactly that moment (advanceTimeBy stops just before it).
@OptIn(ExperimentalCoroutinesApi::class)
private fun TestScope.advanceTicks(ticks: Int = 1) {
    advanceTimeBy(TICK * ticks)
    runCurrent()
}

// backgroundScope runs on the test's virtual clock and is cancelled when the test ends, so the
// endless ticker does not keep the test running.
private fun TestScope.newEngine(store: TelemetryStore, scope: CoroutineScope = backgroundScope) =
    SimulationEngine(store, scope, random = TopOfRangeRandom, now = { testScheduler.currentTime })

/** Counts the state emissions of [store]; each tick produces exactly one. */
@OptIn(ExperimentalCoroutinesApi::class)
private fun TestScope.countEmissions(store: TelemetryStore): () -> Int {
    var count = -1 // The first emission is the current value, not a change.
    backgroundScope.launch(UnconfinedTestDispatcher(testScheduler)) { store.state.collect { count++ } }
    return { count }
}

@OptIn(ExperimentalCoroutinesApi::class)
class SimulationEngineTest {
    // --- Start and stop ---

    @Test
    fun doesNotTickUntilStarted() = runTest {
        val store = TelemetryStore()
        val engine = newEngine(store)

        advanceTicks(3)

        assertFalse(engine.isRunning)
        assertEquals(TelemetryState.initial(), store.state.value)
    }

    @Test
    fun reportsItsRunningState() = runTest {
        val engine = newEngine(TelemetryStore())
        engine.start()
        assertTrue(engine.isRunning)
        engine.stop()
        assertFalse(engine.isRunning)
    }

    @Test
    fun stopsUpdatingTheStoreAfterStop() = runTest {
        val store = TelemetryStore()
        val engine = newEngine(store)
        engine.start()
        advanceTicks()
        engine.stop()
        val stopped = store.state.value

        advanceTicks(3)

        assertEquals(stopped, store.state.value)
    }

    @Test
    fun doesNotDoubleTheTickRateWhenStartedTwice() = runTest {
        val store = TelemetryStore()
        val emissions = countEmissions(store)
        val engine = newEngine(store)
        engine.start()
        engine.start()

        advanceTicks(2)

        assertEquals(2, emissions())
        engine.stop()
        advanceTicks()
        assertEquals(2, emissions())
    }

    @Test
    fun canStopWhenNotRunningAndStartAgainAfterwards() = runTest {
        val store = TelemetryStore()
        val engine = newEngine(store)
        engine.stop()
        engine.start()
        engine.stop()
        engine.start()
        val emissions = countEmissions(store)

        advanceTicks()

        assertEquals(1, emissions())
    }

    @Test
    fun stopsWhenItsScopeIsCancelled() = runTest {
        val scope = CoroutineScope(backgroundScope.coroutineContext + Job())
        val store = TelemetryStore()
        val engine = newEngine(store, scope)
        engine.start()

        scope.cancel()
        advanceTicks()

        assertFalse(engine.isRunning)
        assertEquals(TelemetryState.initial(), store.state.value)
    }

    // --- Ticks ---

    @Test
    fun writesEverySensorAndTheTimestampInASingleUpdate() = runTest {
        val store = TelemetryStore()
        val before = store.state.value
        val emissions = countEmissions(store)
        newEngine(store).start()

        advanceTicks()

        assertEquals(1, emissions())
        val after = store.state.value
        assertEquals(before.heartRate.bpm + TelemetryConfig.HeartRate.NOISE.toInt(), after.heartRate.bpm)
        assertEquals(Accelerometer(0.02, 0.02, 1.02), after.accelerometer)
        assertTrue(after.gps.lat > before.gps.lat)
        assertEquals(before.battery.level - TelemetryConfig.Battery.DRAIN_PER_TICK, after.battery.level, 1e-9)
        assertEquals(DeviceStatus(DeviceMode.Monitoring, lastUpdate = TICK), after.deviceStatus)
    }

    @Test
    fun ticksAtTheConfiguredInterval() = runTest {
        val store = TelemetryStore()
        val emissions = countEmissions(store)
        newEngine(store).start()

        advanceTimeBy(TICK - 1)
        runCurrent()
        assertEquals(0, emissions())

        advanceTimeBy(1)
        runCurrent()
        assertEquals(1, emissions())
    }

    // --- Overrides ---

    @Test
    fun usesTheOverrideValueInsteadOfTheGeneratorOnEveryTick() = runTest {
        val store = TelemetryStore()
        val engine = newEngine(store)
        engine.start()
        engine.setOverride(Sensor.HEART_RATE, HeartRate(150))

        advanceTicks(3)

        assertEquals(HeartRate(150), store.state.value.heartRate)
    }

    @Test
    fun keepsGeneratingTheOtherSensors() = runTest {
        val store = TelemetryStore()
        val before = store.state.value
        val engine = newEngine(store)
        engine.start()
        engine.setOverride(Sensor.HEART_RATE, HeartRate(150))

        advanceTicks()

        assertTrue(store.state.value.battery.level < before.battery.level)
        assertEquals(TICK, store.state.value.deviceStatus.lastUpdate)
    }

    @Test
    fun appliesRightAwayEvenWhileStopped() = runTest {
        val store = TelemetryStore()
        val engine = newEngine(store)

        engine.setOverride(Sensor.ACCELEROMETER, Accelerometer(3.0, 3.0, 3.0))

        assertEquals(Accelerometer(3.0, 3.0, 3.0), store.state.value.accelerometer)
    }

    @Test
    fun acceptsAChangeToTheCurrentValueLikeAPartialOverride() = runTest {
        val store = TelemetryStore()
        val before = store.state.value
        val engine = newEngine(store)
        engine.setPartialOverride(Sensor.GPS) { it.copy(signal = false) }
        engine.start()

        advanceTicks()

        assertEquals(before.gps.copy(signal = false), store.state.value.gps)
    }

    @Test
    fun resumesGenerationAfterClearOverride() = runTest {
        val store = TelemetryStore()
        val engine = newEngine(store)
        engine.setOverride(Sensor.HEART_RATE, HeartRate(150))
        engine.setPartialOverride(Sensor.GPS) { it.copy(signal = false) }
        engine.start()

        engine.clearOverride(Sensor.HEART_RATE)
        engine.clearOverride(Sensor.GPS)
        advanceTicks()

        assertEquals(HeartRate(TelemetryConfig.HeartRate.RESTING_MAX), store.state.value.heartRate)
        assertTrue(store.state.value.gps.signal)
    }

    @Test
    fun continuesFromAnOverriddenBatteryLevelAfterClearingIt() = runTest {
        val store = TelemetryStore()
        val engine = newEngine(store)
        engine.setPartialOverride(Sensor.BATTERY) { it.copy(level = 15.0) }
        engine.clearOverride(Sensor.BATTERY)
        engine.start()

        advanceTicks()

        assertEquals(15.0 - TelemetryConfig.Battery.DRAIN_PER_TICK, store.state.value.battery.level, 1e-9)
    }

    @Test
    fun clearAllOverridesResumesEverySensor() = runTest {
        val store = TelemetryStore()
        val engine = newEngine(store)
        engine.setOverride(Sensor.HEART_RATE, HeartRate(150))
        engine.setOverride(Sensor.ACCELEROMETER, Accelerometer(3.0, 3.0, 3.0))
        engine.start()

        engine.clearAllOverrides()
        advanceTicks()

        val state = store.state.value
        assertEquals(HeartRate(TelemetryConfig.HeartRate.RESTING_MAX), state.heartRate)
        assertTrue(state.accelerometer.x < 1.0)
    }
}
