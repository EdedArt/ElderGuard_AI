import Toybox.Lang;

// Port of src/core/heartRateMonitor.js (HeartRateMonitor.kt in wear-app): feeds the anomaly
// detector from the telemetry store, on every engine tick, and keeps deviceStatus.healthAlert at
// HEALTH_ALERT_HIGH_HEART_RATE while the warning lasts. It only reports: it never touches the
// device mode, so it runs alongside the fall flow, whatever state that is in.
class HeartRateMonitor {
    private var _store as TelemetryStore;
    private var _detector as HeartRateAnomalyDetector;
    private var _clock as Clock;
    private var _listener as TelemetryListener;

    function initialize(store as TelemetryStore, detector as HeartRateAnomalyDetector, clock as Clock) {
        _store = store;
        _detector = detector;
        _clock = clock;
        _listener = method(:onTelemetryChanged) as TelemetryListener;
        store.register(_listener);
    }

    function getDetectorState() as AnomalyState {
        return _detector.getState();
    }

    // Forgets the warning and the time counted so far.
    function reset() as Void {
        _detector.reset();
        _store.setHealthAlert(null);
    }

    function onTelemetryChanged(state as TelemetryState, changedKeys as Array<StateKey>) as Void {
        var event = _detector.process(state.heartRate.bpm, state.accelerometer, _clock.now());
        if (event == ANOMALY_EVENT_WARNING) {
            _store.setHealthAlert(HEALTH_ALERT_HIGH_HEART_RATE);
        } else if (event == ANOMALY_EVENT_RESOLVED) {
            _store.setHealthAlert(null);
        }
    }
}
