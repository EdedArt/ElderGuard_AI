import Toybox.Lang;
import Toybox.System;

// Port of src/core/fallMonitor.js (FallMonitor.kt and FallDetector.feedFrom in wear-app): feeds
// the fall detector from the telemetry store, so every engine tick is a reading.
//
// - Every store notification counts as a reading, not only those that list the accelerometer: a
//   body lying perfectly still gives the same reading tick after tick, and the detector needs
//   those readings to see the time go by. Each tick writes a new battery level and lastUpdate,
//   so the store notifies on every tick.
// - Readings count only while the watch is monitoring. In any other mode the detector is reset,
//   otherwise a fall in progress would resume, with a gap in its timing, after the alert ends.
// - The first reading after coming back to monitoring is skipped: it still dates from the alert.
class FallMonitor {
    private var _detector as FallDetector;
    private var _clock as Clock;
    private var _listener as TelemetryListener;
    private var _previousMode as DeviceMode;

    function initialize(store as TelemetryStore, detector as FallDetector, clock as Clock) {
        _detector = detector;
        _clock = clock;
        _previousMode = store.getState().deviceStatus.mode;
        _listener = method(:onTelemetryChanged) as TelemetryListener;
        store.register(_listener);
    }

    function getDetectorState() as FallState {
        return _detector.getState();
    }

    function onTelemetryChanged(state as TelemetryState, changedKeys as Array<StateKey>) as Void {
        var mode = state.deviceStatus.mode;
        var wasMonitoring = _previousMode == MODE_MONITORING;
        _previousMode = mode;
        if (mode != MODE_MONITORING) {
            _detector.reset();
        } else if (wasMonitoring && _detector.process(state.accelerometer, _clock.now())) {
            onFallConfirmed();
        }
    }

    // Until the fall countdown exists, a confirmed fall is only logged, and the detector starts
    // watching again.
    private function onFallConfirmed() as Void {
        System.println("Fall confirmed");
        _detector.reset();
    }
}
