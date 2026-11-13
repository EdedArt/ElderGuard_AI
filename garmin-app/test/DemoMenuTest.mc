import Toybox.Lang;
import Toybox.Test;
import Toybox.WatchUi;

// The demo menu. Menus cannot be pushed in a test, so the items are read from the Menu2 itself
// and choices go through the delegate's select(), which its onSelect() calls after closing.

(:test)
class DemoMenuHarness {
    var scenario as ScenarioHarness = new ScenarioHarness();
    var demo as DemoController;
    var delegate as DemoMenuDelegate;

    function initialize() {
        demo = new DemoController(scenario.runner, scenario.engine, scenario.store, scenario.fall, scenario.heartRate,
            scenario.alerts);
        delegate = new DemoMenuDelegate(demo);
    }

    function state() as TelemetryState {
        return scenario.state();
    }

    function finish() as Void {
        scenario.finish();
    }
}

(:test)
function demoMenu_listsTheScenariosAndResetInSpanish(logger as Logger) as Boolean {
    var language = new LanguagePreference(new MemoryLanguageStorage(null));
    var menu = DemoMenu.create(language);
    var expected = ["Simular caída", "Pulso alto", "Pulso crítico", "Batería baja", "Sin GPS", "Restablecer"];
    var ids = DemoMenu.ids();
    Test.assertEqual(ids.size(), expected.size());
    for (var i = 0; i < expected.size(); i++) {
        var item = menu.getItem(i) as WatchUi.MenuItem;
        Test.assertEqual(item.getLabel(), expected[i]);
        Test.assert(item.getId() == ids[i]);
    }
    Test.assert(menu.getItem(expected.size()) == null);
    return true;
}

(:test)
function demoMenu_speaksEnglishWhenChosen(logger as Logger) as Boolean {
    var language = new LanguagePreference(new MemoryLanguageStorage("en"));
    var menu = DemoMenu.create(language);
    var expected = ["Simulate fall", "High heart rate", "Critical heart rate", "Low battery", "GPS lost", "Reset"];
    for (var i = 0; i < expected.size(); i++) {
        Test.assertEqual((menu.getItem(i) as WatchUi.MenuItem).getLabel(), expected[i]);
    }
    return true;
}

(:test)
function demoMenu_mapsEachItemToItsScenario(logger as Logger) as Boolean {
    Test.assert(DemoMenu.scenarioFor(:fall) == SCENARIO_FALL);
    Test.assert(DemoMenu.scenarioFor(:highHeartRate) == SCENARIO_HIGH_HEART_RATE);
    Test.assert(DemoMenu.scenarioFor(:criticalHeartRate) == SCENARIO_CRITICAL_HEART_RATE);
    Test.assert(DemoMenu.scenarioFor(:lowBattery) == SCENARIO_LOW_BATTERY);
    Test.assert(DemoMenu.scenarioFor(:gpsLost) == SCENARIO_GPS_LOST);
    Test.assert(DemoMenu.scenarioFor(:reset) == null);
    return true;
}

(:test)
function demoMenu_eachItemRunsItsScenario(logger as Logger) as Boolean {
    var h = new DemoMenuHarness();
    h.delegate.select(:fall);
    Test.assert(h.state().accelerometer.equals(Scenarios.fallSpike()));
    Test.assert(h.scenario.runner.current() == SCENARIO_FALL);

    h.delegate.select(:highHeartRate);
    Test.assertEqual(h.state().heartRate.bpm, Scenarios.HIGH_HEART_RATE_BPM);

    h.delegate.select(:criticalHeartRate);
    Test.assertEqual(h.state().heartRate.bpm, Scenarios.CRITICAL_HEART_RATE_BPM);

    h.delegate.select(:lowBattery);
    Test.assertEqual(h.state().battery.level, Scenarios.LOW_BATTERY_LEVEL);

    h.delegate.select(:gpsLost);
    Test.assert(!h.state().gps.signal);
    h.finish();
    return true;
}

(:test)
function demoMenu_aSelectedFallReachesTheCountdown(logger as Logger) as Boolean {
    var h = new DemoMenuHarness();
    h.delegate.select(:fall);
    h.scenario.tick();
    h.scenario.runner.onStepDue();
    h.scenario.ticks(FallDetectionConfig.IMMOBILITY_DURATION_MS / 1000 + 1);
    Test.assertEqual(h.state().deviceStatus.mode, MODE_FALL_COUNTDOWN);
    h.finish();
    return true;
}

(:test)
function demoMenu_anotherItemCutsAFallShortAndTheDetectorForgetsIt(logger as Logger) as Boolean {
    var h = new DemoMenuHarness();
    h.delegate.select(:fall);
    h.scenario.tick();
    Test.assertEqual(h.scenario.fall.getDetectorState(), FALL_IMPACT);
    h.delegate.select(:lowBattery);
    Test.assertEqual(h.scenario.fall.getDetectorState(), FALL_IDLE);
    Test.assert(!h.scenario.engine.hasOverride(KEY_ACCELEROMETER));
    // The resting readings that follow do not complete the forgotten fall.
    h.scenario.ticks(FallDetectionConfig.IMMOBILITY_DURATION_MS / 1000 + 2);
    Test.assertEqual(h.state().deviceStatus.mode, MODE_MONITORING);
    return true;
}

