package com.elderguard.ai.config

// Mirrors src/config/sos.config.js in the web app. Keep both in sync.
object SosConfig {
    /** How long the SOS button must be held to call for help. */
    const val HOLD_DURATION_MS = 2000

    /** How long the "Mantén presionado" hint stays after a press that was too short. */
    const val HOLD_HINT_DURATION_MS = 2000L
}
