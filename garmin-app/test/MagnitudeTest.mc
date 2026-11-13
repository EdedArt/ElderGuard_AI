import Toybox.Lang;
import Toybox.Test;

// The accelerometer magnitude, like tests/magnitude.test.js.

(:test)
function magnitude_isTheEuclideanNormOfTheThreeAxes(logger as Logger) as Boolean {
    Test.assertEqual(Magnitude.of(new Accelerometer(3.0d, 4.0d, 0.0d)), 5.0d);
    Test.assertEqual(Magnitude.of(new Accelerometer(2.0d, 3.0d, 6.0d)), 7.0d);
    return true;
}

(:test)
function magnitude_isOneGAtRestWhicheverAxisGravityFallsOn(logger as Logger) as Boolean {
    Test.assertEqual(Magnitude.of(new Accelerometer(0.0d, 0.0d, 1.0d)), 1.0d);
    Test.assertEqual(Magnitude.of(new Accelerometer(1.0d, 0.0d, 0.0d)), 1.0d);
    Test.assertEqual(new Accelerometer(0.0d, 1.0d, 0.0d).magnitude(), 1.0d);
    return true;
}

(:test)
function magnitude_ignoresTheSignOfEachAxis(logger as Logger) as Boolean {
    Test.assertEqual(Magnitude.of(new Accelerometer(-3.0d, 4.0d, 0.0d)), 5.0d);
    return true;
}

(:test)
function magnitude_isZeroInFreeFall(logger as Logger) as Boolean {
    Test.assertEqual(Magnitude.of(new Accelerometer(0.0d, 0.0d, 0.0d)), 0.0d);
    return true;
}

(:test)
function magnitude_atRestAcceptsAboutOneGInAnyOrientation(logger as Logger) as Boolean {
    Test.assert(Magnitude.isAtRest(new Accelerometer(0.0d, 0.0d, 1.0d), 0.15d));
    Test.assert(Magnitude.isAtRest(new Accelerometer(1.0d, 0.0d, 0.0d), 0.15d));
    Test.assert(Magnitude.isAtRest(new Accelerometer(0.0d, 0.0d, 1.1d), 0.15d));
    Test.assert(new Accelerometer(0.0d, 0.0d, 0.9d).isAtRest(0.15d));
    return true;
}

(:test)
function magnitude_atRestRejectsReadingsOffOneGByMoreThanTheTolerance(logger as Logger) as Boolean {
    Test.assert(!Magnitude.isAtRest(new Accelerometer(0.0d, 0.0d, 1.2d), 0.15d));
    Test.assert(!Magnitude.isAtRest(new Accelerometer(0.0d, 0.0d, 0.8d), 0.15d));
    return true;
}
