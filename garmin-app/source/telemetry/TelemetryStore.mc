import Toybox.Lang;

// The parts of the telemetry state, used to report which ones changed in an update (the
// changedKeys of the web store) and, for the first four, to name a sensor in the engine.
enum StateKey {
    KEY_HEART_RATE,
    KEY_ACCELEROMETER,
    KEY_GPS,
    KEY_BATTERY,
    KEY_DEVICE_STATUS,
}

// Everything the watch knows at one moment. The single source of data for the UI.
class TelemetryState {
    var heartRate as HeartRate;
    var accelerometer as Accelerometer;
    var gps as Gps;
    var battery as Battery;
    var deviceStatus as DeviceStatus;

    function initialize(
        heartRate as HeartRate,
        accelerometer as Accelerometer,
        gps as Gps,
        battery as Battery,
        deviceStatus as DeviceStatus
    ) {
        self.heartRate = heartRate;
        self.accelerometer = accelerometer;
        self.gps = gps;
        self.battery = battery;
        self.deviceStatus = deviceStatus;
    }

    // The state before the first tick, matching createInitialState in the web store.
    static function initial() as TelemetryState {
        return new TelemetryState(
            // Midpoint rounded half up, like Math.round in JS (integer division alone truncates).
            new HeartRate((TelemetryConfig.HeartRate.RESTING_MIN + TelemetryConfig.HeartRate.RESTING_MAX + 1) / 2),
            new Accelerometer(
                TelemetryConfig.Accelerometer.REST_X,
                TelemetryConfig.Accelerometer.REST_Y,
                TelemetryConfig.Accelerometer.REST_Z
            ),
            new Gps(TelemetryConfig.Gps.BASE_LAT, TelemetryConfig.Gps.BASE_LNG, TelemetryConfig.Gps.ACCURACY_MIN, true),
            new Battery(TelemetryConfig.Battery.START_LEVEL, false),
            new DeviceStatus(MODE_MONITORING, null, null)
        );
    }

    // A shallow copy. Enough to edit safely, because the readings themselves are never changed:
    // replacing a field of the copy leaves the original untouched.
    function copy() as TelemetryState {
        return new TelemetryState(heartRate, accelerometer, gps, battery, deviceStatus);
    }

    // The parts whose values differ from other's, in StateKey order.
    function changedKeys(other as TelemetryState) as Array<StateKey> {
        var keys = [] as Array<StateKey>;
        if (!heartRate.equals(other.heartRate)) { keys.add(KEY_HEART_RATE); }
        if (!accelerometer.equals(other.accelerometer)) { keys.add(KEY_ACCELEROMETER); }
        if (!gps.equals(other.gps)) { keys.add(KEY_GPS); }
        if (!battery.equals(other.battery)) { keys.add(KEY_BATTERY); }
        if (!deviceStatus.equals(other.deviceStatus)) { keys.add(KEY_DEVICE_STATUS); }
        return keys;
    }
}

// A listener receives the new state and the parts that changed, as in the web store.
typedef TelemetryListener as Method(state as TelemetryState, changedKeys as Array<StateKey>) as Void;

// Port of src/core/telemetryStore.js. Holds the current state and notifies listeners when it
// really changes. Monkey C has no reactive streams, so this is a plain observer: listeners are
// Method objects, the callback type the Toybox API itself uses (Timer, WatchUi delegates):
//     store.register(method(:onTelemetryChanged));
class TelemetryStore {
    private var _state as TelemetryState;
    private var _listeners as Array<TelemetryListener> = [] as Array<TelemetryListener>;
    // Notifications waiting to be delivered, as [state, changedKeys] pairs.
    private var _pending as Array<Array> = [] as Array<Array>;
    private var _notifying as Boolean = false;

    function initialize() {
        _state = TelemetryState.initial();
    }

    // A copy, so a caller can edit it and pass it to update() without changing the store first.
    function getState() as TelemetryState {
        return _state.copy();
    }

    // Replaces the state. To change part of it: var next = store.getState(); next.heartRate =
    // new HeartRate(90); store.update(next). Listeners are notified only if something changed.
    function update(next as TelemetryState) as Void {
        replaceState(next.copy());
    }

    // Restores the initial state, notifying listeners of what that changed.
    function reset() as Void {
        replaceState(TelemetryState.initial());
    }

    // Keep the same Method object to unregister it later: method(:x) creates a new one each call.
    function register(listener as TelemetryListener) as Void {
        _listeners.add(listener);
    }

    function unregister(listener as TelemetryListener) as Void {
        _listeners.remove(listener);
    }

    private function replaceState(next as TelemetryState) as Void {
        var changed = next.changedKeys(_state);
        _state = next;
        if (changed.size() > 0) {
            notify(next, changed);
        }
    }

    // An update made from inside a listener waits for the current round to finish. Otherwise the
    // listeners after that one would receive the newer state first and the older one afterwards.
    private function notify(state as TelemetryState, changed as Array<StateKey>) as Void {
        _pending.add([state, changed]);
        if (_notifying) {
            return;
        }
        _notifying = true;
        try {
            while (_pending.size() > 0) {
                var entry = _pending[0];
                _pending = _pending.slice(1, null);
                // A copy of the list, so a listener can register or unregister during the round.
                var listeners = _listeners.slice(0, null);
                for (var i = 0; i < listeners.size(); i++) {
                    // Each listener gets its own copy, so it cannot change what the next one sees.
                    listeners[i].invoke((entry[0] as TelemetryState).copy(), entry[1] as Array<StateKey>);
                }
            }
        } finally {
            _notifying = false;
        }
    }
}
