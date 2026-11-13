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
    private var _controller as WatchfaceController;
    private var _sos as SosController;
    // True from pushing the SOS screen until this view shows again, so it is pushed only once.
    private var _sosScreenShown as Boolean = false;

    // Created in onLayout(), when the screen size is known.
    private var _layout as WatchfaceLayout or Null;
    private var _battery as BatteryIndicator or Null;
    private var _gps as GpsIndicator or Null;
    private var _clock as ClockDisplay or Null;
    private var _heartRate as HeartRateIndicator or Null;
    private var _sosButton as SosButton or Null;
    private var _startHint as ButtonHintArc or Null;
    private var _holdHint as HoldHint or Null;

    function initialize(
        store as TelemetryStore,
        language as LanguagePreference,
        controller as WatchfaceController,
        sos as SosController
    ) {
        View.initialize();
        _store = store;
        _language = language;
        _controller = controller;
        _sos = sos;
        _listener = method(:onTelemetryChanged) as TelemetryListener;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        var layout = new WatchfaceLayout(dc.getWidth(), dc.getHeight());
        _layout = layout;
        _battery = new BatteryIndicator(layout);
        _gps = new GpsIndicator(layout);
        _clock = new ClockDisplay(layout);
        _heartRate = new HeartRateIndicator(layout);
        _sosButton = new SosButton(layout);
        _startHint = new ButtonHintArc(layout, layout.startKeyAngle, WatchColors.DANGER_TEXT);
        _holdHint = new HoldHint(layout);
    }

    // The drawables, as last filled by onUpdate(), for the watchface tests.
    function batteryIndicator() as BatteryIndicator or Null {
        return _battery;
    }

    function gpsIndicator() as GpsIndicator or Null {
        return _gps;
    }

    function clockDisplay() as ClockDisplay or Null {
        return _clock;
    }

    function heartRateIndicator() as HeartRateIndicator or Null {
        return _heartRate;
    }

    function sosButton() as SosButton or Null {
        return _sosButton;
    }

    // True if a touch at these screen coordinates is on the SOS button.
    function isOnSosButton(coordinates as [Number, Number]) as Boolean {
        var layout = _layout;
        return layout != null && layout.isOnSosButton(coordinates[0], coordinates[1]);
    }

    function onShow() as Void {
        _store.register(_listener);
        _sosScreenShown = false;
        showSosScreenIfActive();
    }

    function onHide() as Void {
        _store.unregister(_listener);
        _controller.stop();
    }

    function onTelemetryChanged(state as TelemetryState, changedKeys as Array<StateKey>) as Void {
        WatchUi.requestUpdate();
        if (changedKeys.indexOf(KEY_DEVICE_STATUS) >= 0) {
            showSosScreenIfActive();
        }
    }

    // The SOS screen covers the watchface while the mode is MODE_SOS, like the web app's overlay.
    private function showSosScreenIfActive() as Void {
        if (_sos.isActive() && !_sosScreenShown) {
            _sosScreenShown = true;
            var view = new SosView(_store, _language);
            WatchUi.pushView(view, new SosDelegate(view, _sos), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var layout = _layout;
        var battery = _battery;
        var gps = _gps;
        var clock = _clock;
        var heartRate = _heartRate;
        var sosButton = _sosButton;
        var startHint = _startHint;
        var holdHint = _holdHint;
        if (layout == null || battery == null || gps == null || clock == null || heartRate == null
            || sosButton == null || startHint == null || holdHint == null) {
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

        sosButton.title = _language.text(Rez.Strings.SosTitle, Rez.Strings.SosTitleEn);
        sosButton.label = _language.text(Rez.Strings.SosLabel, Rez.Strings.SosLabelEn);
        sosButton.pressed = _controller.hold.isPressed();
        sosButton.progress = _controller.hold.progress(_controller.now());
        sosButton.draw(dc);
        startHint.draw(dc);

        if (_controller.hold.isHintVisible(_controller.now())) {
            holdHint.text = _language.text(Rez.Strings.SosHoldHint, Rez.Strings.SosHoldHintEn);
            holdHint.draw(dc);
        }
    }
}
