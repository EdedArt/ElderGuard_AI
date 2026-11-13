import Toybox.Lang;
import Toybox.Time;
import Toybox.Timer;

// A value a sensor override can hold.
typedef SensorReading as HeartRate or Accelerometer or Gps or Battery;

// Port of src/core/simulationEngine.js. Every tick runs the generators and writes all readings
// to the store in a single update. While a sensor has an override, its generator is skipped and
// the override value is used instead.
//
// The tick loop is a repeating Toybox.Timer.Timer. Devices allow only a few Timer objects per
// app, so the engine creates one on start() and releases it on stop().
class SimulationEngine {
    private var _store as TelemetryStore;
    private var _random as RandomSource;
    private var _timer as Timer.Timer or Null = null;
    private var _overrides as Dictionary<StateKey, SensorReading> = {} as Dictionary<StateKey, SensorReading>;

    function initialize(store as TelemetryStore, random as RandomSource) {
        _store = store;
        _random = random;
    }

    // Starts ticking every TelemetryConfig.TICK_INTERVAL_MS. Starting twice has no effect.
    function start() as Void {
        if (_timer == null) {
            var timer = new Timer.Timer();
            timer.start(method(:tick), TelemetryConfig.TICK_INTERVAL_MS, true);
            _timer = timer;
        }
    }

    function stop() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }

    function isRunning() as Boolean {
        return _timer != null;
    }

    // Uses value for sensor on every tick. Applied right away, so it does not wait for a tick.
    // sensor is one of the four sensor keys, and value must be that sensor's reading class.
    function setOverride(sensor as StateKey, value as SensorReading) as Void {
        var next = _store.getState();
        if (sensor == KEY_HEART_RATE && value instanceof HeartRate) {
            next.heartRate = value;
        } else if (sensor == KEY_ACCELEROMETER && value instanceof Accelerometer) {
            next.accelerometer = value;
        } else if (sensor == KEY_GPS && value instanceof Gps) {
            next.gps = value;
        } else if (sensor == KEY_BATTERY && value instanceof Battery) {
            next.battery = value;
        } else {
            throw new Lang.InvalidValueException("Not a sensor reading for key " + sensor);
        }
        _overrides.put(sensor, value);
        _store.update(next);
    }

    // The sensor is generated again from the next tick, starting from its current value.
    function clearOverride(sensor as StateKey) as Void {
        _overrides.remove(sensor);
    }

    function clearAllOverrides() as Void {
        _overrides = {} as Dictionary<StateKey, SensorReading>;
    }

    // Called by the timer. Public so tests can run one tick without waiting for the timer.
    function tick() as Void {
        var state = _store.getState();
        var next = state.copy();
        next.heartRate = _overrides.hasKey(KEY_HEART_RATE)
            ? _overrides[KEY_HEART_RATE] as HeartRate
            : Generators.nextHeartRate(state.heartRate, _random);
        next.accelerometer = _overrides.hasKey(KEY_ACCELEROMETER)
            ? _overrides[KEY_ACCELEROMETER] as Accelerometer
            : Generators.nextAccelerometer(_random);
        next.gps = _overrides.hasKey(KEY_GPS)
            ? _overrides[KEY_GPS] as Gps
            : Generators.nextGps(state.gps, _random);
        next.battery = _overrides.hasKey(KEY_BATTERY)
            ? _overrides[KEY_BATTERY] as Battery
            : Generators.nextBattery(state.battery);
        // Epoch milliseconds, as in the other apps. Time.now() has a resolution of one second,
        // which is enough for a 1-second tick.
        next.deviceStatus = new DeviceStatus(
            state.deviceStatus.mode,
            Time.now().value().toLong() * 1000l,
            state.deviceStatus.healthAlert
        );
        _store.update(next);
    }
}
