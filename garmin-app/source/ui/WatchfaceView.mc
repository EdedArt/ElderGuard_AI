import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The main screen, port of the web and Wear OS watchfaces: battery and GPS at the top, the time,
// date and heart rate in the middle, and the SOS button at the bottom (see WatchfaceLayout).
//
// Redrawing follows the pattern from G3: no timer of its own. While on screen it listens to the
// store and calls WatchUi.requestUpdate(), so it redraws at most once per simulation tick (once a
// second), which also keeps the clock current. It stops listening when hidden.
class WatchfaceView extends WatchUi.View {
    private var _store as TelemetryStore;
    private var _language as LanguagePreference;
    private var _listener as TelemetryListener;

    // Created in onLayout(), when the screen size is known.
    private var _layout as WatchfaceLayout or Null;
    private var _battery as BatteryIndicator or Null;
    private var _gps as GpsIndicator or Null;
    private var _clock as ClockDisplay or Null;
    private var _heartRate as HeartRateIndicator or Null;

    function initialize(store as TelemetryStore, language as LanguagePreference) {
        View.initialize();
        _store = store;
        _language = language;
        _listener = method(:onTelemetryChanged) as TelemetryListener;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        var layout = new WatchfaceLayout(dc.getWidth(), dc.getHeight());
        _layout = layout;
        _battery = new BatteryIndicator(layout);
        _gps = new GpsIndicator(layout);
        _clock = new ClockDisplay(layout);
        _heartRate = new HeartRateIndicator(layout);
    }

    function onShow() as Void {
        _store.register(_listener);
    }

    function onHide() as Void {
        _store.unregister(_listener);
    }

    function onTelemetryChanged(state as TelemetryState, changedKeys as Array<StateKey>) as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var layout = _layout;
        var battery = _battery;
        var gps = _gps;
        var clock = _clock;
        var heartRate = _heartRate;
        if (layout == null || battery == null || gps == null || clock == null || heartRate == null) {
            return;
        }
        var state = _store.getState();

        // Status row: the battery and GPS indicators centered together.
        var percent = WatchStatus.batteryPercent(state.battery.level);
        battery.percent = percent;
        battery.text = Lang.format(_language.text(Rez.Strings.BatteryValue, Rez.Strings.BatteryValueEn), [percent]);
        battery.color = WatchColors.batteryColor(WatchStatus.displayedBatteryState(state.battery));
        var gpsState = WatchStatus.gpsState(state.gps);
        gps.text = gpsState == GPS_OK
            ? _language.text(Rez.Strings.GpsOk, Rez.Strings.GpsOkEn)
            : _language.text(Rez.Strings.GpsLost, Rez.Strings.GpsLostEn);
        gps.color = WatchColors.gpsColor(gpsState);

        var now = TimeFormat.now();
        clock.time = now.time;
        clock.period = TimeFormat.periodLabel(now, _language);
        clock.date = TimeFormat.today(_language);

        heartRate.bpm = state.heartRate.bpm;
        heartRate.unit = _language.text(Rez.Strings.HeartRateUnit, Rez.Strings.HeartRateUnitEn);

        dc.setColor(WatchColors.TEXT, WatchColors.BACKGROUND);
        dc.clear();
        dc.setAntiAlias(true);

        var batteryWidth = battery.contentWidth(dc);
        var statusWidth = batteryWidth + layout.statusGap + gps.contentWidth(dc);
        battery.setLocation(layout.centerX - statusWidth / 2, layout.statusY);
        gps.setLocation(layout.centerX - statusWidth / 2 + batteryWidth + layout.statusGap, layout.statusY);
        battery.draw(dc);
        gps.draw(dc);
        clock.draw(dc);
        heartRate.draw(dc);
    }
}
