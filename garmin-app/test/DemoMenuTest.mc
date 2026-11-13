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
        demo = new DemoController(scenario.runner, scenario.engine, scenario.fall);
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
