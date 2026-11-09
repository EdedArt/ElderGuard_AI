package com.elderguard.ai.telemetry.generators

import com.elderguard.ai.config.TelemetryConfig
import com.elderguard.ai.telemetry.Accelerometer
import com.elderguard.ai.telemetry.Battery
import com.elderguard.ai.telemetry.Gps
import com.elderguard.ai.telemetry.HeartRate
import kotlin.random.Random

// Port of src/core/generators. Each function computes the next reading of one sensor. They are
// pure: the randomness comes in as a parameter, so tests pass a seeded Random and get the same
// values on every run. The `random: Random = Random` default is Kotlin's shared random generator.

/** Random walk of whole BPM values, kept within the resting range. */
fun nextHeartRate(current: HeartRate, random: Random = Random): HeartRate {
    val config = TelemetryConfig.HeartRate
    val step = roundTo(randomOffset(random, config.NOISE), 0).toInt()
    return HeartRate((current.bpm + step).coerceIn(config.RESTING_MIN, config.RESTING_MAX))
}

/** The resting reading (1 g on z) plus a little noise on each axis. */
fun nextAccelerometer(random: Random = Random): Accelerometer {
    val config = TelemetryConfig.Accelerometer
    return Accelerometer(
        x = roundTo(config.REST_X + randomOffset(random, config.NOISE), 2),
        y = roundTo(config.REST_Y + randomOffset(random, config.NOISE), 2),
        z = roundTo(config.REST_Z + randomOffset(random, config.NOISE), 2),
    )
}

private const val COORDINATE_DECIMALS = 6

/** Small drift around the base coordinates, never farther than the configured maximum. */
fun nextGps(current: Gps, random: Random = Random): Gps {
    val config = TelemetryConfig.Gps
    return Gps(
        lat = drift(current.lat, config.BASE_LAT, random),
        lng = drift(current.lng, config.BASE_LNG, random),
        accuracy = roundTo(
            config.ACCURACY_MIN + random.nextDouble() * (config.ACCURACY_MAX - config.ACCURACY_MIN),
            1,
        ),
        signal = true,
    )
}

private fun drift(current: Double, base: Double, random: Random): Double {
    val config = TelemetryConfig.Gps
    val moved = (current + randomOffset(random, config.DRIFT))
        .coerceIn(base - config.MAX_DRIFT, base + config.MAX_DRIFT)
    return roundTo(moved, COORDINATE_DECIMALS)
}

// Rounding keeps repeated subtraction from accumulating floating point error.
private const val LEVEL_DECIMALS = 4

/** Linear drain by a fixed amount per tick, never below 0. */
fun nextBattery(current: Battery): Battery = Battery(
    level = maxOf(0.0, roundTo(current.level - TelemetryConfig.Battery.DRAIN_PER_TICK, LEVEL_DECIMALS)),
    charging = false,
)
