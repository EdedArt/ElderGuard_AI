import Toybox.Lang;

// Mirrors src/config/fallDetection.config.js (FallDetectionConfig.kt in wear-app) and the fall
// detection table of the root README. Keep them in sync.
module FallDetectionConfig {
    // Smallest magnitude, in g, that counts as an impact.
    const IMPACT_THRESHOLD_G = 2.5d;

    // Largest distance from 1 g, in g, that still counts as lying still.
    const IMMOBILITY_TOLERANCE_G = 0.15d;

    // How long the stillness must last to confirm a fall.
    const IMMOBILITY_DURATION_MS = 5000;

    // Longest time after the impact for the stillness to begin.
    const IMMOBILITY_START_WINDOW_MS = 3000;

    // Time the person has to cancel before the alert goes out.
    const COUNTDOWN_SECONDS = 10;

    // Last seconds of the countdown, when the alert becomes more insistent.
    const URGENT_SECONDS = 3;
}
