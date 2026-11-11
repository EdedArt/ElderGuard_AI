package com.elderguard.ai.config

// Mirrors src/config/heartRateAnomaly.config.js in the web app. Keep both in sync.
object HeartRateAnomalyConfig {
    /** Heart rates above this, in BPM, count as high. */
    const val BPM_THRESHOLD = 120

    /** How long it must stay high, at rest, before warning. */
    const val SUSTAINED_DURATION_MS = 8000L

    /** Largest distance from 1 g at rest: the same tolerance as the fall detector's stillness. */
    const val STILLNESS_TOLERANCE_G = FallDetectionConfig.IMMOBILITY_TOLERANCE_G

    /**
     * The same detection with a higher bar (criticalHeartRateConfig in the web app), for what is
     * serious enough to tell the family. Duration and stillness tolerance are the ones above.
     */
    const val CRITICAL_BPM_THRESHOLD = 160
}
