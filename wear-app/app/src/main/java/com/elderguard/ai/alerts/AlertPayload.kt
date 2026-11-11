package com.elderguard.ai.alerts

import com.elderguard.ai.config.ContactsConfig
import com.elderguard.ai.telemetry.Gps
import com.elderguard.ai.telemetry.TelemetryState
import com.elderguard.ai.telemetry.batteryPercent

/** What an alert is about. [id] is the type string of the web app's payload. */
enum class AlertType(val id: String) {
    Fall("fall"),
    ManualSos("manual-sos"),
    HighHeartRate("high-heart-rate"),
}

/** The alert an SOS of this reason sends. */
val SosReason.alertType: AlertType
    get() = when (this) {
        SosReason.Fall -> AlertType.Fall
        SosReason.Manual -> AlertType.ManualSos
    }

/**
 * What the family would receive, with the same fields as the web app's payload. [heartRate] is in
 * BPM and [batteryLevel] is the whole percentage shown on the watch.
 *
 * Every field is immutable, so a recorded alert keeps saying what was true when it went out,
 * whatever happens to the state afterwards: no defensive copies are needed, unlike in JavaScript.
 */
data class AlertPayload(
    val type: AlertType,
    val timestamp: Long,
    val gps: Gps,
    val heartRate: Int,
    val batteryLevel: Int,
    val contacts: List<Contact>,
)

/**
 * Port of buildAlertPayload in src/core/alertPayload.js. Pure: reads [state] and returns a new
 * payload. The web version throws on an unknown reason; here [type] is an enum, so an unknown
 * one does not compile.
 */
fun buildAlertPayload(
    state: TelemetryState,
    type: AlertType,
    timestamp: Long,
    contacts: List<Contact> = ContactsConfig.CONTACTS,
): AlertPayload = AlertPayload(
    type = type,
    timestamp = timestamp,
    gps = state.gps,
    heartRate = state.heartRate.bpm,
    batteryLevel = batteryPercent(state.battery.level),
    // A read-only copy: a mutable list passed in cannot change the alert later.
    contacts = contacts.toList(),
)
