import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point of the watch app, named in manifest.xml (entry="ElderGuardApp").
// The system creates it when the app starts and asks it for the first screen.
class ElderGuardApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Called when the app starts. Telemetry and detectors will be started here in later phases.
    function onStart(state as Dictionary?) as Void {
    }

    // Called when the app exits. Sensors and timers will be released here in later phases.
    function onStop(state as Dictionary?) as Void {
    }

    // The first screen: for now, a single view with no input delegate.
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new MainView()];
    }
}
