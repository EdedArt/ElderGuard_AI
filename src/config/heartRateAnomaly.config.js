import { fallDetectionConfig } from './fallDetection.config.js';

export const heartRateAnomalyConfig = {
  bpmThreshold: 120, // Heart rates above this count as high
  sustainedDurationMs: 8000, // How long it must stay high, at rest, before warning
  stillnessToleranceG: fallDetectionConfig.immobilityToleranceG, // Largest distance from 1 g at rest
};
