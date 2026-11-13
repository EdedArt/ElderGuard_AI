import Toybox.Lang;

// Helpers shared by several test files. Everything here is (:test), so it stays out of the app.

// A clock whose time the test sets, so seconds of detection pass instantly.
(:test)
class FakeClock extends Clock {
    var time as Number = 0;

    function initialize() {
        Clock.initialize();
    }

    function now() as Number {
        return time;
    }
}

// Readings and store writes the detector and alert tests share. A class with static functions,
// since a global (:test) function would be taken for a test.
(:test)
class TestReadings {
    // Readings along z only, in g.
    static function z(value as Double) as Accelerometer {
        return new Accelerometer(0.0d, 0.0d, value);
    }

    static function spike() as Accelerometer {
        return z(FallDetectionConfig.IMPACT_THRESHOLD_G + 1.0d);
    }

    static function still() as Accelerometer {
        return z(1.0d);
    }

    static function moving() as Accelerometer {
        return z(1.0d + FallDetectionConfig.IMMOBILITY_TOLERANCE_G + 0.3d);
    }

    // Writes one reading into the store at the given time, the way an engine tick does: with a
    // new lastUpdate, so the store notifies even when the reading itself repeats.
    static function write(store as TelemetryStore, clock as FakeClock, accelerometer as Accelerometer, atMs as Number) as Void {
        clock.time = atMs;
        var next = store.getState();
        var status = next.deviceStatus;
        next.accelerometer = accelerometer;
        next.deviceStatus = new DeviceStatus(status.mode, atMs.toLong(), status.healthAlert);
        store.update(next);
    }
}
