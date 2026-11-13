import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point of the watch app, named in manifest.xml (entry="ElderGuardApp").
// The system creates it when the app starts and asks it for the first screen.
// It owns the telemetry store, the simulation engine, the language preference, the SOS and fall
// logic and the alert screens for as long as the app runs, the role of the ViewModel in the Wear
// OS version.
class ElderGuardApp extends Application.AppBase {

    private var _store as TelemetryStore;
    private var _engine as SimulationEngine;
    private var _language as LanguagePreference;
    private var _sos as SosController;
    private var _fallMonitor as FallMonitor;
    private var _alertScreens as AlertScreens;
    private var _alerts as AlertDispatcher;

    function initialize() {
        AppBase.initialize();
        _store = new TelemetryStore();
        _engine = new SimulationEngine(_store, new RandomSource());
        _language = new LanguagePreference(new LanguageStorage());
        _sos = new SosController(_store);
        _fallMonitor = new FallMonitor(_store, _sos, FallDetector.standard(), new Clock());
        // Registered on the store, which keeps it alive for as long as the app runs.
        new HeartRateMonitor(_store, HeartRateAnomalyDetector.warning(), new Clock());
        _alerts = new AlertDispatcher(_store, _sos, HeartRateAnomalyDetector.critical(), new Clock());
        _alertScreens = new AlertScreens(_store, _language, _sos, _fallMonitor);
    }

    // Called when the app starts, before getInitialView().
    function onStart(state as Dictionary?) as Void {
        _engine.start();
    }

    // Called when the app exits: stops the timer so nothing keeps running.
    function onStop(state as Dictionary?) as Void {
        _engine.stop();
        _alertScreens.stop();
    }

    // The first screen: the watchface, with its input delegate. The alert screens go on top of
    // it, or of whatever is showing, while an alert lasts.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var controller = new WatchfaceController(_sos);
        var view = new WatchfaceView(_store, _language, controller, _alerts);
        _alertScreens.start();
        return [view, new WatchfaceDelegate(view, controller, _language)];
    }
}
