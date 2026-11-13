import Toybox.Lang;
import Toybox.Test;

// The scenario runner, mirroring tests/scenarioRunner.test.js and tests/scenarios.test.js. The
// tests fire onStepDue() instead of waiting for the timer, and run the engine's tick() by hand.

// The real store, engine (not started), monitors and dispatcher, with a fake clock.
(:test)
class ScenarioHarness {
    var store as TelemetryStore = new TelemetryStore();
    var clock as FakeClock = new FakeClock();
    var engine as SimulationEngine;
    var runner as ScenarioRunner;
    var sos as SosController;
    var fall as FallMonitor;
    var alerts as AlertDispatcher;

    function initialize() {
        clock.time = 100000;
        engine = new SimulationEngine(store, new RandomSource());
        runner = new ScenarioRunner(engine, store);
        sos = new SosController(store);
        fall = new FallMonitor(store, sos, FallDetector.standard(), clock);
        new HeartRateMonitor(store, HeartRateAnomalyDetector.warning(), clock);
        alerts = new AlertDispatcher(store, sos, HeartRateAnomalyDetector.critical(), clock);
    }

    // One engine tick, a second later.
    function tick() as Void {
        clock.time += 1000;
        engine.tick();
    }

    function ticks(count as Number) as Void {
        for (var i = 0; i < count; i++) {
            tick();
        }
    }

    function state() as TelemetryState {
        return store.getState();
    }

    function finish() as Void {
        runner.stop();
        fall.countdown().cancel();
    }
}

// --- Steps and timing ---

(:test)
function scenario_appliesTheStepsDueAtZeroRightAway(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_HIGH_HEART_RATE);
    Test.assertEqual(h.state().heartRate.bpm, Scenarios.HIGH_HEART_RATE_BPM);
    Test.assert(h.state().accelerometer.equals(Scenarios.still()));
    // Nothing left to wait for: it has already ended.
    Test.assert(!h.runner.isRunning());
    return true;
}

(:test)
function scenario_keepsLaterStepsWaitingUntilTheirTime(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_FALL);
    Test.assert(h.runner.isRunning());
    Test.assert(h.runner.current() == SCENARIO_FALL);
    Test.assert(h.state().accelerometer.equals(Scenarios.fallSpike()));
    h.runner.onStepDue();
    Test.assert(h.state().accelerometer.equals(Scenarios.still()));
    Test.assert(h.engine.hasOverride(KEY_ACCELEROMETER));
    Test.assert(h.runner.isRunning());
    h.runner.onStepDue();
    // The last step hands the accelerometer back, and the scenario is over.
    Test.assert(!h.engine.hasOverride(KEY_ACCELEROMETER));
    Test.assert(!h.runner.isRunning());
    Test.assert(h.runner.current() == null);
    return true;
}

(:test)
function scenario_theFallHandsTheSensorBackTwoTicksAfterItIsConfirmed(logger as Logger) as Boolean {
    var steps = Scenarios.steps(SCENARIO_FALL, TelemetryState.initial());
    Test.assertEqual(steps.size(), 3);
    Test.assertEqual(steps[0].atMs, 0);
    Test.assert(steps[0].value != null && Magnitude.of(steps[0].value as Accelerometer) >= FallDetectionConfig.IMPACT_THRESHOLD_G);
    Test.assertEqual(steps[1].atMs, Scenarios.SPIKE_HOLD_MS);
    Test.assert((steps[1].value as Accelerometer).isAtRest(FallDetectionConfig.IMMOBILITY_TOLERANCE_G));
    Test.assertEqual(steps[2].atMs, Scenarios.SPIKE_HOLD_MS + FallDetectionConfig.IMMOBILITY_DURATION_MS + 2000);
    Test.assert(steps[2].value == null);
    return true;
}

// --- Ending and stopping ---

(:test)
function scenario_keepsWhatAScenarioLeftSetWhenItEndsByItself(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_LOW_BATTERY);
    Test.assert(!h.runner.isRunning());
    Test.assert(h.engine.hasOverride(KEY_BATTERY));
    h.ticks(3);
    Test.assertEqual(h.state().battery.level, Scenarios.LOW_BATTERY_LEVEL);
    return true;
}

