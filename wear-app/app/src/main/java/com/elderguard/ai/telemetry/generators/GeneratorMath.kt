package com.elderguard.ai.telemetry.generators

import kotlin.math.pow
import kotlin.random.Random

// Port of src/core/math.js. `internal` means visible only inside this module (the app).

/**
 * Rounds half up, like JavaScript's Math.round, so both apps produce the same values.
 * (kotlin.math.round rounds half to even instead.) Adding 0.0 turns -0.0 into 0.0.
 */
internal fun roundTo(value: Double, decimals: Int): Double {
    val factor = 10.0.pow(decimals)
    return Math.round(value * factor) / factor + 0.0
}

/** A value in [-max, max), since nextDouble() returns values in [0, 1). */
internal fun randomOffset(random: Random, max: Double): Double = (random.nextDouble() * 2 - 1) * max
