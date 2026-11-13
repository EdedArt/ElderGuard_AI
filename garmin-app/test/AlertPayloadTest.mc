import Toybox.Lang;
import Toybox.Test;

// The alert payload and the demo contacts, mirroring tests/alertPayload.test.js and
// AlertPayloadTest.kt in wear-app.

(:test)
class PayloadStates {
    // 130 BPM, at 4.6 / -74.08 with signal, with 47.5 % of battery.
    static function sample() as TelemetryState {
        var state = TelemetryState.initial();
        state.heartRate = new HeartRate(130);
        state.gps = new Gps(4.61234d, -74.08765d, 5.0d, true);
        state.battery = new Battery(47.5d, false);
        return state;
    }
}

(:test)
function payload_mapsEachReasonToTheWebType(logger as Logger) as Boolean {
    Test.assertEqual(AlertPayloads.typeId(AlertPayloads.typeFor(SOS_REASON_FALL)), "fall");
    Test.assertEqual(AlertPayloads.typeId(AlertPayloads.typeFor(SOS_REASON_MANUAL)), "manual-sos");
    Test.assertEqual(AlertPayloads.typeId(ALERT_HIGH_HEART_RATE), "high-heart-rate");
    return true;
}

(:test)
function payload_hasExactlyTheAgreedShapeFromTheStateGiven(logger as Logger) as Boolean {
    var state = PayloadStates.sample();
    var alert = AlertPayloads.build(state, ALERT_FALL, 12345l, ContactsConfig.contacts());
    Test.assertEqual(alert.type, ALERT_FALL);
    Test.assertEqual(alert.timestamp, 12345l);
    Test.assert(alert.gps.equals(state.gps));
    Test.assertEqual(alert.heartRate, 130);
    // The whole percentage shown on the watch, rounded half up.
    Test.assertEqual(alert.batteryLevel, 48);
    Test.assertEqual(alert.contacts.size(), 3);
    Test.assertEqual(alert.contacts[0].name, "Ana Ejemplo");
    return true;
}

(:test)
function payload_usesTheContactsItIsGiven(logger as Logger) as Boolean {
    var contacts = [new Contact("Solo Uno", RELATIONSHIP_SON, "555-0199")] as Array<Contact>;
    var alert = AlertPayloads.build(PayloadStates.sample(), ALERT_MANUAL_SOS, 1l, contacts);
    Test.assertEqual(alert.contacts.size(), 1);
    Test.assertEqual(alert.contacts[0].name, "Solo Uno");
    return true;
}

(:test)
function payload_keepsTheLastPositionAndSaysTheSignalWasLost(logger as Logger) as Boolean {
    var state = PayloadStates.sample();
    state.gps = new Gps(4.61234d, -74.08765d, 5.0d, false);
    var alert = AlertPayloads.build(state, ALERT_FALL, 1l, ContactsConfig.contacts());
    Test.assert(!alert.gps.signal);
    Test.assertEqual(alert.gps.lat, 4.61234d);
    return true;
}

(:test)
function payload_aContactListChangedLaterDoesNotChangeTheAlert(logger as Logger) as Boolean {
    var contacts = [new Contact("Solo Uno", RELATIONSHIP_SON, "555-0199")] as Array<Contact>;
    var alert = AlertPayloads.build(PayloadStates.sample(), ALERT_FALL, 1l, contacts);
    contacts.add(new Contact("Otra", RELATIONSHIP_DAUGHTER, "555-0198"));
    Test.assertEqual(alert.contacts.size(), 1);
    return true;
}

(:test)
function payload_aStateChangedLaterDoesNotChangeTheAlert(logger as Logger) as Boolean {
    var state = PayloadStates.sample();
    var alert = AlertPayloads.build(state, ALERT_FALL, 1l, ContactsConfig.contacts());
    state.heartRate = new HeartRate(70);
    state.gps = new Gps(0.0d, 0.0d, 3.0d, true);
    Test.assertEqual(alert.heartRate, 130);
    Test.assertEqual(alert.gps.lat, 4.61234d);
    return true;
}

(:test)
function payload_theDemoContactsAreTheWebOnesAllComplete(logger as Logger) as Boolean {
    var contacts = ContactsConfig.contacts();
    var names = ["Ana Ejemplo", "Luis Ejemplo", "Dra. Prueba"];
    var phones = ["555-0101", "555-0102", "555-0103"];
    var relationships = [RELATIONSHIP_DAUGHTER, RELATIONSHIP_SON, RELATIONSHIP_DOCTOR];
    Test.assertEqual(contacts.size(), names.size());
    for (var i = 0; i < contacts.size(); i++) {
        Test.assertEqual(contacts[i].name, names[i]);
        Test.assertEqual(contacts[i].phone, phones[i]);
        Test.assertEqual(contacts[i].relationship, relationships[i]);
        // Reserved for fiction: 555-01xx.
        var phone = contacts[i].phone;
        Test.assert(phone.length() == 8 && "555-01".equals(phone.substring(0, 6)));
    }
    // A new array each call, so changing one cannot change the next.
    contacts.add(new Contact("Otra", RELATIONSHIP_DAUGHTER, "555-0198"));
    Test.assertEqual(ContactsConfig.contacts().size(), 3);
    return true;
}
