import Toybox.Lang;

// Port of src/config/telemetry.config.js. Constants are grouped in modules, so they read as
// TelemetryConfig.HeartRate.RESTING_MIN, like telemetryConfig.heartRate.restingMin in JS.
// Decimal values carry the d suffix: they are Double, like the readings they feed.
module TelemetryConfig {
    // Time between two simulation ticks.
    const TICK_INTERVAL_MS = 1000;

    module HeartRate {
        const RESTING_MIN = 60; // BPM
        const RESTING_MAX = 80; // BPM
        const NOISE = 2.0d; // Largest change per tick, in BPM
    }

    module Accelerometer {
        // Resting reading, in g: gravity only, on z.
        const REST_X = 0.0d;
        const REST_Y = 0.0d;
        const REST_Z = 1.0d;
        const NOISE = 0.02d; // Largest deviation per axis, in g
    }

    module Gps {
        const BASE_LAT = 4.6097d; // Sample location: Bogotá, Colombia
        const BASE_LNG = -74.0817d;
        const DRIFT = 0.00002d; // Largest change per tick, in degrees (about 2 m)
        const MAX_DRIFT = 0.0002d; // Largest distance from the base, in degrees (about 22 m)
        const ACCURACY_MIN = 3.0d; // Meters
        const ACCURACY_MAX = 8.0d; // Meters
    }

    module Battery {
        const START_LEVEL = 100.0d; // Percent
        const DRAIN_PER_TICK = 0.01d; // Percent
        const LOW_LEVEL = 20.0d; // Percent, inclusive
        const CRITICAL_LEVEL = 10.0d; // Percent, inclusive
    }
}
