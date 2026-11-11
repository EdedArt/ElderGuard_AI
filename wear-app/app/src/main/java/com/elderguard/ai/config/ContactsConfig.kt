package com.elderguard.ai.config

import com.elderguard.ai.alerts.Contact
import com.elderguard.ai.alerts.Relationship

// Mirrors src/config/contacts.config.js in the web app. Keep both in sync.
// Fictional people, used only for the demo. The 555-01xx numbers are reserved for fiction.
object ContactsConfig {
    val CONTACTS: List<Contact> = listOf(
        Contact(name = "Ana Ejemplo", relationship = Relationship.Daughter, phone = "555-0101"),
        Contact(name = "Luis Ejemplo", relationship = Relationship.Son, phone = "555-0102"),
        Contact(name = "Dra. Prueba", relationship = Relationship.Doctor, phone = "555-0103"),
    )
}
