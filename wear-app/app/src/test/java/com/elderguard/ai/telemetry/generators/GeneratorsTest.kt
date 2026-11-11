package com.elderguard.ai.telemetry.generators

import com.elderguard.ai.config.TelemetryConfig
import com.elderguard.ai.telemetry.Battery
import com.elderguard.ai.telemetry.HeartRate
import com.elderguard.ai.telemetry.TelemetryState
import com.elderguard.ai.telemetry.magnitude
import kotlin.math.abs
import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private const val SEED = 42
private const val ITERATIONS = 10_000

class GeneratorsTest {
    @Test
    fun heartRateStaysInTheRestingRange() {
        val random = Random(SEED)
        var heartRate = HeartRate(70)
        repeat(ITERATIONS) {
            val next = nextHeartRate(heartRate, random)
            assertTrue(next.bpm in TelemetryConfig.HeartRate.RESTING_MIN..TelemetryConfig.HeartRate.RESTING_MAX)
            assertTrue(abs(next.bpm - heartRate.bpm) <= TelemetryConfig.HeartRate.NOISE)
            heartRate = next
        }
    }

    @Test
    fun heartRateReturnsToTheRangeFromOutsideIt() {
        assertEquals(HeartRate(80), nextHeartRate(HeartRate(150), Random(SEED)))
        assertEquals(HeartRate(60), nextHeartRate(HeartRate(30), Random(SEED)))
    }

    @Test
    fun heartRateIsDeterministicWithTheSameSeed() {
        val first = generateSequence(HeartRate(70)) { nextHeartRate(it, Random(SEED)) }.take(20).toList()
        val second = generateSequence(HeartRate(70)) { nextHeartRate(it, Random(SEED)) }.take(20).toList()
        assertEquals(first, second)
    }

    @Test
    fun accelerometerMagnitudeStaysNearOneG() {
        val random = Random(SEED)
        // Largest possible deviation: the noise on every axis at once.
        val tolerance = TelemetryConfig.Accelerometer.NOISE * 3
        repeat(ITERATIONS) {
            val reading = nextAccelerometer(random)
            assertTrue(abs(reading.magnitude - 1.0) <= tolerance)
            // Epsilon: 1.02 - 1.0 is slightly more than 0.02 in floating point.
            assertTrue(abs(reading.z - 1.0) <= TelemetryConfig.Accelerometer.NOISE + 1e-9)
        }
    }

    @Test
    fun gpsStaysNearTheBase() {
        val random = Random(SEED)
        val config = TelemetryConfig.Gps
        var gps = TelemetryState.initial().gps
        // Tiny margin for the rounding to 6 decimals.
        val maxDistance = config.MAX_DRIFT + 1e-9
        repeat(ITERATIONS) {
            gps = nextGps(gps, random)
            assertTrue(abs(gps.lat - config.BASE_LAT) <= maxDistance)
            assertTrue(abs(gps.lng - config.BASE_LNG) <= maxDistance)
            assertTrue(gps.accuracy in config.ACCURACY_MIN..config.ACCURACY_MAX)
            assertTrue(gps.signal)
        }
    }

    @Test
    fun gpsRestoresTheSignal() {
        val lost = TelemetryState.initial().gps.copy(signal = false)
        assertTrue(nextGps(lost, Random(SEED)).signal)
    }

    @Test
    fun batteryDrainsByAFixedAmountPerTick() {
        val next = nextBattery(Battery(level = 50.0, charging = false))
        assertEquals(50.0 - TelemetryConfig.Battery.DRAIN_PER_TICK, next.level, 1e-9)
    }

    @Test
    fun batteryDrainDoesNotAccumulateFloatingPointError() {
        var battery = Battery(level = TelemetryConfig.Battery.START_LEVEL, charging = false)
        repeat(1000) { battery = nextBattery(battery) }
        assertEquals(90.0, battery.level, 0.0)
    }

    @Test
    fun batteryNeverGoesNegative() {
        var battery = Battery(level = 0.015, charging = false)
        repeat(5) {
            battery = nextBattery(battery)
            assertTrue(battery.level >= 0.0)
        }
        assertEquals(0.0, battery.level, 0.0)
    }

    @Test
    fun roundToRoundsHalfUpAndAvoidsNegativeZero() {
        assertEquals(3.0, roundTo(2.5, 0), 0.0)
        assertEquals(-2.0, roundTo(-2.5, 0), 0.0) // Math.round in JS gives -2 as well
        assertEquals("0.0", roundTo(-0.001, 2).toString())
    }
}
