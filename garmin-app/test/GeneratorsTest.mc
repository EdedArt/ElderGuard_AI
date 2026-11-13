import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

// Port of tests/generators.test.js. The JS tests use a seeded Mulberry32 generator; here
// Math.srand(seed) seeds Math.rand(), which the plain RandomSource reads, so every run repeats.

// Fewer steps than the 5000 of the JS tests: the simulator stops code that runs too long.
const STEPS = 1000;
// Coordinates are rounded to 6 decimals, which can land just past a limit.
const COORDINATE_TOLERANCE = 0.000001d;

// Always returns the same value, like `random: () => 0.5` in the JS tests.
(:test)
class FixedRandom extends RandomSource {
    private var _value as Double;

    function initialize(value as Double) {
        RandomSource.initialize();
        _value = value;
    }

    function nextDouble() as Double {
        return _value;
    }
}

// A RandomSource that repeats the same sequence for the same seed. A static method: a (:test)
// function would be run as a test.
(:test)
class SeededRandom {
    static function create(seed as Number) as RandomSource {
        Math.srand(seed);
        return new RandomSource();
    }
}

(:test)
function heartRate_staysInRangeWithSmoothChanges(logger as Logger) as Boolean {
    var random = SeededRandom.create(1);
    var current = new HeartRate(70);
    for (var i = 0; i < STEPS; i++) {
        var next = Generators.nextHeartRate(current, random);
        Test.assert(next.bpm >= TelemetryConfig.HeartRate.RESTING_MIN);
        Test.assert(next.bpm <= TelemetryConfig.HeartRate.RESTING_MAX);
        Test.assert((next.bpm - current.bpm).abs() <= TelemetryConfig.HeartRate.NOISE);
        current = next;
    }
    return true;
}

(:test)
function heartRate_movesToBothSidesOfItsStart(logger as Logger) as Boolean {
    var random = SeededRandom.create(2);
    var current = new HeartRate(70);
    var lowest = 70;
    var highest = 70;
    for (var i = 0; i < STEPS; i++) {
        current = Generators.nextHeartRate(current, random);
        if (current.bpm < lowest) { lowest = current.bpm; }
        if (current.bpm > highest) { highest = current.bpm; }
    }
    logger.debug("heart rate range: " + lowest + "-" + highest);
    return lowest < 70 && highest > 70;
}

(:test)
function heartRate_returnsToTheRestingRange(logger as Logger) as Boolean {
    var random = new FixedRandom(0.5d);
    Test.assertEqual(Generators.nextHeartRate(new HeartRate(180), random).bpm, TelemetryConfig.HeartRate.RESTING_MAX);
    Test.assertEqual(Generators.nextHeartRate(new HeartRate(20), random).bpm, TelemetryConfig.HeartRate.RESTING_MIN);
    return true;
}

(:test)
function heartRate_isDeterministicForTheSameSeed(logger as Logger) as Boolean {
    var first = Generators.nextHeartRate(new HeartRate(70), SeededRandom.create(7)).bpm;
    var second = Generators.nextHeartRate(new HeartRate(70), SeededRandom.create(7)).bpm;
    return first == second;
}

(:test)
function accelerometer_staysNearOneGWithinTheNoise(logger as Logger) as Boolean {
    var random = SeededRandom.create(3);
    // The small margin absorbs float error: |0.98 - 1| is 0.020000000000000018.
    var limit = TelemetryConfig.Accelerometer.NOISE + 1e-9d;
    for (var i = 0; i < STEPS; i++) {
        var reading = Generators.nextAccelerometer(random);
        Test.assert((reading.magnitude() - 1.0d).abs() < 0.05d);
        Test.assert((reading.x - TelemetryConfig.Accelerometer.REST_X).abs() <= limit);
        Test.assert((reading.y - TelemetryConfig.Accelerometer.REST_Y).abs() <= limit);
        Test.assert((reading.z - TelemetryConfig.Accelerometer.REST_Z).abs() <= limit);
    }
    return true;
}

(:test)
function accelerometer_roundsToTwoDecimals(logger as Logger) as Boolean {
    var random = SeededRandom.create(4);
    for (var i = 0; i < 200; i++) {
        var reading = Generators.nextAccelerometer(random);
        Test.assertEqual(GeneratorMath.roundTo(reading.x, 2), reading.x);
        Test.assertEqual(GeneratorMath.roundTo(reading.y, 2), reading.y);
        Test.assertEqual(GeneratorMath.roundTo(reading.z, 2), reading.z);
    }
    return true;
}