(:test)
function demoMenu_resetStopsTheScenarioAndClearsTheOverrides(logger as Logger) as Boolean {
    var h = new DemoMenuHarness();
    h.delegate.select(:lowBattery);
    h.delegate.select(:criticalHeartRate);
    h.delegate.select(:fall);
    h.delegate.select(:reset);
    Test.assert(!h.scenario.runner.isRunning());
    Test.assert(!h.scenario.engine.hasOverride(KEY_ACCELEROMETER));
    Test.assert(!h.scenario.engine.hasOverride(KEY_HEART_RATE));
    Test.assert(!h.scenario.engine.hasOverride(KEY_BATTERY));
    Test.assert(!h.scenario.engine.hasOverride(KEY_GPS));
    return true;
}

(:test)
function demoMenu_theMainMenuAndLanguageScreenStillBuild(logger as Logger) as Boolean {
    var language = new LanguagePreference(new MemoryLanguageStorage(null));
    var menu = LanguageMenu.create(language);
    Test.assertEqual((menu.getItem(0) as WatchUi.MenuItem).getLabel(), "Español");
    Test.assertEqual(language.text(Rez.Strings.MenuTitle, Rez.Strings.MenuTitleEn), "Menú");
    Test.assertEqual(language.text(Rez.Strings.MenuDemo, Rez.Strings.MenuDemoEn), "Demostración");
    language.setLanguage(LANGUAGE_EN);
    Test.assertEqual(language.text(Rez.Strings.MenuLanguage, Rez.Strings.MenuLanguageEn), "Language");
    Test.assertEqual(language.text(Rez.Strings.MenuDemo, Rez.Strings.MenuDemoEn), "Demo");
    return true;
}

// --- Reset all ---

(:test)
function demoReset_closesAFallCountdownAndReturnsToMonitoring(logger as Logger) as Boolean {
    var h = new DemoMenuHarness();
    h.delegate.select(:fall);
    h.scenario.tick();
    h.scenario.runner.onStepDue();
    h.scenario.ticks(FallDetectionConfig.IMMOBILITY_DURATION_MS / 1000 + 1);
    Test.assertEqual(h.state().deviceStatus.mode, MODE_FALL_COUNTDOWN);
    h.delegate.select(:reset);
    Test.assertEqual(h.state().deviceStatus.mode, MODE_MONITORING);
    Test.assert(!h.scenario.fall.countdown().isRunning());
    Test.assertEqual(h.scenario.fall.getDetectorState(), FALL_IDLE);
    Test.assert(!h.scenario.runner.isRunning());
    // Monitoring works again: nothing goes off by itself.
    h.scenario.ticks(FallDetectionConfig.COUNTDOWN_SECONDS + 2);
    Test.assertEqual(h.state().deviceStatus.mode, MODE_MONITORING);
    Test.assertEqual(h.scenario.alerts.alerts().size(), 0);
    return true;
}

(:test)
function demoReset_closesAnSosAndForgetsItsAlert(logger as Logger) as Boolean {
    var h = new DemoMenuHarness();
    h.scenario.sos.activate(SOS_REASON_MANUAL);
    Test.assertEqual(h.scenario.alerts.alerts().size(), 1);
    h.delegate.select(:reset);
    Test.assertEqual(h.state().deviceStatus.mode, MODE_MONITORING);
    Test.assert(h.scenario.sos.activeReason() == null);
    Test.assert(h.scenario.alerts.sosAlert() == null);
    Test.assertEqual(h.scenario.alerts.alerts().size(), 0);
    return true;
}

(:test)
function demoReset_clearsTheHeartRateWarningsAndRestoresBatteryAndGps(logger as Logger) as Boolean {
    var h = new DemoMenuHarness();
    h.delegate.select(:gpsLost);
    h.delegate.select(:criticalHeartRate);
    // The draining battery makes every tick a new state: with every sensor overridden, the ticks
    // of a test, all within the same second, would only repeat the same lastUpdate.
    h.scenario.ticks(HeartRateAnomalyConfig.SUSTAINED_DURATION_MS / 1000);
    Test.assert(h.scenario.alerts.isCriticalActive());
    Test.assert(h.state().deviceStatus.healthAlert == HEALTH_ALERT_HIGH_HEART_RATE);
    h.delegate.select(:lowBattery);
    Test.assertEqual(h.state().battery.level, Scenarios.LOW_BATTERY_LEVEL);
    Test.assert(!h.state().gps.signal);

    h.delegate.select(:reset);
    var state = h.state();
    Test.assert(state.deviceStatus.healthAlert == null);
    Test.assert(!h.scenario.alerts.isCriticalActive());
    Test.assertEqual(h.scenario.heartRate.getDetectorState(), ANOMALY_NORMAL);
    Test.assertEqual(h.scenario.alerts.alerts().size(), 0);
    Test.assertEqual(state.battery.level, TelemetryConfig.Battery.START_LEVEL);
    Test.assert(state.gps.signal);
    Test.assertEqual(state.gps.lat, TelemetryConfig.Gps.BASE_LAT);
    Test.assertEqual(state.heartRate.bpm, 70);
    // Every sensor is generated again: the battery drains from 100 %, the GPS keeps its signal.
    h.scenario.tick();
    Test.assert(h.state().battery.level < TelemetryConfig.Battery.START_LEVEL);
    Test.assert(h.state().gps.signal);
    Test.assert(h.state().heartRate.bpm <= TelemetryConfig.HeartRate.RESTING_MAX);
    return true;
}
