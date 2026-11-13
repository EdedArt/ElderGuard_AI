import Toybox.Lang;

// Port of src/core/generators. Each function computes the next reading of one sensor from the
// current one. The randomness comes in as a parameter, so tests get the same values on every run.
module Generators {
    const COORDINATE_DECIMALS = 6;
    // Rounding keeps repeated subtraction from accumulating floating point error.
    const LEVEL_DECIMALS = 4;

    // Random walk of whole BPM values, kept within the resting range.
    function nextHeartRate(current as HeartRate, random as RandomSource) as HeartRate {
        var step = GeneratorMath.roundTo(GeneratorMath.randomOffset(random, TelemetryConfig.HeartRate.NOISE), 0);
        var next = current.bpm + step.toNumber();
        if (next < TelemetryConfig.HeartRate.RESTING_MIN) {
            next = TelemetryConfig.HeartRate.RESTING_MIN;
        } else if (next > TelemetryConfig.HeartRate.RESTING_MAX) {
            next = TelemetryConfig.HeartRate.RESTING_MAX;
        }
        return new HeartRate(next);
    }

    // The resting reading (1 g on z) plus a little noise on each axis.
    function nextAccelerometer(random as RandomSource) as Accelerometer {
        return new Accelerometer(
            noisy(TelemetryConfig.Accelerometer.REST_X, random),
            noisy(TelemetryConfig.Accelerometer.REST_Y, random),
            noisy(TelemetryConfig.Accelerometer.REST_Z, random)
        );
    }

    // Small drift around the base coordinates, never farther than the configured maximum.
    function nextGps(current as Gps, random as RandomSource) as Gps {
        var accuracyRange = TelemetryConfig.Gps.ACCURACY_MAX - TelemetryConfig.Gps.ACCURACY_MIN;
        return new Gps(
            drift(current.lat, TelemetryConfig.Gps.BASE_LAT, random),
            drift(current.lng, TelemetryConfig.Gps.BASE_LNG, random),
            GeneratorMath.roundTo(TelemetryConfig.Gps.ACCURACY_MIN + random.nextDouble() * accuracyRange, 1),
            true
        );
    }

    // Linear drain by a fixed amount per tick, never below 0.
    function nextBattery(current as Battery) as Battery {
        var level = GeneratorMath.roundTo(current.level - TelemetryConfig.Battery.DRAIN_PER_TICK, LEVEL_DECIMALS);
        return new Battery(level < 0.0d ? 0.0d : level, false);
    }

    function noisy(rest as Double, random as RandomSource) as Double {
        return GeneratorMath.roundTo(rest + GeneratorMath.randomOffset(random, TelemetryConfig.Accelerometer.NOISE), 2);
    }

    function drift(current as Double, base as Double, random as RandomSource) as Double {
        var maxDrift = TelemetryConfig.Gps.MAX_DRIFT;
        var moved = GeneratorMath.clamp(
            current + GeneratorMath.randomOffset(random, TelemetryConfig.Gps.DRIFT),
            base - maxDrift,
            base + maxDrift
        );
        return GeneratorMath.roundTo(moved, COORDINATE_DECIMALS);
    }
}
