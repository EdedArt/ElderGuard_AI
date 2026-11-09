import { fallDetectionConfig } from '../config/fallDetection.config.js';
import { telemetryConfig } from '../config/telemetry.config.js';

const SPIKE = { x: 2.5, y: 1.8, z: 3.2 }; // About 4.4 g, well over the impact threshold
const STILL = { x: 0, y: 0, z: 1 };

// Injects a fall through the engine overrides, so the real detector runs from start to end.
export function createFallSimulation({
  engine,
  detection = fallDetectionConfig,
  telemetry = telemetryConfig,
}) {
  let releaseTimer = null;

  return {
    simulateFall() {
      if (!engine.isRunning()) {
        console.warn('simulateFall: tap the start button on the watch first.');
        return false;
      }

      clearTimeout(releaseTimer);
      engine.setOverride('accelerometer', SPIKE);
      engine.setOverride('accelerometer', STILL);
      // Long enough for the stillness to be confirmed, whatever the tick timing.
      releaseTimer = setTimeout(
        () => engine.clearOverride('accelerometer'),
        detection.immobilityDurationMs + telemetry.tickIntervalMs * 2,
      );
      return true;
    },
  };
}
