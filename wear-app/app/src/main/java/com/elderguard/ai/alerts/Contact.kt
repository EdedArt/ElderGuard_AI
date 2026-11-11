package com.elderguard.ai.alerts

/** Who an emergency contact is to the wearer: the keys of contacts.relationship in the web app. */
enum class Relationship { Daughter, Son, Doctor }

/** Someone the watch would tell when an alert goes out. Immutable, so alerts can share it safely. */
data class Contact(val name: String, val relationship: Relationship, val phone: String)
