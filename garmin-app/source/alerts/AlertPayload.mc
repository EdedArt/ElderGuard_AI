import Toybox.Lang;

// What an alert is about. AlertPayloads.typeId() gives the type string of the web app's payload.
enum AlertType {
    ALERT_FALL,
    ALERT_MANUAL_SOS,
    ALERT_HIGH_HEART_RATE,
}

// What the family would receive, with the same fields as the web app's payload: type, timestamp
// (epoch milliseconds), GPS, heart rate in BPM, battery as the whole percentage shown on the
// watch, and the contacts. Treated as immutable, and made of immutable readings, so a recorded
// alert keeps saying what was true when it went out, whatever happens to the state afterwards.
class AlertPayload {
    var type as AlertType;
    var timestamp as Long;
    var gps as Gps;
    var heartRate as Number;
    var batteryLevel as Number;
    var contacts as Array<Contact>;

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
