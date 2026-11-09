export const fallDetectionConfig = {
  impactThresholdG: 2.5, // Smallest magnitude that counts as an impact
  immobilityToleranceG: 0.15, // Largest distance from 1 g that still counts as lying still
  immobilityDurationMs: 5000, // How long the stillness must last to confirm a fall
  immobilityStartWindowMs: 3000, // Longest time after the impact for the stillness to begin
  countdownSeconds: 10, // Time the user has to cancel before the alert goes out
  urgentSeconds: 3, // Last seconds of the countdown, when the alert becomes more insistent
};
