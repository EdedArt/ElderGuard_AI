import Toybox.Lang;

// What the demo menu can do to the watch, with no user interface, like
// src/simulator/demoController.js. Every action goes through the engine overrides or the alert
// logic, so what the audience sees is the real watch reacting.
class DemoController {
    private var _runner as ScenarioRunner;
    private var _engine as SimulationEngine;
    private var _fall as FallMonitor;

    function initialize(runner as ScenarioRunner, engine as SimulationEngine, fall as FallMonitor) {
        _runner = runner;
        _engine = engine;
        _fall = fall;
    }

    // Starts scenario, replacing any in progress. A fall cut short is not something the wearer
    // did, so the detector forgets the half-finished sequence: the generated readings count as
    // lying still, and would otherwise complete it.
    function run(scenario as DemoScenario) as Void {
        if (_runner.current() == SCENARIO_FALL) {
            _runner.stop();
            _fall.resetDetector();
        }
        _runner.run(scenario);
    }

    // Stops any scenario and hands every sensor back to its generator.
    function resetAll() as Void {
        _runner.stop();
        _engine.clearAllOverrides();
    }
}
