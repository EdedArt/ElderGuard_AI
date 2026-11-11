package com.elderguard.ai.telemetry

// Kotlin notes for Java developers:
// - A `data class` is an immutable value object: the compiler writes the constructor, getters,
//   equals, hashCode, toString and copy(). `copy(level = 50.0)` returns a new instance with only
//   that field changed, which is how state is "modified" without mutating it.
// - `val` is a read-only property (a final field with a getter).

/** Heart rate in beats per minute. */
data class HeartRate(val bpm: Int)

/**
 * Acceleration on each axis, in g. A watch at rest reads about 1 g in total (gravity).
 * Its total, [magnitude], and [isAtRest] are in Magnitude.kt.
 */
data class Accelerometer(val x: Double, val y: Double, val z: Double)

/** Position in degrees, with its accuracy in meters. */
data class Gps(val lat: Double, val lng: Double, val accuracy: Double, val signal: Boolean)

/** Charge level from 0 to 100 percent. */
data class Battery(val level: Double, val charging: Boolean)

/** What the watch is doing. Equivalent to the 'monitoring' / 'fall-countdown' / 'sos' strings in JS. */
enum class DeviceMode {
    Monitoring,
    FallCountdown,
    Sos,
}

/** A health warning the watch is showing. Equivalent to the 'high-heart-rate' string in JS. */
enum class HealthAlert {
    HighHeartRate,
}

/**
 * [lastUpdate] is the time of the last simulation tick in epoch milliseconds, or null before the first.
 * [healthAlert] is the health warning in progress, or null. It is independent of [mode]: a warning
 * can show during a fall countdown or an SOS.
 */
data class DeviceStatus(val mode: DeviceMode, val lastUpdate: Long?, val healthAlert: HealthAlert? = null)
