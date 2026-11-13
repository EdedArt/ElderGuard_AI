import Toybox.Lang;

// What the demo menu can do to the watch, with no user interface, like
// src/simulator/demoController.js. Every action goes through the engine overrides or the alert
// logic, so what the audience sees is the real watch reacting.
class DemoController {
    private var _runner as ScenarioRunner;
    private var _engine as SimulationEngine;
    private var _store as TelemetryStore;
    private var _fall as FallMonitor;
    private var _heartRate as HeartRateMonitor;
    private var _alerts as AlertDispatcher;

    function initialize(
        runner as ScenarioRunner,
        engine as SimulationEngine,
        store as TelemetryStore,
        fall as FallMonitor,
        heartRate as HeartRateMonitor,
        alerts as AlertDispatcher
    ) {
        _runner = runner;
        _engine = engine;
        _store = store;
        _fall = fall;
        _heartRate = heartRate;
        _alerts = alerts;
    }

    // Starts scenario, replacing any in progress. A fall cut short is not something the wearer
    // did, so the detector forgets the half-finished sequence: the generated readings count as
    // lying still, and would otherwise complete it.
    function run(scenario as DemoScenario) as Void {
        if (_runner.current() == SCENARIO_FALL) {
            _runner.stop();
            // The store still holds the impact until the next tick, and any update before then
            // would count it again: a resting reading replaces it at once, like applyOnce in the
            // web app, before the detector forgets the sequence.
            _engine.setOverride(KEY_ACCELEROMETER, Scenarios.still());
            _engine.clearOverride(KEY_ACCELEROMETER);
            _fall.resetDetector();
        }
        _runner.run(scenario);
    }

    // Back to the state the watch started in, like resetAll in the web app: no scenario and no
    // overrides, monitoring with the countdown or SOS screen closed (AlertScreens closes it when
    // the mode returns to MODE_MONITORING, which also stops the countdown), full battery, the GPS
    // signal at the base position, both heart rate detectors and the fall detector at rest, no
    // warning, and an empty alert history.
    function resetAll() as Void {
        _runner.stop();
        _engine.clearAllOverrides();
        _store.reset();
        // After the store, whose reset is itself a reading for every detector.
        _fall.resetDetector();
        _heartRate.reset();
        _alerts.reset();
    }
}
