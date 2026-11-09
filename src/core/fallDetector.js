import { fallDetectionConfig } from '../config/fallDetection.config.js';
import { createEventEmitter } from './eventEmitter.js';
import { magnitude } from './magnitude.js';

export const FALL_STATES = Object.freeze({
  IDLE: 'idle',
  IMPACT: 'impact',
  IMMOBILITY: 'immobility',
  CONFIRMED: 'confirmed',
});

const RESTING_MAGNITUDE_G = 1;

// A fall is an impact followed by stillness. Either one alone happens in daily life: clapping or
// bumping the wrist makes a spike, and resting makes stillness. Time comes from the samples, so
// the detector needs no clock and every scenario can be replayed in a test.
export function createFallDetector({ config = fallDetectionConfig } = {}) {
  const emitter = createEventEmitter();
  let state = FALL_STATES.IDLE;
  let impactAt = null;
  let stillSince = null;

  const processAfterImpact = (still, timestamp) => {
    if (timestamp - impactAt > config.immobilityStartWindowMs) {
      state = FALL_STATES.IDLE;
    } else if (still) {
      state = FALL_STATES.IMMOBILITY;
      stillSince = timestamp;
    }
  };

  const processImmobility = (still, timestamp) => {
    if (!still) {
      state = FALL_STATES.IDLE;
    } else if (timestamp - stillSince >= config.immobilityDurationMs) {
      state = FALL_STATES.CONFIRMED;
      emitter.emit('confirmed');
    }
  };

  return {
    process({ accelerometer, timestamp }) {
      if (state === FALL_STATES.CONFIRMED) return;

      const value = magnitude(accelerometer);
      // Checked first in every state: a new blow restarts the sequence from that moment, so a
      // person who stumbles and then falls for real is still detected.
      if (value >= config.impactThresholdG) {
        state = FALL_STATES.IMPACT;
        impactAt = timestamp;
        return;
      }

      const still = Math.abs(value - RESTING_MAGNITUDE_G) <= config.immobilityToleranceG;
      if (state === FALL_STATES.IMPACT) processAfterImpact(still, timestamp);
      else if (state === FALL_STATES.IMMOBILITY) processImmobility(still, timestamp);
    },

    getState: () => state,

    reset() {
      state = FALL_STATES.IDLE;
    },

    onConfirmed: (listener) => emitter.on('confirmed', listener),
  };
}