(:test)
function scenario_aStoppedScenarioClearsWhatItSetAndDropsThePendingSteps(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_FALL);
    h.runner.stop();
    Test.assert(!h.runner.isRunning());
    Test.assert(!h.engine.hasOverride(KEY_ACCELEROMETER));
    // A timer that still fires changes nothing.
    h.runner.onStepDue();
    Test.assert(!h.engine.hasOverride(KEY_ACCELEROMETER));
    return true;
}

(:test)
function scenario_stopDoesNothingWhenNoScenarioIsRunning(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_LOW_BATTERY);
    // Ended by itself: stopping now must not hand back its held battery.
    h.runner.stop();
    Test.assert(h.engine.hasOverride(KEY_BATTERY));
    return true;
}

(:test)
function scenario_aNewScenarioReplacesTheOneInProgress(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_FALL);
    h.runner.run(SCENARIO_LOW_BATTERY);
    // The fall was cut short: its accelerometer is handed back, and its steps never run.
    Test.assert(!h.engine.hasOverride(KEY_ACCELEROMETER));
    h.runner.onStepDue();
    Test.assert(!h.engine.hasOverride(KEY_ACCELEROMETER));
    Test.assert(h.engine.hasOverride(KEY_BATTERY));
    return true;
}

(:test)
function scenario_losingTheGpsKeepsTheLastPosition(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.tick();
    var before = h.state().gps;
    h.runner.run(SCENARIO_GPS_LOST);
    var gps = h.state().gps;
    Test.assert(!gps.signal);
    Test.assertEqual(gps.lat, before.lat);
    Test.assertEqual(gps.lng, before.lng);
    h.ticks(2);
    Test.assert(!h.state().gps.signal);
    return true;
}

// --- Through the real detectors ---

(:test)
function scenario_aSimulatedFallReachesTheCountdown(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_FALL);
    h.tick();
    Test.assertEqual(h.fall.getDetectorState(), FALL_IMPACT);
    h.runner.onStepDue();
    // Stillness for the immobility time, a reading per tick.
    h.ticks(FallDetectionConfig.IMMOBILITY_DURATION_MS / 1000 + 1);
    Test.assertEqual(h.state().deviceStatus.mode, MODE_FALL_COUNTDOWN);
    Test.assert(h.fall.remainingSeconds() == FallDetectionConfig.COUNTDOWN_SECONDS);
    h.finish();
    return true;
}

(:test)
function scenario_highHeartRateShowsTheWarningAndSendsNothing(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_HIGH_HEART_RATE);
    h.ticks(HeartRateAnomalyConfig.SUSTAINED_DURATION_MS / 1000);
    Test.assert(h.state().deviceStatus.healthAlert == HEALTH_ALERT_HIGH_HEART_RATE);
    Test.assertEqual(h.alerts.alerts().size(), 0);
    Test.assertEqual(h.state().deviceStatus.mode, MODE_MONITORING);
    return true;
}

(:test)
function scenario_criticalHeartRateSendsTheHealthAlert(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_CRITICAL_HEART_RATE);
    h.ticks(HeartRateAnomalyConfig.SUSTAINED_DURATION_MS / 1000);
    Test.assert(h.alerts.isCriticalActive());
    Test.assertEqual(h.alerts.alerts().size(), 1);
    Test.assertEqual(h.alerts.alerts()[0].type, ALERT_HIGH_HEART_RATE);
    Test.assertEqual(h.state().deviceStatus.mode, MODE_MONITORING);
    return true;
}

(:test)
function scenario_lowBatteryTurnsTheIndicatorAmber(logger as Logger) as Boolean {
    var h = new ScenarioHarness();
    h.runner.run(SCENARIO_LOW_BATTERY);
    Test.assertEqual(WatchStatus.displayedBatteryState(h.state().battery), BATTERY_LOW);
    return true;
}
