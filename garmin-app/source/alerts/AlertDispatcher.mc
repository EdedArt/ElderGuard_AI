import Toybox.Lang;
import Toybox.System;

// Port of src/core/alertDispatcher.js (AlertDispatcher.kt in wear-app). A mock: it never touches
// the network, and the app has no Communications permission. Sending an alert means building its
// payload and recording it, which is where a real integration with a messaging service would go.
//
// Two things send one:
// - Every SOS, from a fall or from the button. Its listener runs inside SosController.activate(),
//   so the payload records the state of that very moment.
// - A heart rate above HeartRateAnomalyConfig.CRITICAL_BPM_THRESHOLD at rest for the sustained
//   time, once per episode. A health alert, not a fall: nobody is asked anything, and the device
//   mode stays as it is. The warning level (120 BPM) only shows the banner; it sends nothing.
class AlertDispatcher {
    private var _store as TelemetryStore;
    private var _criticalDetector as HeartRateAnomalyDetector;
    private var _clock as Clock;
    private var _listener as TelemetryListener;
    private var _alerts as Array<AlertPayload> = [] as Array<AlertPayload>;
    private var _sosAlert as AlertPayload or Null = null;

    function initialize(store as TelemetryStore, sos as SosController, criticalDetector as HeartRateAnomalyDetector, clock as Clock) {
        _store = store;
        _criticalDetector = criticalDetector;
        _clock = clock;
        sos.addTriggerListener(method(:onSosTriggered));
        _listener = method(:onTelemetryChanged) as TelemetryListener;
        store.register(_listener);
    }

    // Every alert sent, oldest first. A copy, so callers cannot change the record.
    function alerts() as Array<AlertPayload> {
        return _alerts.slice(0, null);
    }

    // The alert sent for the SOS in progress, which the SOS screen confirms; null when no SOS is
    // in progress. A health alert sent during an SOS never appears here.
    function sosAlert() as AlertPayload or Null {
        return _sosAlert;
    }

    // True while a critical heart rate episode, already reported to the family, lasts.
    function isCriticalActive() as Boolean {
        return _criticalDetector.getState() == ANOMALY_WARNING;
    }

    // Forgets every alert sent and the critical time counted so far.
    function reset() as Void {
        _alerts = [] as Array<AlertPayload>;
        _sosAlert = null;
        _criticalDetector.reset();
    }

    function onSosTriggered(reason as SosReason) as Void {
        _sosAlert = dispatch(AlertPayloads.typeFor(reason), _store.getState());
    }

    function onTelemetryChanged(state as TelemetryState, changedKeys as Array<StateKey>) as Void {
        // The next SOS must not show this one's details.
        if (state.deviceStatus.mode != MODE_SOS) {
            _sosAlert = null;
        }
        var event = _criticalDetector.process(state.heartRate.bpm, state.accelerometer, _clock.now());
        if (event == ANOMALY_EVENT_WARNING) {
            dispatch(ALERT_HIGH_HEART_RATE, state);
        }
    }

    private function dispatch(type as AlertType, state as TelemetryState) as AlertPayload {
        var alert = AlertPayloads.build(state, type, _clock.epochMs(), ContactsConfig.contacts());
        _alerts.add(alert);
        System.println("Alert recorded (mock, not sent): " + AlertPayloads.typeId(type) + " to "
            + alert.contacts.size() + " contacts");
        return alert;
    }
}
