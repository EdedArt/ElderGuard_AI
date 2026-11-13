import Toybox.Lang;
import Toybox.Math;

// Port of src/core/magnitude.js (Magnitude.kt in wear-app), with the same formula: the
// Euclidean norm of the three axes, Math.hypot(x, y, z) in the web app.
module Magnitude {
    // What an accelerometer at rest reads in total: gravity alone.
    const RESTING_G = 1.0d;

    // Total acceleration in g, whatever the orientation of the watch.
    function of(reading as Accelerometer) as Double {
        return Math.sqrt(reading.x * reading.x + reading.y * reading.y + reading.z * reading.z) as Double;
    }

    // At rest, an accelerometer reads only gravity, whatever the orientation of the watch. True
    // when the total is within toleranceG of 1 g, edges included.
    function isAtRest(reading as Accelerometer, toleranceG as Double) as Boolean {
        return (of(reading) - RESTING_G).abs() <= toleranceG;
    }
}
