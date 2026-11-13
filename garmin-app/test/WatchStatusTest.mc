import Toybox.Lang;
import Toybox.Test;

// Port of tests/watchStatus.test.js and WatchStatusTest.kt (wear-app).

(:test)
function status_roundsTheBatteryPercentHalfUp(logger as Logger) as Boolean {
    Test.assertEqual(WatchStatus.batteryPercent(99.99d), 100);
    Test.assertEqual(WatchStatus.batteryPercent(20.5d), 21);
    Test.assertEqual(WatchStatus.batteryPercent(20.49d), 20);
    Test.assertEqual(WatchStatus.batteryPercent(0.0d), 0);
    return true;
}

(:test)
function status_batteryThresholdsAreInclusive(logger as Logger) as Boolean {
    Test.assert(WatchStatus.batteryState(100.0d) == BATTERY_NORMAL);
    Test.assert(WatchStatus.batteryState(20.01d) == BATTERY_NORMAL);
    Test.assert(WatchStatus.batteryState(20.0d) == BATTERY_LOW);
    Test.assert(WatchStatus.batteryState(10.01d) == BATTERY_LOW);
    Test.assert(WatchStatus.batteryState(10.0d) == BATTERY_CRITICAL);
    Test.assert(WatchStatus.batteryState(0.0d) == BATTERY_CRITICAL);
    return true;
}

(:test)
function status_batteryColorFollowsTheDisplayedPercent(logger as Logger) as Boolean {
    // 20.4 % is shown as "20 %", so it must already look low.
    Test.assert(WatchStatus.displayedBatteryState(new Battery(20.4d, false)) == BATTERY_LOW);
    Test.assert(WatchStatus.displayedBatteryState(new Battery(20.5d, false)) == BATTERY_NORMAL);
    Test.assert(WatchStatus.displayedBatteryState(new Battery(10.4d, false)) == BATTERY_CRITICAL);
    return true;
}

(:test)
function status_gpsFollowsTheSignal(logger as Logger) as Boolean {
    Test.assert(WatchStatus.gpsState(new Gps(4.6097d, -74.0817d, 3.0d, true)) == GPS_OK);
    Test.assert(WatchStatus.gpsState(new Gps(4.6097d, -74.0817d, 3.0d, false)) == GPS_LOST);
    return true;
}
