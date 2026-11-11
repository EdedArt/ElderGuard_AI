package com.elderguard.ai.config

// Mirrors src/config/fallDetection.config.js in the web app. Keep both in sync.
object FallDetectionConfig {
    /** Smallest magnitude, in g, that counts as an impact. */
    const val IMPACT_THRESHOLD_G = 2.5

    /** Largest distance from 1 g that still counts as lying still. */
    const val IMMOBILITY_TOLERANCE_G = 0.15

    /** How long the stillness must last to confirm a fall. */
    const val IMMOBILITY_DURATION_MS = 5000L

    /** Longest time after the impact for the stillness to begin. */
    const val IMMOBILITY_START_WINDOW_MS = 3000L

    /** Time the user has to cancel before the alert goes out. */
    const val COUNTDOWN_SECONDS = 10

    /** Last seconds of the countdown, when the alert becomes more insistent. */
    const val URGENT_SECONDS = 3
}
