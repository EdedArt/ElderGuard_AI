package com.elderguard.ai.telemetry

import kotlin.math.abs
import kotlin.math.sqrt

// Port of src/core/magnitude.js. Extension members: called as `reading.magnitude` and
// `reading.isAtRest(0.15)`, as if they were declared in Accelerometer itself.

/** What an accelerometer at rest reads in total: gravity alone. */
const val RESTING_MAGNITUDE_G = 1.0

/** Total acceleration in g, whatever the orientation of the watch (Math.hypot in the web app). */
val Accelerometer.magnitude: Double
    get() = sqrt(x * x + y * y + z * z)

/**
 * At rest, an accelerometer reads only gravity, whatever the orientation of the watch. True when
 * the total is within [toleranceG] of 1 g, edges included.
 */
fun Accelerometer.isAtRest(toleranceG: Double): Boolean = abs(magnitude - RESTING_MAGNITUDE_G) <= toleranceG
