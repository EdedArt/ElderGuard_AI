import Toybox.Lang;
import Toybox.WatchUi;

// What AlertScreens does to the view stack when the device mode changes.
enum ScreenAction {
    SCREEN_NONE,
    // An alert starts: its screen goes on top of whatever is showing.
    SCREEN_PUSH,
    // One alert becomes another (a fall countdown reaching zero): its screen replaces the first.
    SCREEN_SWITCH,
    // The alert ends: its screen closes, uncovering what was there before.
    SCREEN_POP,
}

// Shows the alert screens while the device mode asks for them, like the overlays of the web app:
// the fall countdown during MODE_FALL_COUNTDOWN and the red SOS screen during MODE_SOS. The
// screens never open or close themselves.
//
// It listens to the store for as long as the app runs, not only while the watchface is visible,
// so a fall detected while the language screen is open still shows its countdown at once. It also
// gives the countdown its feel: a vibration and a redraw on every second.
class AlertScreens {
    private var _store as TelemetryStore;
    private var _language as LanguagePreference;
    private var _sos as SosController;
    private var _fall as FallMonitor;
    private var _alerts as AlertDispatcher;
    private var _listener as TelemetryListener;
    // The mode whose screen is on top; MODE_MONITORING when none is.
    private var _shown as DeviceMode = MODE_MONITORING;

    function initialize(
        store as TelemetryStore,
        language as LanguagePreference,
        sos as SosController,
        fall as FallMonitor,
        alerts as AlertDispatcher
    ) {
        _store = store;
        _alerts = alerts;
        _language = language;
        _sos = sos;
        _fall = fall;
        _listener = method(:onTelemetryChanged) as TelemetryListener;
    }

    function start() as Void {
        _store.register(_listener);
        _fall.setTickListener(method(:onCountdownTick));
        show(_store.getState().deviceStatus.mode);
    }

    function stop() as Void {
        _store.unregister(_listener);
        _fall.setTickListener(null);
    }

    function onTelemetryChanged(state as TelemetryState, changedKeys as Array<StateKey>) as Void {
        if (changedKeys.indexOf(KEY_DEVICE_STATUS) >= 0) {
            show(state.deviceStatus.mode);
        }
    }

    function onCountdownTick(remaining as Number) as Void {
        Vibration.play(Vibration.countdownPattern(remaining));
        WatchUi.requestUpdate();
    }

    // What to do when the mode whose screen is shown changes to mode.
    static function actionFor(shown as DeviceMode, mode as DeviceMode) as ScreenAction {
        if (mode == shown) {
            return SCREEN_NONE;
        }
        if (shown == MODE_MONITORING) {
            return SCREEN_PUSH;
        }
        return mode == MODE_MONITORING ? SCREEN_POP : SCREEN_SWITCH;
    }

    private function show(mode as DeviceMode) as Void {
        var action = actionFor(_shown, mode);
        _shown = mode;
        if (action == SCREEN_POP) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        } else if (action != SCREEN_NONE) {
            open(mode, action == SCREEN_SWITCH);
        }
    }

    private function open(mode as DeviceMode, replace as Boolean) as Void {
        var view;
        var delegate;
        if (mode == MODE_FALL_COUNTDOWN) {
            var countdownView = new FallCountdownView(_fall, _language);
            view = countdownView;
            delegate = new FallCountdownDelegate(countdownView, _fall);
        } else {
            var sosView = new SosView(_language, _alerts);
            view = sosView;
            delegate = new SosDelegate(sosView, _sos);
        }
        if (replace) {
            WatchUi.switchToView(view, delegate, WatchUi.SLIDE_IMMEDIATE);
        } else {
            WatchUi.pushView(view, delegate, WatchUi.SLIDE_IMMEDIATE);
        }
    }
}
