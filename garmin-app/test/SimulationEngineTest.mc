import Toybox.Lang;
import Toybox.Test;

// Port of the main cases in tests/simulationEngine.test.js. Run No Evil tests are synchronous and
// cannot wait for the timer, so the tests call tick() directly and check start/stop through
// isRunning(). The live timer is checked in the simulator (see README).

(:test)
function engine_doesNotRunOrTickUntilStarted(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var engine = new SimulationEngine(store, new FixedRandom(0.9d));
    Test.assert(!engine.isRunning());
    Test.assert(store.getState().deviceStatus.lastUpdate == null);
    return true;
}

(:test)
function engine_reportsItsRunningStateAndCanRestart(logger as Logger) as Boolean {
    var engine = new SimulationEngine(new TelemetryStore(), new FixedRandom(0.9d));
    engine.stop(); // Stopping while stopped is harmless.
    engine.start();
    engine.start(); // Starting twice keeps a single timer.
    Test.assert(engine.isRunning());
    engine.stop();
    Test.assert(!engine.isRunning());
    engine.start();
    Test.assert(engine.isRunning());
    engine.stop();
    return true;
}

(:test)
function engine_writesEverySensorAndTheTimestampInASingleUpdate(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    // 0.9 moves every reading away from its initial value: +2 BPM (1.6 rounded), +0.02 g, +0.000016 degrees.
    var engine = new SimulationEngine(store, new FixedRandom(0.9d));
    var recorder = new ListenerRecorder("a", [] as Array<String>);
    store.register(recorder.listener());

    engine.tick();

    Test.assertEqual(recorder.states.size(), 1);
    var expected = [KEY_HEART_RATE, KEY_ACCELEROMETER, KEY_GPS, KEY_BATTERY, KEY_DEVICE_STATUS] as Array<StateKey>;
    Test.assert(TestSupport.sameKeys(recorder.keys[0], expected));
    var state = store.getState();
    Test.assertEqual(state.heartRate.bpm, 72);
    Test.assertEqual(state.battery.level, 99.99d);
    Test.assert(state.deviceStatus.lastUpdate != null);
    return true;
}

(:test)
function engine_usesTheOverrideOnEveryTickAndKeepsGeneratingTheRest(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var engine = new SimulationEngine(store, new FixedRandom(0.9d));
    engine.setOverride(KEY_HEART_RATE, new HeartRate(150));
    engine.tick();
    engine.tick();
    var state = store.getState();
    Test.assertEqual(state.heartRate.bpm, 150);
    Test.assertEqual(state.battery.level, 99.98d);
    return true;
}

(:test)
function engine_appliesAnOverrideRightAwayEvenWhileStopped(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var engine = new SimulationEngine(store, new FixedRandom(0.9d));
    engine.setOverride(KEY_GPS, new Gps(4.6097d, -74.0817d, 3.0d, false));
    Test.assert(!store.getState().gps.signal);
    Test.assert(store.getState().deviceStatus.lastUpdate == null);
    return true;
}

(:test)
function engine_resumesGenerationFromTheOverriddenValueAfterClearOverride(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var engine = new SimulationEngine(store, new FixedRandom(0.9d));
    engine.setOverride(KEY_BATTERY, new Battery(15.0d, false));
    engine.tick();
    Test.assertEqual(store.getState().battery.level, 15.0d);
    engine.clearOverride(KEY_BATTERY);
    engine.tick();
    Test.assertEqual(store.getState().battery.level, 14.99d);
    return true;
}

(:test)
function engine_clearAllOverridesResumesEverySensor(logger as Logger) as Boolean {
    var store = new TelemetryStore();
    var engine = new SimulationEngine(store, new FixedRandom(0.9d));
    engine.setOverride(KEY_HEART_RATE, new HeartRate(150));
    engine.setOverride(KEY_BATTERY, new Battery(15.0d, false));
    engine.clearAllOverrides();
    engine.tick();
    Test.assertEqual(store.getState().heartRate.bpm, 80); // 150 + 2, clamped back to the resting range.
    Test.assertEqual(store.getState().battery.level, 14.99d);
    return true;
}

(:test)
function engine_rejectsAValueThatIsNotThatSensorsReading(logger as Logger) as Boolean {
    var engine = new SimulationEngine(new TelemetryStore(), new FixedRandom(0.9d));
    var rejected = 0;
    try {
        engine.setOverride(KEY_DEVICE_STATUS, new HeartRate(150));
    } catch (e instanceof Lang.InvalidValueException) {
        rejected++;
    }
    try {
        engine.setOverride(KEY_GPS, new HeartRate(150));
    } catch (e instanceof Lang.InvalidValueException) {
        rejected++;
    }
    return rejected == 2;
}
