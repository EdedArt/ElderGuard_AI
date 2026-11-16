import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Port of src/core/alertDispatcher.js (AlertDispatcher.kt in wear-app). A mock: sending an alert
// means building its payload and recording it, which is where a real integration with a
// messaging service would go. The only network use is asking Gemini for the text of the message.
//
// Every alert is recorded at once, with its message pending. The message source (Gemini in the
// app) is asked for the text; when it answers, the alert gets that text, and when it answers null
// (timeout, no connection, an error) it gets the static template. Either way the alert is then
// "sent". The flow is the same in both cases, and the same for the three kinds of alert.
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
    private var _language as LanguagePreference;
    private var _messages as AlertMessageSource;
    private var _listener as TelemetryListener;
    private var _alerts as Array<AlertPayload> = [] as Array<AlertPayload>;
    private var _sosAlert as AlertPayload or Null = null;
    private var _criticalAlert as AlertPayload or Null = null;

    function initialize(
        store as TelemetryStore,
        sos as SosController,
        criticalDetector as HeartRateAnomalyDetector,
        clock as Clock,
        language as LanguagePreference,
        messages as AlertMessageSource
    ) {
        _store = store;
        _criticalDetector = criticalDetector;
        _clock = clock;
        _language = language;
        _messages = messages;
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

    // The alert of the critical heart rate episode in progress, or null when there is none.
    function criticalAlert() as AlertPayload or Null {
        return isCriticalActive() ? _criticalAlert : null;
    }

    // Forgets every alert sent and the critical time counted so far, and stops waiting for the
    // messages still being generated.
    function reset() as Void {
        _messages.cancelAll();
        _alerts = [] as Array<AlertPayload>;
        _sosAlert = null;
        _criticalAlert = null;
        _criticalDetector.reset();
    }

    // The message of alert is ready: text from the message source, or null for the template.
    // Only the first answer counts.
    function completeMessage(alert as AlertPayload, text as String or Null) as Void {
        if (!alert.isMessagePending()) {
            return;
        }
        if (text != null) {
            alert.message = text;
            alert.messageOrigin = MESSAGE_AI;
        } else {
            alert.message = AlertMessages.template(alert, _language);
            alert.messageOrigin = MESSAGE_TEMPLATE;
        }
        System.println("Alert sent (mock): " + AlertPayloads.typeId(alert.type) + " to " + alert.contacts.size()
            + " contacts, " + (text != null ? "Gemini" : "template") + " message: " + alert.message);
        WatchUi.requestUpdate();
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
            _criticalAlert = dispatch(ALERT_HIGH_HEART_RATE, state);
        }
    }

    private function dispatch(type as AlertType, state as TelemetryState) as AlertPayload {
        var alert = AlertPayloads.build(state, type, _clock.epochMs(), ContactsConfig.contacts());
        _alerts.add(alert);
        System.println("Alert recorded (mock): " + AlertPayloads.typeId(type) + ", generating its message");
        var pending = new PendingAlertMessage(self, alert);
        _messages.request(AlertMessageContext.of(alert, _language.getLanguage()),
            pending.method(:onText) as AlertMessageCallback);
        return alert;
    }
}

// Takes the answer of the message source back to the alert it is for, since a callback cannot
// carry the alert itself.
class PendingAlertMessage {
    private var _dispatcher as AlertDispatcher;
    private var _alert as AlertPayload;

    function initialize(dispatcher as AlertDispatcher, alert as AlertPayload) {
        _dispatcher = dispatcher;
        _alert = alert;
    }

    function onText(text as String or Null) as Void {
        _dispatcher.completeMessage(_alert, text);
    }
}
