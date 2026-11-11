package com.elderguard.ai.alerts

import com.elderguard.ai.config.ContactsConfig
import com.elderguard.ai.telemetry.Accelerometer
import com.elderguard.ai.telemetry.Battery
import com.elderguard.ai.telemetry.DeviceMode
import com.elderguard.ai.telemetry.DeviceStatus
import com.elderguard.ai.telemetry.Gps
import com.elderguard.ai.telemetry.HeartRate
import com.elderguard.ai.telemetry.TelemetryState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private val STATE = TelemetryState(
    heartRate = HeartRate(88),
    accelerometer = Accelerometer(0.0, 0.0, 1.0),
    gps = Gps(lat = 4.6097, lng = -74.0817, accuracy = 5.0, signal = true),
    battery = Battery(level = 42.6, charging = false),
    deviceStatus = DeviceStatus(mode = DeviceMode.Sos, lastUpdate = 1),
)

/** Mirrors tests/alertPayload.test.js. */
class AlertPayloadTest {
    private fun build(type: AlertType) = buildAlertPayload(STATE, type, timestamp = 12345)

    @Test
    fun mapsEachReasonToTheWebType() {
        assertEquals("fall", SosReason.Fall.alertType.id)
        assertEquals("manual-sos", SosReason.Manual.alertType.id)
        assertEquals("high-heart-rate", AlertType.HighHeartRate.id)
    }

    @Test
    fun hasExactlyTheAgreedShapeFromTheStateGiven() {
        val expected = AlertPayload(
            type = AlertType.Fall,
            timestamp = 12345,
            gps = STATE.gps,
            heartRate = 88,
            batteryLevel = 43,
            contacts = ContactsConfig.CONTACTS,
        )
        assertEquals(expected, build(AlertType.Fall))
    }

    @Test
    fun usesTheContactsItIsGiven() {
        val contacts = listOf(Contact("Test", Relationship.Son, "555-0199"))
        assertEquals(contacts, buildAlertPayload(STATE, AlertType.Fall, 1, contacts).contacts)
    }

    @Test
    fun keepsTheLastPositionAndSaysTheSignalWasLost() {
        val state = STATE.copy(gps = STATE.gps.copy(signal = false))
        val alert = buildAlertPayload(state, AlertType.Fall, 1)
        assertFalse(alert.gps.signal)
        assertEquals(STATE.gps.lat, alert.gps.lat, 0.0)
    }

    @Test
    fun aMutableContactListChangedLaterDoesNotChangeTheAlert() {
        val contacts = mutableListOf(Contact("Test", Relationship.Son, "555-0199"))
        val alert = buildAlertPayload(STATE, AlertType.Fall, 1, contacts)
        contacts.clear()
        assertEquals(1, alert.contacts.size)
    }

    @Test
    fun theDemoContactsAreTheWebOnesTwoOrThreeAllComplete() {
        assertEquals(listOf("Ana Ejemplo", "Luis Ejemplo", "Dra. Prueba"), ContactsConfig.CONTACTS.map { it.name })
        assertTrue(ContactsConfig.CONTACTS.size in 2..3)
        for (contact in ContactsConfig.CONTACTS) {
            assertTrue(contact.name.isNotBlank())
            assertTrue(contact.phone, contact.phone.matches(Regex("^555-01\\d\\d$")))
        }
    }
}
