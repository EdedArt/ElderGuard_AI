import Toybox.Lang;

// Mirrors src/config/heartRateAnomaly.config.js (HeartRateAnomalyConfig.kt in wear-app) and the
// heart rate table of the root README. Keep them in sync.
module HeartRateAnomalyConfig {
    // Heart rates above this, in BPM, count as high. Exactly this value does not.
    const BPM_THRESHOLD = 120;

    // How long it must stay high, at rest, before warning.
    const SUSTAINED_DURATION_MS = 8000;

    // Largest distance from 1 g, in g, that counts as at rest: the same tolerance as the fall
    // detector's stillness.
    const STILLNESS_TOLERANCE_G = FallDetectionConfig.IMMOBILITY_TOLERANCE_G;

    // The same detection with a higher bar (criticalHeartRateConfig in the web app), for what is
    // serious enough to tell the family. Duration and stillness tolerance are the ones above.
    const CRITICAL_BPM_THRESHOLD = 160;
}
