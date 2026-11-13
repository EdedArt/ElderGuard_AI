import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

// Temporary live readout, like the ones the web and Wear OS apps had before their watchfaces:
// heart rate, battery and accelerometer magnitude, centered. White on black, as in the Wear OS
// version: black pixels are off on the AMOLED screen, which saves battery.
//
// Redrawing: the view never redraws on its own timer. While it is on screen, it listens to the
// store and calls WatchUi.requestUpdate(), which asks the system to call onUpdate() at its next
// opportunity (several requests before a frame become one redraw). The store only notifies real
// changes, so the screen is drawn at most once per simulation tick, and not at all while hidden.
class MainView extends WatchUi.View {

    private var _store as TelemetryStore;
    // Kept so the same Method object can be unregistered in onHide().
    private var _listener as TelemetryListener;

    // Loaded once from the string resources, in the language chosen in the app.
    private var _heartRateFormat as String;
    private var _batteryFormat as String;
    private var _movementFormat as String;
    private var _decimalSeparator as String;

    function initialize(store as TelemetryStore, language as LanguagePreference) {
        View.initialize();
        _store = store;
        _listener = method(:onTelemetryChanged) as TelemetryListener;
        _heartRateFormat = language.text(Rez.Strings.ReadoutHeartRate, Rez.Strings.ReadoutHeartRateEn);
        _batteryFormat = language.text(Rez.Strings.ReadoutBattery, Rez.Strings.ReadoutBatteryEn);
        _movementFormat = language.text(Rez.Strings.ReadoutMovement, Rez.Strings.ReadoutMovementEn);
        _decimalSeparator = language.text(Rez.Strings.DecimalSeparator, Rez.Strings.DecimalSeparatorEn);
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

    // Draws the whole screen. Called by the system after requestUpdate() and when the view appears.
    function onUpdate(dc as Graphics.Dc) as Void {
        var state = _store.getState();
        var lines = [
            Lang.format(_heartRateFormat, [state.heartRate.bpm]),
            Lang.format(_batteryFormat, [Math.round(state.battery.level).toNumber()]),
            Lang.format(_movementFormat, [formatDecimal(state.accelerometer.magnitude())]),
        ];
        var fonts = [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_MEDIUM];

        var total = 0;
        for (var i = 0; i < fonts.size(); i++) {
            total += dc.getFontHeight(fonts[i]);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var x = dc.getWidth() / 2;
        var y = (dc.getHeight() - total) / 2;
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(x, y, fonts[i], lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += dc.getFontHeight(fonts[i]);
        }
    }

    // A non-negative value with 2 decimals and the language's decimal separator ("1,00" in
    // Spanish, "1.00" in English), like Intl.NumberFormat in the web app. format() itself always
    // uses a point.
    private function formatDecimal(value as Double) as String {
        var hundredths = Math.round(value * 100.0d).toNumber();
        return Lang.format("$1$$2$$3$", [hundredths / 100, _decimalSeparator, (hundredths % 100).format("%02d")]);
    }
}
