import Toybox.Lang;
import Toybox.WatchUi;

// The demo screen, like the scenario buttons of the web app's simulator panel: a Menu2 that
// lets the presenter trigger each scenario from the watch itself, with no USB or console.
// Choosing an item closes the menu at once, so the audience sees the watchface react.
module DemoMenu {
    // The items, top to bottom, by id.
    function ids() as Array<Symbol> {
        return [:fall, :highHeartRate, :criticalHeartRate, :lowBattery, :gpsLost, :reset] as Array<Symbol>;
    }

    function create(language as LanguagePreference) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => language.text(Rez.Strings.DemoTitle, Rez.Strings.DemoTitleEn)});
        var ids = ids();
        for (var i = 0; i < ids.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(label(ids[i], language), null, ids[i], {}));
        }
        return menu;
    }

    function label(id as Symbol, language as LanguagePreference) as String {
        if (id == :fall) {
            return language.text(Rez.Strings.DemoFall, Rez.Strings.DemoFallEn);
        }
        if (id == :highHeartRate) {
            return language.text(Rez.Strings.DemoHighHeartRate, Rez.Strings.DemoHighHeartRateEn);
        }
        if (id == :criticalHeartRate) {
            return language.text(Rez.Strings.DemoCriticalHeartRate, Rez.Strings.DemoCriticalHeartRateEn);
        }
        if (id == :lowBattery) {
            return language.text(Rez.Strings.DemoLowBattery, Rez.Strings.DemoLowBatteryEn);
        }
        if (id == :gpsLost) {
            return language.text(Rez.Strings.DemoGpsLost, Rez.Strings.DemoGpsLostEn);
        }
        return language.text(Rez.Strings.DemoReset, Rez.Strings.DemoResetEn);
    }

    // The scenario an item runs, or null for the reset.
    function scenarioFor(id as Symbol) as DemoScenario or Null {
        if (id == :fall) {
            return SCENARIO_FALL;
        }
        if (id == :highHeartRate) {
            return SCENARIO_HIGH_HEART_RATE;
        }
        if (id == :criticalHeartRate) {
            return SCENARIO_CRITICAL_HEART_RATE;
        }
        if (id == :lowBattery) {
            return SCENARIO_LOW_BATTERY;
        }
        if (id == :gpsLost) {
            return SCENARIO_GPS_LOST;
        }
        return null;
    }
}

class DemoMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _demo as DemoController;

    function initialize(demo as DemoController) {
        Menu2InputDelegate.initialize();
        _demo = demo;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        select(item.getId() as Symbol);
    }

    // What choosing the item with this id does; the tests call it directly.
    function select(id as Symbol) as Void {
        var scenario = DemoMenu.scenarioFor(id);
        if (scenario != null) {
            _demo.run(scenario);
        } else {
            _demo.resetAll();
        }
    }
}

// The menu of every Garmin watch, opened by holding UP: the language screen and the demo screen.
// Reaching a scenario takes three deliberate steps (hold UP, "Demostración", the scenario), so it
// is never triggered by accident. The language screen also stays one gesture away with DOWN or a
// swipe up, as before.
module MainMenu {
    function open(language as LanguagePreference, demo as DemoController) as Void {
        var menu = new WatchUi.Menu2({:title => language.text(Rez.Strings.MenuTitle, Rez.Strings.MenuTitleEn)});
        menu.addItem(new WatchUi.MenuItem(language.text(Rez.Strings.MenuLanguage, Rez.Strings.MenuLanguageEn), null, :language, {}));
        menu.addItem(new WatchUi.MenuItem(language.text(Rez.Strings.MenuDemo, Rez.Strings.MenuDemoEn), null, :demo, {}));
        WatchUi.pushView(menu, new MainMenuDelegate(language, demo), WatchUi.SLIDE_UP);
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _language as LanguagePreference;
    private var _demo as DemoController;

    function initialize(language as LanguagePreference, demo as DemoController) {
        Menu2InputDelegate.initialize();
        _language = language;
        _demo = demo;
    }

    // Each choice replaces this menu, so closing the next one returns straight to the watchface.
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :demo) {
            WatchUi.switchToView(DemoMenu.create(_language), new DemoMenuDelegate(_demo), WatchUi.SLIDE_LEFT);
        } else {
            WatchUi.switchToView(LanguageMenu.create(_language), new LanguageMenuDelegate(_language), WatchUi.SLIDE_LEFT);
        }
    }
}
