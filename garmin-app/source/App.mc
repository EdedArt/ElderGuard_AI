import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point of the watch app, named in manifest.xml (entry="ElderGuardApp").
// The system creates it when the app starts and asks it for the first screen.
// It owns the telemetry store, the simulation engine and the language preference for as long as
// the app runs, the role of the ViewModel in the Wear OS version.
class ElderGuardApp extends Application.AppBase {

    private var _store as TelemetryStore;
    private var _engine as SimulationEngine;
    private var _language as LanguagePreference;

    function initialize() {
        AppBase.initialize();
        _store = new TelemetryStore();
        _engine = new SimulationEngine(_store, new RandomSource());
        _language = new LanguagePreference(new LanguageStorage());
    }

    // Called when the app starts, before getInitialView().
    function onStart(state as Dictionary?) as Void {
        _engine.start();
    }

    // Called when the app exits: stops the timer so nothing keeps running.
    function onStop(state as Dictionary?) as Void {
        _engine.stop();
    }

    // The first screen: the watchface, with its input delegate.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        var sos = new SosController(_store);
        var controller = new WatchfaceController(sos);
        var view = new WatchfaceView(_store, _language, controller, sos);
        return [view, new WatchfaceDelegate(view, controller)];
    }
}
