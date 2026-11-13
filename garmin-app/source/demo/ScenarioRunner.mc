import Toybox.Lang;
import Toybox.Timer;

// The demo scenarios, like the scenario buttons of the web app's simulator panel.
enum DemoScenario {
    // An impact of about 4.4 g, then stillness: the real detector confirms a fall.
    SCENARIO_FALL,
    // 130 BPM at rest: the amber warning after 8 seconds.
    SCENARIO_HIGH_HEART_RATE,
    // 170 BPM at rest: the critical alert to the family after 8 seconds.
    SCENARIO_CRITICAL_HEART_RATE,
    // The battery at 15 %.
    SCENARIO_LOW_BATTERY,
    // The GPS signal lost, keeping the last position.
    SCENARIO_GPS_LOST,
}

// One timed step: at atMs from the start, override sensor with value, or hand it back to its
// generator when value is null.
class ScenarioStep {
    var atMs as Number;
    var sensor as StateKey;
    var value as SensorReading or Null;

    function initialize(atMs as Number, sensor as StateKey, value as SensorReading or Null) {
        self.atMs = atMs;
        self.sensor = sensor;
        self.value = value;
    }
}

// The steps of each scenario, port of src/simulator/scenarios.js. A scenario with no final
// clear stays in force after it ends (high heart rate, low battery, GPS lost) until something
// else clears it, such as the reset.
module Scenarios {
    // Long enough for the impact to be read by at least one engine tick.
    const SPIKE_HOLD_MS = 1000;
    const HIGH_HEART_RATE_BPM = 130;
    const CRITICAL_HEART_RATE_BPM = 170;
    const LOW_BATTERY_LEVEL = 15.0d;

    // About 4.4 g, well over the impact threshold (the web app's FALL_SPIKE).
    function fallSpike() as Accelerometer {
        return new Accelerometer(2.5d, 1.8d, 3.2d);
    }

    function still() as Accelerometer {
        return new Accelerometer(0.0d, 0.0d, 1.0d);
    }

    // The steps of scenario, given the current state (losing the GPS keeps the position).
    function steps(scenario as DemoScenario, state as TelemetryState) as Array<ScenarioStep> {
        if (scenario == SCENARIO_FALL) {
            // The accelerometer goes back to its generator two ticks after the fall is confirmed,
            // so the outcome does not depend on how the steps line up with the ticks.
            var endMs = SPIKE_HOLD_MS + FallDetectionConfig.IMMOBILITY_DURATION_MS + 2 * TelemetryConfig.TICK_INTERVAL_MS;
            return [
                new ScenarioStep(0, KEY_ACCELEROMETER, fallSpike()),
                new ScenarioStep(SPIKE_HOLD_MS, KEY_ACCELEROMETER, still()),
                new ScenarioStep(endMs, KEY_ACCELEROMETER, null),
            ] as Array<ScenarioStep>;
        }
        if (scenario == SCENARIO_HIGH_HEART_RATE || scenario == SCENARIO_CRITICAL_HEART_RATE) {
            var bpm = scenario == SCENARIO_HIGH_HEART_RATE ? HIGH_HEART_RATE_BPM : CRITICAL_HEART_RATE_BPM;
            // At rest, since a fast heart while moving is not an anomaly.
            return [
                new ScenarioStep(0, KEY_HEART_RATE, new HeartRate(bpm)),
                new ScenarioStep(0, KEY_ACCELEROMETER, still()),
            ] as Array<ScenarioStep>;
        }
        if (scenario == SCENARIO_LOW_BATTERY) {
            return [new ScenarioStep(0, KEY_BATTERY, new Battery(LOW_BATTERY_LEVEL, false))] as Array<ScenarioStep>;
        }
        var gps = state.gps;
        return [new ScenarioStep(0, KEY_GPS, new Gps(gps.lat, gps.lng, gps.accuracy, false))] as Array<ScenarioStep>;
    }
}

// Port of src/core/scenarioRunner.js: plays a scenario's steps through the engine overrides
// (SimulationEngine.setOverride / clearOverride), so what the audience sees is the real watch
// reacting. Steps due at 0 run at once; each later one waits on a one-shot Timer, created only
// while a step is pending.
//
// One scenario at a time: a new one stops the one in progress. A stopped scenario is cut short,
// so it hands back every sensor it had overridden. One that ends by itself leaves in place what
// it did not clear, which is how "stay on low battery" is written.
class ScenarioRunner {
    private var _engine as SimulationEngine;
    private var _store as TelemetryStore;
    private var _timer as Timer.Timer or Null = null;
    private var _current as DemoScenario or Null = null;
    private var _steps as Array<ScenarioStep> = [] as Array<ScenarioStep>;
    private var _next as Number = 0;
    private var _elapsedMs as Number = 0;
    private var _overridden as Array<StateKey> = [] as Array<StateKey>;

    function initialize(engine as SimulationEngine, store as TelemetryStore) {
        _engine = engine;
        _store = store;
    }

    function isRunning() as Boolean {
        return _current != null;
    }

    // The scenario in progress, or null.
    function current() as DemoScenario or Null {
        return _current;
    }

    function run(scenario as DemoScenario) as Void {
        stop();
        _current = scenario;
        _steps = Scenarios.steps(scenario, _store.getState());
        _next = 0;
        _elapsedMs = 0;
        _overridden = [] as Array<StateKey>;
        advance();
    }

    // Cuts the scenario in progress short, handing back the sensors it had overridden.
    function stop() as Void {
        if (_current == null) {
            return;
        }
        _current = null;
        cancelTimer();
        for (var i = 0; i < _overridden.size(); i++) {
            _engine.clearOverride(_overridden[i]);
        }
        _overridden = [] as Array<StateKey>;
    }

    // Called by the timer when the next step is due. Public so tests can fire it at once.
    function onStepDue() as Void {
        _timer = null;
        if (_current != null && _next < _steps.size()) {
            _elapsedMs = _steps[_next].atMs;
            advance();
        }
    }

    // Applies every step due by now, then waits for the next one, or ends.
    private function advance() as Void {
        while (_current != null && _next < _steps.size()) {
            var step = _steps[_next];
            if (step.atMs > _elapsedMs) {
                var timer = new Timer.Timer();
                timer.start(method(:onStepDue), step.atMs - _elapsedMs, false);
                _timer = timer;
                return;
            }
            _next++;
            apply(step);
        }
        _current = null;
    }

    private function apply(step as ScenarioStep) as Void {
        var value = step.value;
        if (value != null) {
            _engine.setOverride(step.sensor, value);
            if (_overridden.indexOf(step.sensor) < 0) {
                _overridden.add(step.sensor);
            }
        } else {
            _engine.clearOverride(step.sensor);
            _overridden.remove(step.sensor);
        }
    }

    private function cancelTimer() as Void {
        var timer = _timer;
        if (timer != null) {
            timer.stop();
            _timer = null;
        }
    }
}
