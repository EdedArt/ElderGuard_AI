package com.elderguard.ai.config

// Mirrors src/config/telemetry.config.js in the web app. Keep both in sync.
// An `object` is a singleton, and `const val` is a compile-time constant (Java's `static final`).
object TelemetryConfig {
    const val TICK_INTERVAL_MS = 1000L

    object HeartRate {
        const val RESTING_MIN = 60 // BPM
        const val RESTING_MAX = 80 // BPM
        const val NOISE = 2.0 // Largest change per tick, in BPM
    }

    object Accelerometer {
        // Resting reading, in g: only gravity, on the z axis.
        const val REST_X = 0.0
        const val REST_Y = 0.0
        const val REST_Z = 1.0
        const val NOISE = 0.02 // Largest deviation per axis, in g
    }

    object Gps {
        const val BASE_LAT = 4.6097 // Sample location: Bogotá, Colombia
        const val BASE_LNG = -74.0817
        const val DRIFT = 0.00002 // Largest change per tick, in degrees (about 2 m)
        const val MAX_DRIFT = 0.0002 // Largest distance from the base, in degrees (about 22 m)
        const val ACCURACY_MIN = 3.0 // Meters
        const val ACCURACY_MAX = 8.0 // Meters
    }

    object Battery {
        const val START_LEVEL = 100.0 // Percent
        const val DRAIN_PER_TICK = 0.01 // Percent
        const val LOW_LEVEL = 20.0 // Percent, inclusive
        const val CRITICAL_LEVEL = 10.0 // Percent, inclusive
    }
}
