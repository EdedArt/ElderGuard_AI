import Toybox.Lang;

// Port of batteryPercent, batteryState and gpsState from src/core/watchStatus.js
// (WatchStatus.kt in wear-app).

enum BatteryState {
    BATTERY_NORMAL,
    BATTERY_LOW,
    BATTERY_CRITICAL,
}

enum GpsState {
    GPS_OK,
    GPS_LOST,
}

module WatchStatus {
    // The whole percentage shown on the watch. Rounds half up, like Math.round in the web app.
    function batteryPercent(level as Double) as Number {
        return GeneratorMath.roundTo(level, 0).toNumber();
    }

    // Critical at 10 % or less, low at 20 % or less, normal above. Both thresholds are inclusive.
    function batteryState(level as Double) as BatteryState {
        if (level <= TelemetryConfig.Battery.CRITICAL_LEVEL) {
            return BATTERY_CRITICAL;
        }
        if (level <= TelemetryConfig.Battery.LOW_LEVEL) {
            return BATTERY_LOW;
        }
        return BATTERY_NORMAL;
    }

    // The state of the battery as displayed: computed from the rounded percentage, like the web
    // app, so the color always agrees with the number on screen (20.4 % shows "20 %" and amber).
    function displayedBatteryState(battery as Battery) as BatteryState {
        return batteryState(batteryPercent(battery.level).toDouble());
    }

    function gpsState(gps as Gps) as GpsState {
        return gps.signal ? GPS_OK : GPS_LOST;
    }
}
