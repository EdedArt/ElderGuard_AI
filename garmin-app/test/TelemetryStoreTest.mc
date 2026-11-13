import Toybox.Lang;
import Toybox.Test;

// Port of the main cases in tests/telemetryStore.test.js, for Run No Evil (Toybox.Test).
// Everything in test/ is annotated (:test), so the compiler leaves it out of normal builds.

// Records every notification it receives.
(:test)
class ListenerRecorder {
    var states as Array<TelemetryState> = [] as Array<TelemetryState>;
    var keys as Array<Array<StateKey> > = [] as Array<Array<StateKey> >;
    var name as String;
    var log as Array<String>;

    function initialize(name as String, log as Array<String>) {
        self.name = name;
        self.log = log;
    }

    function onChange(state as TelemetryState, changedKeys as Array<StateKey>) as Void {
        states.add(state);
        keys.add(changedKeys);
        log.add(name + ":" + state.heartRate.bpm);
    }

    function listener() as TelemetryListener {
        return method(:onChange) as TelemetryListener;
    }
}

// On its first notification, writes another heart rate from inside the listener.
(:test)
class NestedUpdater extends ListenerRecorder {
    private var _store as TelemetryStore;
    private var _done as Boolean = false;

    function initialize(name as String, log as Array<String>, store as TelemetryStore) {
        ListenerRecorder.initialize(name, log);
        _store = store;
    }

    function onChange(state as TelemetryState, changedKeys as Array<StateKey>) as Void {
        ListenerRecorder.onChange(state, changedKeys);
        if (!_done) {
            _done = true;
            _store.update(TestSupport.withHeartRate(_store, 99));
            Test.assertEqualMessage(_store.getState().heartRate.bpm, 99, "nested update not visible right away");
        }
    }
}

// Shared helpers. Static methods of a (:test) class: a (:test) function would be run as a test.
(:test)
class TestSupport {
    static function withHeartRate(store as TelemetryStore, bpm as Number) as TelemetryState {
        var next = store.getState();
        next.heartRate = new HeartRate(bpm);
        return next;
    }

    static function sameKeys(actual as Array<StateKey>, expected as Array<StateKey>) as Boolean {
        if (actual.size() != expected.size()) {
            return false;
        }
        for (var i = 0; i < actual.size(); i++) {
            if (actual[i] != expected[i]) {
                return false;
            }
        }
        return true;
    }
}

(:test)
function store_startsWithTheDocumentedState(logger as Logger) as Boolean {
    var state = new TelemetryStore().getState();
    Test.assertEqual(state.heartRate.bpm, 70);
    Test.assert(state.accelerometer.equals(new Accelerometer(0.0d, 0.0d, 1.0d)));
    Test.assert(state.gps.equals(new Gps(4.6097d, -74.0817d, 3.0d, true)));
    Test.assert(state.battery.equals(new Battery(100.0d, false)));
    Test.assertEqual(state.deviceStatus.mode, MODE_MONITORING);
    Test.assert(state.deviceStatus.lastUpdate == null);
    Test.assert(state.deviceStatus.healthAlert == null);
    return true;
}

(:test)
function store_getStateReturnsACopy(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    store.getState().heartRate = new HeartRate(150);
    Test.assertEqual(store.getState().heartRate.bpm, 70);
    return true;
}

(:test)
function store_updateKeepsTheRestAndNotifiesTheChangedKeys(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var recorder = new ListenerRecorder("a", [] as Array<String>);
    store.register(recorder.listener());

    var next = store.getState();
    next.heartRate = new HeartRate(90);
    next.battery = new Battery(50.0d, false);
    store.update(next);

    Test.assertEqual(recorder.states.size(), 1);
    Test.assertEqual(recorder.states[0].heartRate.bpm, 90);
    Test.assert(recorder.states[0].gps.equals(new Gps(4.6097d, -74.0817d, 3.0d, true)));
    Test.assert(TestSupport.sameKeys(recorder.keys[0], [KEY_HEART_RATE, KEY_BATTERY] as Array<StateKey>));
    return true;
}

(:test)
function store_leavesOutValuesThatDidNotReallyChange(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var recorder = new ListenerRecorder("a", [] as Array<String>);
    store.register(recorder.listener());

    var next = store.getState();
    next.heartRate = new HeartRate(70); // Same value, new object.
    next.gps = new Gps(4.6097d, -74.0817d, 5.0d, true);
    store.update(next);

    Test.assert(TestSupport.sameKeys(recorder.keys[0], [KEY_GPS] as Array<StateKey>));
    return true;
}

(:test)
function store_doesNotNotifyWhenNothingChanged(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var recorder = new ListenerRecorder("a", [] as Array<String>);
    store.register(recorder.listener());
    store.update(store.getState());
    Test.assertEqual(recorder.states.size(), 0);
    return true;
}

(:test)
function store_doesNotKeepTheStateItWasGiven(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var next = TestSupport.withHeartRate(store, 90);
    store.update(next);
    next.heartRate = new HeartRate(150);
    Test.assertEqual(store.getState().heartRate.bpm, 90);
    return true;
}

(:test)
function store_givesListenersACopy(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var log = [] as Array<String>;
    var first = new ListenerRecorder("first", log);
    var second = new ListenerRecorder("second", log);
    store.register(first.listener());
    store.register(second.listener());

    store.update(TestSupport.withHeartRate(store, 90));
    first.states[0].heartRate = new HeartRate(150);

    Test.assertEqual(second.states[0].heartRate.bpm, 90);
    Test.assertEqual(store.getState().heartRate.bpm, 90);
    return true;
}

(:test)
function store_stopsNotifyingAfterUnregister(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var recorder = new ListenerRecorder("a", [] as Array<String>);
    var listener = recorder.listener();
    store.register(listener);
    store.update(TestSupport.withHeartRate(store, 90));
    store.unregister(listener);
    store.update(TestSupport.withHeartRate(store, 91));
    Test.assertEqual(recorder.states.size(), 1);
    return true;
}

(:test)
function store_resetRestoresTheInitialStateAndReportsTheChange(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    store.update(TestSupport.withHeartRate(store, 90));
    var recorder = new ListenerRecorder("a", [] as Array<String>);
    store.register(recorder.listener());

    store.reset();

    Test.assertEqual(store.getState().heartRate.bpm, 70);
    Test.assert(TestSupport.sameKeys(recorder.keys[0], [KEY_HEART_RATE] as Array<StateKey>));
    return true;
}

(:test)
function store_resetDoesNotNotifyWhenAlreadyInitial(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var recorder = new ListenerRecorder("a", [] as Array<String>);
    store.register(recorder.listener());
    store.reset();
    Test.assertEqual(recorder.states.size(), 0);
    return true;
}

(:test)
function store_nestedUpdatesReachEveryListenerInOrderAfterTheCurrentRound(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var log = [] as Array<String>;
    var first = new NestedUpdater("first", log, store);
    var second = new ListenerRecorder("second", log);
    store.register(first.listener());
    store.register(second.listener());

    store.update(TestSupport.withHeartRate(store, 90));

    var expected = ["first:90", "second:90", "first:99", "second:99"];
    Test.assertEqual(log.size(), expected.size());
    for (var i = 0; i < expected.size(); i++) {
        Test.assertEqualMessage(log[i], expected[i], "notification " + i + " out of order");
    }
    return true;
}
