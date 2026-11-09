import { fallDetectionConfig } from '../config/fallDetection.config.js';
import { telemetryConfig } from '../config/telemetry.config.js';

const FALL_SPIKE = { x: 2.5, y: 1.8, z: 3.2 }; // About 4.4 g, well over the impact threshold
const STUMBLE_SPIKE = { x: 2.2, y: 1.2, z: 1.4 }; // About 2.9 g, just over the impact threshold
const STILL = { x: 0, y: 0, z: 1 };
// Walking: all clearly off 1 g, so none of them counts as lying still.
const MOVEMENT = [
  { x: 0.4, y: 0.5, z: 1.4 },
  { x: -0.5, y: 0.7, z: 1.2 },
  { x: 0.6, y: -0.4, z: 1.3 },
];

// Long enough for the audience to read "impact" on the panel before the detector moves on.
const SPIKE_HOLD_MS = 1000;

const HIGH_HEART_RATE_BPM = 140;
const LOW_BATTERY_LEVEL = 15;
const CRITICAL_BATTERY_LEVEL = 5;

const set = (atMs, sensor, value) => ({ atMs, setOverride: { sensor, value } });
const clear = (atMs, sensor) => ({ atMs, clearOverride: sensor });

// Scenarios with no final clear stay in force after ending, until something else clears them.
export function createScenarios({
  detection = fallDetectionConfig,
  telemetry = telemetryConfig,
} = {}) {
  const tickMs = telemetry.tickIntervalMs;

  // Each margin of two ticks makes the outcome independent of how the steps line up with the ticks.
  const fallEndMs = SPIKE_HOLD_MS + detection.immobilityDurationMs + tickMs * 2;
  const stumbleEndMs = SPIKE_HOLD_MS + detection.immobilityStartWindowMs + tickMs * 2;

  const movementSteps = [];
  for (let atMs = SPIKE_HOLD_MS; atMs < stumbleEndMs; atMs += tickMs) {
    const index = movementSteps.length % MOVEMENT.length;
    movementSteps.push(set(atMs, 'accelerometer', MOVEMENT[index]));
  }

  return {
    fall: {
      id: 'fall',
      steps: [
        set(0, 'accelerometer', FALL_SPIKE),
        set(SPIKE_HOLD_MS, 'accelerometer', STILL),
        clear(fallEndMs, 'accelerometer'),
      ],
    },

    // The generated readings count as lying still, so handing the sensor back too soon would turn
    // this into a fall. The movement must outlast the time the detector waits for stillness.
    stumble: {
      id: 'stumble',
      steps: [
        set(0, 'accelerometer', STUMBLE_SPIKE),
        ...movementSteps,
        clear(stumbleEndMs, 'accelerometer'),
      ],
    },

    highHeartRate: {
      id: 'highHeartRate',
      steps: [set(0, 'heartRate', HIGH_HEART_RATE_BPM), set(0, 'accelerometer', STILL)],
    },

    lowBattery: {
      id: 'lowBattery',
      steps: [set(0, 'battery', { level: LOW_BATTERY_LEVEL })],
    },

    criticalBattery: {
      id: 'criticalBattery',
      steps: [set(0, 'battery', { level: CRITICAL_BATTERY_LEVEL })],
    },

    gpsLost: {
      id: 'gpsLost',
      steps: [set(0, 'gps', { signal: false })],
    },
  };
}

export const scenarios = createScenarios();
