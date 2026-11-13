import Toybox.Lang;

// Port of the state shape in src/core/telemetryStore.js (and TelemetryModels.kt in wear-app).
//
// Every reading is a small value class. They are treated as immutable: nobody changes a field
// after construction; a new reading is a new object. Monkey C has no read-only fields, so this
// is a convention, but it is what lets the store hand out its objects without copying them.
// Each class overrides equals(), so the store can tell a real change from a repeated value.
//
// Decimal readings are Double, not Float: Float is 32-bit (about 7 significant digits), which
// cannot hold a coordinate such as -74.081734 with its 6 decimals.

// What the watch is doing. Equivalent to the 'monitoring' / 'fall-countdown' / 'sos' strings in
// the web app. A named enum: integer constants that cost no memory per use (unlike strings) and
// that the strict type checker (-l 3) accepts only where a DeviceMode is expected, the same
// pattern the Toybox API uses for its own constants (for example WatchUi.SlideType).
enum DeviceMode {
    MODE_MONITORING,
    MODE_FALL_COUNTDOWN,
    MODE_SOS,
}

// A health warning the watch is showing. Equivalent to the 'high-heart-rate' string in JS.
enum HealthAlert {
    HEALTH_ALERT_HIGH_HEART_RATE,
}

// Heart rate in beats per minute.
class HeartRate {
    var bpm as Number;

    function initialize(bpm as Number) {
        self.bpm = bpm;
    }

    function equals(other as Object or Null) as Boolean {
        return other instanceof HeartRate && (other as HeartRate).bpm == bpm;
    }
}

// Acceleration on each axis, in g. A watch at rest reads about 1 g in total (gravity).
class Accelerometer {
    var x as Double;
    var y as Double;
    var z as Double;

    function initialize(x as Double, y as Double, z as Double) {
        self.x = x;
        self.y = y;
        self.z = z;
    }

    // Total acceleration in g, whatever the orientation of the watch (see Magnitude).
    function magnitude() as Double {
        return Magnitude.of(self);
    }

    // True when the reading is within toleranceG of 1 g: the watch is not moving.
    function isAtRest(toleranceG as Double) as Boolean {
        return Magnitude.isAtRest(self, toleranceG);
    }

    function equals(other as Object or Null) as Boolean {
        if (!(other instanceof Accelerometer)) {
            return false;
        }
        var reading = other as Accelerometer;
        return reading.x == x && reading.y == y && reading.z == z;
    }
}

// Position in degrees, with its accuracy in meters.
class Gps {
    var lat as Double;
    var lng as Double;
    var accuracy as Double;
    var signal as Boolean;

    function initialize(lat as Double, lng as Double, accuracy as Double, signal as Boolean) {
        self.lat = lat;
        self.lng = lng;
        self.accuracy = accuracy;
        self.signal = signal;
    }

    function equals(other as Object or Null) as Boolean {
        if (!(other instanceof Gps)) {
            return false;
        }
        var reading = other as Gps;
        return reading.lat == lat && reading.lng == lng && reading.accuracy == accuracy
            && reading.signal == signal;
    }
}

// Charge level from 0 to 100 percent.
class Battery {
    var level as Double;
    var charging as Boolean;

    function initialize(level as Double, charging as Boolean) {
        self.level = level;
        self.charging = charging;
    }

    function equals(other as Object or Null) as Boolean {
        if (!(other instanceof Battery)) {
            return false;
        }
        var reading = other as Battery;
        return reading.level == level && reading.charging == charging;
    }
}

// lastUpdate is the time of the last simulation tick in epoch milliseconds, or null before the
// first. It is a Long because epoch milliseconds do not fit in a 32-bit Number.
// healthAlert is the health warning in progress, or null. It is independent of mode: a warning
// can show during a fall countdown or an SOS.
class DeviceStatus {
    var mode as DeviceMode;
    var lastUpdate as Long or Null;
    var healthAlert as HealthAlert or Null;

    function initialize(mode as DeviceMode, lastUpdate as Long or Null, healthAlert as HealthAlert or Null) {
        self.mode = mode;
        self.lastUpdate = lastUpdate;
        self.healthAlert = healthAlert;
    }

    function equals(other as Object or Null) as Boolean {
        if (!(other instanceof DeviceStatus)) {
            return false;
        }
        var status = other as DeviceStatus;
        return status.mode == mode && status.lastUpdate == lastUpdate && status.healthAlert == healthAlert;
    }
}