(:test)
function gps_staysNearTheBaseWithSmallSteps(logger as Logger) as Boolean {
    var random = SeededRandom.create(5);
    var current = new Gps(TelemetryConfig.Gps.BASE_LAT, TelemetryConfig.Gps.BASE_LNG, TelemetryConfig.Gps.ACCURACY_MIN, true);
    var maxDrift = TelemetryConfig.Gps.MAX_DRIFT + COORDINATE_TOLERANCE;
    var step = TelemetryConfig.Gps.DRIFT + COORDINATE_TOLERANCE;
    for (var i = 0; i < STEPS; i++) {
        var next = Generators.nextGps(current, random);
        Test.assert((next.lat - TelemetryConfig.Gps.BASE_LAT).abs() <= maxDrift);
        Test.assert((next.lng - TelemetryConfig.Gps.BASE_LNG).abs() <= maxDrift);
        Test.assert((next.lat - current.lat).abs() <= step);
        Test.assert((next.lng - current.lng).abs() <= step);
        Test.assert(next.accuracy >= TelemetryConfig.Gps.ACCURACY_MIN);
        Test.assert(next.accuracy <= TelemetryConfig.Gps.ACCURACY_MAX);
        current = next;
    }
    return true;
}

(:test)
function gps_actuallyDrifts(logger as Logger) as Boolean {
    var start = new Gps(TelemetryConfig.Gps.BASE_LAT, TelemetryConfig.Gps.BASE_LNG, TelemetryConfig.Gps.ACCURACY_MIN, true);
    var next = Generators.nextGps(start, SeededRandom.create(6));
    return next.lat != start.lat || next.lng != start.lng;
}

(:test)
function gps_reportsASignal(logger as Logger) as Boolean {
    var lost = new Gps(TelemetryConfig.Gps.BASE_LAT, TelemetryConfig.Gps.BASE_LNG, TelemetryConfig.Gps.ACCURACY_MIN, false);
    return Generators.nextGps(lost, SeededRandom.create(8)).signal;
}

(:test)
function gps_returnsNearTheBaseFromFarAway(logger as Logger) as Boolean {
    var next = Generators.nextGps(new Gps(50.0d, 50.0d, 3.0d, true), SeededRandom.create(9));
    var maxDrift = TelemetryConfig.Gps.MAX_DRIFT + COORDINATE_TOLERANCE;
    Test.assert((next.lat - TelemetryConfig.Gps.BASE_LAT).abs() <= maxDrift);
    Test.assert((next.lng - TelemetryConfig.Gps.BASE_LNG).abs() <= maxDrift);
    return true;
}

(:test)
function battery_decreasesByTheDrainPerTick(logger as Logger) as Boolean {
    var next = Generators.nextBattery(new Battery(50.0d, false));
    Test.assert((next.level - (50.0d - TelemetryConfig.Battery.DRAIN_PER_TICK)).abs() < 1e-8d);
    return !next.charging;
}

(:test)
function battery_doesNotAccumulateFloatingPointError(logger as Logger) as Boolean {
    var current = new Battery(TelemetryConfig.Battery.START_LEVEL, false);
    for (var i = 0; i < 100; i++) {
        current = Generators.nextBattery(current);
    }
    Test.assertEqual(current.level, TelemetryConfig.Battery.START_LEVEL - 100 * TelemetryConfig.Battery.DRAIN_PER_TICK);
    return true;
}

(:test)
function battery_neverGoesNegative(logger as Logger) as Boolean {
    var current = new Battery(0.005d, false);
    for (var i = 0; i < 5; i++) {
        current = Generators.nextBattery(current);
        Test.assertEqual(current.level, 0.0d);
    }
    return true;
}

(:test)
function math_roundToRoundsHalfUpLikeJavaScript(logger as Logger) as Boolean {
    Test.assertEqual(GeneratorMath.roundTo(2.5d, 0), 3.0d);
    Test.assertEqual(GeneratorMath.roundTo(-2.5d, 0), -2.0d); // Math.round(-2.5) is -2 in JS.
    Test.assertEqual(GeneratorMath.roundTo(1.005d * 1000.0d, 0), 1005.0d);
    Test.assertEqual(GeneratorMath.roundTo(0.125d, 2), 0.13d);
    return true;
}
