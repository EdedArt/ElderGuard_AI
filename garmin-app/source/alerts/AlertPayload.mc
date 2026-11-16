import Toybox.Lang;

// What an alert is about. AlertPayloads.typeId() gives the type string of the web app's payload.
enum AlertType {
    ALERT_FALL,
    ALERT_MANUAL_SOS,
    ALERT_HIGH_HEART_RATE,
}

// Where the text of an alert comes from. It is pending while Gemini is being asked.
enum MessageOrigin {
    MESSAGE_PENDING,
    MESSAGE_AI,
    MESSAGE_TEMPLATE,
}

// What the family would receive, with the same fields as the web app's payload: type, timestamp
// (epoch milliseconds), GPS, heart rate in BPM, battery as the whole percentage shown on the
// watch, and the contacts. The readings are immutable, so a recorded alert keeps saying what was
// true when it went out, whatever happens to the state afterwards.
//
// The one thing filled in later is the text of the message: null while it is being generated,
// then Gemini's text or the static template, set once by AlertDispatcher.
class AlertPayload {
    var type as AlertType;
    var timestamp as Long;
    var gps as Gps;
    var heartRate as Number;
    var batteryLevel as Number;
    var contacts as Array<Contact>;
    var message as String or Null = null;
    var messageOrigin as MessageOrigin = MESSAGE_PENDING;

    function initialize(
        type as AlertType,
        timestamp as Long,
        gps as Gps,
        heartRate as Number,
        batteryLevel as Number,
        contacts as Array<Contact>
    ) {
        self.type = type;
        self.timestamp = timestamp;
        self.gps = gps;
        self.heartRate = heartRate;
        self.batteryLevel = batteryLevel;
        self.contacts = contacts;
    }

    function isMessagePending() as Boolean {
        return messageOrigin == MESSAGE_PENDING;
    }
}

// Port of buildAlertPayload in src/core/alertPayload.js (AlertPayload.kt in wear-app).
module AlertPayloads {
    // Pure: reads state and returns a new payload. The contacts are copied into a new array, so
    // changing the array passed in cannot change the alert later. The web version throws on an
    // unknown reason; here type is an enum, which the type checker restricts.
    function build(state as TelemetryState, type as AlertType, timestamp as Long, contacts as Array<Contact>) as AlertPayload {
        return new AlertPayload(
            type,
            timestamp,
            state.gps,
            state.heartRate.bpm,
            WatchStatus.batteryPercent(state.battery.level),
            contacts.slice(0, null)
        );
    }

    // The alert an SOS of this reason sends.
    function typeFor(reason as SosReason) as AlertType {
        return reason == SOS_REASON_FALL ? ALERT_FALL : ALERT_MANUAL_SOS;
    }

    // The type as the web app's payload writes it. An identifier, never shown to the wearer.
    function typeId(type as AlertType) as String {
        if (type == ALERT_FALL) {
            return "fall";
        }
        return type == ALERT_MANUAL_SOS ? "manual-sos" : "high-heart-rate";
    }
}
